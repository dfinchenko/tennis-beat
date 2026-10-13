# Quickstart: validate the watch match flow (002)

**Spec**: [spec.md](spec.md) | **Plan**: [plan.md](plan.md) | **Contract**: [contracts/ui-contract.md](contracts/ui-contract.md)

## Prerequisites

- Xcode 26 or newer with a watchOS 26 simulator runtime.
- The 40 mm watch simulator (Series 6 / SE size, Q9) and one larger watch simulator.
- `swift test --package-path Packages/TennisCore` passes (the engine is unchanged by this feature).

## 1. Unit tests (models, no UI)

Run the `TennisBeat Watch App` scheme's unit tests with XcodeBuildMCP `test_sim` (or `xcodebuild test -scheme "TennisBeat Watch App" -destination 'platform=watchOS Simulator,name=<40 mm watch>' -only-testing:"TennisBeat Watch AppTests"`).

Expected: all pass, including:
- `PointOutcomeTests`: every level and change-of-ends case (FR-010..FR-012, ITF EN-01..EN-05, TB-05);
- `SessionFeedbackTests`: haptic and announcement sequences (SC-003);
- `MatchClockTests`: the 30-minute scripted match with pauses within 1 s (SC-004);
- `ScoreScreenModelTests`, `SummaryModelTests`, `FormatChoiceTests`, `CoinTossTests`;
- `StringCatalogTests`: no missing PL or UK value (SC-006).

## 2. UI tests (watch simulator)

Run `TennisBeat Watch AppUITests` on the 40 mm simulator. Expected: scripted sequences in every format pass. Every displayed value equals the engine's value after every tap, undo and correction (SC-002). CI runs the same job (`watch-tests`).

## 3. Manual flow in the simulator (screenshots for each PR)

1. Launch with `-resetFormat`. New match shows Best of 3 · 6 games · Advantage · Full set (Q2).
2. Change Format to 1 set: the Third set row disappears. Change it back: it returns with its value.
3. Start → Coin toss → result → Start. The score screen shows 0–0 with the server marked and "Right".
4. Tap points to 40–40: the status line shows "Deuce". Undo once: it clears.
5. Swipe to Controls: Pause. The time stops and "Paused" shows. Taps add nothing. Resume.
6. Server: the serve icon and the pill move, and the score is unchanged. Undo reverts it.
7. End → confirm: the summary shows "Match ended early" with an "*" chip. Undo returns to the score at the same score, not paused.
8. Play out a set: the summary shows the chips and the duration. Done returns to New match with the format kept.
9. Toggle Always On (simulator: lock the screen, or use the Always On preview). Minutes only, no Undo, no serve icon, pill or status line.
10. Repeat steps 1–8 with the simulator language set to Polish and to Ukrainian, at the largest standard text size and at an accessibility size, on the 40 mm simulator.

## 4. Gates

```bash
scripts/gates/check-artifacts.sh specs/002-watch-match
scripts/gates/check-project-format.sh
scripts/gates/check-infoplist-strings.sh
```

## 5. Device checks (Denys, real watch)

Listed in each screen PR. In total:
- the four haptics told apart without looking, and scoring a set by feel (SC-007, Story 3 s8);
- Undo after a mis-tap in under 3 s;
- the score readable in Always On at arm's length (fully checkable only after spec 003, Q10);
- the largest agreed text size on Denys's watch (Q9);
- no iPhone nearby and no network (FR-027).
