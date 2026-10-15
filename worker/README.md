# bridgewood-mail worker

Cloudflare Worker that receives mail through Email Routing, stores it in D1 (with R2 for attachments and images), sends mail through the Email Service binding, and pushes new mail to the app through OneSignal.

Live: `https://bridgewood-mail.uririnathaniel.workers.dev` (check `GET /health`).

## Setup

Requires Node 20+ and a Cloudflare account that owns the `ALLOWED_DOMAIN` zone.

```sh
npm install
npx wrangler login

npx wrangler d1 create bridgewood-mail          # put the database_id into wrangler.jsonc
npx wrangler r2 bucket create bridgewood-mail
npm run db:init                                 # applies schema.sql to the remote D1

npx wrangler secret put API_KEYS                # comma separated, e.g. key-phone,key-laptop
npx wrangler secret put ONESIGNAL_APP_ID
npx wrangler secret put ONESIGNAL_REST_KEY

npm run deploy
```

### Another domain

Each domain runs the same code as its own worker, declared as a wrangler environment with its own D1, R2 and vars. `uriri.com.ng` is `--env uriri` (worker `uriri-mail`):

```sh
npx wrangler d1 execute uriri-mail --remote --file=schema.sql --env uriri
npx wrangler secret put API_KEYS --env uriri    # likewise ONESIGNAL_APP_ID, ONESIGNAL_REST_KEY, CF_API_TOKEN
npx wrangler deploy --env uriri
```

Set `PUBLIC_HOST` in `wrangler.jsonc` to the host the app uses (workers.dev or a custom domain). Pushes carry it so the app can open the right account. If it is empty, the worker uses the host of the last `/health` or `/senders` call.

### Email Routing (receiving)

1. Dashboard: your zone, Email, Email Routing, enable it and let it add the MX and SPF records.
2. Routing rules: add a custom address (e.g. `admin@`) or edit the catch-all, action **Send to a Worker**, worker `bridgewood-mail`.

Already set up on `bridgewoodinvestment.ng`: `admin@`, `info@`, `support@` and `noreply@` go to the worker; the catch-all is left as it was.

### Routing

Email Routing only delivers to the worker the addresses that have a rule pointing at it; everything else follows the zone's catch-all. So every address the app uses gets its own rule automatically: the addresses a phone links (`PUT /devices`) and every From address the worker sends from. An address that already has a rule pointing elsewhere is left alone, and handled addresses are remembered in `routed_addresses`.

### Catch-all override

`PUT /routing/catch-all {"toWorker": true}` points the zone's catch-all at the worker and saves the previous rule; `{"toWorker": false}` restores it. `GET /routing/catch-all` reports the current state. Both features need:

```sh
# Cloudflare dashboard, My Profile or Account, API Tokens, Create token:
# permissions Zone > Email Routing Rules > Edit, limited to this zone.
npx wrangler secret put CF_API_TOKEN
npx wrangler secret put ROUTING_KEYS   # optional: only these API keys may change routing
```

`CF_ZONE_ID` is set in `wrangler.jsonc`. On the live worker `CF_API_TOKEN` and the OneSignal secrets are already set.

### Email Service (sending)

1. Dashboard: Compute, Email Service, onboard the sending domain and add the DNS records it lists (SPF, DKIM, DMARC).
2. The `send_email` binding `EMAIL` is already declared. Errors such as `E_SENDER_NOT_VERIFIED` mean the domain is not onboarded yet.

### OneSignal

1. Create an app at onesignal.com, add Android (Firebase service account JSON) and iOS (APNs .p8 key).
2. Settings, Keys and IDs: copy the App ID and create a REST API key, then set both secrets above.
3. Put the same App ID in the Flutter app config.

Each new mail notifies the phones registered for the mailbox that received it (`PUT /devices/:deviceId`), with one notification per conversation, so a busy thread updates in place instead of stacking. The payload carries the sender, subject, mailbox address and that mailbox's last few messages of the thread, which the app renders as a Gmail-style notification. Notifications are grouped per mailbox with an "N new emails" summary, and mail that arrives within 60 seconds of earlier mail to the same mailbox is delivered quietly (no sound on Android, `passive` on iOS), so a burst rings once. The `existing_android_channel_id` is `mail`, a high-importance channel the app creates.

### Unread reminders

A cron trigger (every 30 minutes, free on Workers) pushes unread inbox mail again: an hour after it arrived, and once more a day later, never more than twice and only for mail from the last three days. Each mailbox gets one notification: a single conversation comes back as itself (with Archive, Mark as read and Reply), several come as a list of senders and subjects. Phones send their UTC offset with `PUT /devices/:deviceId`, so reminders wait for 8:00 to 21:00 on the phone's clock, and `remind: false` turns them off for that phone.

### Live updates

