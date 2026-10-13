# Implementation Plan: Match on Apple Watch

**Branch**: `feat/002-plan` | **Date**: 2026-10-13 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/002-watch-match/spec.md` (Status: Approved, 2026-10-13, Denys; review 2 decisions R2-1..R2-4 applied in this branch)

## Summary

Build the watch match flow on top of the merged `TennisCore` engine (spec 001):
- **New match** and **First server** (with coin toss);
- the **Score** screen with haptics;
- the **Controls** page;
- the **Summary**;
- the **Always On** rendering.

The watch app computes no tennis logic. A main-actor `MatchSession` owns the engine `Match`, a `MatchClock` and the screen route (research R1, R6). Thin SwiftUI views read pure models built from `MatchState`: `ScoreScreenModel` and `SummaryModel`. The FR-010 outcome function compares the states before and after each added point, and only its result drives haptics and VoiceOver announcements. Haptics and the announcer sit behind protocols so the logic is tested without UI (R2–R4). Elapsed time is wall-clock time minus excluded intervals, with an injected clock (R5).

Tests come first: Swift Testing unit tests for the models, then XCUITest sequences on the watch simulator that compare the screen with an engine replay (SC-002, R12). Delivery is **one small PR per screen** (spec Assumptions, Delivery), each test-first, with screenshots and device checks.

## Technical Context

**Language/Version**: Swift 6 (language mode 6, strict concurrency), app targets with `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` (R13)

**Primary Dependencies**:
- SwiftUI, WatchKit (`WKInterfaceDevice` haptics) and Foundation (`FormatStyle`, `UserDefaults`);
- `TennisCore` (in-repo package, already linked to the watch target).

No new dependency.

**Storage**: `UserDefaults` key `lastFormat.v1`, the last format choice only (FR-004, R9). No match is stored (spec Out of scope).

**Testing**:
- Swift Testing in `TennisBeat Watch AppTests` (models, outcome function, clock, strings);
- XCUITest in `TennisBeat Watch AppUITests` (scripted sequences against a `TennisCore` replay, R12);
- `swift test --package-path Packages/TennisCore`, which stays green and unchanged.

**Target Platform**: watchOS 26. Layout target: 40 mm (Q9). The iOS app is not changed.

**Project Type**: watchOS app (SwiftUI) using a local Swift package

**Performance Goals**:
- A tap updates the screen and starts its haptic within one frame. The engine appends a point in O(1) (001 R2).
- The elapsed-time error is ≤ 1 s over 30 minutes with pauses (SC-004).

**Constraints**:
- No score logic in the app (FR-010).
- No health data, workout session, network, persistence of matches, or iPhone traffic (FR-027).
- Every string in the String Catalog in EN, PL and UK (FR-023).
- Dynamic Type capped at `.xxxLarge` on the score screen only (Q9).
- Full-height tap zones (FR-026).
- Never write `validationLevel` into the project (CLAUDE.md).

**Scale/Scope**:
- 6 screens (Watch 1–6) plus pickers and the coin-toss result.
- 7 user stories, 64 acceptance scenarios, 27 FRs, 7 SCs.
- 5 implementation PRs.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-checked after Phase 1 design.*

| Principle | Status | Evidence |
| --- | --- | --- |
| I. Spec before code | PASS | `spec.md` is `Status: Approved (2026-10-13, Denys)`. The R2-1..R2-4 edits in this branch are Denys's decisions from his PR #15 review, recorded under **Review 2 decisions**; the plan changes no other acceptance criterion. The artifact gate runs after `/speckit-tasks`. |
| II. Tennis rules are the source of truth | PASS | The app doesn't compute rules; the engine does. Tests that check rule-driven behaviour (outcome levels, change of ends, displays, status line) cite ITF IDs (`// ITF: EN-05`). No Conflict: every rule used is a 001 rule. |
| III. Test first | PASS | Each PR's tasks start with failing unit tests, then UI tests, then code. Boundary tests: undo across game, set and match boundaries on screen (PR 2), undo from the summary (PR 4), **pause during a tie-break** (PR 3, constitution III, backlog #6). Crash recovery is out of scope (later spec). |
| IV. Evidence bound to a commit | PASS | Every PR carries `Reviewed-SHA`. The new CI job `watch-tests` runs the watch tests on every push (R12). |
| V. Independent review | PASS | The `reviewer` subagent gets only `specs/002-watch-match` and the base branch for every PR. |
| VI. One writer per worktree | PASS | This plan is in `.worktrees/002-plan`; each screen PR gets its own worktree and branch `feat/002-<screen>`. |
| VII. Green tests ≠ accepted build | PASS | Every screen PR lists device checks for Denys ([quickstart](quickstart.md) §5). |
| VIII. AI never invents numbers | PASS (N/A) | No generated text. Every number shown comes from the engine or the clock. |
| IX. Privacy by default | PASS | No dependency, network, analytics or health data; one `UserDefaults` value with no personal data (FR-027). Works without the iPhone. |
| X. Three languages | PASS | One `Localizable.xcstrings` with EN, PL and UK, semantic keys, plural variations, `FormatStyle` for time (R11). A unit test fails on any missing translation (SC-006). |
| XI. Accessibility and HIG | PASS | VoiceOver summary and zone elements (Story 7), Dynamic Type limits (Q9), full-height zones, a confirmed End, Always On rendering (R7, R8). No colour-only meaning: icons, labels, order, VoiceOver. |
| XII. Honest metrics | PASS | This PR adds the metrics row for #15; each screen PR adds the row for the previous one. |

