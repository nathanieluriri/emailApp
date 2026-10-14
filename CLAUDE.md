# emailApp

An email client modeled on Gmail's design.

## Design references

- `design/gmail/web/`: wide (desktop) layouts: inbox tabs, promotions, sent and spam search, thread view (collapsed and expanded), HTML message, spam message.
- `design/gmail/mobile/`: narrow (phone, dark theme) layouts: primary inbox, promotions, navigation drawer, thread view and overflow menu, reply compose, snooze tip, sent and starred filters.

Match these references for layout, spacing, and behavior before inventing new UI.

## Working rules

- Code is self-documenting. No comments unless they explain a non-obvious reason, workaround, or hidden constraint.
- Separate concerns: keep UI, state, and data access in their own layers.
- Repeating a little code is fine. Abstract only when it clearly pays off.
- Write the least code that does the job well. No speculative features.
- Prefer free, open-source, already-available tools. Add dependencies only when they clearly pay for themselves.
- Never use em dashes in code, comments, docs, or commit messages.
- No AI attribution anywhere (commits, PRs, code, docs).
