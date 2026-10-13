# Data model: Match on Apple Watch (002)

**Date**: 2026-10-13 | **Spec**: [spec.md](spec.md) | **Plan**: [plan.md](plan.md)

The watch app keeps no score logic. Its entities hold the engine `Match` from spec 001 ([public API](../001-scoring-engine/contracts/public-api.md)) and what the engine doesn't model: setup choices, timing, the screen route, and what is shown or read aloud. Engine types are written in `monospace` (`Match`, `MatchState`, `Player`, …). All types below live in `TennisBeat Watch App/Match/` (research R1).

## FormatChoice (stored)

The four New match rows. This is the only data the feature stores (FR-004).

| Field | Values | Default (Q2) | Engine mapping |
| --- | --- | --- | --- |
| `length` | `oneSet`, `bestOfThree` | `bestOfThree` | `MatchLength` |
| `setLength` | `four`, `six`, `eight` | `six` | `SetLength` |
| `atFortyAll` | `advantage`, `decidingPoint` | `advantage` | `GameScoring.advantage` / `.noAd` |
| `thirdSet` | `fullSet`, `tieBreakToTen` | `fullSet` | `matchTieBreak` |

- `matchFormat`: `MatchFormat(length:setLength:gameScoring:matchTieBreak:)`. `matchTieBreak` is `length == .bestOfThree && thirdSet == .tieBreakToTen`, so a 1-set match never has it (FR-002, ITF MT-02) and the init never throws.
- `isThirdSetVisible`: `length == .bestOfThree` (Story 1 s3). `thirdSet` keeps its value while hidden.
- **Storage**: `UserDefaults`, key `lastFormat.v1`, a dictionary of four raw strings. It is written when a match starts (Story 1 s5) and read when New match appears. Each field falls back to its default on its own when it is missing or unknown (Story 1 s6). There is no first-server field (FR-004).

## MatchClock (value)

Elapsed match time (FR-022, research R5). The engine never sees it.

| Field | Type | Meaning |
| --- | --- | --- |
| `startedAt` | `Date` | When the first server was chosen (Story 1 s8) |
| `excluded` | `[DateInterval]` | Closed pauses, and time spent on the summary before an Undo |
| `pausedAt` | `Date?` | Start of the open pause |
| `stoppedAt` | `Date?` | When the match was won or ended early |

| Operation | Precondition | Effect |
| --- | --- | --- |
| `pause(at:)` | running, not paused | `pausedAt = t` |
| `resume(at:)` | paused | append `[pausedAt, t]`, `pausedAt = nil` |
| `stop(at:)` | not stopped | if paused, close the pause at `t`; `stoppedAt = t` |
| `reopen(at:)` | stopped | append `[stoppedAt, t]`, `stoppedAt = nil` (not paused) |
| `elapsed(at:)` | — | `(stoppedAt ?? pausedAt ?? t) − startedAt − Σ excluded` |

`elapsed` never decreases while running, stays fixed while paused or stopped, and is never negative.

## MatchSession (observable, main actor)

The one live match, plus the route. It is created when the app starts and holds no match until First server is answered.

| Field | Type | Meaning |
| --- | --- | --- |
| `route` | `Route` | `.setup`, `.playing`, `.summary` |
| `match` | `Match?` | The engine record (events and state) |
| `clock` | `MatchClock?` | Timing of the current match |
| `isPaused` | `Bool` | Pause state (not an engine event) |
| `formatChoice` | `FormatChoice` | Loaded from the store |
| `haptics` | `HapticPlaying` | Injected (R3) |
| `announcer` | `Announcing` | Injected (R4) |
| `now` | `() -> Date` | Injected clock (R5) |

Derived:
- `acceptsPoints`: `route == .playing && !isPaused && match.state.status == .inProgress` (Story 2 s3, FR-005, FR-016).
- `canUndo`: `match.events.count > 1` (Story 4 s3, FR-015).
- `hasPlayedPoint`: the event list contains at least one `.point` (FR-018).

### Commands and state transitions

