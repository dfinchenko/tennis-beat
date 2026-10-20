# Test-first evidence: 003-workout-health

For each added test, a run against the code before the implementation it checks, or, for a test of existing behaviour, against a recorded mutation (rule: `docs/harness.md` § Test-first evidence). One section per PR, newest last. The reviewer checks each entry against the diff. Simulator: Apple Watch SE 3 (40 mm), watchOS 27.0.

## PR 1 `feat/003-onboarding` (Health onboarding)

The tests were committed first, in **`fa6bd25`** (T003, T004, T008, T011–T015), before any onboarding code.

**Run 1, unit tests at `fa6bd25`:** the test target doesn't compile. `LaunchOptionsHealthTests.swift`, `FakeWorkoutServiceTests.swift`, `HealthOnboardingTests.swift`: cannot find `FakeHealthMode`, `FakeWorkoutService`, `HealthOnboarding`, `WorkoutStatistics` in scope; no members `healthMode`, `heartRate`, `workoutStats`, `saveFails` on `LaunchOptions`. Every test in these three files is covered by this run.

**Run 2, unit tests at `65273b6`** (the Swift code, before the strings and the Info.plist texts): 167 passed, 2 failed:
- `StringCatalogTests` "FR-002 onboarding strings equal the copy table in EN, PL and UK": `health.onboarding.notNow is missing` (and the other five keys);
- `InfoPlistTextTests` "FR-004 both catalogs have the new read text in EN, PL and UK", for both catalogs (`TennisBeat/InfoPlist.xcstrings`, `TennisBeat Watch App/InfoPlist.xcstrings`): the old read text.

`InfoPlistTextTests` "FR-004 the EN read text names heart rate and active energy" passed in this run: it checks the copy-table constant in the test itself, and its positive control (the spec 002 text fails the same check) is part of the test.

