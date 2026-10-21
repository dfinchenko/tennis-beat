# Test expectation changes: 003-workout-health

Expectations changed after the code they check was written (rule: CLAUDE.md, Hard rules; `docs/harness.md`). One section per branch, newest last.

## `feat/003-onboarding` (PR 1)

| Test | Old → new expectation | Source |
| --- | --- | --- |
| `InfoPlistTextTests` "FR-004 the EN read text names heart rate and active energy" → "FR-004 each catalog's EN read text names heart rate and active energy" | Checked the copy-table constant in the test → checks the EN value read from each `InfoPlist.xcstrings` (one case per catalog). The condition is the same (names "heart rate" and "active energy"); it now checks the product. The positive control is kept. Reviewer finding #29 R1-3. | FR-004 |

No other expectation changed. Helper and wait changes that leave every expectation as it was, and so are not listed above:
- the UI-test helper's default `-uiTestHealth denied` (SC-005);
- the onboarding UI tests waiting for the title instead of Continue;
- the injected `workout:` argument in the 002 unit tests.
- the new `dragUp()` UI-test helper, used by the onboarding scrolling test and the screenshot test instead of `swipeUp()`.

## `feat/003-workout` (PR 2)

| Test | Old → new expectation | Source |
| --- | --- | --- |
| `FakeWorkoutServiceTests` "Contract §2: failing — the workout reports .failed after start" | `.failed` delivered during `start(at:)` → delivered after `start(at:)` returns (the test now waits with `settle()`, then expects the same `[.failed]`). The session can only match the event to its workout once `start` has returned the token; HealthKit reports start errors asynchronously too. | research R3 ("`startActivity` and `beginCollection` report errors asynchronously"), R11 |
| `WorkoutLifecycleTests` "US2 s9 a workout that fails to start leaves the match running with no further call" | Calls `[start]` → `[start, discard]`: the failed workout is discarded at once, so its session can't stay active; no call after that. Reviewer finding #30 R1-1. | FR-010 (no workout saved for it; no error blocks scoring) |
| `WorkoutLifecycleTests` "Edge: early end long after the last point …" | Dropped the expectation `workoutState != .summary(openedAt: lastPoint)`, which was always true once the clock had moved; it now checks that the clock moved, and `openedAt` is the End time as before. Reviewer finding #30 R1-5. | Spec Edge cases (early end long after the last point) |

No other expectation changed. Helper changes that leave every expectation as it was, and so are not listed above:
- `ManualSleep` records the durations it was asked for (`requested`), so the timeout tests can check the 10 minutes;
- the new `WorkoutHarness`, `CallKind` and `SaveGate` test support;
- the spec 002 tests still run with the `denied` fake, so their summary keeps Undo (SC-005).

## `feat/003-heart-rate` (PR 3)

| Test | Old → new expectation | Source |
| --- | --- | --- |
| `WorkoutLifecycleTests` "US2 s10, #28 R6-4 a failing best-effort save sets no notice" → "US2 s10, #30 P2-1 a failing best-effort save shows the notice as any failed save" | `pendingSaveFailureNotice` stays `false` after the failing best-effort save, and after End and Done → `true` at both points; the save count (1) is unchanged. A new test checks that a best-effort save that succeeds sets no notice. Denys's decision [#30 P2-1](https://github.com/dfinchenko/tennis-beat/pull/30#issuecomment-6222095428). | US2-S10, FR-010, FR-015 (P2-1) |
| `ScoreAccessibilityUITests.testUS6s2HeartRateFitsAndKeepsTheZones` (`b4f827f`, after the code in `a7272d0`) | The heart rate sits beside the elapsed time on its line, `XCTAssertFalse(value.frame.intersects(elapsed.frame))` → under the elapsed time, `heart.minY >= elapsed.maxY - 1`, with the status not overlapping it; the test also covers a running match tie-break, the longest drawn status (`bb5b1c2`). Denys's decision [#31 L1](https://github.com/dfinchenko/tennis-beat/pull/31#issuecomment-6223261542) (#31 R1-2). | US3-S1, FR-012, Q3 (L1) |
| `ScoreAccessibilityUITests.testUS6s2HeartRateFitsAndKeepsTheZones` | In every state checked (0–0, a match tie-break, paused in it) the zone frames equal those of the same state without a workout → the zones are at least 44 pt tall; within a phase (ordinary games with Advantage or the deciding point, a tie-break, a match tie-break, paused) they don't move between points or between a reading and "--"; they equal the frames without a workout unless the phase's status sits on its own line. The test now walks points inside each phase. Denys's decision [#31 L2](https://github.com/dfinchenko/tennis-beat/pull/31#issuecomment-6237948677). | US6-S2 (L2) |

No other expectation changed. The `latestHeartRate == nil` line added to `WorkoutSaveTests` "R5-3 Done, then a new match at once" is a new expectation (planned in T024, possible only now), not a changed one.


