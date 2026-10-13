# Data model: Scoring engine (001)

**Spec**: [spec.md](spec.md) | **Research**: [research.md](research.md) | **API**: [contracts/public-api.md](contracts/public-api.md)

All types are value types, `Sendable`, `Equatable` and `Hashable`, and live in `Packages/TennisCore`. "Player" is always `Me` or `Opponent`; names are attached outside the engine.

## Input: the match record

| Entity | Fields | Rules |
| --- | --- | --- |
| **Player** | `me` \| `opponent`; `other` | The only two players. |
| **MatchLength** | `oneSet` \| `bestOfThree` | MT-01, MT-02 |
| **SetLength** | `4` \| `6` \| `8` (games, `N`) | ST-04, ST-06, ST-07. Any other value is rejected, including from saved data (US1 s20). |
| **GameScoring** | `advantage` \| `noAd` | GM-02, NA-01 |
| **MatchFormat** | `length`, `setLength`, `gameScoring`, `matchTieBreak: Bool` | `matchTieBreak` is allowed only with `bestOfThree`; otherwise the format is rejected as `invalidFormat` (US1 s19, MT-02). |
| **MatchSetup** | `format`, `firstServer: Player` | SV-01. The coin toss is resolved by the app. |
| **MatchEvent** | `setup(MatchSetup)` \| `point(winner: Player, recordedAt: Date)` \| `matchEndedEarly` \| `firstServerCorrected(Player)` | FR-001, FR-032. `recordedAt` is stored, restored bit-exactly and never read by the reducer. |
| **Match** (the record) | `events: [MatchEvent]` (always starts with exactly one `setup`); cached `state`, `stats` | The only thing saved. It is serialized with `formatVersion` (see [saved-format](contracts/saved-format.md)). |

### Validity of an event list

An event list is valid when it can be built by recording its events one by one from an empty list, with each step accepted. The rejection rules are:

| Incoming event | Rejected when | Error |
| --- | --- | --- |
| first event is not `setup` | always | `missingSetup` |
| `setup` (not first) | always | `duplicateSetup` |
| `point` | status ≠ in progress (won or unfinished) | `matchNotInProgress` (US3 s9, s16; US7 s3) |
| `matchEndedEarly` | status ≠ in progress | `matchNotInProgress` (US7 s6; US3 s16) |
| `firstServerCorrected(p)` | `p` == current effective first server | `sameFirstServer` (US8 s7) |

A `firstServerCorrected` event is accepted in any status (US8 s8, s10). Rejected input leaves the `Match` unchanged.

### Undo

`undo()` removes the last event when there are at least 2 events, and returns it. With only the setup it returns `nil` and changes nothing (FR-004, US3 s6). The resulting value equals `Match(events: shortenedList)`.

## Derived: match state (FR-014)

Computed from `(format, effectiveFirstServer, points, endedEarly)`. `effectiveFirstServer` is the latest correction, or the setup's first server if there is none (research R1).

| Field | Type | Meaning / rule |
| --- | --- | --- |
| `status` | `MatchStatus`: `.inProgress` \| `.won(Player)` \| `.unfinished` | FR-013, FR-029 |
| `completedSets` | `[SetScore]` | In order. A match tie-break appears as the last entry (MT-05). |
| `games` | `PlayerPair<Int>` | Games in the current set. 0–0 once the match is won. |
| `points` | `PlayerPair<PointDisplay>` | GM-01, GM-02, TB-01. "0" once the match is won. |
| `server` | `Player` | SV-02, TB-02, TB-03, MT-04 |
| `courtSide` | `CourtSide`: `.right` \| `.left` \| `.receiversChoice` | SV-03, TB-04, NA-02 |
| `isDeuce` | `Bool` | Advantage, standard game, both ≥ 3 points and equal (FR-015) |
| `isDecidingPoint` | `Bool` | No-Ad, standard game, 3–3 (FR-015) |
| `isTieBreak` | `Bool` | On in set tie-breaks and in the match tie-break |
| `isMatchTieBreak` | `Bool` | On only in the match tie-break |
| `changeOfEnds` | `Bool` | The value of the most recent point; `false` before the first point. Not set by early ends or corrections (FR-014, FR-029, FR-030). |

When the match is not in progress, the UI ignores `server`, `courtSide` and `changeOfEnds`. In an unfinished match, `games` and `points` keep the score at the early end (US7 s1).

