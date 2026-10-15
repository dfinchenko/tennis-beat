---
description: "Task list for workout and Health on Apple Watch (003)"
---

# Tasks: Workout and Health on Apple Watch

**Input**: Design documents from `specs/003-workout-health/`: [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md), [data-model.md](data-model.md), [contracts/ui-contract.md](contracts/ui-contract.md), [quickstart.md](quickstart.md)

**Tests**: REQUIRED (constitution III).
- **Order**: in every phase the test tasks come first. Commit them, run them and **see them fail** before that phase's code tasks start. Record the commit SHA and the failing test names in `specs/003-workout-health/test-first-evidence.md` (CLAUDE.md step 3; compile errors count when the API didn't exist yet). A test is written in the PR whose code makes it pass; no test is `.disabled` to wait for a later PR.
- **Naming**: every acceptance scenario has at least one test whose name starts with its ID (`"US2 s4 …"`). Plan-level tests use `"SC-00n …"`, `"FR-0nn …"` or `"Edge: …"`. Scenarios that only a real watch can check (US2 s2, SC-001, SC-004, and the parts of US4 s6 that compare with Health) are **device checks** owned by Denys and listed in the PR by the spec's device-check number.
- **ITF IDs**: tests that replay matches through the engine keep `// ITF: <ID>` where a rule decides the expected state (for example the tie-break in "Edge: pause during a tie-break", `// ITF: TB-01`).
- **No vacuous tests**: when a stub (a no-op service, an empty model) would already satisfy an assertion, add a positive control that fails against it.
- **Expectation changes**: changing an expectation after its code exists goes in `specs/003-workout-health/test-expectation-changes.md` (`docs/harness.md`). Adding `-uiTestHealth denied` to the UI-test launch helper (T008) is a helper change, not an expectation change.

