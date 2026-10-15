# Bridgewood Mail

A self-hosted email client: a Cloudflare Worker that receives, stores and sends mail for your domain, plus a Flutter app for Android and iOS that reads it, with push notifications for new mail.

This guide takes you from nothing to a working inbox on your phone: deploy your own worker, create its API keys and secrets, then build the app.

- `worker/`: Cloudflare Worker (inbound mail, D1 database, R2 files, sending, OneSignal push, REST API). API reference in [`worker/README.md`](worker/README.md).
- `app/`: Flutter app. Development notes in [`app/README.md`](app/README.md).

## How it fits together

```
sender ──> Cloudflare Email Routing ──> worker ──> D1 (mail) + R2 (attachments)
                                          │
                                          └──> OneSignal ──> FCM / APNs ──> phone
app ──(HTTPS + API key)──> worker ──> Cloudflare Email Service ──> recipient
```

The app talks only to your worker. The worker keeps your mail in your own Cloudflare account.

## What you need

| Item | Used for | Cost |
|---|---|---|
| A domain whose DNS is on Cloudflare | receiving and sending mail | the domain itself |
| Cloudflare account | Worker, D1, R2, Email Routing, Email Service | free tiers cover personal use; check current Email Service pricing |
| OneSignal account | push notifications | free tier |
| Firebase project | Android push (through OneSignal) | free |
| Apple Developer account | iOS only: push and installing on devices | paid yearly |
| Node.js 20+ | deploying the worker | free |
| Flutter 3.47+ (Dart 3.13) and Android SDK | building the APK | free |
| A Mac with Xcode | iOS only | |

Push is required: the app's onboarding refuses a worker whose OneSignal check fails, so set up OneSignal before you test.

## 1. Get the code

```sh
git clone https://github.com/nathanieluriri/emailApp.git
cd emailApp
```

## 2. Deploy the worker

### 2.1 Install and log in

```sh
cd worker
npm install
npx wrangler login
```

### 2.2 Create the database and file bucket

```sh
npx wrangler d1 create bridgewood-mail
npx wrangler r2 bucket create bridgewood-mail
```

`d1 create` prints a `database_id`. Keep it for the next step.

If R2 asks you to enable it first, do that in the dashboard (R2 Object Storage) and run the command again.

### 2.3 Point the config at your account

Open `worker/wrangler.jsonc` and replace the values that belong to the original deployment:

```jsonc
"d1_databases": [
  { "binding": "DB", "database_name": "bridgewood-mail", "database_id": "<your database_id>" }
],
"vars": {
  "ALLOWED_DOMAIN": "<yourdomain.com>",
  "PUBLIC_HOST": "",
  "CF_ZONE_ID": "<your zone id>"
}
```

| Var | Meaning |
|---|---|
| `ALLOWED_DOMAIN` | The domain you send from. The worker only sends from addresses on this domain. |
| `PUBLIC_HOST` | Host the app uses to reach the worker, for example `bridgewood-mail.<subdomain>.workers.dev`. Push notifications are targeted by this host. Leave it empty until you know the URL (step 2.6); the worker then uses the host of the last `/health` call. |
| `CF_ZONE_ID` | Your domain's zone ID (dashboard, your domain, Overview, right column). Only needed for the catch-all switch. |
| `SENDERS` (optional) | Comma-separated local parts offered as From addresses, e.g. `me,hello,support`. Default: `admin,info,support,noreply`. |
| `WORKER_NAME` (optional) | Set this if you rename the worker in `name`, so the catch-all switch recognises it. |

If you rename the database, also change the name in the `db:init` script in `worker/package.json`.

### 2.4 Create the tables

```sh
npm run db:init
```

### 2.5 Set the secrets

Secrets are stored encrypted by Cloudflare and never live in the repo. Each command prompts for the value.

```sh
npx wrangler secret put API_KEYS
npx wrangler secret put ONESIGNAL_APP_ID
npx wrangler secret put ONESIGNAL_REST_KEY
npx wrangler secret put CF_API_TOKEN      # optional, for the catch-all switch
npx wrangler secret put ROUTING_KEYS      # optional
```