**Run 3, UI tests against the app code of `fa6bd25`** with the final UI test files of `6fee9dc` (`git worktree add --detach <dir> fa6bd25`, `git checkout 6fee9dc -- "TennisBeat/TennisBeat Watch AppUITests"`; the three new unit test files were deleted in that throwaway tree only, because they don't compile there, see run 1, and the scheme builds the unit target too):
- failed: `HealthOnboardingUITests` `testUS1s1s2OnboardingBeforeNewMatchWithItsTexts`, `testUS1s3ContinueOpensNewMatch`, `testUS1s4NotNowOpensNewMatchAndTheOnboardingReturnsNextLaunch`, `testUS1s6AfterNotNowAMatchStartsAsInSpec002` ("health.onboarding.title was not ready within 20.0 s"), and `AccessibilityAuditUITests` `testUS6s1s2AuditHealthOnboarding` (no `health.onboarding.continue`);
- passed: `testUS1s5NoOnboardingOnceTheSheetWasAnswered`, which checks that the onboarding is absent; see run 4.

**Run 4, a recorded mutation of the final code** (`6fee9dc`; never committed): the onboarding shows whatever HealthKit answers.

```diff
--- a/TennisBeat/TennisBeat Watch App/Health/HealthOnboarding.swift
+++ b/TennisBeat/TennisBeat Watch App/Health/HealthOnboarding.swift
   var needsOnboarding: Bool {
-    isReady && requestStatus == .shouldRequest && !skippedThisLaunch
+    isReady && !skippedThisLaunch
   }
```

- failed: `HealthOnboardingUITests` `testUS1s5NoOnboardingOnceTheSheetWasAnswered`; `HealthOnboardingTests` "US1 s5 once the sheet was answered the onboarding never shows" (both `denied` and `granted`), "US1 s5 an unknown status (a HealthKit error) never shows the onboarding", "US1 s3 Continue asks once, then New match", "US1 s1, s6 nothing shows while the status is read; a late answer is ignored";
- passed (they expect the onboarding, which the mutation keeps): "US1 s1 the sheet was never answered", "US1 s1 an answer within 1 s", "US1 s4 Not now".

**The 002 UI tests (SC-005):** with the helper's `-uiTestHealth denied` default (T008), the full UI suite on the code before the UI-test wait fix ran 71 tests: 60 passed, 6 skipped (the opt-in screenshot tests), and 5 failed, all of them new onboarding tests (below). Every spec 002 UI test passed.

**One test-harness problem, fixed before review (not an expectation change):** the onboarding UI tests first waited for Continue to be hittable at launch. On the 40 mm watch Continue starts below the fold, so they timed out even with the onboarding on screen. They now wait for the title, and the `tap` helper scrolls to the buttons as before. With that change all six pass on `6fee9dc`.

**Not run for evidence:** `ScreenshotUITests.testHealthOnboardingScreens` (T015) is opt-in (it skips unless `SCREENSHOT_LANGUAGE` is set, so CI skips it) and asserts nothing: it only attaches the PR screenshots. Run for the screenshots in EN, PL and UK at the default size and XXXL.

### Review 1 and Denys's design condition (#29)

**Continue visible without scrolling** ([Denys, #29](https://github.com/dfinchenko/tennis-beat/pull/29#issuecomment-6203433908)): `HealthOnboardingUITests.testDesignContinueVisibleWithoutScrollingAtDefaultSize` was committed in **`99cec81`**, before the pinned Continue. Run on `99cec81`: failed, "Continue off screen in en" (the test stops at the first language). With the pinned Continue it passes in EN, PL and UK.

**R1-3, `InfoPlistTextTests` "FR-004 each catalog's EN read text names heart rate and active energy"** now reads each catalog's EN value instead of a constant in the test (listed in `test-expectation-changes.md`). Run against a recorded mutation (never committed): the watch catalog's EN `NSHealthShareUsageDescription` set back to the spec 002 text, "Tennis Beat reads your heart rate to show it in your match summary. Health data stays in the Health app.". Result: `readTextNamesTypes(catalog:)` and `readTextInCatalog(catalog:)` failed for the watch catalog and passed for the iPhone catalog, which kept the new text.

**`HealthOnboardingUITests.testUS1s2TextScrollsAbovePinnedContinue`** checks the pinned layout: the text drags up until Not now and line 3 sit above Continue. It was written after the pinned Continue (it doesn't apply to the earlier layout, where Not now sits under Continue), so it was run against a recorded mutation of the final code (never committed):

```diff
--- a/TennisBeat/TennisBeat Watch App/Onboarding/HealthOnboardingView.swift
+++ b/TennisBeat/TennisBeat Watch App/Onboarding/HealthOnboardingView.swift
       }
     }
+    .scrollDisabled(true)  // MUTATION
     // Denys's design condition on #29: at the default size Continue stays visible without
```

Result: failed, "Not now under Continue" (Not now's bottom at 348 pt, Continue's top at 135 pt). Without the mutation it passes.

**Another test-harness finding:** with the pinned Continue, a quick XCUITest `swipeUp()` on the watch simulator doesn't scroll the onboarding's `ScrollView`, while a press-and-drag and the Digital Crown do (a temporary probe, not committed: Not now moved from y 304 to 82 under both). The UI tests and the screenshot test now use the helper `dragUp()` (a press-and-drag). Scrolling with a finger and the crown on a real watch is part of device check 2.

## PR 2 `feat/003-workout` (workout lifecycle)

The tests were committed first, in **`f54757f`** (T024–T027, T033, the `WorkoutHarness` support and the `FakeWorkoutServiceTests` "failing" wait), before any lifecycle code.

**Run 1, unit tests at `f54757f`:** the test target doesn't compile (49 errors). `WorkoutHarness.swift`: extra argument `sleep` in the `MatchSession` call; no member `currentToken` on `FakeWorkoutService`. `WorkoutLifecycleTests.swift`: no member `configuration` on `HealthKitWorkoutService`; no member `workoutState` on `MatchSession`. `WorkoutSaveTests.swift`: cannot find `WorkoutEndDate`; no members `beforeSaveReturns`, `emit`, `eventDates`, `eventDelay`, `savedEndDates` on the fake; no members `checkSummaryTimeout`, `dismissSaveFailureNotice`, `pendingSaveFailureNotice`, `workoutState` on `MatchSession`. `WorkoutPermissionTests.swift`: the fake's `mode` setter is inaccessible; no `workoutState`. `WorkoutRecoveryTests.swift`: cannot find `WorkoutRecovery`; no `pendingSaveFailureNotice`, `workoutState`. Every test in these files is covered by this run. The changed `FakeWorkoutServiceTests` "failing" test is in the same target, so it didn't run either; against the code before `2fab92a` it passes trivially (the old fake reported `.failed` during `start`), and its change is listed in `test-expectation-changes.md`.

**Compile fixes in the tests, made with the code in `2fab92a`** (no expectation changed): the `WorkoutSaveTests` script table (`Step`, `Script`, `scripts`) and `CallKind` are marked `nonisolated`, because Swift Testing reads arguments outside the main actor.

**Run 2, unit tests at `2fab92a`:** 289 test cases passed, 0 failed (FakeWorkoutServiceTests 7, WorkoutLifecycleTests 21, WorkoutSaveTests 23, WorkoutPermissionTests 4, WorkoutRecoveryTests 2, with parameterized cases).

**Run 3, the full UI suite at `2fab92a`:** 75 tests, 69 passed and 6 skipped (the opt-in screenshot tests), 0 failed, including both `WorkoutUITests` and every spec 002 UI test (SC-005).

**Run 4, a recorded mutation of `6a58f2f`** (never committed): the summary hides Undo whenever the match has a workout.

```diff
--- a/TennisBeat/TennisBeat Watch App/Summary/SummaryView.swift
+++ b/TennisBeat/TennisBeat Watch App/Summary/SummaryView.swift
-          if session.canUndo {
+          if session.canUndo && session.workoutState == .none {
```

- failed: `WorkoutUITests` `testUS2s4s6WithAWorkoutTheSummaryOffersUndoAndDoneOpensNewMatch` and `testUS2s9AFailedWorkoutLeavesTheMatchAsInSpec002` (`summary.undo` missing, lines 35 and 44);
- passed: all six `SummaryUITests`, which run with the `denied` fake, so the 002 summary keeps Undo (SC-005).

`WorkoutUITests` is a smoke test of existing behaviour (T033): against the code before `2fab92a` the session never called the workout, so both tests would pass there too; run 4 is their evidence.

**Not run for evidence:** `ScreenshotUITests.testWorkoutSummaryScreens` is opt-in and asserts only that the summary shows; it attaches the PR screenshots.

### Review 1 fixes (#30 R1-1, R1-4, R1-5)

The tests were committed first, in **`026050e`**, before the fixes.

**Run 5, unit tests at `026050e`:** the target doesn't compile. `HealthKitStatisticsTests.swift`: extra arguments in the call to `HealthKitWorkoutService.statistics` (no `statistics(averageHeartRate:maximumHeartRate:activeEnergy:)` yet). This covers both `HealthKitStatisticsTests` tests.

**Run 6, `WorkoutLifecycleTests` at `026050e` without `HealthKitStatisticsTests.swift`** (deleted in a throwaway `git worktree add --detach` tree only, so the rest compiles): failed: "US2 s9 a workout that fails to start leaves the match running with no further call" (no `discard` after `.failed`). The other lifecycle tests passed, including the R1-5 edit of "Edge: early end long after the last point", which only removes an always-true expectation (listed in `test-expectation-changes.md`).

**Run 7, unit tests at `9ba9e9a`** (the fixes): 291 test cases passed, 0 failed (`HealthKitStatisticsTests` 2 new). `WorkoutUITests` (2) and `SummaryUITests` (6) passed at `9ba9e9a`; the rest of the UI suite has no code it reaches changed since run 3, except the discard after a failed start, which only `WorkoutUITests` reaches.

## PR 3 `feat/003-heart-rate` (heart rate in the header)

The tests were committed first, in **`c07cc5b`** (T037–T040, the #30 P2-1 expectation change and the T045 follow-ups), before any heart-rate code.

**Run 1, unit tests at `c07cc5b`:** the target doesn't compile. The compiler stops at the first error of each batch, so three probes, each with the earlier failing file removed in the working tree only (restored after), give one error per file: `HeartRateDisplayTests.swift:18` cannot find `HeartRateDisplay`; `FakeWorkoutServiceTests.swift:77` extra argument `heartRate`; `WorkoutSaveTests.swift:315` no member `latestHeartRate`. This covers every test in these files, and `WorkoutLifecycleTests` (same target), whose "#30 P2-1" test expects the notice the old code doesn't set.

**Run 2, UI tests at `c07cc5b`** (the unit test files swapped to their `c07cc5b~1` versions in the working tree only, so the UI target builds; restored after):
- failed: `HeartRateUITests` `testUS3s1AReadingShowsInTheHeader`, `testUS3s3NoReadingShowsDashes`, `testUS3s6VoiceOverReadsTheHeartRateWithTheElapsedTime`; `ScoreAccessibilityUITests` `testUS6s2AuditScoreWithHeartRate`, `testUS6s2HeartRateFitsAndKeepsTheZones`;
- passed: `testUS3s4NoRowWithoutAWorkout`, `testUS3s5AlwaysOnHidesTheHeartRate`, which check an absence; run 5 is their evidence.

**Run 3, unit tests at `a7272d0`** (the code): 317 test cases passed, 0 failed.

**Run 4, UI tests at `a7272d0`:** `HeartRateUITests`, `ScoreAccessibilityUITests` and `AlwaysOnUITests`, 15 tests, 0 failed.

**Run 5, a recorded mutation of `a7272d0`** (never committed): the heart rate always shows "--", and Always On never takes the dimmed branch.

```diff
--- a/TennisBeat/TennisBeat Watch App/Score/ElapsedTimeView.swift
+++ b/TennisBeat/TennisBeat Watch App/Score/ElapsedTimeView.swift
-    if isDimmed {
+    if false {
-        let display = heartRate(context.date)
+        let display = HeartRateDisplay.unavailable
```

- failed: `testUS3s4NoRowWithoutAWorkout` (line 47) and `testUS3s5AlwaysOnHidesTheHeartRate` (line 59).

**Not run for evidence:** `ScreenshotUITests.testHeartRateScoreScreens` (added in `c07cc5b`, its states extended in `b4f827f`) is opt-in through `SCREENSHOT_LANGUAGE` and asserts nothing but that the score screen shows; it only attaches the PR screenshots, so it is one of the 8 skipped tests in the full-suite runs (#31 R2-1).

### #31 L1 (the heart rate under the elapsed time)

The screenshots of `a7272d0` showed the heart rate on the elapsed-time line, under the system clock. Denys decided L1; the test was changed first, in **`b4f827f`**.

**Run 6, `testUS6s2HeartRateFitsAndKeepsTheZones` at `b4f827f`:** failed, "3.25 is less than 22.0 - under the elapsed time" (the first attempt's runner was killed by a simulator hiccup and is not counted).

**Run 7, at `41e5818`** (the L1 code): the same 15 UI tests passed. The test then covered only the paused match tie-break, which draws only "Paused".

**Run 8, at `bb5b1c2`** (the test now also covers the running match tie-break, the longest drawn status): failed, zones `[(2, 116.5, 158, 54.5), (2, 58.5, 158, 54)]` ≠ `[(2, 111.5, 158, 59.5), (2, 48, 158, 59.5)]`: the status moves to its own line and the zones shrink. A prototype that shrinks the status to stay on one line (minimum scale 0.5) still truncated it ("Match…") and was reverted, never committed. Reported to Denys, who decided L2.

### #31 L2 (zones may shrink, but only with the phase)

The tests were committed first, in **`8e284d8`** (the UI test walks points inside each phase) and **`3084a6b`** (`ScoreScreenModelTests` "US6 s2 L2 …").

**Run 9, `testUS6s2HeartRateFitsAndKeepsTheZones` at `8e284d8`** (the L1 code): failed, "zones move within the phase: games ♥205 after MMMOOO", `[(2, 116.5, 158, 54.5), (2, 58.5, 158, 54)]` ≠ `[(2, 111.5, 158, 59.5), (2, 48, 158, 59.5)]`: in EN at XXXL "♥ 205 · Deuce" doesn't fit, so the zones shrank between ordinary points.

**Run 10, unit tests at `3084a6b`** (built in a throwaway `git worktree add --detach` tree): the target doesn't compile: `ScoreScreenModelTests.swift:22` extra argument `gameScoring`; lines 142–153 no member `layoutStatusText`. This covers every test in `ScoreScreenModelTests`.

**Runs 11–12, on the L2 code before `c20bbbc`** (not evidence; they found two problems): run 11 failed "under the elapsed time" at 0–0: the blank second line didn't scale like the status text, so at XXXL it pushed the heart rate 3 pt up (fixed in `7c0f24d`); run 12 failed "zones move within the phase … after M" with the Me zone at x 2.08, width 157.83: its press animation, caught right after the tap. `c20bbbc` makes the test wait for the frames to settle and name the state on failure; no expectation changed.

**Run 13, at `7c0f24d`:** `testUS6s2HeartRateFitsAndKeepsTheZones` passed (511 s).

**Run 14, the full watch suite at `7c0f24d`** (`fb8dbc2` changes docs only): 309 tests in the result bundle (225 unit test functions, 84 UI tests), 301 passed, 8 skipped (the opt-in screenshot tests), 0 failed, including `ScoreScreenModelTests` "US6 s2 L2 …" and every spec 002 UI test (SC-005).

### Review 1 fixes (#31 R1-1, R1-3)

**Run 15, a recorded mutation of `7357a51`** (never committed; #31 R1-1 and R1-3): a successful best-effort save also sets the notice, and the header's heart rate ignores the workout state.

```diff
--- a/TennisBeat/TennisBeat Watch App/Match/MatchSession.swift
+++ b/TennisBeat/TennisBeat Watch App/Match/MatchSession.swift
           _ = try await workout.save(endingAt: end)
+          self?.pendingSaveFailureNotice = true
--- a/TennisBeat/TennisBeat Watch App/Health/HeartRateDisplay.swift
+++ b/TennisBeat/TennisBeat Watch App/Health/HeartRateDisplay.swift
-    guard !isDimmed else {
+    guard !isDimmed || true else {
     switch workoutState {
+    case _ where true: self = .unavailable
```

- failed: `WorkoutLifecycleTests` "#30 P2-1 a best-effort save that succeeds sets no notice" (`endedSaveSucceeds`), which uses no new API and passes on the code before `a7272d0` too, so this run is its evidence (R1-1); `HeartRateUITests.testUS3s4NoRowWithoutAWorkout` (line 47), on the current header (`HeaderStatusLine`, R1-3);
- passed: `testUS3s5AlwaysOnHidesTheHeartRate`: in Always On `HeaderStatusLine` draws only the status and never asks for the heart rate, so a second guard covers it (run 16).

**Run 16, a recorded mutation of `7357a51`** (never committed): both Always On guards removed.

```diff
--- a/TennisBeat/TennisBeat Watch App/Score/HeaderStatusLine.swift
+++ b/TennisBeat/TennisBeat Watch App/Score/HeaderStatusLine.swift
-    if isDimmed {
+    if false {
--- a/TennisBeat/TennisBeat Watch App/Score/ScoreView.swift
+++ b/TennisBeat/TennisBeat Watch App/Score/ScoreView.swift
-      isDimmed: isLuminanceReduced)
+      isDimmed: false)
```

- failed: `testUS3s5AlwaysOnHidesTheHeartRate` (line 59). Run 5's mutation of `ElapsedTimeView` (`a7272d0`) stays valid for the unchanged tests; runs 15 and 16 repeat it on the current code.

### Review 2 fixes (#31 R2-3)

The test was committed first, in **`bc57eac`**: `ScoreScreenModelTests` "US6 s2 L2 the drawn status is empty or the phase's layout status, never wider". It checks existing code, so it passes there.

**Run 17, a recorded mutation of `bc57eac`** (never committed): a set tie-break draws "Deciding point" while the header is laid out for "Tie-break".

```diff
--- a/TennisBeat/TennisBeat Watch App/Match/ScoreScreenModel.swift
+++ b/TennisBeat/TennisBeat Watch App/Match/ScoreScreenModel.swift
-    if state.isTieBreak { return "status.tieBreak" }
+    if state.isTieBreak { return "status.decidingPoint" }
```

- failed: `statusNeverWiderThanLayout` (the new test) and `statusLine` ("US2 s8 …").

## `feat/003-ci-budget` (CI time budget)

No test is added. The layout test's default scope changes (see `test-expectation-changes.md`).

**Run 1, the worst case at the branch's test change** (no `LAYOUT_MATRIX`): `testUS6s2HeartRateFitsAndKeepsTheZones` passed in 93 s on Apple Watch SE 3 40 mm (the full matrix took 511 s, PR 3 run 13). The full matrix runs in this PR's CI, because the PR changes the CI files (`scripts/layout-scope.sh`).

## `feat/003-lost-tap` (lost tap in the SC-002 UI tests)

No test is added and no expectation changes. The lost tap was diagnosed with the DEBUG-only tap log (`Match/TapLog.swift`):

- **Locally:** 150 runs of `testSC002BestOfThreeMatchTieBreakAdvantage` and `…NoAd` passed (`-test-iterations 50 -run-tests-until-failure`: 100 runs, then 50 with all CPU cores busy) on Apple Watch SE 3 40 mm.
- **On CI** (temporary `Lost-tap repro` workflow, run [39154763078](https://github.com/dfinchenko/tennis-beat/actions/runs/39154763078), 5 jobs × 20 iterations, removed before review): 198 runs passed, and 1 failed. Job 5, `testSC002BestOfThreeMatchTieBreakNoAd`, step 40 (Me): the screen stayed at 0–0 instead of 15–0. The test synthesized the tap at 19:13:11.186 UTC. The app logged the three taps before it 0.10–0.11 s after each was synthesized (events 38–40) and logged **no zone action** for this tap up to the failure at 19:13:15.105. The scene was active throughout, the screen was not dimmed and no change-of-ends haptic was pending (the last one played at 19:13:09.560). The log is inside the action, so it shows that no zone action ran, not whether the touch reached the app (#33 R1-1; the log now also records changes of the tap gates). Classified as an environment flake under Denys's rule ([#33](https://github.com/dfinchenko/tennis-beat/pull/33#issuecomment-6253707014)), handled with one whole-test retry for these two tests (`docs/harness.md` § CI time budget).

**The retry exits 0 when it passes** (#33 R1-3), checked locally on Apple Watch SE 3 40 mm before review 1. A throwaway UI test, never committed, failed on its first attempt only; `-retry-tests-on-failure -test-iterations 2` printed `failed`, `started (Iteration 2 of 2)`, `passed` and `** TEST SUCCEEDED **`, with exit 0.

## `feat/003-release-build` (Release builds in CI, #33 R2-4)

No test is added. The failing check is the new CI step `Build for simulator (Release)` in both `build (<scheme>)` jobs. It was committed alone in `1979471`, before the fix.

- **Locally at `1979471`:** both `xcodebuild build -configuration Release` (iOS and watchOS Simulator) exit 65. The errors are `type 'MatchSession' has no member 'preview'` and `type 'HealthOnboarding' has no member 'preview'` in `RootView`, `HealthOnboardingView`, `CoinTossResultView`, `FirstServerView`, `NewMatchView` and `OptionPickerView`, plus "failed to produce diagnostic" at the `#Preview` blocks of `ScoreView` and `ControlsView`. The iOS app embeds the watch app, so it fails on the same errors.
- **On CI at `1979471`:** [run 39162279294](https://github.com/dfinchenko/tennis-beat/actions/runs/39162279294). In both `build (TennisBeat)` and `build (TennisBeat Watch App)`, the Debug step passed and the Release step failed.
- **After the fix** (the `#Preview` blocks that use the DEBUG-only helpers wrapped in `#if DEBUG`): both apps build locally in Release and in Debug.
- The compiler stops early, so the list above is not every error: `SummaryView`'s `#Preview` uses `MatchSession.preview` too and is wrapped in the same fix (#34 R3-1, recorded in 003 PR 4).

## PR 4 `feat/003-summary` (summary rows and the save-failure notice)

Tests committed alone in `8f07518` (T047–T051), before the code in `02356ce`.

- **Unit tests at `8f07518`** (`-only-testing:"TennisBeat Watch AppTests"`, 40 mm simulator): the target doesn't compile, because the API didn't exist yet. The compiler stopped at `FakeWorkoutServiceTests` (`type 'FakeWorkoutService' has no member 'launched'`, `value of type 'FakeWorkoutService' has no member 'savedStats'`). The other new tests use API that also didn't exist: `SummaryHealthRows` and `SummaryModel(…, statistics:)` (`SummaryHealthRowsTests`), `MatchSession.summaryStatistics` (the `WorkoutSaveTests` snapshot cases: `snapshotAtOpening`, `snapshotAtEarlyEnd`, `snapshotAfterTimeoutSave`, `undoDropsSnapshot`, `failedTimeoutSaveDropsSnapshot`, `failureOnSummaryDropsSnapshot`, `noWorkoutNoSnapshot`, `doneClearsSnapshot`; `HealthStorageTests.nothingStored`), and `WorkoutHarness.store`. `StringCatalogTests.summaryStrings` needs the PR 4 keys, which `main`'s catalog doesn't have.
- **UI tests at `8f07518`**: the scheme builds the unit-test target too, so they can't build at that commit as it is. They were run in a scratch checkout of `8f07518` whose `TennisBeat Watch AppTests` folder was `main`'s (the new unit-test files removed, the changed ones restored), app code unchanged. Failed: `SummaryHealthUITests` `testUS4s1TheSummaryShowsHeartRateAndEnergyAfterDuration`, `testUS4s2NoEnergyValueHidesTheEnergyRow`, `testUS4s2NoHeartRateHidesTheHeartRateRow` (no `summary.heartRate` / `summary.energy`), `testUS4s7AFailedSaveShowsTheNoticeOnceOnNewMatch` (no notice), and `AccessibilityAuditUITests.testSC006AuditSummaryWithHealthRows` (`summary.heartRate en UICTContentSizeCategoryXXXL` missing). Passed, as expected on `main`, which has no rows at all: `testUS4s3WithoutAWorkoutTheSummaryShowsDurationOnly` and `testUS2s9AWorkoutThatFailedToStartShowsDurationOnly`. They check that the rows stay hidden; US4 s1 is their failing counterpart, and the unit test `noWorkoutNoSnapshot` covers the same rule in the session.
- **The `import TennisCore` fix** to `SummaryHealthRowsTests` (`MemberImportVisibility`) went in with the code commit `02356ce`, not before it; no expectation changed. At `8f07518` the file already failed to compile for the missing API (#35 R1-5).
- **`scripts/tests/flaky-retries-test.sh`** (#34 R3-3) is a test of existing code: `scripts/flaky-retries.sh` as merged in #34 at the base `93fbaf9`, and this PR's version (R3-2: issues listed, not searched). It came in the code commit `02356ce`, so its evidence is recorded mutations (#35 R1-1). Unmutated, all 14 checks pass on both versions under `/bin/bash` 3.2 and bash 5. Each mutation below was applied to both versions with `FLAKY_SCRIPT=<mutated copy>`, and failed the same checks on both. Every check fails under at least one mutation. Diffs are against this PR's script; the base script has the same lines, except that its lookup still passes `--search` (M1, M3).

| Mutation | Diff | Checks that fail |
| --- | --- | --- |
| M1 exact title -> prefix | `-    --jq "map(select(.title == \"$1\")) \| first \| .number // empty"`<br>`+    --jq "map(select(.title \| startswith(\"$1\"))) \| first \| .number // empty"` | "no exact title: creates the tracking issue" |
| M2 a new issue doesn't count this run | `-  week=$((earlier + $#))`<br>`+  week=$earlier` | "3 retries in the week", "a new issue counts this run's retries", "an old last comment does not fail the run (#34 R2-2)", "an open investigation gets a comment", "more than 2: opens the investigation and mentions Denys", "the window counts only the last 7 days", "two tests count twice" |
| M3 lookup never finds the issue | `-    --jq "map(select(.title == \"$1\")) \| first \| .number // empty"`<br>`+    --jq "map(select(.title == \"$1\")) \| first \| empty"` | "2 retries: no investigation", "3 retries in the week", "an open investigation gets a comment", "existing issue: comments on it", "existing issue: no new tracking issue", "more than 2: opens the investigation and mentions Denys", "the window counts only the last 7 days" |
| M4 window 8 days | `-week_ago=$((now - 7 * 24 * 3600))`<br>`+week_ago=$((now - 8 * 24 * 3600))` | "2 retries: no investigation", "the window counts only the last 7 days" |
| M5 threshold -ge | `-if [[ "$week" -gt "$week_limit" ]]; then`<br>`+if [[ "$week" -ge "$week_limit" ]]; then` | "2 retries: no investigation" |
| M6 no comment counted | `-      if [[ "$epoch" -ge "$week_ago" ]]; then echo x; fi`<br>`+      if [[ "$epoch" -gt "$now" ]]; then echo x; fi` | "3 retries in the week", "an open investigation gets a comment", "more than 2: opens the investigation and mentions Denys", "the window counts only the last 7 days" |
| M7 no mention | `-    gh_do issue create --title "$investigation" --body "@dfinchenko $note`<br>`+    gh_do issue create --title "$investigation" --body "$note` | "more than 2: opens the investigation and mentions Denys" |
| M8 open investigation not looked up | `-  open_task="$(find_issue "$investigation")"`<br>`+  open_task=""` | "an open investigation gets a comment", "an open investigation: no second one" |
| M9 R2-2 reverted | `-      if [[ "$epoch" -ge "$week_ago" ]]; then echo x; fi`<br>`+      [[ "$epoch" -ge "$week_ago" ]] && echo x` | "an old last comment does not fail the run (#34 R2-2)", "an old last comment: the script exits 0", "the window counts only the last 7 days" |
| M10 only the first test | `-for test_name in "$@"; do`<br>`+for test_name in "$1"; do` | "one comment per retried test" |

  Changes to the check script made while recording this (#35 R1-1): every run prints `script exited <status>` when the script fails, so a failing run fails its own checks instead of stopping the whole check script (before, M9 stopped it at the window check with exit 1 and no FAIL line); and "an old last comment: the script exits 0" is a new check.
- **At `02356ce`**: all 248 watch unit tests pass; the full watch UI suite runs 91 tests, 83 passed, 8 skipped (the opt-in screenshot tests), 0 failures; the 119 engine tests pass; both apps build in Debug and Release.
- **`HealthStorageTests.nothingStored`** failed in the reviewer's clean run at `64f346f`: a binary Metal shader cache under `Library/Caches` matched a 3-digit value once decoded as UTF-8 (#35 R1-2). That run is the failing evidence for the fix. The search now reads only property lists and valid UTF-8 text, and counts only matches that are new or changed against a snapshot taken before the match. The positive control also checks that an unchanged match isn't counted, a changed one is, and a non-UTF-8 file is skipped. Its probe preference sits in the in-memory registration domain, and the suite is serialized: the first local run of the fix failed because the control's suite file reached `Library/Preferences` while the other test was searching.


## `feat/003-haptic-tap` (lost-tap check: the pending change-of-ends haptic; #35 R2-1, R2-3)

Tests committed alone in `851399c`, before the code in `6780555`.

- **Every recorded lost tap, checked** (Denys, after #35): each failing test's steps replayed through the engine (same seeds and setup as `ScoringUITests`), against CI's failure messages and, where one exists, the tap log. A change-of-ends haptic was pending at **2 of the 4**:

  | Lost tap | Step before it | Haptic pending? |
  | --- | --- | --- |
  | `main` [run 39208688165](https://github.com/dfinchenko/tennis-beat/actions/runs/39208688165), `testSC002OneSetOfFourAdvantage`, step 4 (Me) | step 3 won game 1: change of ends | yes (scheduled 0.33 s before the tap; the log shows it played on its own 0.8 s later) |
  | #30, `testSC002BestOfThreeMatchTieBreakAdvantage`, step 54 (Undo) | step 53, the 6th match tie-break point: change of ends | yes (no tap log then) |
  | #32 [run 39070518470](https://github.com/dfinchenko/tennis-beat/actions/runs/39070518470), `testSC002BestOfThreeMatchTieBreakNoAd`, step 74 (Me) | last change of ends at step 67 | no |
  | #33 repro [run 39154763078](https://github.com/dfinchenko/tennis-beat/actions/runs/39154763078), `testSC002BestOfThreeMatchTieBreakNoAd`, step 40 (Me) | last change of ends at step 35; the log shows it played 1.6 s before the tap | no |

- **`ChangeOfEndsTapUITests.testTapsCountWhileTheChangeOfEndsHapticIsPending`** is a test of existing code: with the haptic held pending (`-uiTestHoldChangeOfEnds`), it taps a zone at once, a zone after 2 s and Undo after 2 s. It **passes on the unchanged app**: 10 runs on Apple Watch SE 3 40 mm, 323 zone and Undo actions, 40 of them while a held haptic was pending, none lost. The tap log shows each held haptic pending for 2.35–2.52 s until the next point played it, and Undo dropping it. So a pending change-of-ends haptic does not block or intercept a tap, and there is no app fix for it. The test stays as a regression check. Rerun at `6780555` (the hold and the final tap log): 10 runs passed on the 40 mm simulator. Its evidence is two recorded mutations of `6780555`, each failing it there (first recorded on a working copy with an earlier version of the tap log, with the same results):

  | Mutation | Diff | Fails at |
  | --- | --- | --- |
  | M1 the first tap after a change of ends is eaten | `MatchSession.addPoint`, after `guard acceptsPoints, var match else { return }`:<br>`+    if (haptics as? WatchHaptics)?.isPending == true {`<br>`+      haptics.flushPending()`<br>`+      return`<br>`+    }`<br>(`WatchHaptics`: `+  var isPending: Bool { pending != nil }`) | step 5 (Opponent): 0–0 shown, 15–0 (Opponent serving) expected |
  | M2 Undo is ignored while the haptic is pending | `MatchSession.undo`, first line:<br>`+    if (haptics as? WatchHaptics)?.isPending == true {`<br>`+      haptics.cancelPending()`<br>`+      return`<br>`+    }` | "undo after game 5": games 3–2 at 0–0 shown, 2–2 at 40–0 expected |

- **Unit tests at `851399c`** (`-only-testing:"TennisBeat Watch AppTests"`, 40 mm simulator): the target doesn't compile, because the API didn't exist yet (`SessionFeedbackTests.launchedHoldsTheChangeOfEnds`, `launchedWithoutHold`: `WatchHaptics` has no member `launched`, `LaunchOptions` has no member `holdChangeOfEnds`). The UI tests can't build at that commit either (the scheme builds the unit-test target).
- **`SummaryHealthRowsTests.heartRateNumberFormat`** (#35 R2-1): in a scratch checkout of `851399c` with only the hold code of `6780555` added (`Feedback.swift`, `LaunchOptions.swift`, `TennisBeatApp.swift`), so the target compiles, it is the only watch unit test that fails: the value is `138 / 171` for a locale with Arabic-Indic digits, `١٣٨ / ١٧١` expected.
- **The DEBUG tap log** (`View.touchLog`) adds a simultaneous `SpatialTapGesture` to the score screen and each zone. A first version with a zero-distance `DragGesture`, and then one with a never-ending `LongPressGesture`, took the page swipe: every `ControlsUITests` test failed with "Controls did not appear", and passed with the log removed. The spatial tap drops out when the finger moves; with it all 13 `ControlsUITests` pass.

- **Repro result** ([run 39500151219](https://github.com/dfinchenko/tennis-beat/actions/runs/39500151219) on `a6c02b3`, [report](https://github.com/dfinchenko/tennis-beat/pull/36#issuecomment-6303150923)): 199 runs of the 7 SC-002 scripted tests, 1 lost tap (`testSC002OneSetOfEightAdvantage`, run 19, step 51), which reached neither the score screen nor a zone. An environment flake under Denys's rule, so the retry covers all seven tests and the sequences tap only their last 12 steps.
- **Launch steps** (tests in `b9eed21`, code in `5a6d2d2`): at `b9eed21` the unit-test target doesn't compile (`LaunchStepsTests`: `Player` has no member `point`, `undo`, `correctServer`; `MatchSession` has no member `play`). In a scratch checkout of `b9eed21` without `LaunchStepsTests.swift`, so the UI tests build, `testSC002OneSetOfFourAdvantage` and `testSC002BestOfThreeMatchTieBreakNoAd` fail at the check after the launch steps (Apple Watch SE 3 44 mm): the old parser drops `U` and `S`, so the launched match isn't the engine's (`40–30, I'm serving` shown, `30–40, Opponent serving` expected; `7–4` shown, `6–4` expected). At `5a6d2d2` all ten `ScoringUITests` pass (40 mm), each SC-002 sequence in about 19 s, and all watch unit tests pass.