## `feat/003-ci-budget` (CI time budget)

No expectation changed. `ScoreAccessibilityUITests.testUS6s2HeartRateFitsAndKeepsTheZones` checks the same things in every case it runs, but by default it now runs only the worst case, UK with ♥ 205 in every phase; `LAYOUT_MATRIX=full` runs EN, PL and UK with ♥ 205 and "--" as before (nightly, PRs that change header or layout files, pushes to `main`). Denys's decision, [relayed on #31](https://github.com/dfinchenko/tennis-beat/pull/31#issuecomment-6238799308).

## `feat/003-lost-tap` (lost tap in the SC-002 UI tests)

No expectation changed (#33 R3-1). The two SC-002 match tie-break tests check the same things; CI may run each once more as a whole test (Denys, [relayed on #33](https://github.com/dfinchenko/tennis-beat/pull/33#issuecomment-6253707014)).

## `feat/003-release-build` (Release builds in CI)

No test and no expectation changed. The new CI step builds both apps in Release (Denys, [relayed on #33](https://github.com/dfinchenko/tennis-beat/pull/33#issuecomment-6254547417)).

## `feat/003-summary` (PR 4)

| Test | Old → new expectation | Source |
| --- | --- | --- |
| `SummaryModelTests` "US5 s8 the summary has no heart-rate or calorie field" → "US5 s8, spec 003 US4 s3 without workout statistics the summary has no heart-rate or energy row" | The model's fields `title, chips, duration, spokenDuration` → the same plus `health`, and `health.rows` is empty for a summary without statistics. Spec 003 adds the rows; without a workout the spec 002 summary is unchanged (Duration only). Spec 002 Story 5 s8 now carries a "changed by spec 003" note. | Spec 003 FR-013, US4-S1, US4-S3 (spec 002 US5-S8) |

No other expectation changed. Helper and test-support changes that leave every expectation as it was, and so are not listed above:
- `WorkoutHarness.store` exposes the session's format-store defaults (searched by `HealthStorageTests`);
- `StringCatalogTests.everyKeyTranslated` also checks the plural categories of substitutions (an added check; every existing key still passes);
- `ScreenshotUITests.testWorkoutSummaryScreens` launches with `-uiTestWorkoutStats 138,171,612` and takes two more screenshots (the rows, the notice); it asserts nothing new;
- `-uiTestSaveFails` fails only the first save, 2 s after it starts (contract §2); no existing test used it.


## `feat/003-haptic-tap` (lost-tap check, #35 minors)

| Test | Old → new expectation | Source |
| --- | --- | --- |
| `ScoringUITests` SC-002 scripted sequences (all seven `testSC002…`) | Every step of each sequence was a real tap, Undo or correction, with the screen compared with the engine after each → the same seeded steps, but all except the last 12 before the match ends are played at launch (`-uiTestPoints` with `U` and `S`); the screen is compared with the engine once after the launch steps, and after each of the last 12 real steps, which always hold at least one Undo and one correction (asserted). Each comparison is unchanged; fewer intermediate states are reached by taps. | SC-002; Denys, [relayed on #36](https://github.com/dfinchenko/tennis-beat/pull/36#issuecomment-6301821874) (reduce exposure after the [repro](https://github.com/dfinchenko/tennis-beat/pull/36#issuecomment-6303150923)) |

No other expectation changed. Helper and wait changes that leave every expectation as it was, and so are not listed above:
- `ScreenshotUITests.testWorkoutSummaryScreens` waits for the save-failure notice by its title (#35 R2-3) instead of a fixed wait, and asserts that it appears: an added check in an opt-in test, no existing expectation changed (its recorded mutation is in `test-first-evidence.md` § `feat/003-sc002-nightly`, #36 R2-2);
- `-uiTestPoints` reads `U` and `S` too; the existing tests pass only `M` and `O`, which play as before.

## `feat/003-sc002-nightly` (SC-002 as decided after #36, nightly full taps, shards)

No expectation changed. SC-002 itself was changed by Denys ([relayed on #37](https://github.com/dfinchenko/tennis-beat/pull/37#issuecomment-6310232479)) to what `ScoringUITests` already checks on PRs since #36 (the final 12 tapped steps). Helper and wait changes that leave every expectation as it was:
- `ScoringUITests.realSteps` is every step when `SC002_TAPS=all` (the nightly), which restores the tap-by-tap run SC-002 now asks for nightly;
- `SessionFeedbackTests.launchedWithoutHold` ends the change-of-ends delay by hand (`ManualSleep` through `WatchHaptics.launched(…, sleep:)`) instead of waiting 2.4 s of real time (#36 R2-3); it still checks the delay asked for and the change of ends playing after it;
- `HealthStorageTests.searchFindsWrittenValues` uses a probe key that is new each run, so a repeated run doesn't find the last run's probe in the shared registration domain.
