# Research: Match on Apple Watch (002)

**Date**: 2026-10-13 | **Spec**: [spec.md](spec.md) | **Plan**: [plan.md](plan.md)

The Technical Context had no open `NEEDS CLARIFICATION` items: the spec, the constitution, `docs/product/plan.md`, the design export and the engine contract ([001 public API](../001-scoring-engine/contracts/public-api.md)) fix the platform, the language and the engine. The decisions below settle how to build the watch flow. Each lists what was chosen, why, and what was rejected.

## R1. Where the logic lives: a testable model layer in the watch app target

- **Decision**: All match-flow logic that is not drawing lives in plain Swift types in the watch app target, under `TennisBeat Watch App/Match/`:
  - `MatchSession`: the match, its timing and the screen route;
  - `PointOutcome`: the FR-010 outcome function;
  - `ScoreScreenModel`: what the score screen shows and what VoiceOver reads;
  - `SummaryModel`: the summary's title, chips and duration;
  - `MatchClock`: elapsed time;
  - `FormatChoice` with its store: the remembered setup.

  SwiftUI views only read these models and call their methods. The types are unit-tested with Swift Testing in `TennisBeat Watch AppTests` (`@testable import TennisBeat_Watch_App`).
- **Rationale**: FR-010 asks for the outcome function and the haptic logic to be tested without UI. SC-002, SC-003 and SC-004 need many scripted sequences, which run in milliseconds against models and in minutes against a simulator UI. Keeping the views thin also keeps each screen PR small.
- **Alternatives rejected**:
  - A new local Swift package (for example `Packages/MatchFlow`) tested with `swift test` on macOS: faster CI, but it is a new module boundary the constitution doesn't name. The String Catalog would also have to move into a package bundle, and the shared catalog with the app would need extra plumbing. It can be revisited when the iPhone app needs the same models (spec 004).
  - Adding these types to `TennisCore`: spec 001 must not change (FR-010), and the engine has no user-facing strings, timing or haptics (constitution, Technical Constraints).

## R2. The outcome function (FR-010, FR-011, FR-012)

- **Decision**: `PointOutcome.evaluate(before: MatchState, after: MatchState, winner: Player) -> PointOutcome` is a pure function. It is called only after `recordPoint` succeeds:
  - **match**: `before.status == .inProgress` and `after.status == .won(_)`;
  - **set**: `after.completedSets.count > before.completedSets.count` (not the match);
  - **game**: the total of `after.games` is greater than the total of `before.games` (not a set);
  - **point**: none of the above;
  - **change of ends**: `after.changeOfEnds`, and only when the match was not won by this point [ITF: EN-05].

  The result is one `level` (point, game, set or match), the `changeOfEnds` flag and the `winner`. Undo, correction, early end, pause and resume never call it, so they can't produce haptics (Story 3 s7, FR-012).
- **Rationale**: The engine exposes the state, not a per-point result (review 1, R1-4). A won game that ends a set resets `games` to 0–0, so the set check comes before the game check. A tie-break point that ends the set changes `completedSets`. A match tie-break point that wins the match changes `status`. The `changeOfEnds` value belongs to the latest point (spec 001), which is the point just added.
- **Tests**: a table of scripted cases built with the engine for every level, in Advantage and No-Ad games, set tie-breaks and match tie-breaks, plus the change-of-ends cases (odd games EN-01..EN-03, the first game of a set EN-04, every 6 tie-break points TB-05, and the match-winning point EN-05). A seeded property test checks that exactly one level is produced per added point and that the level agrees with the changes in `status`, `completedSets` and `games` over generated matches.
- **Alternative rejected**: diffing the event lists, or counting points in the app: that is score logic outside the engine (FR-010).

## R3. Haptics: `WKInterfaceDevice` behind a protocol