While the app is open it holds a WebSocket to `GET /live` (with `Authorization` and `X-Mailbox`), served by a `MailboxHub` Durable Object per mailbox. Every change to a mailbox (new mail, a send, a reaction, a read, archive or label change, a notification action) bumps the hub's version and sends `{"version": n}` down every socket, and a new socket gets the current version straight away, so the app refreshes only when something changed. Sockets use the hibernation API: an idle connection costs no duration, server messages and protocol pings are free, and each change costs one small request, well inside the free plan's 100,000 a day. `wrangler deploy` creates the SQLite-backed class from `migrations`.

## Mailboxes

Every stored message records which addresses own it (`message_owners`): the delivered-to address and the To and Cc addresses of received mail, and the From address (plus the sending account) of sent mail. A request with an `X-Mailbox: <address>` header only sees that mailbox: Inbox is what it received, Sent is what it sent, and search, labels, counts and threads follow the same rule. Mail between two addresses on the domain is stored once when sent, and its delivery adds the recipient's copy. Requests without the header see everything, as before. Applying `schema.sql` again gives existing mail its owners.

Lists are conversations, as in Gmail: `GET /messages` returns one row per thread that has mail in the folder, showing the thread's newest message (so a reply of yours brings it back to the top), with `participants` (who wrote, in order, `me` for the mailbox) and thread-wide `read`, `starred` and `hasAttachments`. Sent, Trash and Spam show the newest message that is in them. `PATCH /threads/:id` acts on every message of the conversation the mailbox can see.

## Reactions

Emoji reactions use Gmail's format, so they show as reactions in Gmail and as a short email elsewhere: a reply whose `multipart/alternative` carries a `text/vnd.google.email-reaction+json` part (`{"emoji","version":1}`) between the plain text and HTML, with `In-Reply-To` naming the message. Incoming reaction emails are stored as reactions on that message (and pushed quietly) instead of as new mail. `POST /messages/:id/react` sends one to everyone on the message, at most 20 people, when the mailbox is the sender or in To or Cc.

## Other databases

`src/db.js` exposes `all`, `first`, `run`, `batch`. D1 is the default. Set `DB_DRIVER=libsql` with `LIBSQL_URL` and secret `LIBSQL_TOKEN` to use Turso/libSQL over HTTP (apply `schema.sql` there). Add another driver by returning the same four functions; the schema uses SQLite FTS5 for search.

## API

All routes except `/health`, `/img/:key` and `/actions` need `Authorization: Bearer <key>`. JSON in and out, CORS open. Send `X-Mailbox: <address>` to scope a request to one mailbox.

| Route | Notes |
|---|---|
| `GET /health` | `{ok, service, version, domain, routes, checks:{db,r2,email,onesignal}}` |
| `GET /messages?label=&q=&unread=&cursor=` | label defaults to `inbox`; also `starred`, `all`, label ids. Returns `{messages, nextCursor}` |
| `GET /messages/:id`, `GET /threads/:id` | full bodies and attachment metadata |
| `PATCH /messages/:id` | `{read, starred, archived, labels[]}` |
| `PATCH /threads/:id` | `{read, starred, archived, add[], remove[]}` for the whole conversation; `starred: true` stars its newest message, `archived: false` puts received mail back in the inbox |
| `POST /messages/:id/react` | `{emoji, fromName}`: sends a Gmail-style reaction, returns the message's `reactions` |
| `POST /messages/:id/reply` | `{from, fromName, html, text, cc, bcc, attachments, replyAll}` |
| `POST /send` | `{from, fromName, to[], cc[], bcc[], subject, html, text, attachments[{filename,type,content(base64)}], inReplyTo, clientKey}`. A repeated `clientKey` (the app's outbox id) returns the first send instead of sending again; the same holds for `/messages/:id/reply` |
| `GET /live` | WebSocket upgrade for live updates of the `X-Mailbox` mailbox; see Live updates |
| `GET /attachments/:id` | raw file |
| `GET/POST /labels`, `PATCH/DELETE /labels/:id` | system labels: inbox, sent, spam, trash |
| `GET /senders` | from `SENDERS` var (local parts) or admin, info, support, noreply. With `X-Mailbox`, also `name`: what that address last sent as, or else what others last wrote to it as |
| `/templates`, `/signatures` | `GET`, `POST`, `GET/PATCH/DELETE /:id` |
| `POST /uploads` | image (raw body or multipart `file`), returns `{key, url}` |
| `GET /img/:key` | public image for use inside sent mail |
| `GET/PUT /routing/catch-all` | `{toWorker}`; see Catch-all override |
| `POST /push/test` | `{device}`: sends a sample notification to one phone the same way new mail is sent, returns the mailboxes linked to it, or OneSignal's error if it cannot be delivered |
| `PUT /devices/:deviceId` | `{addresses[], subscriptionId, utcOffset, remind}`: the mailboxes this phone is notified for (replaces the list). Phones sign in to OneSignal with the device id as their External ID, so pushes target the phone, and the worker deletes the push subscriptions earlier installs left on it, keeping `subscriptionId` |
| `POST /actions/:threadId/:action` | public, `{token, address}` from the push payload (the token is good for 30 days); `read` or `archive` that mailbox's copy of the conversation from a notification button, or `reply` with `{text, messageId}` to answer from the notification |
