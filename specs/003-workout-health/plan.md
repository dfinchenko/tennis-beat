# Implementation Plan: Workout and Health on Apple Watch

**Branch**: `feat/003-plan` | **Date**: 2026-10-15 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/003-workout-health/spec.md` (Status: Approved, 2026-10-15, Denys; his review 2 decisions R2-1 and R2-3 from #27 and his plan-review decisions applied in this branch)

## Summary

Turn every watch match into a tennis workout. The 002 `MatchSession` gains an injected `WorkoutService` (research R1). The session calls it from its existing commands:
- start at the match start;
- pause and resume with the match;
- pause at the summary, with the end date fixed then;
- resume on Undo from the summary;
- save on Done or after 10 minutes on the summary;
- discard on a 0-point End (R2, R4).

Heart rate comes from the live workout builder, is held in memory only, and is shown in the score header through a pure `HeartRateDisplay` (R6). The summary rows come from the builder's statistics up to the summary opening, the same data the saved workout gets (R7). Before New match, a Health onboarding shows while HealthKit says the permission sheet has never been answered (R8). The app stores nothing new. Without permission, or when the workout fails, the 002 flow runs unchanged.

Tests come first: unit tests with a fake workout service, clock and sleep for the whole lifecycle (SC-002, SC-003); the 002 UI tests run unchanged against a "denied" fake (SC-005); new UI tests and audits cover the onboarding, header and summary rows (SC-006). Real HealthKit is covered by the spec's 15 device checks. Delivery is **four small PRs** (§ Delivery).

## Technical Context

**Language/Version**: Swift 6 (language mode 6, strict concurrency), app targets with `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` (002 R13; HealthKit delegates `nonisolated`, research R11)

**Primary Dependencies**:
- HealthKit (`HKHealthStore`, `HKWorkoutSession`, `HKLiveWorkoutBuilder`, `HKLiveWorkoutDataSource`) and WatchKit (`WKApplicationDelegate` for workout recovery): system frameworks;
- SwiftUI, Foundation (`Measurement`, `FormatStyle`) and `TennisCore`, as in 002.

No new dependency.

**Storage**: none new. The onboarding state is HealthKit's own authorization request status (R8); heart rate, energy and the workout state stay in memory (FR-014, constitution IX). The saved workout lives in Health.

**Testing**:
- Swift Testing in `TennisBeat Watch AppTests` with `FakeWorkoutService`, `FakeClock` and `ManualSleep` (R12);
- XCUITest in `TennisBeat Watch AppUITests` with the `-uiTestHealth` fake modes ([contract](contracts/ui-contract.md) §2);
- `swift test --package-path Packages/TennisCore`, green and unchanged;
- device checks 1–15 for everything HealthKit does (constitution VII).

**Target Platform**: watchOS 26, 40 mm layout target (002 Q9). The iOS app changes only its Info.plist read text (FR-004, R1-3).

**Project Type**: watchOS app (SwiftUI) using a local Swift package

**Performance Goals**:
- The first heart-rate reading in the header within 30 s of the start (SC-004, device);
- a new reading shown within one header redraw (1 s);
- workout active time and the saved duration within 1 s of the match's elapsed time (FR-006, SC-003);
- battery comparable to the system Workout app's tennis workout (device check 12).

**Constraints**:
- The workout never changes the score, the clock or the route (FR-011);
- no error blocks scoring (FR-010);
- at most one saved workout per match (FR-009);
- nothing written to app storage (FR-014, SC-007);
- strings in EN, PL and UK (FR-016);
- `Packages/TennisCore` untouched (FR-018);
- never write `validationLevel` into the project (CLAUDE.md);
- Info.plist texts change in the catalogs first (gate).

**Scale/Scope**:
- 1 new screen (Health onboarding), 2 changed (Watch 3 header, Watch 6 rows), 1 notice;
- 6 user stories, 18 FRs + FR-009a, 7 SCs, 15 device checks;
- 4 implementation PRs.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-checked after Phase 1 design.*

| Principle | Status | Evidence |
| --- | --- | --- |
| I. Spec before code | PASS | `spec.md` is `Status: Approved (2026-10-15, Denys)`. The spec edits in this branch are Denys's decisions only: R2-1 and R2-3 from #27 (**Review 2 decisions**), and R3-2, the PR order and the permission rule from his plan review (**Review 3 and plan decisions**). Every decision is in [Denys's #28 comment](https://github.com/dfinchenko/tennis-beat/pull/28#issuecomment-6201412560), and the approval commit cites it (harness: decisions are PR comments). The artifact gate runs after `/speckit-tasks`. |
| II. Tennis rules | PASS (N/A) | No scoring rule is touched; the engine is unchanged (FR-011, FR-018). Tests that replay matches keep their 002 ITF citations. |
| III. Test first | PASS | Each PR starts with failing unit tests against the fake service, then UI tests, then code, with `test-first-evidence.md` rows. Boundary tests: Undo from the summary resumes the workout and keeps one save (Story 4 s5); the 10-minute timeout; pause during a tie-break also pauses the workout (spec Edge cases); the 30-second staleness boundary. Crash recovery of the match stays in spec 004; FR-009a's workout recovery is unit-tested (R10). |
| IV. Evidence bound to a commit | PASS | `Reviewed-SHA` on every PR; `watch-tests` CI runs the unit and UI tests. |
| V. Independent review | PASS | The `reviewer` gets only `specs/003-workout-health` and the base branch. |
| VI. One writer per worktree | PASS | This plan is in `.worktrees/003-plan`; each PR gets its own worktree and branch. |
| VII. Green tests ≠ accepted build | PASS | HealthKit can't be tested in the simulator (R12), so each PR lists its device checks (§ Delivery), and they join `docs/harness.md`. |
| VIII. AI never invents numbers | PASS (N/A) | No generated text. Heart rate and energy come from HealthKit only. |
| IX. Privacy by default | PASS | HealthKit is a system framework, not a dependency. No network, no analytics. Health values only in memory, never stored (FR-014), checked by `HealthStorageTests` (SC-007). The onboarding state is the system's (R8). Works without permission (Story 5, SC-005) and without the iPhone (device check 13). |
| X. Three languages | PASS | New keys in `Localizable.xcstrings` and both `InfoPlist.xcstrings`, EN/PL/UK, plural forms, `Measurement` formatting (R13); `StringCatalogTests` and the Info.plist gate. |
| XI. Accessibility and HIG | PASS | VoiceOver texts in the models (Stories 3, 4), 44 pt rows and buttons, audits in three languages at XXXL on 40 mm (SC-006), the heart icon always with text (Story 6 s4), no heart rate in Always On. |
| XII. Honest metrics | PASS | This PR adds the #27 metrics row; each implementation PR adds the row for the previous one. |

**Post-design re-check (after Phase 1)**: PASS, no new violations.
- The `WKBackgroundModes` key and the delegate adaptor are configuration, not dependencies. The pbxproj change is checked by `check-project-format.sh` (R9).
- No type is added to `TennisCore`.
- The only new persistent data is the saved workout in Health, which is the feature's purpose.

## Project Structure

### Documentation (this feature)

```text
specs/003-workout-health/
├── spec.md              # Approved spec (+ review 2 decisions)
├── plan.md              # This file
├── research.md          # Phase 0: decisions R1–R14
├── data-model.md        # Phase 1: WorkoutService, WorkoutState, HeartRateDisplay, WorkoutStatistics, SummaryHealthRows, HealthOnboarding
├── quickstart.md        # Phase 1: validation guide
├── contracts/
│   └── ui-contract.md   # identifiers, launch arguments, values, workout per command
├── checklists/requirements.md
└── tasks.md             # Phase 2 (/speckit-tasks)
```

### Source Code (repository root)

```text
TennisBeat/TennisBeat Watch App/
├── TennisBeatApp.swift              # injects the workout service; @WKApplicationDelegateAdaptor
├── AppDelegate.swift                # handleActiveWorkoutRecovery → WorkoutRecovery (FR-009a)
├── RootView.swift                   # onboarding cover; save-failure notice on New match
├── Localizable.xcstrings            # + health.*, score.heartRate.*, summary.heartRate.*, summary.energy.*
├── InfoPlist.xcstrings              # new read text (FR-004)
├── Health/
│   ├── WorkoutService.swift         # protocol, WorkoutEvent, HeartRateReading, WorkoutStatistics, SavedWorkout
│   ├── HealthKitWorkoutService.swift
│   ├── FakeWorkoutService.swift     # DEBUG launch modes (contract §2); also used by unit tests
│   ├── WorkoutRecovery.swift
│   ├── HealthOnboarding.swift       # observable onboarding state
│   ├── HeartRateDisplay.swift
│   └── SummaryHealthRows.swift
├── Match/
│   ├── MatchSession.swift           # + workoutState, the timeout, the notice flag
│   ├── SummaryModel.swift           # + health rows
│   └── LaunchOptions.swift          # + -uiTestHealth, -uiTestHeartRate, -uiTestWorkoutStats, -uiTestSaveFails
├── Onboarding/
│   └── HealthOnboardingView.swift   # new screen (Story 1)
├── Score/ScoreView.swift, ElapsedTimeView.swift   # heart-rate row
└── Summary/SummaryView.swift        # two rows; Undo hidden after the save