- **Decision**: A `HapticPlaying` protocol with one method, `play(_ outcome: PointOutcome)`. The production type maps the outcome to `WKInterfaceDevice.current().play(_:)`:

  | Haptic | `WKHapticType` (proposal) |
  | --- | --- |
  | Point (Q6) | `.click` |
  | Game | `.directionUp` |
  | Set | `.success` |
  | Match | `.notification` |
  | Change of ends | `.retry`, played about 0.8 s after the point's haptic |

  Tests use a recording fake. SC-003 compares the recorded sequence with the outcome table.
- **Rationale**: These are the system's distinct patterns; custom Core Haptics patterns are not available on watchOS. The delay keeps the change-of-ends pattern separate from the point's haptic (Story 3 s5). Whether the four are told apart without looking is the Story 3 s8 / SC-007 device check, so the mapping is a proposal that Denys may change after that check without a spec change.
- **Alternative rejected**: `.sensoryFeedback` view modifiers. They fire on value changes, so they can't distinguish an added point from an undo that produces a similar state, and they can't be tested without UI.

## R4. VoiceOver announcements behind a protocol

- **Decision**: An `Announcing` protocol. The production type posts `AccessibilityNotification.Announcement(_:)`. The session announces:
  - after an added point: the game, set or match winner (from `PointOutcome`), then "Change ends" if the point calls for it;
  - after a server correction: the new server;
  - after any event: the new status-line text, when it differs from the previous one.

  Tests use a recording fake.
- **Rationale**: FR-024 and Story 7 s2–s4 are testable without a simulator this way. The strings come from the String Catalog, so the fake records localized text.
- **Alternative rejected**: deriving announcements in views with `onChange`: not testable without UI, and it can't tell an added point from an undo.

## R5. Elapsed time with an injected clock

- **Decision**: `MatchClock` is a value type with `startedAt`, a list of excluded intervals (pauses, and time spent on the summary) and an optional `stoppedAt`.
  - `elapsed(at now: Date) = (stoppedAt ?? now) − startedAt − excluded`.
  - **Pause** opens an interval and **Resume** closes it.
  - **Ending** (match won or ended early) sets `stoppedAt`, closing an open pause at that moment first.
  - **Undo from the summary** adds the interval `[stoppedAt, now]` to the excluded list and clears `stoppedAt`, so the time on the summary is not counted (Story 5 s9) and the match is not paused (edge case "Undo of an early end").

  The session takes a `now: () -> Date` closure. Views redraw with `TimelineView`: every second in the active state, `.everyMinute` when the luminance is reduced (R8).
- **Rationale**: FR-022 needs wall-clock time minus pauses, which stays right after the app returns from the background or the screen wakes: nothing counts ticks. SC-004 (≤ 1 s over a scripted 30-minute match) is checked with a fake clock in a unit test.
- **Formatting**: the header uses `Duration.formatted(.time(pattern: .minuteSecond))`, or `.hourMinuteSecond` from one hour on, with `.monospacedDigit()`. Always On uses `Duration.formatted(.units(allowed: [.minutes], width: .abbreviated))` in whole minutes, for example "42 min" or "84 min" (R1-8). The summary uses `.time(pattern: .hourMinuteSecond)`. All of them follow the current locale (FR-023).
- **Alternative rejected**: a `Timer` that increments a counter: it drifts, and it stops while the app is suspended.

## R6. Navigation and screens

- **Decision**: A root view switches on `MatchSession.route`:
  - **`.setup`**: a `NavigationStack` with New match → First server → Coin-toss result. The format pickers are pushed views (Story 1 s4). Back from First server and from the coin-toss result is the system back button (Story 1 s10).
  - **`.playing`**: a `TabView` with `.tabViewStyle(.page)`, which pages horizontally: Controls, then Score. It opens on Score. Swiping right shows Controls, as in the system Workout app (Story 4 s1).
  - **`.summary`**: the summary as a full screen.

  End uses `.confirmationDialog` with a destructive "End match" button; Cancel is the system button (Story 4 s11).
