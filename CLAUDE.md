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
  serialization round-trips, month↔page-index mapping in `round_screen.dart`, and
  the reminder plan builders (`test/reminder_plan_test.dart`), which are pure by
  design precisely so the schedule can be tested without a platform.
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
    widgets/                # cross-feature widgets (BillIcon, RoundRing, ScreenHeader, EmptyState)
  data/
    database/               # AppDatabase + tables/ (+ generated .g.dart)
    models/                 # non-DB models (PaymentMethod enum)
    repositories/           # plain classes over AppDatabase
  features/<name>/          # screen(s) + providers/ + widgets/ per feature
  l10n/                     # hand-rolled AppLocalizations (en, es)
```

Feature folders: `round` (the monthly pager — the first tab), `bills` (list/form/detail),
`history`, `mark_paid` (bottom sheet), `settings`. A feature owns its screens, its
`providers/`, and feature-local `widgets/`. Widgets used by only one screen are private
`_Widget` classes at the bottom of that screen's file — that is the preferred pattern;
only promote to `widgets/` (feature) or `core/widgets/` (cross-feature) on actual reuse.

## State management — Riverpod, manual only

**Hand-written providers are the convention. Do not introduce riverpod codegen**
(`@riverpod` annotations) or re-add the generator packages. `build_runner` exists
solely for Drift: `dart run build_runner build` after touching tables.

Patterns in use:
- **Root wiring** currently lives in `features/round/providers/round_providers.dart`
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
Cross-tab navigation = set state, then `context.go('/')` (see history → round).
Mark-paid is a `showModalBottomSheet`, not a route.

## Startup sequencing (`main.dart`) — do not reorder casually

Every line ordering there is deliberate and commented:
1. `SharedPreferences` is the **only** thing awaited before `runApp` — theme and
   locale come from it, so reading it later would flash the wrong ones.
2. One shared `ProviderContainer` (via `UncontrolledProviderScope`) so startup
   scheduling and the UI use the same DB instance.
3. `container.read(activeBillsProvider)` warms the drift isolate before first frame.
4. *All* notification work — plugin/timezone init, `handleLaunchSnooze()`, the
   re-arm pass — happens after the first frame **+ 2s settle**, wrapped in
   try/catch. Initializing the timezone DB is hundreds of ms of parsing on the UI
   isolate, and every platform call behind it is serviced by the Android main
   thread, which is also what delivers touch events. Keep any new startup work
   behind that same deferral, and off the pre-`runApp` path entirely.

Because init is deferred, a user action can reach `NotificationService` before it
is ready — every entry point therefore `await`s `_ready()` rather than no-op'ing,
so e.g. marking a bill paid two seconds after launch still cancels its reminders.

## Notifications — the most delicate subsystem

All logic in `core/utils/notification_service.dart` (singleton,
`NotificationService.instance`). Key invariants:

- **ID scheme**: `instanceId * 10 + offset`, offsets 0–3 (overdue=0, tomorrow=1,
  in-2-days=2, due-today=3) plus 4–5 (overdue ladder, days 2–3 past due). Offset
  values are frozen for upgrade compatibility — re-scheduling must overwrite, not
  duplicate. **6–9 are retired**: they held days 4–7 of the original seven-day
  ladder. Nothing plans them, but upgraded installs still have them armed, so
  every clearing path (`_kEveryOffset`, the overdue takeover) keeps cancelling
  them until they expire. Reserved IDs: 999999 (test), 1000001 (monthly kickoff).
  New notification kinds need IDs that can't collide with `instanceId * 10 + n`.
- **Scheduling model — a small rolling window, re-armed blindly.** This is the
  load-bearing design decision. Do **not** "optimize" it back into a diff
  against `pendingNotificationRequests()`; that has been tried and it broke
  reminders outright. See the trap below.
  - `plannedRemindersFor()` and `monthlyKickoffPlan()` are **pure functions** —
    no platform calls, fully unit-tested. `refreshReminderSchedule`
    (`round_providers.dart`) builds the plans, `applyReminderPlans` issues them.
  - **The window is a span of days, not a count of months**:
    `kReminderHorizon` = 35. Cost then tracks *how many bills fall due soon*, not
    bills × slots × months. 35 because due days are capped at 28, so consecutive
    due dates are ≤31 days apart — the next occurrence of every bill is always
    armed, with slack. `test/reminder_plan_test.dart` proves this exhaustively
    across every due-day/launch-day pair; don't lower it without re-reading that.
  - **The pass is blind and unconditional.** It re-issues everything, every
    launch, without asking what is armed. Re-issuing *is* the repair.
  - **The trap — `pendingNotificationRequests()` lies.** It reads the plugin's
    own SharedPreferences mirror (`loadScheduledNotifications`), *not*
    AlarmManager. A force-stop or an OEM battery manager cancels the real alarms
    and leaves that mirror perfectly intact. Anything that trusts it concludes
    "all armed", repairs nothing, and goes silent **permanently** — the only
    recovery paths are `BOOT_COMPLETED` and `MY_PACKAGE_REPLACED` (the plugin's
    `rescheduleNotifications`, called from its boot receiver and nowhere else),
    and a force-stopped app doesn't even receive the boot broadcast. Android
    offers no honest way to ask whether an alarm survived.
  - **During development this is constant, not exotic.** Android Studio's Stop
    button — and re-running the app — issues `am force-stop`, so every debug
    cycle wipes the alarms while leaving the mirror intact. It cost three days
    of silent, missed reminders once (Aug 2026) before the cause was found on a
    stock Pixel, where no OEM battery manager was ever involved.
  - To inspect the *real* state, ask AlarmManager rather than the app:
    `adb shell dumpsys alarm | grep -A2 "com.rounds.rounds}"`. The `origWhen=`
    lines are the armed local times, and their per-day histogram should match
    each unpaid bill's six slots (due −2, −1, 0, +1, +2, +3).
  - `ReminderPlan` is `(arm, clear)`. `clear` is always derived from the *plan*
    — the ladder slots the overdue repeat supersedes, or slot 0 as a backstop for
    a settled bill whose cancel was lost — never from what the platform reports.
  - Overdue nagging reaches back one month, no further: unpaid instances older
    than that are retired via `cancelForInstances`.
  - `kNotificationSchedulePacing` yields between individual calls so a pass can't
    monopolise the Android main thread, which is also what delivers touch input.
  - Reminders are armed from the due date forward so they fire even if the app is
    never reopened. Paid and archived bills arm nothing.
- **Reminder ladder** per unpaid instance, all at 9:00 local: −2d, −1d, due day,
  then **three one-shot overdue pings** (due+1 on slot 0, due+2/+3 on slots 4–5,
  `overdueLadder()`). Six notifications per bill, and that count is the budget
  that keeps a blind re-arm affordable. The ladder only has to bridge the gap
  until the app is next opened: any launch while the bill is overdue replaces it
  with an **open-ended daily repeating reminder** that nags without limit, and
  puts the superseded slots in the plan's `clear` list so they can't double up.
  **Plugin gotcha, learned the hard way**: `matchDateTimeComponents`
  snaps a repeating schedule to the *next* component match on both platforms —
  a future start date is silently ignored — so never arm a repeating
  notification that shouldn't begin firing immediately.
- Overdue notification copy is month-aware (`overdueSinceDate` → "Was due
  Jun 5"): the previous month is inside the scheduling window, and a bare day
  number would read as the current month's bill.
- **Two channels**: regular reminders on `bill_reminders_v2` (default importance);
  overdue reminders on `overdue_alerts_v1` (high importance, heads-up). Importance
  is per-channel on Android 8+ — escalation means a different channel, never an
  importance override on an existing one. Snooze payloads carry an `overdue` flag
  so a snoozed overdue reminder is rescheduled on the right channel.
- **Snooze**: notification actions carry a JSON payload (`notifId`, `title`, `body`,
  `langCode`, `overdue`, `repeating`) that must be self-contained — the
  background isolate handler (`@pragma('vm:entry-point')`) re-initializes timezone +
  plugin from scratch and can touch nothing from the app's state. Cold-start snoozes
  are recovered via `getNotificationAppLaunchDetails`. Snoozing reschedules on the
  *same* ID, so the payload's `repeating` flag decides one-shot vs. daily repeat —
  the open-ended overdue repeat is the only reminder left after the ladder takeover,
  and snoozing it as a one-shot would silently end the nagging. A snooze survives
  only until the next launch: the blind re-arm re-issues the reminder at its
  canonical 9:00.
- **Anything that retires a bill or instance must cancel its notifications**:
  mark-paid cancels the instance's IDs; deleting a bill cancels all its instances'
  IDs via `cancelForInstances` (grab them *before* the delete removes the rows);
  archiving does the same. Undoing a payment on a past-due bill re-arms the daily
  overdue reminder; unarchiving relies on the next scheduling pass. The re-arm
  pass is *not* a full backstop for these — it only clears slot 0 for a settled
  bill (the one alarm that repeats without end), so a lost cancel on an upcoming
  reminder still fires once. Keep the explicit cancels.
- **Release-build trap**: `ic_stat_rounds` is only referenced by name from Dart, so
  R8 would strip it — the `<meta-data>` entry in `AndroidManifest.xml` exists solely
  to pin it. Any new drawable referenced only from Dart needs the same treatment.
- **Timezone data is `latest_all` on purpose.** It's the biggest of the three
  bundled databases (537 KB, ~200 ms of parsing) but the only one with all 596
  zones — `latest` and `latest_10y` ship 431, dropping legacy aliases *and*
  current canonical zones (`America/Ciudad_Juarez`, `America/Nuuk`,
  `America/Punta_Arenas`, `Asia/Yangon`, `Pacific/Bougainville`). A device
  reporting one of those would fail the lookup and fall back. Don't shrink it to
  save startup time — that cost is already off the critical path (see Startup
  sequencing), so the trade buys nothing.
- **Timezone fallback ladder** (`_setLocalTimezone`): the reported zone, then the
  `Etc/GMT±N` zone nearest the device's own UTC offset, then UTC. The middle rung
  exists because plain UTC fired every 9:00 reminder at 9:00 UTC — 4 AM in
  Bogotá. `DateTime.now().timeZoneOffset` is a good backstop precisely because it
  comes from the Dart VM, not the platform channel that just failed.
  `etcGmtZoneName` is public so the **inverted POSIX sign** (`Etc/GMT+5` is
  UTC-5) is pinned by a test that resolves each name against the real database.
- **iOS and Android consume the schedule differently** — worth knowing before
  touching anything time-related. Android gets an absolute
  `millisecondsSinceEpoch` computed in Dart, so the bundled database decides the
  real fire time. iOS gets the zone *name* as text (`location.name`) and
  re-resolves it with `NSTimeZone` against Apple's database. A synthetic
  `tz.Location` therefore works on Android and breaks on iOS — the fallback has
  to be a name both databases know, which is why it's `Etc/GMT±N`.
- `zonedSchedule` with `exactAllowWhileIdle` everywhere; exact-alarm permission
  is requested from Settings.

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

`core/theme/` is the whole design system, built in the 2026-08 redesign:
- `app_theme.dart` — two fully hand-picked M3 `ColorScheme`s (light + dark,
  blue/navy identity — **not** seed-generated; don't replace with
  `ColorScheme.fromSeed`), the `textTheme`, and component styling in
  `_buildTheme` (cards 16px radius, filled inputs without borders, pill
  FilledButtons 52px high, bordered chips, floating snackbars) — style at the
  theme level, not per-widget, unless truly local.
- **Type**: Manrope (bundled asset, weights 400–800) for everything the UI
  says; Spline Sans Mono via `AppTypography` (`money`, `monoMeta`, `eyebrow`)
  for everything numeric or label-like — amounts, dates, counts, section
  eyebrows. Nothing sets a bare `fontFamily` string outside these.
- `rounds_colors.dart` — `RoundsColors` ThemeExtension: the status tokens
  (`paid`/`paidContainer` green, `overdueSurface`/`overdueBorder` tint,
  `neutralDot`) and the two named de-emphasis steps (`textSecondary`,
  `textFaint`). Use these instead of improvising `withValues(alpha: …)`.
- `category_visuals.dart` — `CategoryVisual.resolve` maps name/category
  keywords → **icon + hue together** (so they can't disagree), with whole-word
  matching (padded spaces) to avoid substring traps ('credit card' vs ' car ');
  tested in `test/category_visuals_test.dart`. The paid green and error red
  are reserved for status and never appear as category hues.

Recurring UI idioms:
- **The Round** (`core/widgets/round_ring.dart`) is the signature element: a
  month drawn as a circle, one unit per bill, with consecutive same-state
  units merged into smooth proportional arcs (paid green / pending
  `neutralDot` / overdue error — callers group colors by state). Big in the
  Home header (animated draw-in), mini in History rows, hollow in empty
  states. `ringArcs` is pure and unit-tested — keep it that way.
- **Due date leads, amount follows.** Amounts are optional, so the due date is
  the primary right-column datum on unpaid cards; the amount appears under it
  in mono when the bill has one. Don't invert this.
- Paid bills render as compact `PaidBillRow` ledger rows, not full cards —
  settled items get out of the way.
- Every tab header is `core/widgets/ScreenHeader` (display title + mono meta
  line + actions); Home composes the same lockup inside `MonthNavigator`.
- Every screen's async body: `async.when(loading: spinner, error: l10n.genericErrorMessage, data: ...)`,
  with `core/widgets/EmptyState` (ring motif) for empty data. Never show raw
  exceptions.
- Confirmations go through `core/widgets/confirm_dialog.dart`
  (`showConfirmDialog`): icon lockup, centered copy, stacked full-width pill
  buttons (a row of text buttons doesn't survive Spanish label lengths).
  `destructive: true` for irreversible intents (delete, import-replace);
  reversible ones (archive, undo) stay on primary. The delete dialog offers
  "Archive instead" as an alternative action — archiving from there skips the
  second confirmation on purpose. Deleting a bill lives on the edit screen
  (with archive), not in list rows.
- List padding leaves ~100px bottom clearance for the FAB.

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

## Known debt & pitfalls (as of 2026-08)

- **Notifications toggle**: every scheduling path (startup, language change,
  undo-payment, import) must check `settings.notificationsEnabled` — they all do
  now; keep it that way when adding new scheduling paths. `cancelAll()` needs no
  bookkeeping any more: the next pass sees an empty pending list and re-arms.
- **iOS caps pending local notifications at 64**, keeping the soonest and
  silently discarding the rest. The old design armed up to 10 slots per instance
  across three months, so roughly 7 bills reach the cap. The rolling window makes
  this far less likely — six slots per bill over 35 days puts a typical schedule
  near 60–75 — but it isn't a guarantee, and iOS discards silently. Android has
  no such limit, so this is latent, not live.
- `analysis_options.yaml` is stock `flutter_lints` — intentional for now.
- Amounts are `double`. Fine for a personal app, but know it before building
  anything money-math heavy. Display and input both go through `Currency`
  (`data/models/currency.dart`): it owns the separators, the symbol and the
  parsing, and `CurrencyInputFormatter` groups digits live as they are typed.
  Grouping comes from the locale pattern but the symbol is prefixed by hand —
  `es_CO` formats currency as `1.000.000 $`, which nobody writes. Decimals show
  only when the amount has them. Anything that renders or reads an amount takes
  the currency from `settingsProvider`; nothing formats money inline.
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