TennisBeat/TennisBeat Watch AppTests/
├── Support/                         # + recording use of FakeWorkoutService
├── WorkoutLifecycleTests.swift      # Story 2, SC-002, SC-003
├── WorkoutSaveTests.swift           # Story 4 s4–s7, FR-008, FR-009, FR-015
├── WorkoutRecoveryTests.swift       # FR-009a
├── HealthOnboardingTests.swift      # Story 1
├── HeartRateDisplayTests.swift      # Story 3
├── SummaryHealthRowsTests.swift     # Story 4 s1–s3, s8
└── HealthStorageTests.swift         # SC-007

TennisBeat/TennisBeat Watch AppUITests/
├── Support/XCUIApplication+Helpers.swift   # adds -uiTestHealth denied by default (SC-005)
├── HealthOnboardingUITests.swift
├── HeartRateUITests.swift
├── SummaryHealthUITests.swift
└── AccessibilityAuditUITests.swift, ScreenshotUITests.swift   # + new screens

TennisBeat/TennisBeat/InfoPlist.xcstrings    # same read text (R1-3)
TennisBeat/TennisBeat.xcodeproj/project.pbxproj  # INFOPLIST_KEY_NSHealthShareUsageDescription ×4; WKBackgroundModes
docs/design/screens/watch-0-health-onboarding.md (new), watch-3-score.md, watch-6-summary.md
specs/002-watch-match/spec.md               # FR-020 "changed by spec 003" note (R1-2)
docs/harness.md                             # device checklist rows, metrics rows
```

**Structure Decision**: New code goes into the watch app target and its two test targets; the folders are synchronized, so new files join the targets. HealthKit types are confined to `Health/HealthKitWorkoutService.swift`, `WorkoutRecovery.swift` and `AppDelegate.swift`; everything else sees only the protocol. The iOS app changes only its Info.plist read text. `TennisCore` is not changed.

## Delivery: four small PRs

Each PR has its own worktree and branch off `main` after the previous one is merged. Each one writes failing tests first, then the code, builds both schemes, runs the flow on the 40 mm simulator in EN, PL and UK with screenshots, lists its device checks, adds the metrics row for the previous PR, and runs the reviewer.

| PR | Branch | Scope | Stories / FRs | Device checks |
| --- | --- | --- | --- | --- |
| 1 | `feat/003-onboarding` | `WorkoutService` protocol with the authorization members, `HealthKitWorkoutService` (authorization only), `FakeWorkoutService`, `-uiTestHealth`, the UI-test helper default (SC-005), the onboarding screen and its design record, the FR-004 texts in both apps | US1; FR-001..FR-004; US6 for the onboarding | 2 |
| 2 | `feat/003-workout` | The lifecycle in `MatchSession`, the HealthKit session and builder, `WKBackgroundModes`, the 10-minute timeout, saving and discarding, failures, FR-009a recovery, Undo removed after the save, the spec 002 FR-020 note | US2; US4 s4, s5; US5; FR-005..FR-011, FR-009a | 1, 4, 6, 7, 8, 10, 12, 13, 14, 15 |
| 3 | `feat/003-heart-rate` | Readings, `HeartRateDisplay`, the header row, `watch-3-score.md` | US3; FR-012; US6 for the header | 3, 9 (header), 11 |
| 4 | `feat/003-summary` | `WorkoutStatistics`, `SummaryHealthRows`, the rows, the save-failure notice, `HealthStorageTests`, `watch-6-summary.md`, the final SC-006 audit | US4 s1–s3, s6–s8; FR-013..FR-017; SC-006, SC-007 | 5, 9 (summary) |

**Order** (decided by Denys, 2026-10-15, spec Assumptions): the onboarding comes first. Without it nothing would ask for permission, so a lifecycle PR couldn't be tested on the watch. With the onboarding first, every PR leaves `main` working and device-testable, and PR 2 starts real workouts at once.

Why the rest of the order: PR 2 is the main reason for the feature (the app stays on screen) and holds every save rule. PR 3 and PR 4 are display layers on PR 2's state. US6 is not a separate PR: each PR meets it for its own screens.

## Dependencies and open inputs

- **R3-2 (decided)**: a match whose workout failed to start, ended unexpectedly or failed to save keeps Undo on the summary (research R3, R5).
- **Share permission for heart rate and energy (device check 4, decided)**: the plan follows Apple's pattern (share the workout type only, research R8). If the device shows a workout without its heart-rate graph or energy, a spec change to FR-003/FR-004 is opened, not a workaround.
- **Summary vs Health values (device check 5)**: research R7 explains a possible fraction-of-a-beat difference from late samples, and its fix, which needs no spec change.
- **Copy**: the PL rows and the draft rows go in as drafts; the Polish native review (#22) doesn't block the PRs. The UK strings use the catalog's typographic apostrophe («Здоров’я», R9).
- **Watch onboarding design**: PR 1 adds the screen to `docs/design/screens/` for Denys's approval (R14).
- **CI**: `watch-tests` already runs watch unit and UI tests on the 40 mm simulator; no CI change is expected.

## Complexity Tracking

No constitution violations to justify.