- **Rationale**: The spec places Controls next to Score with a horizontal swipe (Assumptions, Navigation). Setup is a stack with back navigation. A route enum makes the screen flow unit-testable: the match is won → `.summary`; End with no points → `.setup`; Done → `.setup`; Undo from the summary → `.playing`.
- **Alternative rejected**: a single `NavigationStack` for the whole flow: back from Score to First server would be possible mid-match, which the spec doesn't allow.

## R7. Score screen: tap zones, Dynamic Type and VoiceOver

- **Decision**:
  - **Layout**: a header (Undo, elapsed time), then two zones in a `VStack` of equal height, each a `Button` with a plain style filling its frame (FR-005, FR-026). The status line sits above the zones in the header area, as in the design.
  - **Taps**: the zones are disabled when the session doesn't accept points (paused, won or ended) and when the luminance is reduced (Story 6 s3).
  - **Dynamic Type**: the score screen uses `.dynamicTypeSize(...DynamicTypeSize.xxxLarge)` (Q9, FR-025), the largest standard size on watchOS. The other screens are `ScrollView`s with no cap.
  - **Fonts**: text styles from `docs/design/typography.md`, with `.rounded` and `.monospacedDigit()` for numbers.
  - **VoiceOver**: the score summary is the first element after the header. Each zone is one element (`.accessibilityElement(children: .ignore)`) with the zone sentence as its label and "Add point for …" as its hint. All strings come from `ScoreScreenModel`.
- **Rationale**: Story 7 s1 fixes the reading order and the content. The wording is the copy table's, with separate Me and Opponent strings (R2-1). Keeping the strings in the model lets unit tests check the VoiceOver text for every state without a simulator.
- **Alternative rejected**: `.accessibilityAction(named:)` for "Add point": the zone's default action is already the tap, and a named action would make VoiceOver users pick from the actions menu.

## R8. Always On

- **Decision**: The score view reads `@Environment(\.isLuminanceReduced)`. When it is true, the view:
  - swaps to the dimmed palette and the minutes-only header;
  - hides Undo, the serve icon, the court-side pill and the status line (Q8, FR-021);
  - turns off animations;
  - disables both zones.

  The dimmed rendering is checked with previews and simulator screenshots. Readability at arm's length is a device check.
- **Rationale**: This is the system's Always On API. Until spec 003 starts a workout session, the app may leave the screen when the wrist drops (Q10), so the full check waits for 003.
- **Alternative rejected**: a separate Always On view: it would duplicate the score layout.

## R9. Remembered format (FR-004)

- **Decision**: `FormatChoice` holds four app-side values: format, set length, at 40–40, third set. The third set is kept even for 1 set, so the row reappears with its previous value (Story 1 s3). It is stored in `UserDefaults` under `lastFormat.v1` as four raw strings, written when a match starts (Story 1 s5). On read, each row falls back to its Q2 default on its own when its value is missing or unknown (Story 1 s6). The `MatchFormat` built from it sets `matchTieBreak` only for best of 3 with Tie-break to 10 (FR-002), so `MatchFormat.init` never throws for a stored value. The first server is never stored.
- **Rationale**: This is the only data the feature stores (FR-004, FR-027). Per-row fallback is what Story 1 s6 asks for. A versioned key lets a later spec migrate it.
- **Alternatives rejected**:
  - Storing `MatchFormat` as JSON: it isn't `Codable` in the 001 contract, and one bad field would reset every row.
  - SwiftData: unnecessary for four values. History persistence is a later spec.

## R10. Coin toss

- **Decision**: `CoinToss` takes an injected `() -> Player`. The production value is `Bool.random() ? .me : .opponent`, which uses the system's random generator. The result screen shows the result and one Start button. Going back discards it, and the next tap tosses again (Story 1 s9, s10).
- **Tests**: a unit test with a fixed toss. A distribution test runs 10,000 tosses with a seeded generator and accepts 50% ± 2% (FR-003).
- **Alternative rejected**: a custom generator in production: the system generator is already uniform.

