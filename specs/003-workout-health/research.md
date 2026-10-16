# Research: Workout and Health on Apple Watch (003)

**Date**: 2026-10-15 | **Spec**: [spec.md](spec.md) | **Plan**: [plan.md](plan.md)

The Technical Context had no open `NEEDS CLARIFICATION` items. The platform, language and architecture come from spec 002 ([research](../002-watch-match/research.md)), `docs/product/plan.md` (Architecture: `HKWorkoutSession` + `HKLiveWorkoutBuilder` on the watch) and the constitution. The decisions below settle how to build the workout on top of the 002 `MatchSession`. Each lists what was chosen, why, and what was rejected. Items that only a real watch can confirm are marked **device check** and refer to the spec's numbered device-only checks.

## R1. The workout behind a protocol, driven by `MatchSession`

- **Decision**: A main-actor protocol `WorkoutService` in `TennisBeat Watch App/Health/` is the only thing `MatchSession` knows about the workout ([data-model.md](data-model.md) § WorkoutService). It has two implementations:
  - `HealthKitWorkoutService`: `HKHealthStore`, `HKWorkoutSession`, `HKLiveWorkoutBuilder` with an `HKLiveWorkoutDataSource`;
  - `FakeWorkoutService`: in memory, scripted by tests and by DEBUG launch arguments ([contract](contracts/ui-contract.md) §2). It records every call.

  `MatchSession` calls the service from its existing commands (`start`, `pause`, `resume`, the route change to `.summary`, `undo` from the summary, `endEarly`, `done`) and from one new timer (R4). The service reports back through one callback, `onEvent(WorkoutEvent)`: heart-rate reading, failed, ended unexpectedly (statistics are read with `statistics()`, not sent as events). The session keeps a `WorkoutState` value (none, running, paused, summary, saving, saved, discarded, failed) that the views and models read.
- **Rationale**: SC-002 asks for every lifecycle step to be checked automatically with a fake service, and HealthKit sessions don't run in unit tests. FR-011 keeps the engine unaware of the workout: the workout follows `MatchSession`, never `Match`. The 002 contract §5 already says spec 003 hooks the workout to `start` and `.summary` through the session.
- **Alternatives rejected**:
  - Views calling HealthKit directly (`onChange(of: route)`): not testable without UI, and the order of calls on Undo from the summary would depend on view timing.
  - Putting the workout in `TennisCore`: forbidden (constitution Technical Constraints, FR-018).
  - A Combine or `AsyncStream` interface: one callback closure is enough, and it's simpler to fake and to isolate on the main actor (R11).

## R2. Mapping the match to `HKWorkoutSession` (FR-005..FR-009, review findings R2-1/R3-1, R2-3)

`HKWorkoutSession.end()` can't be undone, but Story 2 s5 resumes the workout after Undo on the summary. So "the workout stops when the summary opens" is built as a **pause with a recorded end date**, as Denys approved on #27 (R2-1, R3-1):

| Match step | Workout call | Notes |
| --- | --- | --- |
| `start(firstServer:)`, workout saving allowed | `startActivity(with: clock.startedAt)`, `builder.beginCollection(withStart: clock.startedAt)` | `HKWorkoutConfiguration`: `activityType = .tennis`, `locationType = .unknown` (no court type, Q1) |
| `pause()` | `session.pause()` | The builder records an `HKWorkoutEvent` `.pause` |
| `resume()` | `session.resume()` | `.resume` event |
| Summary opens (winning point, or confirmed End with a point) | `session.pause()` if running; `summaryOpenedAt = clock.stoppedAt` | The session stays alive, so the app stays frontmost on the summary (device check 1) |
| `undo()` from the summary | `session.resume()`; `summaryOpenedAt = nil` | The summary time becomes a paused interval (Story 4 s5) |
| `done()`, or the 10-minute timeout (R4) | `session.stopActivity(with: effectiveEnd)`, `session.end()`, `builder.endCollection(withEnd: effectiveEnd)`, `builder.finishWorkout()`, where `effectiveEnd` is `summaryOpenedAt` or the builder's last event date if that is later (see below) | One save per match (FR-009); the saved workout ends when the summary opened **the last time** (R2-3) |
| `endEarly()` with 0 points | `session.end()`, `builder.discardWorkout()` | Nothing saved (FR-008) |
| Workout failed to start, or ended by the system | none | `WorkoutState.failed`: no heart-rate row, no save, match unchanged (FR-010) |

