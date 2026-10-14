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

Set `PUBLIC_HOST` in `wrangler.jsonc` to the host the app uses (workers.dev or a custom domain). Push notifications target devices tagged `worker_host=<PUBLIC_HOST>`. If it is empty, the worker uses the host of the last `/health` or `/senders` call.

### Email Routing (receiving)

1. Dashboard: your zone, Email, Email Routing, enable it and let it add the MX and SPF records.
2. Routing rules: add a custom address (e.g. `admin@`) or edit the catch-all, action **Send to a Worker**, worker `bridgewood-mail`.

### Email Service (sending)

1. Dashboard: Compute, Email Service, onboard the sending domain and add the DNS records it lists (SPF, DKIM, DMARC).
2. The `send_email` binding `EMAIL` is already declared. Errors such as `E_SENDER_NOT_VERIFIED` mean the domain is not onboarded yet.

### OneSignal

1. Create an app at onesignal.com, add Android (Firebase service account JSON) and iOS (APNs .p8 key).
2. Settings, Keys and IDs: copy the App ID and create a REST API key, then set both secrets above.
3. Put the same App ID in the Flutter app config.

## Other databases

`src/db.js` exposes `all`, `first`, `run`, `batch`. D1 is the default. Set `DB_DRIVER=libsql` with `LIBSQL_URL` and secret `LIBSQL_TOKEN` to use Turso/libSQL over HTTP (apply `schema.sql` there). Add another driver by returning the same four functions; the schema uses SQLite FTS5 for search.

## API

All routes except `/health` and `/img/:key` need `Authorization: Bearer <key>`. JSON in and out, CORS open.

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
