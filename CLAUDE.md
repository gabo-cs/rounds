# CLAUDE.md

Guidance for Claude Code sessions in this repository. Part 1 is how the maintainer
likes to work; Part 2 is the engineering documentation for the app. Treat the codebase as the source of
truth — if this file and the code disagree, the code wins; update this file.

---

# Part 1 — Working in this repo

## Workflow

- **Implement directly, summarize briefly.** No plan-first ceremony for normal tasks.
  Make the change, then give a short summary of what changed and why. Only pause to
  discuss beforehand for genuinely architectural decisions (new dependency, schema
  redesign, new top-level pattern).
- **Fix whatever you find.** If you notice problems outside the task (dead code, a
  hardcoded string, a real bug), fix them proactively — but as **separate commits**
  from the main task, so each commit stays reviewable.
- **Verification before commit:** `flutter analyze` and `flutter test` must pass.
  CI (`.github/workflows/ci.yml`) enforces the same two checks on push and PRs.
  On-device testing is the maintainer's job; don't try to launch emulators.

## Git

- Work directly on `master`. Commit each completed, verified task proactively —
  don't leave finished work uncommitted.
- Commit messages: one imperative line describing the user-visible or engineering
  outcome, in the style of the existing history — e.g. "Make bill-instance generation
  race-safe", "Show a friendly message instead of raw load errors". No prefixes, no
  bodies unless something genuinely needs explaining.
- One logical change per commit (the history is disciplined about this; keep it so).

## Testing policy

- The suite is small and being built up. **New features and bug fixes should come
  with tests.**
- Priorities: repository logic against a real in-memory DB via
  `AppDatabase.forTesting(NativeDatabase.memory())`, and unit tests for tricky pure
  logic — date math (`date_extensions.dart`), notification-ID mapping, backup
  serialization round-trips, month↔page-index mapping in `home_screen.dart`.
- **Inject time in new logic.** The riskiest bugs here are date-boundary ones
  (overdue cutoffs, month rollover, December edges), and inline `DateTime.now()`
  calls make them untestable. New date-sensitive functions take a `DateTime now`
  parameter (defaulted to `DateTime.now()`); migrate existing call sites
  opportunistically when touching them.
- **Every `schemaVersion` bump ships with a migration test**: build the previous
  schema, seed representative data, run the upgrade, verify nothing was lost or
  mangled. Real devices carry real data; migrations are the highest-value tests
  in this repo.
- Widget tests are welcome but secondary.

## Code style

- Comments explain **why**, never what — race safety, upgrade compatibility, perf
  rationale. This codebase is consistently good at this; match it. No comment is
  better than a narrating comment.
- Package imports everywhere: `package:rounds/...`, never relative `../` imports.
- Code, comments, and commits in English. The *app* ships English + Spanish (see l10n).
- Follow existing idioms: trailing commas, `withValues(alpha: x)` (never the
  deprecated `withOpacity`), records and pattern matching where they clarify
  (`typedef BillInstanceWithBill = ({BillInstance instance, Bill bill})`).
- Don't add dependencies without a strong reason; this app is deliberately lean.

---

# Part 2 — The Rounds app

## What it is (and isn't)

Personal recurring-bill tracker. Every month is a "round" of the same obligations;
the app tells you what's paid, pending, or overdue, and reminds you via local
notifications. Explicitly **not** an expense tracker or budget app — resist feature
creep in that direction.

Fully offline by design: no accounts, no network, no analytics. SQLite on device,
JSON export/import as the only data exit/entry.

**The app is installed on real devices with real data.** Consequences:
- Every Drift schema change needs a schema-version bump, a hand-written,
  non-destructive migration in `app_database.dart`, and a migration test (see
  Testing policy). Never wipe or regenerate the DB.
- Notification-ID layout changes must stay compatible with already-scheduled
  notifications (see Notifications below).
- Backup JSON must stay readable by version checks (`_backupVersion` in
  `backup_service.dart`).

Platforms: **Android first** — it's where all testing happens and where the polish is
(manifest workarounds, Gradle tuning, adaptive icons). Keep iOS compiling and
configured, but don't invest in iOS-specific polish unless asked.

## Domain model

Two tables, two concepts:

