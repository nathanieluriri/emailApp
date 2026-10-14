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

Set `PUBLIC_HOST` in `wrangler.jsonc` to the host the app uses (workers.dev or a custom domain). Pushes carry it so the app can open the right account. If it is empty, the worker uses the host of the last `/health` or `/senders` call.

### Email Routing (receiving)

1. Dashboard: your zone, Email, Email Routing, enable it and let it add the MX and SPF records.
2. Routing rules: add a custom address (e.g. `admin@`) or edit the catch-all, action **Send to a Worker**, worker `bridgewood-mail`.

Already set up on `bridgewoodinvestment.ng`: `admin@`, `info@`, `support@` and `noreply@` go to the worker; the catch-all is left as it was.

### Catch-all override

`PUT /routing/catch-all {"toWorker": true}` points the zone's catch-all at the worker and saves the previous rule; `{"toWorker": false}` restores it. `GET /routing/catch-all` reports the current state. It needs:

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

Each new mail notifies the phones registered for the mailbox that received it (`PUT /devices/:subscriptionId`), with one notification per conversation, so a busy thread updates in place instead of stacking. The payload carries the sender, subject, mailbox address and that mailbox's last few messages of the thread, which the app renders as a Gmail-style notification. Notifications are grouped per mailbox with an "N new emails" summary, and mail that arrives within 60 seconds of earlier mail to the same mailbox is delivered quietly (no sound on Android, `passive` on iOS), so a burst rings once. The `existing_android_channel_id` is `mail`, a high-importance channel the app creates.

## Mailboxes

Every stored message records which addresses own it (`message_owners`): the delivered-to address and the To and Cc addresses of received mail, and the From address (plus the sending account) of sent mail. A request with an `X-Mailbox: <address>` header only sees that mailbox: Inbox is what it received, Sent is what it sent, and search, labels, counts and threads follow the same rule. Mail between two addresses on the domain is stored once when sent, and its delivery adds the recipient's copy. Requests without the header see everything, as before. Applying `schema.sql` again gives existing mail its owners.

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
| `POST /messages/:id/reply` | `{from, fromName, html, text, cc, bcc, attachments, replyAll}` |
| `POST /send` | `{from, fromName, to[], cc[], bcc[], subject, html, text, attachments[{filename,type,content(base64)}], inReplyTo}` |
| `GET /attachments/:id` | raw file |
| `GET/POST /labels`, `PATCH/DELETE /labels/:id` | system labels: inbox, sent, spam, trash |
| `GET /senders` | from `SENDERS` var (local parts) or admin, info, support, noreply |
| `/templates`, `/signatures` | `GET`, `POST`, `GET/PATCH/DELETE /:id` |
| `POST /uploads` | image (raw body or multipart `file`), returns `{key, url}` |
| `GET /img/:key` | public image for use inside sent mail |
| `GET/PUT /routing/catch-all` | `{toWorker}`; see Catch-all override |
| `POST /push/test` | `{subscriptionId}`: sends a sample notification to one device and returns OneSignal's error if it cannot be delivered |
| `PUT /devices/:subscriptionId` | `{addresses[]}`: the mailboxes this OneSignal subscription is notified for (replaces the list) |
| `POST /actions/:threadId/:action` | public, `{token, address}` from the push payload; `read` or `archive` that mailbox's copy of the conversation from a notification button |
