# Contract: watch match UI (v1)

The surfaces that tests, the reviewer and later specs (003 HealthKit, persistence, 004 sync) rely on. The views may change freely as long as these hold. The semantics are in [data-model.md](../data-model.md).

## 1. Accessibility identifiers (UI tests, SC-002, SC-005)

| Screen | Identifier | Element |
| --- | --- | --- |
| New match | `setup.format`, `setup.setLength`, `setup.atFortyAll`, `setup.thirdSet` | Setting rows (button; value = current choice) |
| New match | `setup.start` | Start |
| Picker | `picker.option.<rawValue>` | One option per value |
| First server | `firstServer.me`, `firstServer.opponent`, `firstServer.coinToss` | Choice buttons |
| Coin-toss result | `coinToss.result`, `coinToss.start` | Result text, Start |
| Score | `undo`, `elapsed`, `status`, `score.summary` | Header, status line, VoiceOver summary |
| Score | `zone.me`, `zone.opponent` | Tap zones (buttons) |
| Score | `zone.<player>.points`, `.games`, `.sets`, `.serve`, `.side` | Displayed values; `.serve` and `.side` exist only for the server |
| Controls | `controls.undo`, `controls.pauseResume`, `controls.server`, `controls.end`, `controls.elapsed` | Controls page |
| End confirmation | `confirm.end` | Destructive "End match" |
| Summary | `summary.title`, `summary.chip.<n>`, `summary.duration`, `summary.done`, `summary.undo` | Summary (chips numbered from 1) |

## 2. Launch arguments (UI tests only)

| Argument | Effect |
| --- | --- |
| `-resetFormat` | Clears `lastFormat.v1` before launch (first-use defaults, Story 1 s1) |
| `-coinToss me` / `-coinToss opponent` | Fixes the coin-toss result (Story 1 s9) |

Without these arguments the app behaves as in production. Neither argument exists in a Release build (`#if DEBUG`).

## 3. Displayed values (EN), as checked by UI tests

| Engine value | Shown |
| --- | --- |
| `PointDisplay.zero/.fifteen/.thirty/.forty` | `0` / `15` / `30` / `40` [ITF: GM-01] |
| `PointDisplay.advantage` | `AD` (all languages, glossary) |
| `PointDisplay.tieBreak(n)` | `n` [ITF: TB-01] |
| `CourtSide.right/.left/.receiversChoice` | `Right` / `Left` / `Choice` [ITF: SV-03, TB-04, NA-02] |
| Status flags | `Match tie-break` › `Tie-break` › `Deciding point` › `Deuce` › empty; `Paused` replaces it while paused (FR-008) |

## 4. Feedback per command (SC-003, FR-011, FR-012, FR-024)

| Command | Haptics (in order) | VoiceOver announcements |
| --- | --- | --- |
| Point, no game won | point | status change, if any |
| Point wins a game | game | "Game: <winner>", status change |
| Point wins a set | set | "Set: <winner>" |
| Point wins the match | match | "Match: <winner>" |
| …and `changeOfEnds` (not the match point) | + change of ends, after ~0.8 s | + "Change ends" |
| Undo, early end, undo of an early end, pause, resume | none | status change, if any |
| Server correction | none | "Server: <new server>" |

## 5. Session commands (for 003, persistence and 004)

`MatchSession` exposes `start(firstServer:)`, `addPoint(for:)`, `undo()`, `pause()`, `resume()`, `correctServer()`, `endEarly()` and `done()`, plus the read-only `route`, `match`, `clock` and `isPaused`. Later specs extend the session; they don't bypass it to call the engine from views. Spec 003 hooks the workout session to `start` and `.summary`; persistence saves `match.events` after each command.