- **`Bills`** — the recurring template: name, optional amount, `dueDayOfMonth` (1–28,
  capped at 28 *by design* to avoid short-month problems), optional category/notes,
  `isArchived`. Archiving hides a bill from future months without touching history;
  deleting removes the bill *and* all its instances (explicit transaction, since the
  FK is `onDelete: restrict`).
- **`BillInstances`** — one row per bill per month: year, month, `isPaid`, payment
  details (paidAt, method, amountPaid, referenceNote). `UNIQUE(billId, year, month)`
  is a load-bearing constraint — it's what makes instance generation race-safe.

**Instance generation** (`BillInstancesRepository.ensureInstancesExist`): instances are
created lazily when a month is viewed, for a rolling horizon of [current month, +12
months]. Past months only show what was actually recorded. Generation reads existing
rows once, batch-inserts only the missing ones with `InsertMode.insertOrIgnore` —
multiple concurrent callers (month provider re-runs, startup warm-up) are expected
and safe. Don't "simplify" this into per-bill upserts.

## Layout

```
lib/
  main.dart                 # startup sequencing — carefully ordered, see below
  app.dart                  # MaterialApp.router, theme + locale wiring
  routing/app_router.dart   # all routes + custom bottom nav shell
  core/
    constants/              # AppConstants (due-day bounds, categories)
    extensions/             # DateTime + currency formatting extensions
    theme/app_theme.dart    # the entire design system
    utils/                  # NotificationService, BackupService
    widgets/                # cross-feature widgets (BillIcon)
  data/
    database/               # AppDatabase + tables/ (+ generated .g.dart)
    models/                 # non-DB models (PaymentMethod enum)
    repositories/           # plain classes over AppDatabase
  features/<name>/          # screen(s) + providers/ + widgets/ per feature
  l10n/                     # hand-rolled AppLocalizations (en, es)
```

Feature folders: `home` (monthly pager — the main screen), `bills` (list/form/detail),
`history`, `mark_paid` (bottom sheet), `settings`. A feature owns its screens, its
`providers/`, and feature-local `widgets/`. Widgets used by only one screen are private
`_Widget` classes at the bottom of that screen's file — that is the preferred pattern;
only promote to `widgets/` (feature) or `core/widgets/` (cross-feature) on actual reuse.

## State management — Riverpod, manual only

**Hand-written providers are the convention. Do not introduce riverpod codegen**
(`@riverpod` annotations) or re-add the generator packages. `build_runner` exists
solely for Drift: `dart run build_runner build` after touching tables.

Patterns in use:
- **Root wiring** currently lives in `features/home/providers/home_providers.dart`
  (`appDatabaseProvider` → `billsRepositoryProvider` /
  `billInstancesRepositoryProvider`) — a historical accident, not a convention.
  **Cross-feature providers never go in a feature folder**: put new ones in
  `lib/data/providers.dart`, and move the existing root providers there the next
  time a change touches them. New repositories hang off `appDatabaseProvider`
  the same way.
- **Reads are streams**: repositories expose `watch*()` Drift streams; providers wrap
  them in `StreamProvider`. UI updates reactively; there are no manual refresh calls.
- **Parametrized queries**: `StreamProvider.family` keyed by a value-equal type
  (`SelectedMonth` implements `==`/`hashCode` precisely so it can key a family).
  Add `.autoDispose` when instances are unbounded (one per month page).
- **Mutations** go through repository methods called via `ref.read(...)` in callbacks —
  never watch inside callbacks.
- **Form/sheet state**: `StateNotifier` + immutable state class with `copyWith`
  (including `clearX` flags for nullable fields) — see `mark_paid_providers.dart`.
- **Multi-step mutations belong in a notifier**, following the mark_paid pattern:
  anything beyond a single repo call (repo write + notification changes, etc.) is
  orchestrated by a `StateNotifier`, not a widget callback. `bill_form_screen._save`
  and the settings notifications toggle are legacy counterexamples — don't copy
  them; migrate them when touched.
- **Services are accessed through providers in new code.** `NotificationService`
  is a singleton reached via `NotificationService.instance` today, which is why
  its callers can't be unit-tested. New code takes it from a
  `notificationServiceProvider` (create it wrapping the singleton on first need)
  so tests can override it; any new service gets a provider from day one.
- **Screen-private providers are fine** for single-screen queries
  (`_allBillsProvider` in `bills_screen.dart`).
