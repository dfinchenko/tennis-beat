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
| Score | `undo`, `elapsed`, `score.summary` | Header and the VoiceOver summary; the status is the summary label's trailing text (the status line is hidden from VoiceOver) |
| Score | `zone.me`, `zone.opponent` | Tap zones (buttons; with `-uiTestExposeValues` possibly containers, so look them up with `descendants(matching: .any)`) |
| Score | `zone.<player>.points`, `.games`, `.sets`, `.serve`, `.side` | Displayed values, visible to UI tests **only with `-uiTestExposeValues`**; `.serve` and `.side` exist only for the server |
| Controls | `controls.undo`, `controls.pauseResume`, `controls.server`, `controls.end`, `controls.elapsed` | Controls page |
| End confirmation | `confirm.end` | Destructive "End match". Set in code, but watchOS gives `confirmationDialog` actions no identifier, so UI tests find the button by its label ("End match", «Zakończ mecz», «Завершити матч») and the dialog by its system Close button `AX_ActionContentControllerCancelButton` (#21 R1-4) |
| Summary | `summary.title`, `summary.chip.<n>`, `summary.duration`, `summary.done`, `summary.undo` | Summary (chips numbered from 1) |

## 2. Launch arguments (UI tests only)

| Argument | Effect |
| --- | --- |
| `-resetFormat` | Clears `lastFormat.v1` before launch (first-use defaults, Story 1 s1) |
| `-coinToss me` / `-coinToss opponent` | Fixes the coin-toss result (Story 1 s9) |
| `-uiTestExposeValues` | Zones use `.accessibilityElement(children: .contain)` so their child values are visible to XCUITest (R3-1). Never used for accessibility audits or VoiceOver checks |
| `-uiTestAlwaysOn` | The match screens render as in Always On (`isLuminanceReduced` is true), for the US6 UI tests and the Watch 5 screenshots; the simulator can't lower the wrist on demand (PR 5) |
| `-uiTestPoints MMOUS…` | Plays these steps once when the first match opens (M = Me, O = Opponent, U = Undo, S = server correction), so Always On tests and screenshots reach a score (Always On zones take no taps, PR 5), and the SC-002 sequences tap only their last steps (U and S added on #36) |
| `-uiTestHoldChangeOfEnds` | A scheduled change-of-ends haptic stays pending until the next command plays it (a point) or drops it (Undo and the other commands), instead of playing after 0.8 s, so a UI test can tap while it is pending (lost-tap check after #35) |

Without these arguments the app behaves as in production. None of these arguments exists in a Release build (`#if DEBUG`).

## 3. Displayed values (EN), as checked by UI tests

The status is checked as `score.summary` label == `expectedSummary + (status.isEmpty ? "" : ". " + status)` (research R7). The drawn status line itself is covered by unit tests only.


| Engine value | Shown |
| --- | --- |
| `PointDisplay.zero/.fifteen/.thirty/.forty` | `0` / `15` / `30` / `40` [ITF: GM-01] |
| `PointDisplay.advantage` | `AD` (all languages, glossary) |
| `PointDisplay.tieBreak(n)` | `n` [ITF: TB-01] |
| `CourtSide.right/.left/.receiversChoice` | `Right` / `Left` / `Choice` [ITF: SV-03, TB-04, NA-02] |
| Status flags | `Match tie-break` › `Tie-break` › `Deciding point` › `Deuce` › empty; `Paused` replaces it while paused (FR-008). Read as the trailing text of the `score.summary` label |

## 4. Feedback per command (SC-003, FR-011, FR-012, FR-024)

| Command | Haptics (in order) | VoiceOver announcements |
| --- | --- | --- |
| Point, no game won | point | status change, if any |
| Point wins a game | game | "Game: <winner>", status change, if any |
| Point wins a set | set | "Set: <winner>", status change, if any |
| Point wins the match | match | "Match: <winner>" |
| …and `changeOfEnds` (not the match point) | + change of ends, after ~0.8 s; cancelled by undo, correction, pause, End or Done; played at once (not dropped) if another point is added first | + "Change ends" |
| Undo, early end, undo of an early end, pause, resume | none | status change, if any |
| Server correction | none | "Server: <new server>" |

All announcements for one command are joined into **one** announcement, for example "Game: Me. Change ends" (research R4). "Status change" means the status-line text differs from before the command. After the match-winning point there is no status line, so the match row has none.

## 5. Session commands (for 003, persistence and 004)

`MatchSession` exposes `start(firstServer:)`, `addPoint(for:)`, `undo()`, `pause()`, `resume()`, `correctServer()`, `endEarly()` and `done()`, plus the read-only `route`, `match`, `clock` and `isPaused`. Later specs extend the session; they don't bypass it to call the engine from views. Spec 003 hooks the workout session to `start` and `.summary`; persistence saves `match.events` after each command.
