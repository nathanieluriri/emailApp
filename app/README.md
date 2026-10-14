# Quirepost

Quirepost is the Flutter client (Android and iOS) for the `bridgewood-mail` Cloudflare worker in `../worker`. It follows Gmail's mobile layout, uses Quire's colours, type, motion and haptics, and supports several worker accounts.

## Run

Requires Flutter 3.47+ (Dart 3.13).

```sh
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # json_serializable and drift code
flutter run   # OneSignal App ID is set in lib/core/config.dart; override with --dart-define=ONESIGNAL_APP_ID=...
flutter analyze && flutter test
flutter test test/screens --update-goldens   # re-render the screen screenshots in test/screens/goldens (light and dark)
flutter test test/brand --update-goldens     # re-render the mark the launcher icons are cut from
```

Adding an account works like Outlook: enter your email, then the worker's access key, then the display name recipients see next to your address. A custom worker is under "Use a custom server".

The default worker URL lives in `lib/core/config.dart` (`https://bridgewood-mail.<SUBDOMAIN>.workers.dev`, subdomain `uririnathaniel`). Onboarding checks it through `GET /health`, then asks for one of the worker's `API_KEYS` and verifies it with `GET /senders`. A custom worker must pass every route and check in the list, or onboarding says exactly what is missing.

## OneSignal

Push is required: new mail is pushed by the worker, and tapping a push opens the right account and thread.

1. Create an app at onesignal.com.
2. **Android:** in Firebase, create a project, add an Android app with package `ng.bridgewoodinvestment.bridgewood_mail`, download a service account JSON (Project settings, Service accounts) and upload it to OneSignal (Settings, Push and in-app, Google Android FCM).
3. **iOS:** in the Apple developer portal create an APNs auth key (.p8), and upload it with the Key ID and Team ID to OneSignal (Apple iOS). In Xcode, open `ios/Runner.xcworkspace`, add the **Push Notifications** capability and **Background Modes** (Remote notifications, Background fetch, Background processing).
4. The App ID is in `lib/core/config.dart`. The worker holds the same App ID plus a REST API key (`ONESIGNAL_APP_ID`, `ONESIGNAL_REST_KEY`, already set).

How a push looks on Android: `MailNotificationExtension` (a OneSignal service extension in `android/app/src/main/kotlin`) restyles every mail push before it shows. It uses the Quirepost mark as the status bar icon (`ic_stat_onesignal_default`), the brand accent, the high-importance `mail` channel (sound and heads-up), a letter avatar for the sender in the same colours as the app, the account address as the header subtext, the subject and preview, and the last few messages of the conversation when it is a thread. Archive and Mark as read call the worker's `/actions` route in the background, and Reply opens the reply screen. A private version hides the content on the lock screen.

Checking a phone: Settings, Notifications shows whether push is allowed, paused or still waiting for a push ID, sends a test notification through the worker, and shows the Push ID to search for in OneSignal (Audience, Subscriptions). The inbox shows a card to turn notifications on while they are off ("Not now" hides it for three days). If the test reports that the phone is not subscribed while notifications are allowed, the Firebase service account is missing from OneSignal (step 2).

Devices are tagged `worker_host=<active account host>` and `wh_<host>=1` for every saved account; removing an account removes its tag.

## Worker

See `../worker/README.md` for D1, R2, Email Routing, Email Service and secrets. Deploy it before onboarding.

## Layout

`lib/` is split by feature: `core` (config, API client, drift cache, theme, motion, Quire's copied theme and widgets under `core/quire`), `accounts`, `notifications`, `mail`, `compose`, `builder`, `templates`, `signatures`, `settings`.

- Offline: inbox lists and threads are cached in drift and shown first; drafts autosave locally.
- Reminders: a workmanager task (default every 30 minutes, adjustable or off in Settings) checks unread mail and only notifies when OneSignal push is off, plus one daily reminder when unread mail is waiting.
