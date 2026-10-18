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
