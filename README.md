# Rounds

A personal bill tracker for mobile. Every month is a new round of the same recurring obligations — Rounds helps you stay on top of them.

No more sticky notes, spreadsheets, or trying to remember if you paid the internet bill. Set up each bill once and Rounds reminds you when it's coming up, due today, or overdue — you don't even need to open the app. And when you do, you know exactly where you stand.

Not an expense tracker. Not a budget app. Just a simple, focused tool for knowing which bills you've paid this month and which ones are still waiting.

---

## Features

- **Recurring bills** — set up each bill once with a name, optional amount, and due day. They show up automatically every month, and reminders come with them — no monthly setup.
- **Bill reminders** — notifications 2 days and 1 day before each due date, on the due date, and daily while a bill is overdue. Set it once and the app keeps you on track without you having to open it.
- **Mark as paid** — record payment date, method, amount paid, and a reference note. Or just tap and go.
- **Monthly view** — pending bills at the top, paid ones below. Clean, at-a-glance status.
- **History** — browse past months you've had activity in.
- **Backup & restore** — export your full data as JSON and import it back anytime.
- **Fully offline** — no accounts, no cloud, no tracking. Everything stays on your device.

## Stack

- [Flutter](https://flutter.dev) + Dart
- [Drift](https://drift.simonbinder.eu) — type-safe SQLite ORM
- [Riverpod](https://riverpod.dev) — state management
- [go_router](https://pub.dev/packages/go_router) — navigation
- Material Design 3

## Getting Started

```bash
git clone https://github.com/yourusername/rounds.git
cd rounds
flutter pub get
dart run build_runner build
flutter run
```

## License

MIT — see [LICENSE](LICENSE).
