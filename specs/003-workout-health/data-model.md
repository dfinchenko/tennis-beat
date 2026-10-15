# Data model: Workout and Health on Apple Watch (003)

**Date**: 2026-10-15 | **Spec**: [spec.md](spec.md) | **Plan**: [plan.md](plan.md)

The workout follows the 002 `MatchSession` ([002 data model](../002-watch-match/data-model.md)); the engine (`TennisCore`) is unchanged and knows nothing about it (FR-011, FR-018). New types live in `TennisBeat Watch App/Health/` (research R1). **Nothing in this model is stored**: heart rate, energy and the workout state live in memory only (FR-014, constitution IX). The only persistent state is HealthKit's own: its authorization status and the saved workout.

## WorkoutService (protocol, main actor)

What `MatchSession` and the onboarding need from HealthKit (research R1, R2, R8).

| Member | Meaning |
| --- | --- |
| `authorizationRequestStatus() async -> AuthorizationRequestStatus` | `.shouldRequest` until the sheet has been answered for the FR-003 types; `.unnecessary` after; `.unknown` on error (treated as `.unnecessary`, so an error never shows the onboarding forever) |
| `requestAuthorization() async` | Shows the system sheet for the FR-003 types; never throws to the caller |
| `canStartWorkout: Bool` | Sharing workouts is authorized (R3) |
| `start(at: Date)` | Starts a tennis workout, no location type (Q1), collection from `at` |
| `pause()` / `resume()` | Session pause and resume |
| `statistics() -> WorkoutStatistics` | Snapshot of the builder's statistics now (R7) |
| `save(endingAt: Date) async throws -> SavedWorkout` | Ends the session, ends collection at the date, finishes the workout; returns its `uuid` and statistics (`SavedWorkout`). Spec 003 drops the UUID after Done; spec 004 stores it with the match (spec Key Entities) |
| `discard()` | Ends the session and discards the builder (FR-008) |
| `recoverAndSave() async` | FR-009a: recovers a running session after a relaunch and saves it at now (R10) |
| `onEvent: (WorkoutEvent) -> Void` | Set by the session |

