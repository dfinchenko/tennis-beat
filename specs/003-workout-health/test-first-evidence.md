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