- Settings: `SettingsNotifier(StateNotifier<AppSettings>)` over SharedPreferences;
  `sharedPreferencesProvider` throws by default and is overridden in `main.dart`.

## Routing

`go_router`, flat table in `routing/app_router.dart`. Four tabs via
`StatefulShellRoute.indexedStack` (`/`, `/bills-tab`, `/history`, `/settings`) with a
**custom** bottom nav (`_BottomNavBar` — the indicator covers icon+label, which
`NavigationBar` can't do; don't swap it back). Full-screen flows are top-level routes
pushed over the shell: `/bills/new`, `/bills/:billId`, `/bills/:billId/edit`.
Cross-tab navigation = set state, then `context.go('/')` (see history → home).
Mark-paid is a `showModalBottomSheet`, not a route.

## Startup sequencing (`main.dart`) — do not reorder casually

Every line ordering there is deliberate and commented:
1. Notification init is wrapped in try/catch — a failure must never strand the splash.
2. `handleLaunchSnooze()` recovers snooze taps that cold-started the app.
3. One shared `ProviderContainer` (via `UncontrolledProviderScope`) so startup
   scheduling and the UI use the same DB instance.
4. `container.read(activeBillsProvider)` warms the drift isolate before first frame.
5. Notification scheduling is deferred until after first frame **+ 2s settle**,
   because dozens of platform-channel responses landing during startup caused visible
   swipe stutter. Keep any new startup work behind that same deferral.

## Notifications — the most delicate subsystem

All logic in `core/utils/notification_service.dart` (singleton,
`NotificationService.instance`). Key invariants:

- **ID scheme**: `instanceId * 10 + offset`, offsets 0–3 (overdue=0, tomorrow=1,
  in-2-days=2, due-today=3). Offset values are frozen for upgrade compatibility —
  re-scheduling must overwrite, not duplicate. Reserved IDs: 999999 (test),
  1000001 (monthly kickoff). New notification kinds need IDs that can't collide
  with `instanceId * 10 + n`.
- **Scheduling model**: proactive and startup-driven. `scheduleUpcomingReminders`
  (in `home_providers.dart`) arms current + next month at every launch — a sliding
  window anchored to the device date, independent of which month the user browses —
  and then re-arms the daily overdue reminder for every unpaid, non-archived
  instance from *past* months, so nagging survives month rollover and lost alarms
  (force-stop, OEM battery killers). A per-month signature hash skips platform work
  when nothing changed. Reminders are scheduled from the due date forward so they
  fire even if the app is never reopened. Archived bills are never scheduled.
- **Reminder ladder** per unpaid instance, all at 9:00 local: −2d, −1d, due day,
  then a **daily repeating overdue reminder until paid**. On Android the daily
  series is armed proactively (first fire = due date + 1, repeats via
  `DateTimeComponents.time`); on iOS repeating triggers ignore the start date and
  would nag before the due date, so iOS gets a single due+1 ping and the daily
  repeat is armed by the next launch's scheduling pass.
- **Two channels**: regular reminders on `bill_reminders_v2` (default importance);
  overdue reminders on `overdue_alerts_v1` (high importance, heads-up). Importance
  is per-channel on Android 8+ — escalation means a different channel, never an
  importance override on an existing one. Snooze payloads carry an `overdue` flag
  so a snoozed overdue reminder is rescheduled on the right channel.
- **Snooze**: notification actions carry a JSON payload (`notifId`, `title`, `body`,
  `langCode`) that must be self-contained — the background isolate handler
  (`@pragma('vm:entry-point')`) re-initializes timezone + plugin from scratch and can
  touch nothing from the app's state. Cold-start snoozes are recovered via
  `getNotificationAppLaunchDetails`.
- **Anything that retires a bill or instance must cancel its notifications**:
  mark-paid cancels the instance's IDs; deleting a bill cancels all its instances'
  IDs (grab them *before* the delete removes the rows); archiving does the same.
  Undoing a payment on a past-due bill re-arms the daily overdue reminder;
  unarchiving relies on the next scheduling pass.
- **Release-build trap**: `ic_stat_rounds` is only referenced by name from Dart, so
  R8 would strip it — the `<meta-data>` entry in `AndroidManifest.xml` exists solely
  to pin it. Any new drawable referenced only from Dart needs the same treatment.