`WorkoutEvent`: `.heartRate(HeartRateReading)`, `.failed` (didn't start), `.endedUnexpectedly`.

Implementations: `HealthKitWorkoutService` (production) and `FakeWorkoutService` (tests and DEBUG launch arguments, [contract](contracts/ui-contract.md) §2). The fake records calls with their dates, can be set to fail any step, and emits scripted readings.

## WorkoutState (value, in `MatchSession`)

| State | Meaning | Header row | Summary rows | Summary Undo |
| --- | --- | --- | --- | --- |
| `none` | No workout for this match (permission not given, or no match) | none | none | yes (002 FR-020) |
| `running` | Workout running, match in play | yes | — | — |
| `paused` | Match paused | yes ("--") | — | — |
| `summary(openedAt: Date)` | Summary shown; session paused; the end date fixed (R2) | — | yes | yes |
| `saving` / `saved` | Save started (Done or timeout) / finished | — | yes | **no** (FR-007) |
| `discarded` | 0-point End (FR-008) | — | — | — |
| `failed` | Didn't start, or ended unexpectedly (FR-010) | none | none | yes (research R3, #27 R3-2) |

### Transitions

| Session command / event | From | To | Service call |
| --- | --- | --- | --- |
| `start(firstServer:)`, `canStartWorkout` | — | `running` | `start(at: clock.startedAt)` |
| `start(firstServer:)`, not allowed | — | `none` | none |
| `pause()` / `resume()` | `running` / `paused` | `paused` / `running` | `pause()` / `resume()` |
| Summary opens (won, or End with a point) | `running`, `paused` | `summary(openedAt: clock.stoppedAt)` | `pause()` if running; `statistics()` → snapshot; start the 10-minute task (R4) |
| `undo()` from the summary | `summary` | `running` | `resume()`; cancel the task; drop the snapshot |
| `done()` | `summary` | `saving` → `saved`, route → `.setup` at once | `save(endingAt: openedAt)`; failure → `pendingSaveFailureNotice` (R5) |
| 10-minute task fires | `summary` | `saving` → `saved` (route stays `.summary`) | `save(endingAt: openedAt)`; snapshot ← the saved workout's statistics (R7); failure → notice flag |
| `done()` | `saving`, `saved` | — (route → `.setup`) | none (no second save) |
| `endEarly()` with 0 points | `running`, `paused` | `discarded` → (`none` for the next match) | `discard()` |
| `.failed` or `.endedUnexpectedly` | `running`, `paused`, `summary` | `failed` | none (the service has already dropped the builder) |
| `.heartRate(r)` | `running`, `paused` | same | `latestHeartRate = r` |
| any event | `none`, `saved`, `discarded`, `failed` | same | ignored (R11) |

Invariants (tested, SC-002):
- at most one `save` per match (FR-009);
- `save` is never called after `discard`, and `discard` never after `save`;
- `save(endingAt:)` gets the `stoppedAt` of the **last** summary opening (R2-3);
- no workout event changes `match`, `clock`, `route` (except through the commands above) or `isPaused` (FR-011).

## MatchSession additions

| Field | Type | Meaning |
| --- | --- | --- |
| `workout` | `WorkoutService` | Injected; production `HealthKitWorkoutService` |
| `workoutState` | `WorkoutState` | As above |
| `latestHeartRate` | `HeartRateReading?` | Latest reading; cleared with the match (FR-014) |
| `summaryStatistics` | `WorkoutStatistics?` | The summary snapshot (R7); cleared on Undo and Done |
| `pendingSaveFailureNotice` | `Bool` | Shown once on New match after Done (FR-015) |
| `sleep` | `@Sendable (Duration) async throws -> Void` | Injected; drives the 10-minute timeout (R4) |

Changed derived value:
- `canUndo` on the summary is false when `workoutState` is `saving` or `saved` (FR-007).

## HeartRateReading (value)

| Field | Type | Meaning |
| --- | --- | --- |
| `bpm` | `Int` | Rounded beats per minute |
| `date` | `Date` | End of the sample's interval |

## HeartRateDisplay (value, pure)

What the score header shows (FR-012, Story 3), built from `workoutState`, `latestHeartRate`, `now` and `isLuminanceReduced`.

| Case | Condition | Shown | VoiceOver |
| --- | --- | --- | --- |
| `hidden` | `workoutState` is `none` or `failed`, or Always On | no row | — |
| `value(bpm)` | `running`, reading at most 30 s old | ♥ + number | "Heart rate, 142 beats per minute" (plural) |
| `unavailable` | `running` without a fresh reading, or `paused` | ♥ + "--" | "Heart rate unavailable" |

Boundary: a reading exactly 30 s old still shows; at 30.001 s it's `unavailable` (tested).

## WorkoutStatistics (value)

| Field | Type | Source (research R7) |
| --- | --- | --- |
| `averageHeartRate` | `Int?` | `statistics(for: .heartRate).averageQuantity()`, count/min, rounded |
| `maximumHeartRate` | `Int?` | `maximumQuantity()`, rounded |
| `activeEnergy` | `Double?` | `statistics(for: .activeEnergyBurned).sumQuantity()`, kilocalories |

Heart rate is present only when both average and maximum are.

## SummaryHealthRows (value, pure)

The two Watch 6 rows (FR-013, Story 4), built from `WorkoutStatistics?` and the locale; added to `SummaryModel` after Duration.

| Row | Shown when | Text | VoiceOver |
| --- | --- | --- | --- |
| Heart rate | `averageHeartRate` and `maximumHeartRate` | "Heart rate avg / max" · "138 / 171" with ♥ | "Heart rate: average 138, maximum 171 beats per minute" |
| Active energy | `activeEnergy` | "Active energy" · "612 kcal" (system format, R13) | "Active energy: 612 kilocalories" |

No statistics (`workoutState` `none` or `failed`) → no rows: the spec 002 summary (Story 4 s3).

## HealthOnboarding (observable, main actor)

| Field | Type | Meaning |
| --- | --- | --- |
| `requestStatus` | `AuthorizationRequestStatus?` | Read at launch; `nil` until the read returns (see Launch below) |
| `skippedThisLaunch` | `Bool` | Not now (Q4); not stored |
| `needsOnboarding` | derived | `requestStatus == .shouldRequest && !skippedThisLaunch` |

Commands: `continue()` → `requestAuthorization()`, then `requestStatus = .unnecessary`; `notNow()` → `skippedThisLaunch = true`. Both lead to New match (Story 1 s3, s4).

Launch: the status read is fast and local. Until it returns, the root view shows the 002 New match; if the answer is `.shouldRequest`, the onboarding is presented over it (a full-screen cover). This way a slow read never blocks the remembered format and Start (Story 1 s6).

## Relationships

```text
HealthOnboarding ──▶ WorkoutService.requestAuthorization
MatchSession ──owns──▶ Match (TennisCore), MatchClock, WorkoutState
      │ commands ──▶ WorkoutService (start, pause, resume, statistics, save, discard)
      │ ◀── onEvent (heart rate, failed, ended)
      ├─ workoutState + latestHeartRate + now ──▶ HeartRateDisplay ──▶ ScoreView header
      └─ summaryStatistics ──▶ SummaryHealthRows ──▶ SummaryView
WKApplicationDelegate.handleActiveWorkoutRecovery ──▶ WorkoutService.recoverAndSave (FR-009a)
```
