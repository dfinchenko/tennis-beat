---
description: "Task list for the match on Apple Watch (002)"
---

# Tasks: Match on Apple Watch

**Input**: Design documents from `specs/002-watch-match/`: [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md), [data-model.md](data-model.md), [contracts/ui-contract.md](contracts/ui-contract.md), [quickstart.md](quickstart.md)

**Tests**: REQUIRED (constitution III).
- **Order**: in every phase the test tasks come first. Run them and **see them fail** before that phase's implementation tasks start. A test is written in the phase (PR) whose code makes it pass. No test is `.disabled` to wait for a later PR.
- **Naming**: every acceptance scenario has at least one test whose name starts with its ID (`"US2 s4 …"`). Plan-level tests use `"SC-00n …"`, `"FR-0nn …"` or `"Edge: …"`. Scenarios that only a real watch can check (US3 s8, US6 s4, SC-007) are **device checks** owned by Denys and listed in the PR.
- **ITF IDs**: rule-driven tests carry `// ITF: <ID>` from `docs/rules/itf-notes.md`.
- **No vacuous tests**: when a stub (an empty model, a no-op command) would already satisfy an assertion, add a positive control that fails against it.
- **Expectation changes**: changing an expectation after its code exists goes in `specs/002-watch-match/test-expectation-changes.md` (`docs/harness.md`).

