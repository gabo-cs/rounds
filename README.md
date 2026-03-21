# Rounds

A personal bill tracker for mobile. Every month is a new round of the same recurring obligations — Rounds helps you stay on top of them.

No more sticky notes, spreadsheets, or trying to remember if you paid the internet bill. Just open the app and know exactly where you stand.

Not an expense tracker. Not a budget app. Just a simple, focused tool for knowing which bills you've paid this month and which ones are still waiting.

---

## Features

- **Recurring bills** — set up your bills once with a name, optional amount, and due day. They show up automatically every month.
- **Mark as paid** — record payment date, method, amount paid, and a reference note. Or just tap and go.
- **Monthly view** — pending bills at the top, paid ones below. Clean, at-a-glance status.
- **History** — browse past months you've had activity in.
- **Bill reminders** — optional notifications 2 days and 1 day before each due date.
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