| Secret | Required | Where it comes from |
|---|---|---|
| `API_KEYS` | yes | You make these up. Comma-separated, one per device or person, e.g. `key-phone,key-laptop`. Use long random values: `openssl rand -hex 32`. The app asks for one during onboarding. Remove a key from the list to revoke that device. |
| `ONESIGNAL_APP_ID` | yes | OneSignal, step 3. |
| `ONESIGNAL_REST_KEY` | yes | OneSignal, step 3. |
| `CF_API_TOKEN` | no | Cloudflare dashboard, My Profile, API Tokens, Create Token, custom token with **Zone, Email Routing Rules, Edit** on your zone only. Lets the app point the catch-all address at the worker. |
| `ROUTING_KEYS` | no | A subset of `API_KEYS` that may change the catch-all. If unset, any API key can. |

You can deploy now and add the OneSignal secrets after step 3; secrets apply immediately without redeploying.

### 2.6 Deploy

```sh
npm run deploy
```

Wrangler prints the worker URL, e.g. `https://bridgewood-mail.<subdomain>.workers.dev`. Put its host in `PUBLIC_HOST` in `wrangler.jsonc` and deploy again.

Check it:

```sh
curl https://bridgewood-mail.<subdomain>.workers.dev/health
```

Every entry in `checks` should be `true`. `onesignal: false` means the OneSignal secrets are missing; `email: false` means the `send_email` binding is not available on your account yet.

### 2.7 Receive mail (Email Routing)

1. Dashboard, your domain, Email, Email Routing: enable it and let it add the MX and SPF records.
2. Routing rules: add a custom address (e.g. `me@yourdomain.com`) with action **Send to a Worker**, worker `bridgewood-mail`. Repeat for each address you want in the app.
3. Optional: send everything to the worker by editing the catch-all rule the same way, or later from the app if `CF_API_TOKEN` is set.

Remove any existing MX records from another mail provider first, or mail keeps going there.

### 2.8 Send mail (Email Service)

1. Dashboard, Compute, Email Service: onboard your domain and add the DNS records it lists (SPF, DKIM, DMARC).
2. Wait for the records to verify. Until then sending fails with `E_SENDER_NOT_VERIFIED`.

Test with the API key you set:

```sh
curl -X POST https://bridgewood-mail.<subdomain>.workers.dev/send \
  -H "authorization: Bearer <one of your API_KEYS>" \
  -H "content-type: application/json" \
  -d '{"from":"me@yourdomain.com","to":["you@example.com"],"subject":"Hello","text":"It works"}'
```

## 3. Set up push notifications

The worker tells OneSignal about new mail, and OneSignal delivers it through Firebase (Android) and APNs (iOS). The app and the worker must use the **same OneSignal app**.

### 3.1 OneSignal app

1. Sign up at onesignal.com and create an app.
2. Settings, Keys and IDs: copy the **App ID** and create a **REST API key**.
3. Put both in the worker: `npx wrangler secret put ONESIGNAL_APP_ID` and `npx wrangler secret put ONESIGNAL_REST_KEY`.

The REST API key can send pushes to all your users. Keep it only in the worker secret.

### 3.2 Android (Firebase)

1. In the Firebase console, create a project. Adding an Android app to it is optional; the app does not read `google-services.json`.
2. Project settings, **Service accounts**, **Generate new private key**. This downloads a JSON file.
3. In OneSignal: Settings, Push and In-App, **Google Android (FCM)**, upload that JSON.

The service account JSON is a credential with admin rights on your Firebase project. Do not commit it or share it.

### 3.3 iOS (APNs)

1. Apple Developer portal, Certificates, Identifiers and Profiles, Keys: create a key with **Apple Push Notifications service (APNs)**. Download the `.p8` (you can only download it once) and note the Key ID and your Team ID.
2. In OneSignal: Settings, Push and In-App, **Apple iOS (APNs)**, upload the `.p8` with the Key ID, Team ID and the app's bundle ID.
3. In Xcode (`app/ios/Runner.xcworkspace`), Runner target, Signing and Capabilities: select your team and add **Push Notifications**.