## R11. Localization

- **Decision**: One `Localizable.xcstrings` in `TennisBeat Watch App/` (the folder is synchronized, so the file joins the target), with EN as the source and PL and UK. The project already lists `en`, `pl` and `uk` in `knownRegions`.
  - Keys are semantic (`score.summary.me.right`, `setup.setLength.value`), so the separate Me and Opponent strings (R2-1) and the match tie-break chip (R2-4) are separate keys.
  - Counts (games, sets, "%d games" in Set length) use plural variations.
  - Minutes and durations use `FormatStyle` (R5), not catalog strings.
  - Every row of the spec's copy table becomes keys in the screen PR that first uses it.
  - A unit test loads the catalog's PL and UK bundles and fails on any key that is missing a translation (SC-006).
- **Rationale**: Constitution X, FR-023, SC-006. Semantic keys stop an EN wording change from orphaning translations.
- **Alternative rejected**: EN text as the key: the R2-1 split would need the same EN text twice in some languages, and edits to EN copy would orphan the PL and UK values.

## R12. UI tests and CI

- **Decision**:
  - **UI tests**: `TennisBeat Watch AppUITests` (XCUITest) run scripted tap sequences on the watch simulator in EN. Elements carry accessibility identifiers (`zone.me`, `zone.me.points`, `zone.me.games`, `zone.me.sets`, `zone.me.serve`, `zone.me.side`, `status`, `undo`, …).
  - **Expected values**: the UI test target links `TennisCore`, replays the same taps through a `Match`, and compares each displayed text with the engine's value after every tap, undo and correction (SC-002). The display mapping in the test is one trivial table: `PointDisplay` to "0/15/30/40/AD" or a number, and `CourtSide` to Right/Left/Choice.
  - **Launch arguments**: `-resetFormat` and `-coinToss me|opponent` make runs deterministic.
  - **CI**: a new `watch-tests` job runs `xcodebuild test` for the `TennisBeat Watch App` scheme (unit and UI tests) on a watchOS simulator on the `macos-26` runner. It is added in PR 1.
  - **Fallback**: if the runner image has no watchOS simulator runtime, the job runs the unit tests only on a generic destination, and the PRs attach local XcodeBuildMCP UI-test results. Denys is told in that PR.
- **Rationale**: SC-002 asks for UI-level tests on the watch simulator. Checking against the engine, and not against the app's own model, keeps the test independent of the code under test. CI evidence is bound to the head SHA (constitution IV).
- **Alternative rejected**: hard-coded expected strings per tap: brittle, and it covers fewer formats.
- **Project change**: linking `TennisCore` to the UI test target edits `project.pbxproj`. It is made with the Xcode MCP tools, and `scripts/gates/check-project-format.sh` must still pass (no `validationLevel`, `objectVersion = 100`).

## R13. Main-actor isolation

- **Decision**: The app targets build with `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`. `MatchSession` is an `@Observable` main-actor class. The pure types (`PointOutcome`, `MatchClock`, `FormatChoice`, `ScoreScreenModel`, `SummaryModel`) are value types marked `nonisolated`, so tests and helpers can use them from any context.
- **Rationale**: Swift 6 strict concurrency. The engine types are `Sendable` (001 contract).

## R14. Deferred and out-of-scope checks

- **Deferred**: the 001 SC-004 device check ("app killed during a 500-point match and relaunched") stays deferred. It needs persistence and restore, which are a later spec, not 002 (spec Out of scope). The plan leaves the device-checklist row unchanged.
- **Covered here**: the constitution III boundary test "pause during a tie-break" (backlog #6) is written in PR 3 (Controls). It checks that pause and resume leave the tie-break state, the server and the court side unchanged.