**Organization (Denys, 2026-10-15: onboarding first, then the workout)**. Phases follow the four PRs of [plan.md § Delivery](plan.md#delivery-four-small-prs):

| Phase | PR | Stories |
| --- | --- | --- |
| 1–3 | PR 1, Health onboarding | US1 (+ US6 for the onboarding) |
| 4 | PR 2, workout lifecycle | US2, US5, US4 s4–s5 (saving) |
| 5 | PR 3, heart rate in the header | US3 (+ US6 for the header) |
| 6 | PR 4, summary rows and the notice | US4 s1–s3, s6–s8 (+ the final US6 audit) |

US6 (accessibility and languages) is cross-cutting: each PR meets it for its own screens, so its tasks are labelled `[US6]` inside each phase.

**Paths**:
- `App/` means `TennisBeat/TennisBeat Watch App/`.
- `UnitTests/` means `TennisBeat/TennisBeat Watch AppTests/`.
- `UITests/` means `TennisBeat/TennisBeat Watch AppUITests/`.

**How to run**: as in 002. Unit tests: XcodeBuildMCP `test_sim`, scheme `TennisBeat Watch App`, 40 mm watch simulator, `-only-testing:"TennisBeat Watch AppTests"`. UI tests: the same with `TennisBeat Watch AppUITests`. Engine: `swift test --package-path Packages/TennisCore` (green and unchanged, FR-018).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can run in parallel (different files, no dependency on an incomplete task)
- **[Story]**: the user story the task belongs to
- **Owner**: the agent, unless a task says **Owner: Denys**

## Per-PR checklist (applies to every PR phase; referenced as "PR checklist")

1. **Start**: create a worktree `.worktrees/003-<slug>` on branch `feat/003-<slug>` from the latest `origin/main`, with `.specify/feature.json` → `specs/003-workout-health`. Run `scripts/gates/check-artifacts.sh specs/003-workout-health` and STOP if it fails.
2. **Tests**: write the phase's tests, commit them, run them, see them fail, and record it in `test-first-evidence.md`.
3. **Code**: implement until they pass. Run the full watch unit and UI suites and the engine tests. `git diff origin/main -- Packages/TennisCore` must be empty (FR-018; the reviewer checks it too), and the diff adds no network, analytics or sync code.
4. **Build and run**: build both schemes (`TennisBeat`, `TennisBeat Watch App`). Run the PR's flow on the 40 mm simulator in EN, PL and UK at the largest standard text size and at an accessibility size, with the `-uiTestHealth` modes of [quickstart](quickstart.md) §3. Attach the screenshots to the PR.
5. **Gates**: `scripts/gates/check-project-format.sh` and `scripts/gates/check-infoplist-strings.sh`.
6. **Metrics**: append the metrics row for the previous merged PR to `docs/harness.md`.
7. **Device checks**: add the spec's device checks this PR touches to the device checklist in `docs/harness.md` (each once, in the first PR that touches it) and list them in the PR body for Denys.
8. **Review**: invoke the `reviewer` subagent with only `specs/003-workout-health` and `main`. Post each report as a PR comment with numbered findings (R<n>-<m>) and their outcomes. The PR body carries `Reviewed-SHA: pending` until a review of the head passes, then the full SHA.

---

## Phase 1: Setup (PR 1)

**Purpose**: the worktree and the Health folder. No behaviour yet.

- [X] T001 PR checklist step 1 for PR 1: worktree `.worktrees/003-onboarding`, branch `feat/003-onboarding`.
- [X] T002 Create the folders `App/Health/` and `App/Onboarding/` (synchronized groups: new files join the watch target). Confirm `App/TennisBeat Watch App.entitlements` already has `com.apple.developer.healthkit` and change nothing in it (research R9).

---

## Phase 2: Foundational (PR 1)

**Purpose**: the `WorkoutService` seam, the fake, and the launch arguments that every later phase uses. Blocks all stories.

### Tests

- [X] T003 [P] `UnitTests/LaunchOptionsHealthTests.swift`: `-uiTestHealth denied|shouldRequest|granted|failing`, `-uiTestHeartRate 142`, `-uiTestWorkoutStats 138,171,612` (an empty field is `nil`: `138,171,` → no energy), `-uiTestSaveFails`, and unknown values → `nil` ([contract](contracts/ui-contract.md) §2). Positive control: no argument → `nil` mode, so production HealthKit is used.
- [X] T004 [P] `UnitTests/FakeWorkoutServiceTests.swift`: the fake records every call in order with its dates; each mode's `authorizationRequestStatus()` and `canStartWorkout` (`denied` → `.unnecessary`, false; `shouldRequest` → `.shouldRequest` until `requestAuthorization()`, then `.unnecessary` and true; `granted` → `.unnecessary`, true); `failing` emits `.failed` after `start`.

### Code

- [X] T005 Create `App/Health/WorkoutService.swift` (data-model § WorkoutService): the `@MainActor` protocol with `authorizationRequestStatus() async -> AuthorizationRequestStatus` (`.shouldRequest`, `.unnecessary`, `.unknown`), `requestAuthorization() async`, `canStartWorkout`, `start(at:)`, `pause()`, `resume()`, `statistics()`, `save(endingAt:) async throws -> SavedWorkout`, `discard()`, `recoverAndSave() async`, `onEvent`. Also the `nonisolated` `Sendable` values `WorkoutEvent` (`.heartRate(HeartRateReading)`, `.failed`, `.endedUnexpectedly`, each tagged with a workout token that `start(at:)` returns), `HeartRateReading(bpm: Int, date: Date)`, `WorkoutStatistics(averageHeartRate: Int?, maximumHeartRate: Int?, activeEnergy: Double?)` and `SavedWorkout(uuid: UUID, statistics: WorkoutStatistics)`.
- [X] T006 Create `App/Health/FakeWorkoutService.swift`: in-memory, records calls (`calls: [Call]` with dates), configurable per step to fail, emits scripted readings and statistics; built from `LaunchOptions` in DEBUG (contract §2) and used directly by unit tests. Compiled in all configurations so unit tests can use it, but only `#if DEBUG` code creates it from launch arguments.
- [X] T007 Extend `App/Match/LaunchOptions.swift` with `healthMode`, `heartRate`, `workoutStats` and `saveFails` (contract §2), parsed only `#if DEBUG`.
- [X] T008 Change `UITests/Support/XCUIApplication+Helpers.swift`: `launched(_:)` appends `-uiTestHealth denied` unless the arguments already contain `-uiTestHealth`, so every 002 UI test runs against "not authorized" without an expectation change (SC-005, research R12).
- [X] T009 Create `App/Health/HealthKitWorkoutService.swift` with the authorization members only (research R8): `typesToShare = [HKObjectType.workoutType()]`, `typesToRead = [HKQuantityType(.heartRate), HKQuantityType(.activeEnergyBurned)]` and nothing else (FR-003); `authorizationRequestStatus()` from `HKHealthStore.statusForAuthorizationRequest(toShare:read:)` (an error → `.unknown`); `requestAuthorization()` swallows errors; `canStartWorkout` is `authorizationStatus(for: .workoutType()) == .sharingAuthorized`. The workout members are stubs that do nothing until PR 2 (T028); no stub is reached because the PR 1 session never calls the service (T010), whatever `canStartWorkout` returns.
- [X] T010 Inject the service: `MatchSession.init` takes `workout: WorkoutService` (PR 1 stores it and doesn't call it yet). `App/TennisBeatApp.swift` builds `FakeWorkoutService` when `LaunchOptions.current.healthMode` is set, `HealthKitWorkoutService` otherwise. Update `MatchSession.preview` and every unit test that builds a session (pass a `denied` fake).

**Checkpoint**: all 002 unit and UI tests pass unchanged (SC-005 holds from here on).

---

## Phase 3: User Story 1 — Decide about Health before the first match (P1, PR 1) 🎯 MVP start

**Goal**: the onboarding before New match while the sheet has never been answered; Continue asks, Not now skips for this launch.

**Independent test**: `-uiTestHealth shouldRequest` shows the onboarding; Not now → New match; relaunch → onboarding; Continue → New match; relaunch (`granted`) → no onboarding.

### Tests

- [X] T011 [P] [US1] `UnitTests/HealthOnboardingTests.swift` (data-model § HealthOnboarding):
  - "US1 s1": `.shouldRequest` → `needsOnboarding` true;
  - "US1 s3": `continue()` calls `requestAuthorization()` once, then `needsOnboarding` false;
  - "US1 s4": `notNow()` → false, no request; a new `HealthOnboarding` (next launch) with the same `.shouldRequest` → true again;
  - "US1 s5": `.unnecessary` → false; `.unknown` → false;
  - "US1 s1, s6": while the status is being read, the root shows nothing; `.shouldRequest` within 1 s → onboarding, never New match first; no answer after 1 s (`ManualSleep` released) → New match, and a late `.shouldRequest` is ignored for this launch.
- [X] T012 [P] [US1] `UnitTests/StringCatalogTests.swift`: keep the 002 tests and add `"FR-002 onboarding strings"` checking the keys `health.onboarding.title`, `.line.1`, `.line.2`, `.line.3`, `.continue`, `.notNow` exist in EN, PL and UK and the EN values equal the copy table.
- [X] T013 [P] [US1] `UnitTests/InfoPlistTextTests.swift`: `"FR-004"` both `InfoPlist.xcstrings` catalogs have the new `NSHealthShareUsageDescription` EN, PL and UK values of the copy table (UK with «Здоров’я», research R9), and the EN read text mentions heart rate and active energy. Positive control: the old text fails it.
- [X] T014 [P] [US1] `UITests/HealthOnboardingUITests.swift`:
  - "US1 s1/s2": with `shouldRequest`, `health.onboarding` shows before `setup.format`; title, three lines, Continue and Not now exist with the copy-table EN texts;
  - "US1 s3": Continue → `setup.format` ready;
  - "US1 s4": Not now → `setup.format`; terminate and relaunch with `shouldRequest` → onboarding again;
  - "US1 s5": `granted` and `denied` → no onboarding;
  - "US1 s6": after Not now, Start → First server → a match starts as in 002.
- [X] T015 [P] [US6] Add the onboarding to `UITests/AccessibilityAuditUITests.swift` in EN, PL and UK at XXXL and at an accessibility size on 40 mm, and to `UITests/ScreenshotUITests.swift` (opt-in screenshots): no audit issue, both buttons ≥ 44 pt, nothing truncated (the screen scrolls) (US6 s1, s2, SC-006).

### Code

- [X] T016 [US1] Add the onboarding strings to `App/Localizable.xcstrings` from the copy table: EN source, PL draft, UK (line 2 approved R1-4, line 3 second sentence R1-5), using «Здоров’я» with the typographic apostrophe (research R9, R13). No string addresses the player as «ти» / «ви».
- [X] T017 [US1] Create `App/Health/HealthOnboarding.swift` (`@Observable`, main actor): `requestStatus`, `skippedThisLaunch` (not stored, Q4), `needsOnboarding`, `continue()`, `notNow()`; reads the status once at launch.
- [X] T018 [US1] Create `App/Onboarding/HealthOnboardingView.swift` (research R14): a `ScrollView` with the title (Watch/Headline), three lines (Watch/Body, `watch/text-secondary`), Continue (primary capsule, `brand/ball`) and Not now (secondary capsule, `watch/surface-raised`), identifiers of contract §1. No Dynamic Type cap.
- [X] T019 [US1] `App/RootView.swift`: wait for the status read up to 1 s (data-model § HealthOnboarding, Launch), then show `HealthOnboardingView` while `needsOnboarding`, otherwise the setup flow. Both buttons lead to New match.
- [X] T020 [US1] FR-004 texts, **catalogs first**: update `NSHealthShareUsageDescription` in `App/InfoPlist.xcstrings` and `TennisBeat/TennisBeat/InfoPlist.xcstrings` (EN, PL, UK from the copy table), then `INFOPLIST_KEY_NSHealthShareUsageDescription` in all four app build configurations in `TennisBeat/TennisBeat.xcodeproj/project.pbxproj` to the exact EN value (R1-3). Run `scripts/gates/check-infoplist-strings.sh` and `check-project-format.sh`.
- [X] T021 [US1] Add `docs/design/screens/watch-0-health-onboarding.md` with the 40 mm EN screenshot and the layout of T018, and a row for it in `docs/design/screens/README.md` (research R14). **Owner: Denys** approves the design in the PR review.
- [ ] T022 [US1] PR checklist steps 2–8 for PR 1. Device check for Denys: **2** (the sheet after Continue; Not now returns next launch; never again after an answer).

**Checkpoint**: PR 1 merged; a fresh install asks for Health with context; all 002 tests green.

---

## Phase 4: User Stories 2 and 5 — A match is a workout; play without permission (P1, PR 2) 🎯 MVP

**Goal**: every match with permission runs one tennis workout that follows the match and is saved once, or discarded for 0 points; without permission or after a failure, the 002 flow is unchanged.

**Independent test**: with `FakeWorkoutService`, `FakeClock` and `ManualSleep`, script start, pause, resume, summary, Undo, timeout, Done, 0-point End and failures, and check the calls and dates after every step (SC-002, SC-003).

### Tests

- [ ] T023 PR checklist step 1 for PR 2: worktree `.worktrees/003-workout`, branch `feat/003-workout`.
- [ ] T024 [P] [US2] `UnitTests/WorkoutLifecycleTests.swift` (data-model § WorkoutState transitions, contract §4):
  - "US2 s1": `granted` → `start(at: clock.startedAt)` once at `start(firstServer:)`, also after the coin toss; the fake's configuration is tennis with no location type (Q1); `formatChoice` has no new field;
  - "US2 s3", "FR-006": pause → `pause()`, resume → `resume()`; the fake records `now()` from the shared `FakeClock` at each call; after a scripted 30-minute match with three pauses, the recorded pause/resume times equal the clock's excluded intervals, and the active time computed from them equals `clock.elapsed` within 1 s. Positive control: a session that skips one `resume()` call fails it;
  - "US2 s4": the winning point and a confirmed End with a point → `pause()` and `workoutState == .summary(openedAt: clock.stoppedAt)`; the start of the 10-minute task (`ManualSleep.waiting == 1`);
  - "US2 s5": Undo from the summary → `resume()`, `.running`, the task cancelled;
  - "US2 s8", "FR-008": End with 0 points, and End after undoing every point → `discard()`, never `save`;
  - "US2 s9": `failing` → `.failed`; the match runs; no further call; `denied` → `.none`, no call at all;
  - "US2 s10": `.endedUnexpectedly` mid-match → `.failed`; score, clock, route and `isPaused` unchanged (FR-011); no `save` later;
  - "FR-011": no event (`heartRate`, `failed`, `endedUnexpectedly`) changes `match`, `clock`, `route` or `isPaused` — checked against a session snapshot before and after each event;
  - "Edge: pause during a tie-break": the workout pauses and resumes; tie-break state, server and side unchanged (`// ITF: TB-01`);
  - "Edge: early end long after the last point": End 20 min after the last point, unpaused → `openedAt` is the End time, not the point's.
- [ ] T025 [P] [US2] `UnitTests/WorkoutSaveTests.swift`:
  - "SC-002 scripted matrix": a table of scripted matches (start, pause, resume, summary Undo, timeout, early end with and without points, won) checks the expected call list after every step and exactly one `save` per final match with points, none otherwise;
  - "US4 s6, SC-003": for a won match and an early end, `save(endingAt:)` gets `clock.stoppedAt`, so `endingAt − startedAt − paused` equals the summary's Duration within 1 s;
  - "US2 s6", "US4 s4": Done → `save(endingAt: openedAt)` once; route `.setup` at once, before the save returns (FR-010);
  - "US2 s7": the task fires after 10 minutes → `save` once, `.saved`, `canUndo == false`, Done → `.setup` with no second save; positive control: at 9:59 nothing is saved;
  - "US2 s7, R3-2": the timeout save fails → `.failed`, `canUndo == true`, Undo returns to the match with no further workout call; Done after it → `pendingSaveFailureNotice`;
  - "US2 s7, R1-2": `denied` → the summary keeps Undo after 10 minutes (no task started);
  - "US4 s5", "FR-009": win → Undo → win again → Done: one `save`, ending at the **second** summary opening (R2-3); the first summary's time appears as a paused interval in the fake;
  - "FR-009": a double Done and Done after the timeout save never save twice;
  - "R5-2 end date": the fake stamps `pause()` 5 ms after `now()`; the saved workout's end is `>=` its last pause event and within 1 s of `clock.stoppedAt` (research R2);
  - "R5-3 Done, then start at once": the old save completes and the old workout emits `.ended` and a reading after the new match has started; the new match's `workoutState`, `latestHeartRate` and calls are unchanged; the old save's failure still sets the notice flag;
  - "US4 s7", "FR-015": Done with a failing save → `pendingSaveFailureNotice == true` after the save returns, while the route is already `.setup`; the same for a timeout save still running when Done is tapped that fails afterwards;
  - "Edge: summary left open, then Undo after the 10-minute save": Undo is a no-op once `.saved`.
- [ ] T026 [P] [US5] `UnitTests/WorkoutPermissionTests.swift`:
  - "US5 s1": `denied` → `.none`, no service call, summary Undo as in 002;
  - "US5 s2": `granted` with no readings → the workout runs and is saved;
  - US5 s3 has no test: it describes system behaviour (the watch face may return without a workout), and nothing in the app claims otherwise;
  - "US5 s4": permission changed between matches → the next `start` follows it; a running match keeps its state (the fake's `canStartWorkout` flipped mid-match changes nothing).
- [ ] T027 [P] [US2] `UnitTests/WorkoutRecoveryTests.swift` ("FR-009a"): `WorkoutRecovery.recover()` calls `recoverAndSave()` once, leaves the session route `.setup` with no match; a failing recovery is ignored.

### Code

- [ ] T028 [US2] Fill in the workout members of `App/Health/HealthKitWorkoutService.swift` (research R2, R3, R11): `HKWorkoutConfiguration` (`activityType = .tennis`, `locationType = .unknown`); `HKWorkoutSession` + `associatedWorkoutBuilder()` with `HKLiveWorkoutDataSource`; `startActivity(with:)` and `beginCollection(withStart:)` at the given date; `pause()` / `resume()`; `save(endingAt:)` = `stopActivity(with:)`, `end()`, `endCollection(withEnd:)`, `finishWorkout()`, all at `max(endingAt, last builder event date)` (research R2, #28 R5-2); one per-workout session/builder object with a token, callbacks tagged with it (research R11, #28 R5-3) → `SavedWorkout(uuid:statistics:)`; `discard()` = `end()`, `discardWorkout()`. `nonisolated` delegate methods hop to the main actor; `didFailWithError` and an unrequested `.ended` → `.endedUnexpectedly`; a start error → `.failed`. `recoverAndSave()` uses `recoverActiveWorkoutSession` and saves at now (R10).
- [ ] T029 [US2] `App/Match/MatchSession.swift` (data-model § MatchSession additions): `workoutState`, `sleep` (injected; production `Task.sleep(for:)`), the calls from `start`, `pause`, `resume`, the summary opening in `addPoint` and `endEarly`, `undo` from the summary, `done`, the 10-minute task with the scene-phase safety net (R4), the event handler ignoring events by state (R11), `pendingSaveFailureNotice`, and `canUndo` false while `.saving`/`.saved` (FR-007). `latestHeartRate` and `summaryStatistics` are added in PR 3 and PR 4.
- [ ] T030 [US2] `App/Summary/SummaryView.swift`: hide `summary.undo` when `canUndo` is false on the summary (contract §1).
- [ ] T031 [US2] Create `App/Health/WorkoutRecovery.swift` and `App/AppDelegate.swift` (`WKApplicationDelegate`, `handleActiveWorkoutRecovery()` → `WorkoutRecovery`); add `@WKApplicationDelegateAdaptor` in `App/TennisBeatApp.swift` (research R10).
- [ ] T032 [US2] Add `WKBackgroundModes = [workout-processing]` to the watch app's Info.plist with the Xcode MCP tools (research R9). Run `scripts/gates/check-project-format.sh` (no `validationLevel`, `objectVersion = 100`) and `check-infoplist-strings.sh`.
- [ ] T033 [US2] `UITests/WorkoutUITests.swift`: with `-uiTestHealth granted`, a won match shows Undo, and with `failing` the match scores to the summary (US2 s9). This is a smoke test: the summary has no Health rows before PR 4, so the Duration-only check is in T050. The 10-minute path is unit-tested only (T025).
- [ ] T034 [US2] Spec 002 notes (R1-2): add "changed by spec 003" to FR-020 in `specs/002-watch-match/spec.md` and to the Undo bullet in `docs/design/screens/watch-6-summary.md`: Undo is gone once a workout is saved (10-minute timeout); a failed save brings it back (R3-2).
- [ ] T035 [US2] PR checklist steps 2–8 for PR 2. Device checks for Denys: **1, 4, 6, 7, 8, 10, 12, 13, 14, 15** (4 decides the permission rule: missing heart-rate or energy data in the saved workout → open a spec change for FR-003/FR-004, no workaround).

**Checkpoint**: PR 2 merged; the app stays on screen for a whole match on a real watch, and each match with points leaves one tennis workout in Health. Until PR 4, a failed save sets `pendingSaveFailureNotice` but nothing shows it yet (T055).

---

## Phase 5: User Story 3 — See heart rate during the match (P2, PR 3)

**Goal**: the header shows ♥ and the latest reading, or ♥ and "--", while a workout runs.

**Independent test**: scripted readings through the fake; the header and its VoiceOver text in every Q3 state.

### Tests

- [ ] T036 PR checklist step 1 for PR 3: worktree `.worktrees/003-heart-rate`, branch `feat/003-heart-rate`.
- [ ] T037 [P] [US3] `UnitTests/HeartRateDisplayTests.swift` (data-model § HeartRateDisplay):
  - "US3 s1": `running` + a reading 5 s old → `.value(142)`;
  - "US3 s3": no reading → `.unavailable`; a reading exactly 30 s old → `.value`, at 30.001 s → `.unavailable`; `paused` → `.unavailable`;
  - "US3 s4": `.none` and `.failed` → `.hidden`;
  - "US3 s5": Always On → `.hidden`;
  - "US3 s6": VoiceOver "Heart rate, 142 beats per minute", "Heart rate unavailable", in EN, PL and UK, with PL and UK plural forms for 1, 2, 5 and 22 (positive control: PL differs from EN);
  - "Edge: heart rate above 199": `.value(205)` text is "205";
  - "US3 s2": `animation` is `nil` for every display (a new reading is shown without animation).
- [ ] T038 [P] [US3] `UnitTests/WorkoutLifecycleTests.swift` additions: `.heartRate` events update `latestHeartRate` only while `running`/`paused`; ignored after `.saved`, `.discarded`, `.failed`; `latestHeartRate` is `nil` after Done (FR-014).
- [ ] T039 [P] [US3] `UITests/HeartRateUITests.swift`:
  - "US3 s1": `granted -uiTestHeartRate 142 -uiTestExposeValues` → `heartRate.value` is "142", and `heartRate`'s label is the VoiceOver text;
  - "US3 s2" is checked in T037's unit test, not here (UI tests can't see animations);
  - "US3 s4": `denied` → no `heartRate` element;
  - "US3 s5": `-uiTestAlwaysOn` → no `heartRate` element;
  - "US3 s3": `granted` without readings → "--".
- [ ] T040 [P] [US6] Add the score screen with `granted -uiTestHeartRate 205` to the accessibility audits and screenshots in EN, PL and UK at XXXL on 40 mm: time and heart rate untruncated, zones unchanged from 002 (US6 s2, Q3).

### Code

- [ ] T041 [US3] Add `score.heartRate.accessibility %lld` (plural) and `score.heartRate.unavailable` to `App/Localizable.xcstrings` (copy table, research R13).
- [ ] T042 [US3] Create `App/Health/HeartRateDisplay.swift` (`nonisolated`, pure); add `latestHeartRate` to `MatchSession` and handle `.heartRate` events; `HealthKitWorkoutService` emits readings from `workoutBuilder(_:didCollectDataOf:)` (research R6).
- [ ] T043 [US3] `App/Score/ScoreView.swift` / `App/Score/ElapsedTimeView.swift`: the heart-rate row (with a unit test in `UnitTests/HeartRateDisplayTests.swift`, written first in T037: "US3 s2" `HeartRateDisplay.animation` is `nil` for a reading change, and the view applies it with `.transaction { $0.animation = display.animation }`) on the elapsed-time line after the time (`ViewThatFits`, research R6), `status/heart` icon, Watch/Footnote, monospaced digits, no animation; part of the elapsed-time element's VoiceOver value; identifiers `heartRate`, `heartRate.value` (contract §1). The status line keeps its place.
- [ ] T044 [US3] `docs/design/screens/watch-3-score.md`: replace "Heart-rate row is hidden in spec 002" with the Q3 layout and the XXXL 40 mm result (US3 s1).
- [ ] T045 [US3] PR checklist steps 2–8 for PR 3. Device checks for Denys: **3, 9** (header part), **11**.

---

## Phase 6: User Story 4 — See and keep the workout after the match (P1, PR 4), and the final US6 audit

**Goal**: the summary rows from the workout's statistics; the save-failure notice; nothing stored.

**Independent test**: scripted statistics through the fake; the rows, hidden rows, VoiceOver, the notice once.

### Tests

- [ ] T046 PR checklist step 1 for PR 4: worktree `.worktrees/003-summary`, branch `feat/003-summary`.
- [ ] T047 [P] [US4] `UnitTests/SummaryHealthRowsTests.swift` (data-model § SummaryHealthRows):
  - "US4 s1": `138/171/612` → "Heart rate avg / max" · "138 / 171", "Active energy" · "612 kcal" (EN), «612 ккал» (UK), PL per system format; order after Duration;
  - "US4 s2": no heart rate → no heart-rate row; average without maximum → no row; no energy → no energy row; Duration always;
  - "US4 s3": `nil` statistics → no rows;
  - "US4 s8": VoiceOver "Heart rate: average 138, maximum 171 beats per minute", "Active energy: 612 kilocalories", plural on the maximum in PL and UK (positive control: PL differs from EN);
  - "Edge: rounding": 137.6 → 138; 611.5 kcal → whole kilocalories as the formatter rounds.
- [ ] T048 [P] [US4] `UnitTests/WorkoutSaveTests.swift` additions: "FR-013" the summary snapshot is `statistics()` at the summary opening; after the timeout save it becomes the `SavedWorkout.statistics`; Undo drops it; a failed timeout save drops it, so the summary shows Duration only (Story 4 s3, R3-2, data-model § WorkoutState).
- [ ] T049 [P] [US4] `UnitTests/HealthStorageTests.swift` ("SC-007", "FR-014"): run a scripted match with a fake reading of 187 bpm and statistics 181/197/733, Done; then search `UserDefaults.standard.dictionaryRepresentation()` and every file under the app container's `Library` and `Documents` for "187", "197" and "733". Positive control: a value written on purpose to a test suite is found by the same search.
- [ ] T050 [P] [US4] `UITests/SummaryHealthUITests.swift`:
  - "US4 s1": `granted -uiTestWorkoutStats 138,171,612` → `summary.heartRate`, `summary.energy` with their labels;
  - "US4 s2": `138,171,` → no `summary.energy`; `,,612` → no `summary.heartRate`;
  - "US4 s3": `denied` → neither; "US2 s9": `failing` → neither, Duration only;
  - "US4 s7": `granted -uiTestSaveFails` → Done → `health.saveFailed` on New match; OK → gone; a second Done of a new match without failure → no notice; with a fake save that fails 1 s after Done, the notice appears on the already-showing New match.
- [ ] T051 [P] [US6] Final audit (SC-006): the summary with both rows, the onboarding and the score header in the accessibility audits and screenshots in EN, PL and UK at XXXL and an accessibility size on 40 mm; rows ≥ 44 pt; no truncation; the heart icon always with text (US6 s1–s4).

### Code

- [ ] T052 [US4] Add `summary.heartRate.*`, `summary.energy.*` and `health.saveFailed.*` to `App/Localizable.xcstrings` (copy table; plural on `%2$lld`; research R13).
- [ ] T053 [US4] Create `App/Health/SummaryHealthRows.swift` (`nonisolated`, pure, research R7, R13: `Measurement<UnitEnergy>` in kilocalories, `.abbreviated` shown, `.wide` spoken, `usage: .asProvided`); `HealthKitWorkoutService.statistics()` and the saved workout's statistics (`averageQuantity`, `maximumQuantity`, `sumQuantity`); `summaryStatistics` in `MatchSession`; rows in `SummaryModel` after Duration.
- [ ] T054 [US4] `App/Summary/SummaryView.swift`: the two rows like the Duration row (one VoiceOver element ≥ 44 pt each, `ViewThatFits`), `status/heart` icon, identifiers `summary.heartRate`, `summary.energy`.
- [ ] T055 [US4] `App/RootView.swift` / setup flow: the one-time alert "Workout not saved to Health" · OK on New match after Done when `pendingSaveFailureNotice` is true, observed, so it also appears when the flag turns true while New match is showing; cleared on OK (research R5, contract §1).
- [ ] T056 [US4] `docs/design/screens/watch-6-summary.md`: record the two rows, "Active energy" replacing «Активні ккал» (Q5), and remove "Heart-rate and kcal rows are hidden".
- [ ] T057 [US4] PR checklist steps 2–8 for PR 4. Device checks for Denys: **5, 9** (summary part).

**Checkpoint**: spec 003 complete; every device check 1–15 is in `docs/harness.md`.

---

## Dependencies & Execution Order

- **Phases 1–2** (PR 1) block everything: `WorkoutService`, the fake, the launch arguments and the UI-test default.
- **Phase 3** (US1, PR 1) needs Phase 2.
- **Phase 4** (US2, US5, PR 2) needs PR 1 merged: the onboarding is how a device grants permission.
- **Phase 5** (US3, PR 3) and **Phase 6** (US4, PR 4) need PR 2 (`workoutState`); they touch different screens and could be built in either order, but are merged one at a time (one PR per worktree). The plan order is PR 3 then PR 4.
- **Within a phase**: tests first (committed, failing, recorded), then strings, then models, then the service, then views, then docs; then the PR checklist.

## Parallel opportunities

- Phase 2: T003 and T004 together; T005 before T006–T010.
- Phase 3: T011–T015 together (different files); T016–T018 before T019.
- Phase 4: T024–T027 together; T028 and T031–T032 in parallel with T029 once T024–T027 fail as expected.
- Phase 5: T037–T040 together.
- Phase 6: T047–T051 together; T052 before T053–T055.

## Implementation strategy

1. **MVP**: PR 1 + PR 2. The app asks for Health with context, every match is a workout, the app stays on screen, and the workout is saved once. This is the reason for the feature (US2 Why).
2. **PR 3** adds the live heart rate; **PR 4** adds the summary rows, the save notice and the final audit.
3. Each PR leaves `main` working: without permission the 002 flow is unchanged from PR 1 on (SC-005).