## 4. Build the app

### 4.1 Install the toolchain

Install Flutter (3.47+) and Android Studio (for the Android SDK), then:

```sh
flutter doctor            # fix anything it reports for Android
flutter doctor --android-licenses
cd app
flutter pub get
```

Generated code (`*.g.dart`) is committed. Only after changing models run `dart run build_runner build --delete-conflicting-outputs`.

### 4.2 Use your own OneSignal App ID

The App ID is compiled into the app. Pass yours at build time:

```sh
--dart-define=ONESIGNAL_APP_ID=<your OneSignal App ID>
```

or change the default in `app/lib/core/config.dart`. While you are there, set `workerSubdomain` to your workers.dev subdomain so onboarding suggests your worker by default (otherwise pick **Use custom worker** and type the URL).

### 4.3 Optional: your own package name

To install alongside the original app, or to publish it, change the Android `applicationId` and `namespace` in `app/android/app/build.gradle.kts`, and the iOS bundle identifier in Xcode.

### 4.4 Build an APK (Android)

```sh
cd app
flutter build apk --release --dart-define=ONESIGNAL_APP_ID=<your App ID>
```

Output: `app/build/app/outputs/flutter-apk/app-release.apk`. Copy it to the phone and open it (allow installs from unknown sources when asked). For smaller files, one per CPU type, add `--split-per-abi`.

The release build is signed with the debug key, which is fine for sideloading onto your own devices. For the Play Store, create an upload keystore and a release `signingConfig` ([Flutter guide](https://docs.flutter.dev/deployment/android#sign-the-app)), then build an app bundle with `flutter build appbundle --release`.

To run straight on a phone connected over USB instead: `flutter run --release --dart-define=ONESIGNAL_APP_ID=<your App ID>`.

### 4.5 Build for iOS

On a Mac, with the push capability from step 3.3:

```sh
cd app
flutter build ipa --release --dart-define=ONESIGNAL_APP_ID=<your App ID>
```

Upload the `.ipa` from `build/ios/ipa/` with Xcode's Organizer or Transporter to TestFlight. To install directly on your own iPhone, open `ios/Runner.xcworkspace` and run the Runner target on the device.

## 5. First run

1. Open the app. Onboarding checks the worker URL through `/health`; a custom worker must pass every route and check, or the app lists what is missing.
2. Enter one of your `API_KEYS`. The app verifies it with `/senders`.
3. Allow notifications.
4. Send an email to an address routed to the worker. It should appear in the inbox, and with the app in the background, a push should arrive within seconds.

You can add several workers as separate accounts. They all push to the same device as long as every worker uses the same OneSignal app as the app build.

## Troubleshooting

| Problem | Check |
|---|---|
| Onboarding says the worker is missing a check | `curl .../health` and fix the `false` entry (see 2.6). |
| `401` from the API | The key is not in `API_KEYS` (check for typos; the list is comma-separated). |
| Mail does not arrive | Email Routing rule points at the worker; MX records are Cloudflare's; `npx wrangler tail` while sending. |
| Sending fails | Email Service onboarding and DNS records (2.8); the From address must be on `ALLOWED_DOMAIN`. |
| No push | OneSignal, Audience, Subscriptions: is the device subscribed with a `worker_host` tag matching `PUBLIC_HOST`? Then `npx wrangler tail` and look for `push failed`. On iOS, confirm the Push Notifications capability. |
| No banner while the app is open | Expected: the app refreshes the inbox instead of showing a system notification. |

## Updating

```sh
git pull
cd worker && npm install && npm run deploy
cd ../app && flutter pub get && flutter build apk --release --dart-define=ONESIGNAL_APP_ID=<your App ID>
```

If `worker/schema.sql` changed, run `npm run db:init` again in `worker/`. It only creates what is missing.