- **Paused intervals**: the clock and the workout get the same timestamps, from the session's injected `now`. `session.pause()` and `resume()` take no date, so the builder stamps its events a few milliseconds after the clock. The difference is far below the 1-second limit of FR-006 and SC-003, and the device check (spec check 5) confirms it. The fake records `now()` from the session's clock at each call, and the unit tests compare those recorded times with the clock's intervals; `start(at:)` and `save(endingAt:)` take explicit dates, which the tests check exactly.
- **The end date and HealthKit's own event dates** (#28 R5-2, approved by [Denys](https://github.com/dfinchenko/tennis-beat/pull/28#issuecomment-6201412560)): `session.pause()` takes no date, so the builder's last `.pause` event can be dated a few milliseconds **after** `clock.stoppedAt`. HealthKit requires workout events to lie inside the workout, so ending at `clock.stoppedAt` could make `finishWorkout()` fail on every save. The service therefore ends at `effectiveEnd = max(summaryOpenedAt, the date of the builder's last event in builder.workoutEvents)` in `stopActivity`, `endCollection` and the saved workout. The difference stays far below 1 s, so SC-003 still holds. The fake stamps `pause()` 5 ms after `now()`, and a unit test checks that the saved end is `>=` the last pause (T025). This is a risk for device check 4: if a save still fails there, the cause is recorded and a fix proposed to Denys before any workaround.
- **The end date in the past**: `endCollection(withEnd:)` with `summaryOpenedAt` cuts the summary time off the saved workout. The workout's `duration` in Health then equals `clock.elapsed(at: stoppedAt)`, the summary's Duration (SC-003).
- **Rationale**: one live session from start to save keeps the app frontmost for the whole match, the pauses and the summary (Story 2 s2, device check 1). It also gives exactly one workout per match whatever the number of Undos (FR-009, Story 4 s5).
- **Alternatives rejected**:
  - Ending the session when the summary opens and starting a new one after Undo: two workouts per match, against FR-009.
  - `HKWorkoutSession.stopActivity` at the summary, then `startActivity` again after Undo: `stopActivity` moves the session to `.stopped`, which can't return to `.running`.
  - Ending the workout at Done time: it would count the summary time, against R1-1.

## R3. Who decides whether a workout starts (FR-005, FR-010, Story 5)