**Post-design re-check (after Phase 1)**: PASS, no new violations.
- The CI job `watch-tests` and linking `TennisCore` to the UI test target are build changes, not dependencies.
- The pbxproj change is checked by `check-project-format.sh`.
- No type is added to `TennisCore` (FR-010: spec 001 is unchanged).

## Project Structure

### Documentation (this feature)

```text
specs/002-watch-match/
├── spec.md              # Approved spec (+ review 2 decisions)
├── plan.md              # This file
├── research.md          # Phase 0: decisions R1–R14
├── data-model.md        # Phase 1: FormatChoice, MatchClock, MatchSession, PointOutcome, screen models
├── quickstart.md        # Phase 1: validation guide
├── contracts/
│   └── ui-contract.md   # identifiers, launch arguments, displayed values, feedback per command
├── checklists/requirements.md
└── tasks.md             # Phase 2 (/speckit-tasks)
```

### Source Code (repository root)

```text
TennisBeat/TennisBeat Watch App/
├── TennisBeatApp.swift              # creates MatchSession, injects production haptics/announcer
├── ContentView.swift                # → RootView (route switch); placeholder removed
├── Localizable.xcstrings            # EN/PL/UK, semantic keys (R11)
├── Match/
│   ├── FormatChoice.swift           # + FormatStore (UserDefaults, per-row fallback)
│   ├── CoinToss.swift
│   ├── MatchClock.swift
│   ├── MatchSession.swift           # route, commands, feedback dispatch
│   ├── PointOutcome.swift           # FR-010 pure function
│   ├── Feedback.swift               # HapticPlaying, Announcing + WatchKit / AccessibilityNotification impls
│   ├── ScoreScreenModel.swift
│   ├── SummaryModel.swift
│   └── LaunchOptions.swift          # DEBUG-only UI-test arguments
├── Setup/
│   ├── NewMatchView.swift           # Watch 1
│   ├── OptionPickerView.swift
│   ├── FirstServerView.swift        # Watch 2
│   └── CoinTossResultView.swift
├── Score/
│   ├── MatchPagesView.swift         # TabView(.page): Controls | Score
│   ├── ScoreView.swift              # Watch 3 + Always On rendering (Watch 5)
│   ├── PlayerZoneView.swift
│   ├── ElapsedTimeView.swift        # TimelineView; seconds / minutes in AOD
│   └── ControlsView.swift           # Watch 4
├── Summary/
│   └── SummaryView.swift            # Watch 6
└── DesignSystem/
    ├── Colors.swift                 # tokens.json → Color
    └── Typography.swift             # Watch/* text styles

TennisBeat/TennisBeat Watch AppTests/
├── Support/                         # fakes: RecordingHaptics, RecordingAnnouncer, FakeClock; MatchScript DSL
├── FormatChoiceTests.swift          # Story 1 s1–s6, FR-001, FR-002, FR-004
├── CoinTossTests.swift              # FR-003
├── PointOutcomeTests.swift          # FR-010..FR-012, Story 3
├── SessionTests.swift               # routes, commands, Story 4, edge cases
├── SessionFeedbackTests.swift       # SC-003, FR-024 announcements
├── MatchClockTests.swift            # FR-022, SC-004
├── ScoreScreenModelTests.swift      # Story 2, Story 7 s1–s2
├── SummaryModelTests.swift          # Story 5
└── StringCatalogTests.swift         # SC-006

TennisBeat/TennisBeat Watch AppUITests/
├── Support/ScreenReader.swift       # identifiers → values; engine replay helper
├── SetupFlowUITests.swift           # Story 1
├── ScoringUITests.swift             # SC-002 sequences per format
├── ControlsUITests.swift            # Story 4
└── SummaryUITests.swift             # Story 5

.github/workflows/ci.yml             # + watch-tests job (R12)
docs/design/screens/watch-1-new-match.md, watch-6-summary.md  # Q1 row, Q7 Undo (R1-9)
docs/harness.md                      # metrics rows
```

