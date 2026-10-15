# Contract: Health on the watch (v1)

Additions to the [002 UI contract](../../002-watch-match/contracts/ui-contract.md), which stays in force. Tests, the reviewer and spec 004 rely on these surfaces. Semantics are in [data-model.md](../data-model.md).

## 1. Accessibility identifiers

| Screen | Identifier | Element |
| --- | --- | --- |
| Health onboarding | `health.onboarding` | The screen (scroll view) |
| Health onboarding | `health.onboarding.title`, `health.onboarding.line.1` … `.3` | Texts (Story 1 s2) |
| Health onboarding | `health.onboarding.continue`, `health.onboarding.notNow` | Buttons |
| Score | `heartRate` | The heart-rate row; absent without a workout (Story 3 s4) and in Always On. Its label is the VoiceOver text (Story 3 s6). With `-uiTestExposeValues` the drawn number has `heartRate.value` ("142" or "--") |
| Summary | `summary.heartRate`, `summary.energy` | The rows, each one VoiceOver element of at least 44 pt (as `summary.duration`); absent when hidden (Story 4 s2, s3) |
| New match | `health.saveFailed`, `health.saveFailed.ok` | The one-time notice and its OK (FR-015). The alert button is found by its label if watchOS drops the identifier, as for `confirm.end` |

`summary.undo` is absent while the workout is saving and once it is saved (Story 2 s7; the plan's reading of FR-007, data-model § WorkoutState); after a failed timeout save it is shown again (R3-2).

## 2. Launch arguments (UI tests only, `#if DEBUG`)

| Argument | Effect |
| --- | --- |
| `-uiTestHealth denied` | Fake service: sheet answered, workouts not allowed. No onboarding, no workout. **Added by the UI-test helper to every 002 test** (SC-005) |
| `-uiTestHealth shouldRequest` | Fake service: sheet never answered, so the onboarding shows; Continue "answers" it as `granted` |
| `-uiTestHealth granted` | Fake service: sheet answered, workouts allowed |
| `-uiTestHealth failing` | As `granted`, but the workout fails to start (Story 2 s9) |
| `-uiTestHeartRate 142` | With `granted`: one reading of 142 when the match starts; `--` after 30 s as normal |
| `-uiTestWorkoutStats 138,171,612` | With `granted`: the statistics the summary gets (average, maximum, kcal); an empty field hides its row (`138,171,` → no energy row) |
| `-uiTestSaveFails` | With `granted`: the save fails, so New match after Done shows the notice |

Without `-uiTestHealth` the app uses `HealthKitWorkoutService`, also in DEBUG builds.

## 3. Displayed values (EN)

| State | Shown |
| --- | --- |
| Heart rate, fresh reading | `♥ 142`, monospaced digits; VoiceOver "Heart rate, 142 beats per minute" |
| Heart rate, no reading (Q3) | `♥ --`; VoiceOver "Heart rate unavailable" |
| Summary heart rate | "Heart rate avg / max" · `♥ 138 / 171`; VoiceOver "Heart rate: average 138, maximum 171 beats per minute" |
| Summary energy | "Active energy" · `612 kcal`; VoiceOver "Active energy: 612 kilocalories" |
| Save failure | "Workout not saved to Health" · OK |

Row order on the summary: title, chips, Duration, Heart rate, Active energy, Done, Undo (FR-013).

## 4. Workout per session command (SC-002)

| Command or moment | Workout (with permission) |
| --- | --- |
| `start(firstServer:)` | start, tennis, no location type, at the clock's start |
| `pause()` / `resume()` | pause / resume |
| Summary opens | pause; end date fixed = `clock.stoppedAt`; statistics snapshot; 10-minute timer |
| `undo()` from the summary | resume; end date cleared; timer cancelled |
| `done()` | save, ending at the last summary opening; route changes at once |
| 10 minutes on the summary | save as on Done; Undo removed; on failure Undo returns and the notice follows Done (R3-2, R1-6) |
| `endEarly()` with 0 points | discard |
| Relaunch with a running workout | save at that moment; New match (FR-009a) |

Without permission, or after a failure, no row of this table calls the workout, and the 002 contract §4 and §5 apply unchanged.

## 5. Session interface (for spec 004)

`MatchSession` adds `workoutState`, `latestHeartRate` and `summaryStatistics` (read-only) and takes a `WorkoutService` in its initializer. Spec 004 links a saved match to its workout by the workout's UUID, which `save` already returns (`SavedWorkout.uuid`); spec 003 drops it after Done (spec Key Entities).