- **Decision**: At `start(firstServer:)` the session asks the service `canStartWorkout`, which is `healthStore.authorizationStatus(for: .workoutType()) == .sharingAuthorized`. When it's false, the match starts with `WorkoutState.none`: no service call, no heart-rate row, Duration-only summary, the summary keeps Undo as in spec 002 FR-020. Permission is read at every start, so a change in Settings applies from the next match (Story 5 s4).
- **Read access**: HealthKit doesn't tell apps whether read access was given. With workouts allowed and heart rate denied, the workout runs and simply gets no readings (Story 5 s2): the header shows "--" and the summary hides the row. Nothing in the app branches on read access.
- **Start failure**: `startActivity` and `beginCollection` report errors asynchronously (for example another app's workout, spec Edge cases). The service reports `failed`, and the session moves to `WorkoutState.failed` (FR-010, Story 2 s9). The match was already running and is never blocked.
- **Workout ended unexpectedly** (Story 2 s10): the `HKWorkoutSessionDelegate` reports `didFailWithError`, or a move to `.ended` the app didn't ask for. The service discards the builder and reports `endedUnexpectedly`. The session moves to `WorkoutState.failed`: the heart-rate row disappears, nothing is saved for this match.
- **Summary Undo without a workout** (R3-2, [Denys, #28](https://github.com/dfinchenko/tennis-beat/pull/28#issuecomment-6201412560)): a match whose workout failed to start or to save counts as "without a workout" and keeps Undo on the summary as in spec 002 FR-020; after a failed 10-minute save, Undo returns (FR-007). A workout that ended unexpectedly (Story 2 s10) is never saved, so FR-007 never removes its Undo either; it uses the same `failed` state.

## R4. The 10-minute summary timeout (FR-007, Story 2 s7)

- **Decision**: When the summary opens with a workout running or paused (End confirmed while paused), the session starts a task that sleeps 10 minutes through an injected `sleep: @Sendable (Duration) async throws -> Void`, the same seam as 002's `WatchHaptics` (`ManualSleep` in tests). When it fires and the route is still `.summary`, the session saves the workout as on Done and sets `WorkoutState.saved`. `canUndo` is then false on the summary. Undo and Done cancel the task (End isn't available on the summary).
- **Wake-ups**: the session keeps running while paused, so the app keeps running in the background, and the task fires on time even with the wrist down (device check 15). As a safety net, a scene-phase change to `.active` checks `now() − summaryOpenedAt ≥ 10 min` and saves at once if the timer missed.
- **Rationale**: tests drive the timeout by hand, as the haptics delay in 002 R3. The safety net covers a timer that is late after the app was suspended.
- **Alternative rejected**: `Timer.scheduledTimer`: not testable without waiting, and it's tied to the run loop.

## R5. Saving and the failure notice (FR-009, FR-015, Story 4 s7)

- **Decision**: `save(endingAt:)` is `async throws`. The session moves to `WorkoutState.saving` when the save starts and to `saved` when it succeeds, so a second Done can't save twice. If `finishWorkout` throws, the session sets an in-memory flag `pendingSaveFailureNotice`. The setup flow observes the flag: when it is true while New match shows after Done, also when it turns true after New match is already showing (the save usually fails after Done has changed the route, or a timeout save still running at Done fails later), it presents a one-time alert "Workout not saved to Health" with OK, then clears the flag (R1-6). Done never waits for the save: the route changes at once (FR-010).
- **The flag is not stored**: it's not health data, but a relaunch drops it; the notice is a convenience, not a record. A save that fails during the 10-minute timeout sets the same flag, shown after Done (Story 4 s7). It also moves the session to `WorkoutState.failed`, so the summary shows Undo again and drops the heart-rate and energy rows (Duration only, Story 4 s3); Undo then resumes the match with no workout (R3-2).
- **Exactly one save**: the fake counts `save` calls. SC-002 checks one save per final match with points and none otherwise, across Undo from the summary, the timeout, and a second Done tap.

## R6. Heart rate in the header (FR-012, Story 3)

- **Decision**: The service reports each new heart-rate value from `workoutBuilder(_:didCollectDataOf:)`: `statistics(for: .heartRate).mostRecentQuantity()` in count/min, with `mostRecentQuantityDateInterval().end` as its date. The session keeps the latest `HeartRateReading(bpm: Int, date: Date)` in memory only (FR-014). A pure `HeartRateDisplay` value decides the header:
  - `WorkoutState.none` or `.failed`: no row;
  - running, with a reading no older than 30 seconds at `now`: the number;
  - otherwise (no reading yet, older than 30 s, paused): the heart icon and "--" (Q3).
- **Redraw**: the header already redraws every second through 002's `TimelineView` (`ElapsedTimeView`), so a reading turns into "--" within one second of going stale, with no extra timer. A new reading is shown without animation (`.transaction { $0.animation = nil }`), and nothing is announced (Story 3 s6).
- **Layout**: heart rate sits on the elapsed-time line, after the time: `ViewThatFits` tries "42:18 ♥ 142" on one line, then the time with the heart rate in a smaller trailing size. The 3-digit case (above 199, Edge cases) and the XXXL text size on 40 mm are covered by screenshot tests. The result is recorded in `watch-3-score.md` (Q3). The status line keeps its place under the time.
- **Always On**: the row is hidden when the luminance is reduced (Story 3 s5, FR-012), like the other Q8 elements.
- **VoiceOver**: the heart rate is part of the elapsed-time element's value ("Heart rate, 142 beats per minute", plural), or "Heart rate unavailable". It isn't a separate stop, so the 002 reading order (time, then the score summary) is kept. A new reading isn't announced.
- **Alternative rejected**: an `HKAnchoredObjectQuery` for heart rate: a second query alongside the builder that already collects the same samples; the builder's statistics are also what the summary uses (R7).

## R7. Summary statistics equal Health's (FR-013, Story 4 s1, s6)

- **Decision**: When the summary opens, the session asks the service for a `WorkoutStatistics` snapshot: heart rate average and maximum (`statistics(for: .heartRate)`, `averageQuantity`, `maximumQuantity`) and active energy (`statistics(for: .activeEnergyBurned).sumQuantity()` in kilocalories). These are the builder's statistics up to that moment, the same data the saved workout gets with `endCollection(withEnd: summaryOpenedAt)`. When `finishWorkout` returns the `HKWorkout` while the summary is still open (the 10-minute save), the session replaces the snapshot with `workout.statistics(for:)`, so the rows show exactly Health's values.
- **Rounding**: heart rate is rounded to whole beats per minute, energy to whole kilocalories, as Health shows them. Health's values are compared on the device (spec check 5).
- **Late samples**: a heart-rate sample delivered a moment after the summary opened can carry an earlier date, so Health may have one more sample than the snapshot. The average could differ by a fraction of a beat. Spec check 5 checks this; if it shows a visible difference, the fix is to refresh the snapshot a few seconds after the summary opens, without a spec change.
- **Rows hidden**: no heart-rate statistics → no heart-rate row; no energy sum → no energy row (Story 4 s2).

## R8. Permissions and the onboarding (FR-001..FR-003, Story 1, Q4)

- **Decision**:
  - **Types** (FR-003): share `HKObjectType.workoutType()`; read `HKQuantityType(.heartRate)` and `HKQuantityType(.activeEnergyBurned)`. Nothing else. This is Apple's pattern in "Running workout sessions": the workout type to share, the measured types to read; the live data source saves the samples it collects with the workout.
  - **"The sheet was answered once"** (Q4): `HKHealthStore.statusForAuthorizationRequest(toShare:read:)` returns `.shouldRequest` until the user has answered the sheet for these types, and `.unnecessary` after. The onboarding shows while it's `.shouldRequest`. **The app stores nothing for Q4**: the system keeps the state.
  - **Not now**: an in-memory flag for the current launch, so the onboarding returns on the next launch (Q4, Story 1 s4).
  - **Continue**: `requestAuthorization(toShare:read:)`. Whatever the answer, or an error, New match opens next (Story 1 s3).
  - **Order**: the root view shows the onboarding before `.setup` while `needsHealthOnboarding` is true. Scoring and the remembered format are untouched (Story 1 s6).
- **Device check**: whether the live data source saves heart-rate and energy samples with share permission for the workout type only (spec check 4). Apple's sample does exactly this, so no change is expected. If Health shows the workout without its heart-rate graph or energy, a spec change to FR-003/FR-004 is opened for Denys instead of a workaround (spec Review 3 and plan decisions).
- **Alternatives rejected**:
  - A `UserDefaults` flag "onboarding seen": it can disagree with the system (reinstall, reset in Settings), and FR-001 ties the onboarding to the sheet, not to the screen.
  - Requesting at the first Start: the request would interrupt the match start, and App Review 2.5.1 asks for the purpose to be explained first.

## R9. Info.plist texts and the workout background mode (FR-004)

- **Decision**:
  - **Read text**: the new EN, PL and UK `NSHealthShareUsageDescription` values go into both `InfoPlist.xcstrings` catalogs first, then into `INFOPLIST_KEY_NSHealthShareUsageDescription` in all four app build configurations (R1-3). `scripts/gates/check-infoplist-strings.sh` checks them. The UK value uses the typographic apostrophe, «Здоров’я», as Apple writes it and as the catalogs already do; the copy table uses the same ([Denys, #28](https://github.com/dfinchenko/tennis-beat/pull/28#issuecomment-6201412560)), so the app writes the Health app's name one way.
  - **Background mode**: `HKWorkoutSession` on watchOS needs `WKBackgroundModes = [workout-processing]` in the watch app's Info.plist. It's added with the Xcode MCP tools (`AddInfoPlist` / the Background Modes capability), and `scripts/gates/check-project-format.sh` must still pass (no `validationLevel`, `objectVersion = 100`).
  - **Entitlement**: the watch app already has `com.apple.developer.healthkit`; no change.

## R10. Recovery after the app was ended mid-match (FR-009a, Q6)

- **Decision**: The watch app adds a `WKApplicationDelegate` through `@WKApplicationDelegateAdaptor`. In `handleActiveWorkoutRecovery()` it calls `HKHealthStore.recoverActiveWorkoutSession`. With the recovered session it ends the session at `now`, ends the builder's collection at `now`, and calls `finishWorkout()`, whatever the number of points (Q6). A failure is ignored (there's no match to report it against). The route stays `.setup`, so New match opens. The workout's own pauses are kept as recorded.
- **Testing**: the recovery path is a small `WorkoutRecovery` type over the `WorkoutService` protocol (`recoverAndSave()`), unit-tested with the fake: one save, no session change, route `.setup`. The real path is device check 14.
- **Spec 004** replaces this with resuming the workout together with the recovered match.

## R11. Concurrency

- **Decision**: `WorkoutService` and both implementations are `@MainActor` (the targets' default isolation, 002 R13). `HealthKitWorkoutService` is the `HKWorkoutSessionDelegate` and `HKLiveWorkoutBuilderDelegate`. Its delegate methods are `nonisolated`, copy what they need into `Sendable` values (`HeartRateReading`, `WorkoutStatistics`, the error) and hop to the main actor with `Task { @MainActor in … }` before calling `onEvent`. HealthKit's async methods are called from main-actor tasks. The pure models (`HeartRateDisplay`, `WorkoutStatistics`, `SummaryHealthRows`) are `nonisolated` value types.
- **Event order**: events from one delegate arrive in order. An event that arrives after the session has moved on (for example a reading after the save) is ignored by `MatchSession` according to `WorkoutState`.
- **One workout at a time, callbacks by workout** (#28 R5-3): Done changes the route while `finishWorkout` may still be running, so the next match can start before the old save ends. `HealthKitWorkoutService` keeps each workout's `HKWorkoutSession` and builder in a per-workout object with a token. A new `start` creates a new object; the old one finishes its save on its own. Delegate callbacks and the save's completion carry their token, and `MatchSession` drops any event whose token isn't the current workout's. Only the old save's result (success or failure → the notice flag) is still delivered, through its own `save` call.

## R12. Tests, launch arguments and SC-005

- **Unit tests** (Swift Testing, `TennisBeat Watch AppTests`), with `FakeWorkoutService`, `FakeClock` and `ManualSleep`:
  - `WorkoutLifecycleTests`: every Story 2 step and every row of the R2 table, with the dates passed to the fake (SC-002, SC-003, FR-006);
  - `WorkoutSaveTests`: exactly one save per final match with points, none for 0 points, Undo from the summary, the timeout, a double Done, a failed save → notice (Story 4 s4, s5, s7);
  - `HeartRateDisplayTests`: every Q3 state, the 30-second boundary, Always On, VoiceOver text and plural forms (Story 3);
  - `SummaryHealthRowsTests`: the rows, hidden rows, formatting and VoiceOver in EN, PL and UK (Story 4 s1–s3, s8);
  - `HealthOnboardingTests`: `.shouldRequest` / `.unnecessary`, Not now for this launch, Continue → request, New match after any answer (Story 1);
  - `HealthStorageTests`: after a scripted match with distinctive values (for example 187 bpm and 733 kcal), no `UserDefaults` value and no file in the app container contains them (SC-007);
  - `StringCatalogTests` (002) covers the new keys (SC-007, FR-016).
- **UI tests** (XCUITest): the DEBUG-only launch argument `-uiTestHealth <mode>` replaces HealthKit with the fake ([contract](contracts/ui-contract.md) §2). The UI-test helper launches every existing 002 test with `-uiTestHealth denied` (sheet answered, workouts not allowed), so those tests run unchanged against the "not authorized" state (SC-005). This is a helper change; no expectation changes. New UI tests use `granted`, `shouldRequest` and scripted readings for the onboarding, the header and the summary rows, and run the accessibility audits in EN, PL and UK at XXXL on 40 mm (SC-006).
- **HealthKit in the simulator**: not used by tests. The simulator's workout session doesn't produce realistic readings and can't answer the permission sheet from a test, so real HealthKit is covered by the device checks only.
- **Alternatives rejected**: testing against the simulator's HealthKit: flaky permission sheets and no control over readings.

## R13. Localization and formatting (FR-016)

- **Decision**: New keys in the watch `Localizable.xcstrings`, semantic as in 002 R11: `health.onboarding.*`, `score.heartRate.*`, `summary.heartRate.*`, `summary.energy.*`, `health.saveFailed.*`. Plural variations: `score.heartRate.accessibility %lld` and the summary heart-rate VoiceOver string, whose plural is on the maximum (`%2$lld`, copy table).
  - **Energy**: `Measurement(value: kcal, unit: UnitEnergy.kilocalories).formatted(.measurement(width: .abbreviated, usage: .asProvided, numberFormatStyle: .number.precision(.fractionLength(0))))` with the model's locale, giving "612 kcal" / «612 ккал». VoiceOver uses `width: .wide` ("612 kilocalories", plural by the system). `usage: .asProvided` keeps kilocalories whatever the locale (spec Assumptions: no kJ).
  - **Heart rate**: an integer with `.monospacedDigit()`; the unit is in the VoiceOver string only, as Watch 3 shows the number alone.
  - **The Health app's name**: "Health" / «Zdrowie» / «Здоров’я» in the strings themselves, with the inflected forms of the copy table («w Zdrowiu», «в „Здоров’ї“» written with the catalog's quotes).
- The PL and draft rows go in as drafts; the Polish native review (#22) doesn't block the PRs (as in 002).

## R14. Design records

- **Watch onboarding**: there's no watch design. PR 1 adds `docs/design/screens/watch-0-health-onboarding.md` with a simulator screenshot: title, three lines, Continue (primary capsule, `brand/ball`) and Not now (secondary capsule, `watch/surface-raised`), in a `ScrollView`, built from the 002 tokens and type styles. Denys approves it in that PR's review.
- **Watch 3**: PR 3 replaces "Heart-rate row is hidden in spec 002" with the Q3 layout in `watch-3-score.md`.
- **Watch 6**: PR 4 records the two rows, "Active energy" (Q5), and the Undo change (R1-2) in `watch-6-summary.md`. Spec 002 FR-020 gets its "changed by spec 003" note in PR 2, which builds the timeout.