| Command | From | Engine call | Then |
| --- | --- | --- | --- |
| `start(firstServer:)` | `.setup` | `Match(setup:)` | store `formatChoice`; `clock = MatchClock(startedAt: now())`; `isPaused = false`; → `.playing` |
| `addPoint(for:)` | `.playing`, `acceptsPoints` | `recordPoint(wonBy:at: now())` | `PointOutcome.evaluate(before:after:winner:)` → haptics and announcements; if `status` is `.won`, `clock.stop`, → `.summary` |
| `undo()` | `.playing` or `.summary`, `canUndo` | `undo()` | if it was `.summary`: `clock.reopen`, `isPaused = false`, → `.playing`; announce a status-line change only; no haptic (Story 3 s7) |
| `pause()` / `resume()` | `.playing`, in progress | none | `clock.pause` / `clock.resume`; toggle `isPaused`; no haptic |
| `correctServer()` | `.playing`, in progress (paused or not) | `correctFirstServer(to: effectiveFirstServer.other)` | announce the new server; no haptic (Story 4 s9, s10) |
| `endEarly()` (after confirmation) | `.playing` | `hasPlayedPoint` ? `endEarly()` : none | with a point: `clock.stop`, → `.summary`. With none: `match = nil`, `clock = nil`, → `.setup` (Story 4 s13) |
| `done()` | `.summary` | none | `match = nil`, `clock = nil`, → `.setup` with the stored format (Story 5 s10) |

A rejected engine call (`MatchError`) leaves the session unchanged and plays nothing (Edge cases: very fast taps; tap while the summary is opening, ITF MT-08).

## PointOutcome (value, pure)

The FR-010 result for one added point (research R2).

| Field | Type | Rule |
| --- | --- | --- |
| `winner` | `Player` | The point's winner |
| `level` | `.point`, `.game`, `.set`, `.match` | Match if `status` became `.won`; else set if `completedSets` grew; else game if the total of `games` grew; else point |
| `changeOfEnds` | `Bool` | `after.changeOfEnds && level != .match` [ITF: EN-01..EN-05, TB-05] |

Haptic order: the `level` haptic, then the change-of-ends haptic if set (FR-011, FR-012).

## ScoreScreenModel (value, pure)

Everything Watch 3 shows or reads, built from `MatchState`, `isPaused` and the language (FR-006..FR-009, Story 7 s1). Views don't format scores.

| Field | Source |
| --- | --- |
| `zones[player].label` | "Me" / "Opponent" |
| `zones[player].points` | `state.points[player]`: 0, 15, 30, 40, "AD", or a tie-break number |
| `zones[player].games` | `state.games[player]` |
| `zones[player].sets` | number of `completedSets` with `winner == player` |
| `zones[player].isServer` | `state.server == player` |
| `zones[player].courtSide` | `state.courtSide` when serving, otherwise nil: "Right" / "Left" / "Choice" |
| `statusText` | "Paused" if paused, else the first true of `isMatchTieBreak`, `isTieBreak`, `isDecidingPoint`, `isDeuce`, else empty (FR-008) |
| `summaryAccessibilityLabel` | the server's score first, then a separate Me or Opponent string with the side or the receiver's choice (Story 7 s1, R2-1) |
| `zones[player].accessibilityLabel` / `hint` | the copy-table zone sentence with plural games and sets / "Add point for …" |
| `zonesAcceptTaps(isLuminanceReduced:)` | `acceptsPoints && !isLuminanceReduced` (Story 6 s3) |
| `statusAccessibilityText` | "Paused. <state>" or "<state>" (R1-3) |

Point display order for VoiceOver: the server's score first [ITF: GM-01]; "advantage" for AD.

## SummaryModel (value, pure)

Watch 6, built from `MatchState`, the clock and the language (FR-019, Story 5).

| Field | Rule |
| --- | --- |
| `title` | `.won(.me)` → Win; `.won(.opponent)` → Loss; `.unfinished` → Match ended early |
| `chips` | One per `completedSets` entry: games Me–Opponent, or the tie-break points if `isMatchTieBreak` [ITF: MT-05]; `isLost = winner == .opponent` |
| unfinished chip | Only when `status == .unfinished` and a point of the current set was played (`games` total > 0 or a point display ≠ 0): the current games with "*", or the match tie-break points with "*" (Story 5 s5, R1-2) |
| `chips[i].accessibilityLabel` | "Set n: a–b, won/lost/unfinished", or for a match tie-break "Match tie-break: a–b, won/lost/unfinished" (R2-4) |
| `duration` | `clock.elapsed(at: stoppedAt)`, `.time(pattern: .hourMinuteSecond)` |

## Relationships

```text
FormatChoice ──(start)──▶ MatchSession ──owns──▶ Match (TennisCore), MatchClock
                               │
                 state before/after a point ──▶ PointOutcome ──▶ HapticPlaying, Announcing
                               │
           MatchState + isPaused ──▶ ScoreScreenModel ──▶ ScoreView, AlwaysOn rendering
           MatchState + clock    ──▶ SummaryModel     ──▶ SummaryView
```