**Organization (Denys, 2026-10-13: one small PR per screen)**. Phases follow the five PRs of [plan.md § Delivery](plan.md#delivery-one-small-pr-per-screen), not one phase per story:

| Phase | PR | Stories |
| --- | --- | --- |
| 1–3 | PR 1, setup screens | US1 (+ US7 for its screens) |
| 4 | PR 2, Score with haptics | US2 and US3, both P1 (+ US7) |
| 5 | PR 3, Controls | US4 (+ US7) |
| 6 | PR 4, Summary | US5 (+ US7) |
| 7 | PR 5, Always On | US6, final US7 audit |

US7 (accessibility and languages) is cross-cutting: each PR meets it for its own screens, so its tasks are labelled `[US7]` inside each phase.

**Paths**:
- `App/` means `TennisBeat/TennisBeat Watch App/`.
- `UnitTests/` means `TennisBeat/TennisBeat Watch AppTests/`.
- `UITests/` means `TennisBeat/TennisBeat Watch AppUITests/`.

**How to run**:
- Unit tests: XcodeBuildMCP `test_sim` with scheme `TennisBeat Watch App` on the 40 mm watch simulator, `-only-testing:"TennisBeat Watch AppTests"`.
- UI tests: the same with `TennisBeat Watch AppUITests`.
- Engine: `swift test --package-path Packages/TennisCore` (it must stay green; `TennisCore` is not changed).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can run in parallel (different files, no dependency on an incomplete task)
- **[Story]**: the user story the task belongs to
- **Owner**: the agent, unless a task says **Owner: Denys**

## Per-PR checklist (applies to every PR phase; listed once here, referenced as "PR checklist")

1. **Start**: create a worktree `.worktrees/002-<screen>` on branch `feat/002-<screen>` from the latest `origin/main`, with `.specify/feature.json` → `specs/002-watch-match`. Run `scripts/gates/check-artifacts.sh specs/002-watch-match` and STOP if it fails.
2. **Tests**: write the tests first, run them and see them fail.
3. **Code**: implement until they pass. Run the full watch unit and UI suites, plus the engine tests.
4. **Build and run**: build both schemes (`TennisBeat`, `TennisBeat Watch App`). Run the PR's flow on the 40 mm simulator in EN, PL and UK, at the largest standard text size and at an accessibility size. Attach the screenshots to the PR.
5. **Gates**: run `scripts/gates/check-project-format.sh` and `scripts/gates/check-infoplist-strings.sh`.
6. **Metrics**: append the metrics row for the previous merged PR to `docs/harness.md`.
7. **Review**: invoke the `reviewer` subagent with only `specs/002-watch-match` and `main`. Post the report as a PR comment (R<n>-<m> findings and their outcomes). Open the PR with `Reviewed-SHA: <head>`, plus device checks for Denys.

---

## Phase 1: Setup (PR 1)

**Purpose**: Catalog, design tokens, CI and test support. No screen yet.

- [X] T001 PR checklist step 1 for PR 1: worktree `.worktrees/002-setup`, branch `feat/002-setup`.
- [X] T002 Add a `watch-tests` job to `.github/workflows/ci.yml` (research R12):
  - `runs-on: macos-26`, the same "Select newest Xcode" step as `app-builds`;
  - pick the 40 mm watchOS simulator (the layout target, Q9) with `xcrun simctl list devices available -j`, or the first available watchOS simulator if the image has none (R1-6 of #18);
  - `timeout-minutes: 45`;
  - run `xcodebuild test -project TennisBeat/TennisBeat.xcodeproj -scheme "TennisBeat Watch App" -destination "platform=watchOS Simulator,id=<udid>" CODE_SIGNING_ALLOWED=NO`.

  If no watchOS runtime exists on the image, run `xcodebuild build-for-testing` with a generic destination instead, and record this in the PR body for Denys (R12 fallback). Do not add the job to the required checks: that is Denys's ruleset.
- [X] T003 [P] Create `App/Localizable.xcstrings`: source language `en`, with `pl` and `uk` localizations, empty for now (research R11). Confirm that `knownRegions` in `project.pbxproj` already lists `en`, `pl` and `uk`, and leave the project file unchanged.
- [X] T004 [P] Create `App/DesignSystem/Colors.swift`: one `Color` per `watch/*`, `brand/*` and `status/*` token in `docs/design/tokens.json`, with the exact hex and alpha values (for example `watch/zone-me` `#DFFF4F29`). Use names like `Color.brandBall` and `Color.watchZoneMe`.
- [X] T005 [P] Create `App/DesignSystem/Typography.swift`: `Font` helpers for `Watch/Large Title`, `Title`, `Headline`, `Body`, `Footnote`, `Label`, `Caption`, `Score` and `Number` (`docs/design/typography.md`). Build them on SwiftUI text styles so Dynamic Type works, and use `.rounded` with monospaced digits for `Score` and `Number`.
- [X] T006 [P] Create the test support in `UnitTests/Support/`:
  - `FakeClock.swift`: a settable `now`, with `advance(by:)`;
  - `RecordingHaptics.swift` and `RecordingAnnouncer.swift`: record calls in order;
  - `MatchScript.swift`: builds a TennisCore `Match` from a format, a first server and a string like `"MMOM"` (M = Me, O = Opponent), with helpers `games(_:)` and `set(_:)` (the same idea as 001's `MatchBuilder`).
- [X] T007 Remove the template test `UnitTests/TennisBeat_Watch_AppTests.swift` and the template UI tests in `UITests/` once the first real tests exist (T011 and T015).

---

## Phase 2: Foundational (PR 1)

**Purpose**: The session skeleton and the root view that every screen needs.

- [X] T008 Create `App/Match/LaunchOptions.swift` (`#if DEBUG` only):
  - parse `-resetFormat`, `-coinToss me|opponent` and `-uiTestExposeValues` (used from PR 2) from `ProcessInfo.processInfo.arguments` (contract §2);
  - in a Release build, return the production defaults.
- [X] T009 Create `App/Match/MatchSession.swift`: an `@Observable` main-actor class with `route: Route` (`.setup`, `.playing`, `.summary`), `match: Match?`, `clock: MatchClock?`, `isPaused`, and the injected `haptics`, `announcer` and `now`. The commands are stubs that change nothing. In this PR only `start(firstServer:)` gets a body (T019). Follow [data-model.md § MatchSession](data-model.md#matchsession-observable-main-actor) exactly.
- [X] T010 Replace `App/ContentView.swift` with `RootView`, which switches on `session.route`:
  - `.setup` → `NewMatchView` in a `NavigationStack`;
  - `.playing` → a placeholder `Text` with the identifier `score.placeholder`, removed in PR 2;
  - `.summary` → `EmptyView`.

  Update `App/TennisBeatApp.swift` to create one `MatchSession` with the production feedback types (stubs until PR 2) and `Date.init` as `now`.

**Checkpoint**: both schemes build; the app launches to an empty New match.

---

## Phase 3: User Story 1 — Set up and start a match (P1, PR 1) 🎯 MVP start

**Goal**: New match with four rows, pickers, the remembered format, First server and the coin toss, ending on the (placeholder) score route.

**Independent Test**: Change each setting, start, choose a first server, and check that the session holds a 0–0 match with that format and first server. Relaunch and check that the last choices are preselected.

### Tests (write first, see them fail)

- [X] T011 [P] [US1] `UnitTests/FormatChoiceTests.swift`:
  - US1 s1: with no stored value, the defaults are best of 3, 6 games, Advantage, Full set (Q2);
  - US1 s3: `isThirdSetVisible` is false for 1 set, and `thirdSet` is kept;
  - US1 s5: save then load round-trips all four rows, and nothing about the first server is stored;
  - US1 s6: each unknown or missing raw value falls back to its own default while the other rows keep theirs (parameterized over the four rows);
  - FR-002: `matchFormat` for 1 set with `thirdSet == .tieBreakToTen` has `matchTieBreak == false`; `// ITF: MT-02`;
  - US1 s6: `matchFormat` is non-nil for all 24 combinations; with a `MatchSession` whose injected `makeFormat` returns nil, `start` keeps `route == .setup` and `match == nil` (no `try!`, no trap);
  - FR-001: every one of the 2×3×2×2 combinations builds a `MatchFormat` with the expected fields; `// ITF: MT-01, MT-03, ST-04, ST-06, ST-07, GM-02, NA-01`.

  Use a throwaway `UserDefaults(suiteName:)` for each test.
- [X] T012 [P] [US1] `UnitTests/CoinTossTests.swift`:
  - US1 s9: an injected toss of `.opponent` starts the match with the Opponent as first server;
  - FR-003: 10,000 tosses through the production `CoinToss.toss(using:)` with a seeded generator give `.me` in 50% ± 2%; `// ITF: SV-01`.
- [X] T013 [P] [US1] `UnitTests/SessionTests.swift`, setup part:
  - US1 s8: `start(firstServer: .me)` → `route == .playing`, the match has one `.setup` event with the chosen format and first server, the state is 0–0 with `server == .me` and `courtSide == .right`, and the clock started at `now`; `// ITF: SV-01, SV-03`;
  - US1 s5: `start` stores the format;
  - US1 s10: no match exists before `start` (the back navigation itself is checked in the UI test).
- [X] T014 [P] [US7] `UnitTests/StringCatalogTests.swift`:
  - SC-006: load the source catalog `App/Localizable.xcstrings` as JSON, from a path relative to `#filePath` (the simulator can read host paths);
  - fail on any key without a `pl` or `uk` value, or with a plural variation missing a category its language needs (`one`, `few`, `many`, `other` for PL and UK).
- [X] T015 [P] [US1] `UITests/SetupFlowUITests.swift` (launch with `-resetFormat`), using the identifiers from contract §1:
  - US1 s1 and s2: four rows with captions and values;
  - US1 s3: set Format to 1 set, the Third set row is gone; back to best of 3, it returns with "Tie-break to 10" when that was chosen before;
  - US1 s4: tapping a row shows a picker with the current value selected, and picking returns with the row updated;
  - US1 s5: start a match, relaunch without `-resetFormat`, and the format is preselected;
  - US1 s7: Start shows "Who serves first?" with three buttons;
  - US1 s8: Me → `score.placeholder` exists;
  - US1 s9: launch with `-coinToss opponent` → Coin toss → the result reads "First server: Opponent" → Start → `score.placeholder`;
  - US1 s10: back from First server returns to New match unchanged; back from the result returns to First server;
  - US7 s7 (other language): launch with `-AppleLanguages (de)`, and New match shows the EN strings ("New match", "Start").
- [X] T016 [P] [US7] `UITests/SetupAccessibilityUITests.swift`:
  - US7 s5: each row's accessibility label and value read like "Set length, 6 games";
  - SC-005: `XCUIApplication().performAccessibilityAudit()` passes on New match, the picker, First server and the coin-toss result.

### Implementation

- [X] T017 [P] [US1] `App/Match/FormatChoice.swift`: `FormatChoice` and `FormatStore`, as in [data-model.md § FormatChoice](data-model.md#formatchoice-stored):
  - key `lastFormat.v1`, a dictionary of four raw strings;
  - per-row fallback to the defaults "best of 3, sets of 6, Advantage, third set as a full set";
  - `matchTieBreak = length == .bestOfThree && thirdSet == .tieBreakToTen`.
- [X] T018 [P] [US1] `App/Match/CoinToss.swift`: `CoinToss.toss(using: inout some RandomNumberGenerator) -> Player` (`Bool.random(using:)` → Me or Opponent); production passes `SystemRandomNumberGenerator`; the `-coinToss` override from `LaunchOptions` bypasses it.
- [X] T019 [US1] `MatchSession.start(firstServer:)`:
  - `Match(setup: MatchSetup(format: formatChoice.matchFormat, firstServer:))`;
  - save the format;
  - `clock = MatchClock(startedAt: now())`; this creates `App/Match/MatchClock.swift` with `startedAt` and `elapsed(at:)` only; pause and stop come in PR 2 and PR 3;
  - `route = .playing`.

  Also `formatChoice` loading on init, honouring `-resetFormat`.
- [X] T020 [US1] `App/Setup/NewMatchView.swift` (Watch 1, with the Set length row second, Q1):
  - a `ScrollView` with the title and the setting rows (caption in Footnote/secondary, value in Title, on `watch/surface`, radius 16);
  - the Third set row only when `isThirdSetVisible`;
  - a capsule Start button (`brand/ball`) that pushes First server;
  - each row is a button with an accessibility label (caption) and value (current value).
- [X] T021 [P] [US1] `App/Setup/OptionPickerView.swift`: a list of options with a checkmark on the current one. Picking sets the value and pops. Identifiers `picker.option.<rawValue>`.
- [X] T022 [US1] `App/Setup/FirstServerView.swift` (Watch 2): the title "Who serves first?" and three 52 pt capsule buttons (Me `brand/ball`, Opponent `watch/button-opponent`, Coin toss `watch/surface`). Me and Opponent call `session.start`. Coin toss pushes `CoinTossResultView` with a new toss each time.
- [X] T023 [US1] `App/Setup/CoinTossResultView.swift`: "First server: %@" and a Start button that calls `session.start(firstServer: result)` (Q3, R1-12).
- [X] T024 [US7] Add the EN, PL and UK strings for New match, the pickers, First server and the coin toss to `App/Localizable.xcstrings`, exactly as the spec's copy table, with semantic keys (R11):
  - `setup.title`, `setup.format.caption`, `setup.format.oneSet`, `setup.format.bestOfThree`;
  - `setup.setLength.caption`, `setup.setLength.value` with plural variations "%d games" / «%d gemów» / «%d геймів»;
  - `setup.atFortyAll.*`, `setup.thirdSet.*`, `setup.start`;
  - `firstServer.title`, `player.me`, `player.opponent`, `firstServer.coinToss`, `coinToss.result`.
- [X] T025 [US1] Update `docs/design/screens/watch-1-new-match.md`: add the "Set length" row as the second row, with EN, PL and UK texts and a note "added by spec 002 Q1" (R1-9).
- [ ] T026 [US1] PR checklist steps 3–7 for PR 1. Screenshots: New match (defaults and 1 set), a picker, First server, the coin-toss result, each in EN, PL and UK at the largest standard and an accessibility size on 40 mm. Device checks for Denys: SC-001 (two taps from launch to the score route). Metrics row for the 002 plan PR (its number is in `git log` on `main`).

**Checkpoint (PR 1 merged)**: a match can be set up and started; US1 is fully covered.

---

## Phase 4: User Stories 2 and 3 — Score points and feel the score (P1, PR 2) 🎯 MVP

**Goal**: The score screen with tap zones, the display, the status line, the header with Undo and elapsed time, haptics and announcements. A won match goes to a minimal summary (title + Done) until PR 4.

**Independent Test**: Tap known sequences in every format and compare every displayed value with the engine. Unit-test the outcome function and the haptics requested after each tap and undo.

### Tests (write first, see them fail)

- [X] T027 PR checklist step 1 for PR 2: worktree `.worktrees/002-score`, branch `feat/002-score`.
- [X] T028 [P] [US3] `UnitTests/PointOutcomeTests.swift` (FR-010, FR-011, research R2). Build the states with `MatchScript`:
  - US3 s4: a point that wins no game → `.point`;
  - US3 s1: a game won, not the set → `.game`, in an Advantage game and in a No-Ad deciding point; `// ITF: GM-02, NA-01`;
  - US3 s2: a set won 6–4, and a set won in a 7–6 tie-break → `.set`; `// ITF: ST-03, ST-07, TB-01`;
  - US3 s3: the match won in a set, and in a match tie-break 10–8 → `.match`; `// ITF: MT-03`;
  - US3 s5, change of ends (each case built with the engine):
    - games 1 and 3 of a set → `.game` + change (`// ITF: EN-01`);
    - a 6–3 set won → `.set` + change (`// ITF: EN-02`);
    - a 6–4 set won → `.set`, no change; then game 1 of the next set → `.game` + change (`// ITF: EN-02, EN-01`);
    - a 7–6 tie-break set won → `.set` + change (`// ITF: EN-03`);
    - in a match-tie-break format, set 2 won with an odd total → `.set` + change; with an even total → `.set`, no change (`// ITF: EN-04`);
    - the 6th point of a set tie-break and of a match tie-break that doesn't end it → `.point` + change (`// ITF: TB-05`);
  - US3 s6: the match-winning point never has `changeOfEnds`, checked on engine-built matches where EN-01, EN-02 or TB-05 would otherwise apply (a match won 6–3 on an odd game; a match tie-break won 10–8 on the 18th point); `// ITF: EN-05`;
  - positive control: a 6–5 game is `.game`, not `.set`.
- [X] T029 [P] [US3] `UnitTests/PointOutcomePropertyTests.swift`, `"FR-010 property …"`: over 500 seeded random matches in every format (SplitMix64 copied from 001's test support into `UnitTests/Support/`), each added point gives exactly one level, and the level agrees with the change in `status`, `completedSets.count` and the games total.
- [X] T030 [P] [US3] `UnitTests/SessionFeedbackTests.swift` (SC-003, FR-012, FR-024), with `RecordingHaptics` and `RecordingAnnouncer`, as in contract §4:
  - US3 s1–s5: the haptic sequence per added point, with change of ends after the point's haptic, including set + change of ends (a 6–3 set: set haptic, then change of ends; `// ITF: EN-02`);
  - US3 s7: undo of a game-winning point and undo that brings back a state whose `changeOfEnds` reads true record **no** haptic (undo from `.summary` is tested in PR 4, T061);
  - Edge "change of ends on a game-winning point that is undone and played again": the haptic plays again;
  - FR-012 (pending haptic): undo calls `cancelPending()` first, and an added point calls `flushPending()` (never `cancelPending()`). `WatchHaptics` with an injected sink and a hand-driven `sleep`: a change-of-ends point, then `undo()` before the sleep returns → the sink receives only the point's haptic; a change-of-ends point, then another point before the sleep returns → the sink receives point 1's haptic, change of ends, point 2's haptic, in that order; positive control: without a later command the change-of-ends haptic arrives after the sleep;
  - R4: each command yields at most one announcement, for example a change-of-ends game point → exactly one "Game: Me. Change ends";
  - US7 s3: announcements "Game: Me", "Set: Opponent", "Match: Me";
  - US7 s4: "Change ends" after a change-of-ends point;
  - US7 s2: the status text is announced when it changes ("Deuce");
  - FR-013: `WatchHaptics`' mapping gives four different `WKHapticType` values for game, set, match and change of ends (test the pure mapping function, not the device call).

  Pause, resume, correction and early end are added in PR 3.
- [X] T031 [P] [US2] `UnitTests/ScoreScreenModelTests.swift`:
  - US2 s4: points 0/15/30/40/AD and tie-break numbers, games, and sets counted from `completedSets`; "0" never "love"; `// ITF: GM-01, GM-02, TB-01`;
  - US2 s5: only the server has `isServer` and a `courtSide`;
  - US2 s6: Right / Left in EN, PL and UK; the model is built with `Locale(identifier: "pl")` / `"uk"` and resolves strings through `LocalizedStringResource` with that `locale` (research R11); positive control: the PL and UK texts differ from EN; `// ITF: SV-03, TB-04`;
  - US2 s7: Choice on the deciding point, and VoiceOver "Receiver chooses the side"; `// ITF: NA-02`;
  - US2 s8: the status text is exactly one of Deuce / Deciding point / Tie-break / Match tie-break, and empty otherwise; a match tie-break shows only "Match tie-break"; `// ITF: GM-02, NA-01, TB-01, MT-03`;
  - US2 s9: Advantage → empty status.
- [X] T032 [P] [US7] `UnitTests/ScoreAccessibilityTests.swift`:
  - US7 s1: the summary reads the server's score first, with separate Me and Opponent strings (R2-1): "30–15, I'm serving, from the right", "15–30, Opponent serving, from the left", "advantage" for AD, and "…, receiver chooses the side" on the deciding point; `// ITF: GM-01`;
  - the zone label "Me, 30. 3 games, 1 set. Serving from the right." with the hint "Add point for Me";
  - plural forms for games and sets in PL and UK (1, 2, 5, 22);
  - US7 s8 (score): the server is marked by `isServer` (serve icon) **and** by the VoiceOver phrase "serving"/«подаю»/«serwuję»; Me and Opponent differ by label text and position (`zones` order Opponent, Me), not only colour;
  - US7 s2: at deuce the summary label ends with ". Deuce"; while paused it ends with ". Paused. Deuce"; with an empty status it has no trailing status; the status line is hidden from VoiceOver.
- [X] T033 [P] [US2] `UnitTests/SessionTests.swift`, scoring part:
  - US2 s2: `addPoint(for: .me)` adds exactly one point event for Me;
  - Edge "Language changes during a match": rebuilding `ScoreScreenModel` with another `Locale` changes only the strings, and the match is unaffected;
  - US2 s3: after the match is won, `addPoint` adds nothing and requests no haptic; `// ITF: MT-08`;
  - Edge "very fast taps": two calls add two points in order;
  - US2 s11: after any sequence of `addPoint` and `undo`, `ScoreScreenModel(state:)` equals the model built from `Match(events:)` with the same events;
  - US4 s2 (header Undo part): `undo()` removes the last event;
  - US4 s3: `canUndo` is false with only the setup;
  - US4 s4: undo across a game, a set and a match tie-break boundary returns the previous point score, server and court side; `// ITF: SV-02, TB-02`;
  - a won match → `route == .summary`, and the clock is stopped.
- [X] T034 [P] [US2] `UnitTests/MatchClockTests.swift`, start and stop part: `elapsed` grows with the fake clock, stays fixed after `stop`, and is never negative. Also FR-022: a 10-minute gap in `now` (the app in the background) counts in full.
- [X] T035 [P] [US7] `UITests/ScoreAccessibilityUITests.swift`:
  - FR-025 / Q9: launch once at `.xxxLarge` (`-UIPreferredContentSizeCategoryName UICTContentSizeCategoryXXXL`) and once at `UICTContentSizeCategoryAccessibilityXXXL`; the `zone.me.points` frames are equal (the score screen keeps the largest standard size);
  - SC-005: `performAccessibilityAudit()` on Score, including the `.textClipped` audit type, at both sizes.
- [X] T036 [US2] Link the `TennisCore` product to the `TennisBeat Watch AppUITests` target with the Xcode MCP tools, not by hand-editing. Then run `scripts/gates/check-project-format.sh` and confirm no `validationLevel` and `objectVersion = 100` (research R12).
- [X] T037 [US2] `UITests/Support/ScreenReader.swift`: with the app launched with `-uiTestExposeValues`, find elements with `descendants(matching: .any)[id]`, read `zone.<player>.points/.games/.sets/.serve/.side` into a struct, and check the status exactly: the `score.summary` label must equal `expectedSummary + (status.isEmpty ? "" : ". " + status)` (research R7, R3-1; the drawn status line is covered by unit tests only). Also map a TennisCore `MatchState` to the same struct with the contract §3 table: EN texts, Right/Left/Choice, and status priority.
- [X] T038 [US2] `UITests/ScoringUITests.swift`, SC-002, launched with `-uiTestExposeValues`. First a failing guard test: without the argument `zone.me.points` is not found, and with it it is found (checks the R3-1 switch both ways); it also asserts the element type of `zone.me` in each mode, found with `descendants(matching: .any)`. Then run scripted sequences of 40–120 taps for each format:
  - 1 set ×4, ×6, ×8;
  - best of 3 with a full third set;
  - best of 3 with a match tie-break;
  - each in Advantage and in No-Ad.

  After every tap and every header Undo (every 7th step), the screen equals the mapped state of a `Match` replayed in the test. Also check US2 s1: the two zones have equal heights (±1 pt), span the full width, and sit Opponent on top. And US2 s10: the header shows `undo` and an `elapsed` value matching `^(\d{1,2}:)?\d{1,2}:\d{2}$`, and no heart-rate element exists. `// ITF: GM-01, GM-02, NA-01, NA-02, TB-01, TB-04, MT-03`.

### Implementation

- [X] T039 [P] [US3] `App/Match/PointOutcome.swift`: `nonisolated struct PointOutcome { winner, level, changeOfEnds }` and `static func evaluate(before:after:winner:)`, exactly as [data-model.md § PointOutcome](data-model.md#pointoutcome-value-pure).
- [X] T040 [P] [US3] `App/Match/Feedback.swift`:
  - the `HapticPlaying` and `Announcing` protocols;
  - `WatchHaptics`: point `.click`, game `.directionUp`, set `.success`, match `.notification`, change of ends `.retry`, played 0.8 s after the first on a stored, cancellable `Task`, with the injected sink and `sleep`; `cancelPending()` cancels it and `flushPending()` plays it at once (research R3);
  - `VoiceOverAnnouncer`: posts one `AccessibilityNotification.Announcement` per command with `.high` announcement priority (research R4).
- [X] T041 [US2] `MatchClock.stop(at:)`, and `MatchSession`:
  - `addPoint(for:)`: guard `acceptsPoints`; keep the state before; `recordPoint(wonBy:at: now())`; on an error, return; evaluate the outcome → haptics → announcements; when `.won`, `clock.stop` and `route = .summary`;
  - `undo()` for `.playing`;
  - `addPoint` calls `haptics.flushPending()` and `undo()` calls `haptics.cancelPending()` first; every command posts at most one combined announcement (data model).
- [X] T042 [P] [US2] `App/Match/ScoreScreenModel.swift`: as [data-model.md § ScoreScreenModel](data-model.md#scorescreenmodel-value-pure). All strings come from the catalog, with separate Me and Opponent summary keys (R2-1).
- [X] T043 [US2] `App/Score/ScoreView.swift`, `App/Score/PlayerZoneView.swift` and `App/Score/ElapsedTimeView.swift` (Watch 3):
  - the header: a 44 pt Undo circle (disabled and announced unavailable when `!canUndo`), and the elapsed time in `TimelineView(.periodic(from:by: 1))` with `.minuteSecond` or `.hourMinuteSecond` and monospaced digits;
  - the status line;
  - the VoiceOver summary element first;
  - two equal-height zone `Button`s with a plain style over the full width and half the remaining height (FR-026), radius 24, colours from the tokens;
  - the serve icon (tennis-ball glyph) and the court-side pill only for the server;
  - `.dynamicTypeSize(...DynamicTypeSize.xxxLarge)` on the screen (Q9);
  - point displays up to 2 digits fit with `.minimumScaleFactor` (Edge "long tie-breaks");
  - the identifiers from contract §1;
  - `-uiTestExposeValues` (DEBUG only, `LaunchOptions`) switches the zones from `.accessibilityElement(children: .ignore)` to `.contain`; the status line is `.accessibilityHidden(true)` in both modes (research R7, R3-1).
- [X] T044 [US2] `App/Score/MatchPagesView.swift`: `TabView(.page)` with a placeholder Controls page (filled in PR 3) and `ScoreView`, opening on Score. Replace the `.playing` placeholder in `RootView`. For `.summary`, add a minimal `App/Summary/SummaryView.swift` with the title Win / Loss and Done → `session.done()` (finished in PR 4). Implement `done()`.
- [X] T045 [US7] Add the strings for this PR to `App/Localizable.xcstrings`:
  - the status line and the court-side pill;
  - "AD", and VoiceOver "advantage";
  - the score summary with **separate** `score.summary.me.right/left/choice` and `score.summary.opponent.right/left/choice` keys (R2-1 texts);
  - the zone sentence with games and sets plurals, the zone hint;
  - the announcements and "Change ends";
  - Win / Loss / Done.

  Use the spec's copy table exactly.
- [X] T046 [US2] Update `docs/design/screens/watch-3-score.md` (R1-9): the status line also shows Tie-break, Match tie-break and Paused (FR-008, Q4); the VoiceOver summary element comes first, with the status in it (Story 7 s1, s2, R2-1); the heart-rate row is hidden in 002 (spec 003). Note "changed by spec 002".
- [ ] T047 [US2] PR checklist steps 3–7 for PR 2. Screenshots: 0–0, 30–15 Right, deuce, No-Ad deciding point (Choice), tie-break, match tie-break, "15"-wide tie-break points at the largest size. Device checks for Denys:
  - US3 s8: the four haptics are told apart (R3 mapping, may change after this check);
  - SC-007: a set scored by feel, and Undo after a mis-tap in under 3 s.

**Checkpoint (PR 2 merged)**: a full match can be scored to a result. US2 and US3 are fully covered (US3 s7's pause, resume, correction and early-end cases are added in PR 3).

---

## Phase 5: User Story 4 — Fix mistakes and control the match (P1, PR 3)

**Goal**: The Controls page (Undo, Pause/Resume, Server, End with confirmation) and the Paused state.

**Independent Test**: Use each control during a match and check the engine state, the elapsed time and the screen.

### Tests (write first, see them fail)

- [X] T048 PR checklist step 1 for PR 3: worktree `.worktrees/002-controls`, branch `feat/002-controls`.
- [X] T049 [P] [US4] `UnitTests/MatchClockTests.swift`, pause part:
  - US4 s5 and s6: `pause` freezes `elapsed`, and `resume` continues from the same value;
  - US4 s8: several pauses are all excluded;
  - Edge "Pause, then End": `stop` while paused closes the pause, and the duration excludes it;
  - SC-004: a scripted 30-minute match with 4 pauses of 1–5 minutes and random 5–40 s steps, where `elapsed` at every step differs from (wall time − pauses) by ≤ 1 s.
- [X] T050 [P] [US4] `UnitTests/SessionTests.swift`, controls part:
  - US4 s5: while paused, `acceptsPoints` is false and `addPoint` adds nothing;
  - US2 s3 (ended early): after `endEarly()`, `addPoint` adds nothing and requests no haptic; `// ITF: MT-08`;
  - US4 s7: while paused, `undo` and `correctServer` work and `isPaused` stays true; `endEarly` works and sets `isPaused = false`; `done()` also leaves `isPaused == false`;
  - US2 s11 (extended): the PR 2 equivalence test's random sequences now also contain `correctServer`, `pause` and `resume`, and `ScoreScreenModel` still equals the model built from `Match(events:)` plus `isPaused`;
  - US4 s9: `correctServer()` records `.firstServerCorrected(effectiveFirstServer.other)`, and the score is unchanged while the server and side follow the engine; it also works paused and in a tie-break; `// ITF: CE-02`;
  - US4 s12: `endEarly()` with a point → `.matchEndedEarly`, the clock is stopped, `route == .summary`; `// ITF: MT-08`;
  - US4 s13 and Edge "early end at 0–0 or after only undone points": `endEarly()` with no point event → `match == nil`, `route == .setup`, nothing kept;
  - Edge "Pause during a tie-break" (constitution III boundary test, backlog #6): pause and resume inside a tie-break leave `isTieBreak`, the points, the server and the court side unchanged; `// ITF: TB-02, TB-04`.
- [X] T051 [P] [US4] `UnitTests/SessionFeedbackTests.swift`, controls part:
  - US3 s7: pause, resume, correction and early end record no haptic; pause, correction and early end call `cancelPending()` first (a pending change of ends is dropped);
  - US4 s10 / US7 s3: correction announces "Server: Opponent";
  - FR-008 / R1-3: while paused the status text is "Paused" and VoiceOver reads "Paused. Deuce".
- [X] T052 [P] [US4] `UITests/ControlsUITests.swift` (value checks launched with `-uiTestExposeValues`; the audit without it):
  - US4 s1: swipe right from Score → Controls with `controls.elapsed` and four labelled buttons; swipe back → Score;
  - US4 s2: Undo on Controls removes the last point;
  - US4 s3: Undo is disabled at 0–0;
  - US4 s5 and FR-016: Pause → the `score.summary` label ends with "Paused" (or "Paused. <state>"), the zones add nothing, and the button reads Resume;
  - US4 s6: Resume → taps score again;
  - US4 s9: Server moves `zone.*.serve` and keeps the points;
  - SC-002 (corrections): extend the `ScoringUITests` scripted sequences for every format with a server correction (via Controls) every 11th step, and check that the screen equals the engine replay after each; `// ITF: CE-02`;
  - US4 s11: End → `confirm.end` and Cancel; Cancel changes nothing;
  - US4 s12: confirm with a point → the summary route, and the minimal summary's `summary.title` reads "Match ended early", never Win or Loss (US5 s3); US4 s13: confirm at 0–0 → New match;
  - SC-005: `performAccessibilityAudit()` (including `.textClipped`) on Controls and the End confirmation, at `.xxxLarge` and at an accessibility size;
  - US7 s5 (Controls): each button's accessibility label is Undo / Pause (Resume while paused) / Server / End, and Undo reports `isEnabled == false` at 0–0.

### Implementation

- [X] T053 [US4] `MatchClock.pause(at:)` and `resume(at:)`, with `stop` closing an open pause, as [data-model.md § MatchClock](data-model.md#matchclock-value).
- [X] T054 [US4] `MatchSession.pause()`, `resume()`, `correctServer()` and `endEarly()`, as in the data-model command table. `ScoreScreenModel.statusText` gets "Paused" priority, and the zones dim while paused (Q4). The minimal summary from PR 2 shows "Match ended early" for `.unfinished` (US5 s3), so `main` is right between PR 3 and PR 4 (R3-3).
- [X] T055 [US4] `App/Score/ControlsView.swift` (Watch 4), replacing the placeholder page:
  - `controls.elapsed` at the top;
  - a 2×2 grid of 64 pt round buttons with labels: Undo (`surface-raised`), Pause/Resume (`control-pause`), Server ⇆ (`surface-raised`), End (`control-end`, stop square);
  - End opens `.confirmationDialog("End match?")` with a destructive "End match" button;
  - a `ScrollView` so that large text never clips.
- [X] T056 [US7] Add the strings for this PR to `App/Localizable.xcstrings`: Undo, Pause, Resume, Server, End, "End match?" / "End match", "Paused", "Paused. %@", the "Server: %@" announcement, and "Match ended early" (for the minimal summary) (copy table).
- [X] T057 [US4] Update `docs/design/screens/watch-4-controls.md` (R1-9): the Server control is decided as the first-server correction [ITF: CE-02], not CE-01; Pause shows Resume while paused; End opens the "End match?" confirmation. Note "changed by spec 002".
- [ ] T058 [US4] PR checklist steps 3–7 for PR 3. Screenshots: Controls, Paused at deuce, the End confirmation, in EN, PL and UK. Device checks for Denys: pause and resume on a real watch; the End confirmation is reachable with wet fingers.

**Checkpoint (PR 3 merged)**: US4 is fully covered, along with US3 s7 and SC-004.

---

## Phase 6: User Story 5 — See the result (P2, PR 4)

**Goal**: The full summary: the title, the set chips (with the unfinished chip and the match tie-break chip), the duration, Done and Undo.

**Independent Test**: Finish matches in each format, and end one early, then check the title, the chips, the duration and their VoiceOver labels.

### Tests (write first, see them fail)

- [ ] T059 PR checklist step 1 for PR 4: worktree `.worktrees/002-summary`, branch `feat/002-summary`.
- [ ] T060 [P] [US5] `UnitTests/SummaryModelTests.swift`:
  - US5 s2: Win when Me won, Loss when the Opponent won;
  - US5 s3: "Match ended early", never Win or Loss;
  - US5 s4: chips "6:4", "3:6", a match tie-break "10:7" (`// ITF: MT-05`), and a tie-break set "7:6" (Q11);
  - US5 s5: an early end mid-set gives "3:2*"; mid-match-tie-break gives "7:5*" (`// ITF: MT-05, MT-08`); right after a completed set with no point played, no extra chip; with points played in the first game at 0–0, "0:0*"; in a match-tie-break format, an early end at 1–1 in sets with no match tie-break point played gives no chip (the display is `tieBreak(0)`), and with one point played the chip reads "1:0*" or "0:1*" (`// ITF: MT-05`);
  - US5 s6: `isLost` for the Opponent's sets; VoiceOver "Set 2: 3–6, lost", "Set 3: 4–2, unfinished", and the match tie-break variant "Match tie-break: 10–7, won" (R2-4), in EN, PL and UK;
  - US5 s7: the duration is `clock.elapsed(at: stoppedAt)` formatted `.hourMinuteSecond`;
  - US5 s8: the model has no heart-rate or calorie field (a compile-time shape check in the test);
  - US7 s8 (summary): a lost set is marked by `isLost` (dimmed) **and** by its VoiceOver text ending "lost" / «przegrany» / «програний», and the chips keep set order.
- [ ] T061 [P] [US5] `UnitTests/SessionTests.swift`, summary part:
  - US5 s1: the match-winning point → `.summary`, and the clock is stopped;
  - US5 s9 and Edge "Undo after the match is won": `undo()` from `.summary` → `.playing` at match point, `isPaused == false`, and `elapsed` excludes the summary time; the same for an early end ("Undo of an early end");
  - US5 s10: `done()` → `.setup`, `match == nil`, and the format is kept;
  - US3 s7 (summary part, moved from PR 2): undo of the match point and of an early end from `.summary` record **no** haptic; `// ITF: EN-05`.
- [ ] T062 [P] [US5] `UITests/SummaryUITests.swift`:
  - play a 1-set match to Win with `-coinToss me`: `summary.title` reads "Win", the chips match, and `summary.duration` exists;
  - Undo → Score at match point;
  - End early → "Match ended early" with an "*" chip;
  - Done → New match with the format kept;
  - SC-005: `performAccessibilityAudit()` (including `.textClipped`) on the summary at an accessibility size;
  - US7 s5 (Summary): `summary.done` and `summary.undo` have the labels Done and Undo, and each chip's label is its full VoiceOver sentence.

### Implementation

- [ ] T063 [US5] `MatchClock.reopen(at:)`, and `MatchSession.undo()` from `.summary`: reopen, `isPaused = false`, `.playing`.
- [ ] T064 [P] [US5] `App/Match/SummaryModel.swift`, as [data-model.md § SummaryModel](data-model.md#summarymodel-value-pure).
- [ ] T065 [US5] `App/Summary/SummaryView.swift` (Watch 6), replacing the minimal summary:
  - the title in Large Title `brand/ball`;
  - a chip row on `surface-raised`, with lost sets in `text-tertiary`; each chip is one VoiceOver element; the chips wrap at large sizes;
  - a Duration row;
  - Done (primary capsule) and Undo (secondary, under Done, Q7);
  - in a `ScrollView`, with no heart-rate or kcal rows.
- [ ] T066 [US7] Add the strings for this PR to `App/Localizable.xcstrings` ("Match ended early" exists since PR 3): Duration, Undo (summary), the set-chip VoiceOver strings, and the separate match tie-break chip key (R2-4), from the copy table.
- [ ] T067 [US5] Update `docs/design/screens/watch-6-summary.md`: the secondary Undo button under Done (Q7), the unfinished chip with "*" (Q5), the hidden heart-rate and kcal rows (spec 003). Note "changed by spec 002" (R1-9).
- [ ] T068 [US5] PR checklist steps 3–7 for PR 4. Screenshots: Win, Loss, Match ended early, a match tie-break win, in EN, PL and UK at the largest sizes. Device check for Denys: the summary is readable after a real match.

**Checkpoint (PR 4 merged)**: US5 is fully covered.

---

## Phase 7: User Story 6 — Always On (P2, PR 5), and the final US7 audit

**Goal**: The dimmed score screen as in Watch 5, and the accessibility audit across all screens.

**Independent Test**: Enter the dimmed state in the simulator during a match and compare it with Watch 5.

### Tests (write first, see them fail)

- [ ] T069 PR checklist step 1 for PR 5: worktree `.worktrees/002-always-on`, branch `feat/002-always-on`.
- [ ] T070 [P] [US6] `UnitTests/ScoreScreenModelTests.swift`, dimmed part:
  - US6 s1: the dimmed time text is whole minutes in the abbreviated system format ("42 min", "84 min"; PL and UK via `Locale`), rounded down: 42:59 → "42 min";
  - `ElapsedMinuteSchedule`: with a clock started at T and a 90 s pause, its entries are the dates at which `elapsed` equals 1, 2, 3… whole minutes (± 1 ms);
  - US6 s2: the dimmed model has no seconds, no Undo, no serve icon, no court-side pill and no status (Q8).
- [ ] T071 [P] [US6] `UnitTests/AlwaysOnTests.swift`, US6 s3: `ScoreScreenModel.zonesAcceptTaps(isLuminanceReduced:)` is false when the luminance is reduced, even while `session.acceptsPoints` is true (positive control: true when not reduced). `ScoreView` passes this value to `.allowsHitTesting`.
- [ ] T072 [P] [US7] `UITests/AccessibilityAuditUITests.swift`: the final SC-005 pass across all screens and languages (each earlier PR already audited its own screens in EN). `performAccessibilityAudit()` on every screen (New match, the picker, First server, the coin-toss result, Score, Controls, the End confirmation, Summary) in EN. Then repeat with `-AppleLanguages (pl)` and `(uk)`, and with `-UIPreferredContentSizeCategoryName UICTContentSizeCategoryAccessibilityXXXL`, failing on any clipped-text issue (US7 s6, s7).

### Implementation

- [ ] T073 [US6] `ScoreView` and `ElapsedTimeView` read `isLuminanceReduced`. When it is true:
  - the dimmed fills and the point colours are lower-opacity `brand/opponent` and `brand/ball`, with sets and games in `text-secondary`;
  - the header is minutes-only `Duration.formatted(.units(allowed: [.minutes], width: .abbreviated, fractionalPart: .hide(rounded: .down)))` in a `TimelineView` driven by `ElapsedMinuteSchedule` (research R5);
  - Undo, the serve icon, the pill and the status line are hidden;
  - `.transaction { $0.animation = nil }`;
  - `.allowsHitTesting(model.zonesAcceptTaps(isLuminanceReduced:))` on the zones, false when dimmed (FR-021, Story 6 s3).
- [ ] T074 [US7] Fix every audit finding from T072 in the screen it concerns. US7 s8 is tested in T032 (score) and T060 (summary); here, check the remaining screens' screenshots for colour-only meaning (First server buttons differ by label and position).
- [ ] T075 [US6] Update `docs/design/screens/watch-5-always-on.md` (R1-9): Q8 also hides the court-side pill and the status line; the header minutes use the system's abbreviated format, with no plural variations (R1-8). Note "changed by spec 002".
- [ ] T076 PR checklist steps 3–7 for PR 5. Screenshots: Always On in EN, PL and UK, next to `docs/design/screens/watch-5-always-on.png`. Device checks for Denys:
  - US6 s4: readable at arm's length (complete only after spec 003, Q10);
  - the harness Dynamic Type check on his watch (Q9);
  - a full match with no iPhone nearby and no network (FR-027).

**Checkpoint (PR 5 merged)**: every story is covered; spec 002 is done.

---

## Dependencies & Execution Order

- **PR order is strict**: PR 1 → PR 2 → PR 3 → PR 4 → PR 5. Each PR starts from `main` after the previous one is merged.
- **Why**:
  - PR 2 needs the session and the route from PR 1;
  - PR 3 needs the score screen and `MatchPagesView`;
  - PR 4 replaces PR 2's minimal summary and needs PR 3's early end;
  - PR 5 renders PR 2's screen.
- **Inside a phase**: the test tasks come first (they may run in parallel, [P]), then the implementation tasks. The models ([P]) come before the views that use them, and the string-catalog and PR-checklist tasks come last.
- T036 (linking `TennisCore` to the UI tests) blocks T037 and T038.

### Parallel examples

- PR 1: T011, T012, T013, T014, T015 and T016 together; then T017, T018 and T021 together.
- PR 2: T028–T035 together; then T039, T040 and T042 together.
- PR 3: T049–T052 together.
- PR 4: T060–T062 together; then T064 alongside T063.

## Implementation strategy

- **MVP** = PR 1 + PR 2: set up a match and score it to a result with haptics. That is the product (US2 "This is the product").
- PR 3 makes the score trustworthy (undo, pause, correction, early end).
- PR 4 and PR 5 complete the P2 stories.
- Stop after any PR: `main` always runs end to end for what is merged.
