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

No other expectation changed. The `latestHeartRate == nil` line added to `WorkoutSaveTests` "R5-3 Done, then a new match at once" is a new expectation (planned in T024, possible only now), not a changed one.

