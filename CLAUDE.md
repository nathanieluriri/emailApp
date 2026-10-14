# emailApp

Quirepost: an email client modeled on Gmail's design, with Quire's branding and motion. The mark is Quire's four panes with the last one folded into an envelope (`app/lib/core/brand.dart`).

## Projects

- `worker/`: Cloudflare Worker (`bridgewood-mail`): inbound mail, D1 storage, R2 files, sending, OneSignal push, REST API. Deploy with `npx wrangler deploy`.
- `app/`: Flutter app (Android and iOS), Riverpod, go_router, dio, drift. Run `flutter analyze` and `flutter test` before committing. After any UI change, re-render `flutter test test/screens --update-goldens` and look at the light and dark PNGs.
- Quire's theme, widgets and painters are copied into `app/lib/core/quire/` from `nathanieluriri/Mobile-experiments-flutter/quire`. Reuse them before writing new UI. Every tap gets a `Feel` haptic.

## Design references

- `design/gmail/web/`: wide (desktop) layouts: inbox tabs, promotions, sent and spam search, thread view (collapsed and expanded), HTML message, spam message.
- `design/gmail/mobile/`: narrow (phone, dark theme) layouts: primary inbox, promotions, spam, navigation drawer, thread view and overflow menus, spam message, reply compose, snooze tip, toast, sent and starred filters.

Match these references for layout, spacing, and behavior before inventing new UI.

## Working rules

- Code is self-documenting. No comments unless they explain a non-obvious reason, workaround, or hidden constraint.
- Separate concerns: keep UI, state, and data access in their own layers.
- Repeating a little code is fine. Abstract only when it clearly pays off.
- Write the least code that does the job well. No speculative features.
- Prefer free, open-source, already-available tools. Add dependencies only when they clearly pay for themselves.
- Never use em dashes in code, comments, docs, or commit messages.
- No AI attribution anywhere (commits, PRs, code, docs).