**Structure Decision**: All new code is in the watch app target and its two test targets; the folders are synchronized, so new files join the targets. `TennisCore` and the iOS app are not changed. The one project-file change is linking the `TennisCore` product to `TennisBeat Watch AppUITests` (R12), made in PR 2, which first needs it.

## Delivery: one small PR per screen

Each PR is a separate worktree and branch off `main` after the previous PR is merged. Each one:
- writes failing tests first, then the code;
- builds both app schemes;
- runs the flow on the 40 mm simulator in EN, PL and UK with screenshots;
- lists device checks;
- adds the metrics row for the previous PR;
- runs the reviewer and sets `Reviewed-SHA`.

| PR | Branch | Screens | Stories / FRs | Also in this PR |
| --- | --- | --- | --- | --- |
| 1 | `feat/002-setup` | Watch 1 New match, pickers, Watch 2 First server, coin-toss result | US1; FR-001..FR-004; US7 for these screens | `Localizable.xcstrings`, design tokens and typography, `MatchSession` skeleton (`.setup` → `.playing` route with a placeholder score view), `watch-tests` CI job, `watch-1-new-match.md` gains the Set length row (Q1) |
| 2 | `feat/002-score` | Watch 3 Score with haptics | US2; US3; FR-005..FR-013, FR-022 (no pause yet), FR-024, FR-026; US7 for Score | `PointOutcome`, feedback protocols, `MatchClock` (start, stop), header Undo, UI-test link to `TennisCore`, SC-002 and SC-003 suites. When the match is won the route goes to `.summary`, which shows a **minimal summary** (title + Done) until PR 4 |
| 3 | `feat/002-controls` | Watch 4 Controls, End confirmation | US4; FR-014..FR-018; SC-004 | Pause/resume in `MatchClock`, the Paused status (Q4), server correction, End with the 0-point discard, the pause-during-a-tie-break boundary test |
| 4 | `feat/002-summary` | Watch 6 Summary | US5; FR-019, FR-020 | `SummaryModel`, chips incl. unfinished and match tie-break (R1-2, R2-4), Undo from the summary (Q7) with `clock.reopen`, `watch-6-summary.md` gains Undo (Q7) |
| 5 | `feat/002-always-on` | Watch 5 Always On | US6; FR-021 | Dimmed palette, minutes-only header, hidden elements (Q8), no hit testing; the remaining SC-005 audit across all screens and languages |

Why this order: each PR leaves `main` in a working state. PR 1 can start a match; PR 2 can score it to the end; PR 3 adds control; PR 4 completes the result; PR 5 is a rendering mode of PR 2's screen. US7 (accessibility, languages) is not a separate PR: each PR meets it for its own screens.

## Dependencies and open inputs

- **Engine**: spec 001 is merged and provides every value (review 2 confirmed). If an implementation PR finds a gap, it stops and proposes a 001 change to Denys (spec Assumptions).
- **Copy drafts**: the PL drafts and the draft EN/UK rows in the copy table go into the catalog as drafts. A native Polish tennis player's review is still open (glossary status); it doesn't block the PRs.
- **Haptic mapping (R3)**: proposed; confirmed or changed by Denys's device check in PR 2.
- **CI watchOS simulator**: if the `macos-26` runner has no watchOS simulator runtime, PR 1 says so and uses the R12 fallback.
- **Workout session (Q10)**: the Always On and long-match device checks are complete only after spec 003.

## Complexity Tracking

No constitution violations to justify.