| Entity | Fields | Rules |
| --- | --- | --- |
| **PlayerPair<T>** | `me`, `opponent`; `subscript(Player)` | Order is always Me, then Opponent (spec convention "Me–Opponent"). |
| **PointDisplay** | `.zero` \| `.fifteen` \| `.thirty` \| `.forty` \| `.advantage` \| `.tieBreak(Int)` | The apps map it to localized text; the engine has no strings (research R7). |
| **SetScore** | `games: PlayerPair<Int>`, `tieBreak: PlayerPair<Int>?`, `isMatchTieBreak: Bool`, `winner: Player` | A tie-break set: games N+1–N plus the tie-break points (US4 s9). A match tie-break: games 1–0 to the winner, `tieBreak` holds the points (e.g. 10–7), `isMatchTieBreak` is true (MT-05). |

### Internal score-track state machine

```text
Standard game ──(game won, set not decided, games == N–N)──▶ Set tie-break (first to 7, +2)
     │                                                              │
     │ (game won → set decided)                                     │ (tie-break won → set N+1–N)
     ▼                                                              ▼
 Set complete ──(match decided)──▶ Match won
     │
     ├─(bestOfThree, sets 1–1, matchTieBreak on)──▶ Match tie-break (first to 10, +2) ──▶ Match won
     └─(otherwise)──▶ next Standard game, games 0–0
```

Any in-progress state goes to **Unfinished** on `matchEndedEarly`; undo returns to it.

- A standard game is won with ≥ 4 points and a 2-point lead (Advantage), or at 4 points (No-Ad: the 4th point wins at 3–3) (GM-02, NA-01).
- A set is won at N with a 2-game lead, at N+1–N−1, or by the N–N tie-break (ST-03, ST-04, ST-06, ST-07).

### Service track

- **Standard game**: the server alternates after each standard game, across sets (SV-02).
- **Tie-break point k** (0-based): the tie-break's first server serves k = 0. The server changes after k = 0, 2, 4, …, i.e. before points 1, 3, 5, … (TB-02).
- **After a tie-break set**: the next set (or the match tie-break) is started by the tie-break's first receiver (TB-03, SV-04, MT-04).
- **Match tie-break after a standard-game set 2**: started by the player due to serve the next game (MT-04).

### Court side

`n` is the number of points already played in the current game or tie-break.

- Standard game: `.right` if `n` is even, `.left` if odd. On the No-Ad deciding point (3–3), `.receiversChoice` (SV-03, NA-02).
- Tie-break: `.right` if `n` is even, `.left` if odd, never `.receiversChoice` (TB-04).

### Change of ends (per point, score track only)

For the point just played:
1. If it wins the match → `false` (EN-05, FR-023).
2. If it ends a standard game or a set tie-break → `true` iff the games played in that set are now odd (EN-01, EN-02, EN-03, EN-04). A tie-break set has 2N+1 games, so the answer is always `true`; this also covers the change before the match tie-break (FR-022).
3. Otherwise, inside a tie-break or match tie-break → `true` iff the tie-break points played are a positive multiple of 6 (TB-05).
4. Otherwise → `false`.

Rules 2 and 3 never both fire for one point (US5 s6).

## Derived: match stats (FR-024..027)

| Entity | Fields | Rules |
| --- | --- | --- |
| **Tally** | `won: Int`, `of: Int` | `0 ≤ won ≤ of` |
| **PlayerStats** | `pointsWonOnServe`, `pointsWonOnReturn`, `serviceGamesHeld`, `breakPointsConverted`, `breakPointsSaved` (all `Tally`) | `breakPointsConverted` = converted/opportunities (as receiver); `breakPointsSaved` = saved/faced (as server). |
| **MatchStats** | `me`, `opponent: PlayerStats`; `subscript(Player)` | Recomputed on replay (undo, correction); accumulated on append. |

Per point, from the service track's server `s` and receiver `r`:
- Every point (including tie-breaks): `s.pointsWonOnServe.of += 1` and `r.pointsWonOnReturn.of += 1`. The winner's matching `won` is incremented (FR-024).
- **Break point**: a standard-game point where the receiver wins the game by winning it (30–40, 15–40, 0–40, receiver's advantage, No-Ad deciding point). On a break point, `r.breakPointsConverted.of += 1` and `s.breakPointsSaved.of += 1`. Then +1 to `r…converted.won` if the receiver wins the point, or to `s…saved.won` if the server wins it (BP-01, BP-02). Tie-break points are never break points.
- **Standard game completed**: `s.serviceGamesHeld.of += 1`, and `won += 1` if the server won the game (BP-03). Tie-breaks and games in progress are not counted.

Invariants (SC-006, US6 s2/s12), for each player p:
- `p.pointsWonOnServe.of == p.other.pointsWonOnReturn.of`;
- `p.pointsWonOnServe.won + p.other.pointsWonOnReturn.won == p.pointsWonOnServe.of`;
- `p.breakPointsConverted.won == p.other.breakPointsSaved.of − p.other.breakPointsSaved.won`.