- Timezone setup can fail → falls back to UTC silently; `zonedSchedule` with
  `exactAllowWhileIdle` everywhere; exact-alarm permission is requested from Settings.

## Localization

Hand-rolled — **no ARB files, no gen-l10n**. `l10n/app_localizations.dart` declares an
abstract `AppLocalizations` (grouped with `// ──` section headers); `_en.dart` and
`_es.dart` implement it. Adding a string = abstract member + **both** implementations
(the compiler enforces it — that's the point of this design).

- In widgets: `AppLocalizations.of(context)`.
- Outside the widget tree (notifications): construct directly —
  `languageCode == 'es' ? AppLocalizationsEs() : AppLocalizationsEn()`.
- Parameterized strings are plain methods (`dueThe(int day)`), Spanish ordinals etc.
  handled inside each implementation.
- Language switch re-registers the monthly kickoff; iOS snooze categories exist per
  language (`bill_reminder_en` / `bill_reminder_es`).

## Theming & UI conventions

`core/theme/app_theme.dart` is the whole design system: two fully hand-picked M3
`ColorScheme`s (light + dark, blue/navy identity — **not** seed-generated; don't
replace with `ColorScheme.fromSeed`). Component styling goes in `_buildTheme`
(cards 16px radius, filled inputs without borders, pill FilledButtons 52px high,
floating snackbars) — style at the theme level, not per-widget, unless truly local.

Recurring UI idioms:
- De-emphasized text = `onSurface.withValues(alpha: 0.4–0.7)`, not grey constants.
- Paid = green `0xFF27AE60` (only in `BillIcon`); overdue = `colorScheme.error`.
- Every screen's async body: `async.when(loading: spinner, error: l10n.genericErrorMessage, data: ...)`,
  with a friendly `_EmptyState` for empty data. Never show raw exceptions.
- Destructive confirmations: `AlertDialog` with error-colored `FilledButton`.
- List padding leaves ~100px bottom clearance for the FAB.
- `BillIcon` maps name/category keywords → icon with whole-word matching (padded
  spaces) to avoid substring traps ('credit card' vs ' car '); check-circle when paid.

Home month pager: `PageView.builder` mapped to months via a fixed 2000–2100 origin,
`allowImplicitScrolling: true` pre-builds neighbours; `selectedMonthProvider` is the
single source of truth (arrows, Today button, history deep-links all set it; the
pager listens and animates ≤1-step moves, jumps otherwise). Keep that unidirectional.

## Backup / restore

`core/utils/BackupService`: export = versioned JSON (`_backupVersion = 1`, UTC ISO
timestamps, explicit hand-written toJson/fromJson per table — no codegen) built by
`buildBackupJson()` (kept separate from sharing so it's testable), written to temp
dir and handed to `share_plus`. Import = user picks the JSON via `file_picker`, then
**full replace** in one transaction, preserving original IDs (required — notification
IDs derive from instance IDs); afterwards the notification schedule is rebuilt, since
the old one references replaced instances. `importFromFile` returns typed
`ImportError` values (never message strings) so the UI can localize failures.
Bump `_backupVersion` and keep old versions importable whenever the schema grows.
Round-trip and error paths are covered in `test/backup_service_test.dart`.

## Known debt & pitfalls (as of 2026-07)

- **Notifications toggle**: every scheduling path (startup, language change,
  undo-payment, import) must check `settings.notificationsEnabled` — they all do
  now; keep it that way when adding new scheduling paths. After `cancelAll()`,
  call `resetNotificationSignatures()` (in `home_providers.dart`) or the
  signature cache will skip the next re-arm as "already done".
- `analysis_options.yaml` is stock `flutter_lints` — intentional for now.
- Amounts are `double` + hardcoded `$` formatting; fine for a personal app, know it
  before building anything money-math heavy.
- **Version lives in two places**: `version:` in `pubspec.yaml` and the hardcoded
  `appVersionLabel` in both l10n implementations. Bump them together, always.

## Command reference

```bash
flutter pub get
dart run build_runner build          # only needed after touching Drift tables
flutter analyze                      # must be clean before commit
flutter test                         # must pass before commit
flutter run                          # on-device testing is done manually
dart run flutter_launcher_icons      # after changing assets/icon/*
```
