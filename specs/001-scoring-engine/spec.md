# Feature Specification: Scoring engine

**Feature Branch**: `feat/001-scoring-engine`

**Created**: 2026-10-07

**Status**: Draft

**Input**: User description: "Scoring engine in Packages/TennisCore (pure Swift; no UI, HealthKit or persistence). A match is an ordered list of Codable events: setup (format, first server) and pointWon(by: me | opponent). State is a pure reduction of events. Undo removes the last event and works across game/set boundaries and after the match has ended. Formats: singles; 1 set or best of 3; set length 4, 6 or 8 games; Advantage or No-Ad; tie-break at N–N (ST-04, ST-06; 7-point tie-break); optional 10-point match tie-break instead of the deciding set, only for best of 3 (MT-02). State exposes: point display per player (0/15/30/40/AD; numbers in tie-breaks), games, sets, set and match winner, current server, serving court side (right when points already played in the current game or tie-break are even, left when odd; at the No-Ad deciding point it is "receiver's choice", NA-02), flags for deuce, deciding point, tie-break and match tie-break, and change-of-ends events (Rule 10, EN-02, EN-04; a set won in a tie-break has 2N+1 games, so ends change after it). Serve rotation: alternate each game; in a tie-break the first server serves one point, then two each; the player who served first in a tie-break receives first in the next set. Derived stats: points won on serve and on return, service games held (BP-03), break points converted and saved (BP-01, BP-02; tie-break points are never break points). Every rule references its ID in docs/rules/itf-notes.md. Acceptance criteria list these edge cases as testable scenarios."

## Overview

The scoring engine is the part of Tennis Beat that knows the rules of tennis. The watch app tells it who won each point. The engine answers everything the score screen, haptics, history and stats need: the score, who serves and from which side of the court, when the players change ends, who won, and the match stats.

A match is recorded as an ordered list of events:
- one **setup** event (the format and the first server), always first;
- one **point won** event per point (by **Me** or by the **Opponent**), carrying the time it was recorded;
- a **match ended early** event, when the players stop before the match is decided (court time over, injury);
- a **first server corrected** event, when the players realise the wrong player was recorded as serving first.

Every answer is computed from that list alone. Recording the list is therefore enough to restore a match exactly after a crash or relaunch, to undo any number of events, and to recompute stats later.

Every rule in this spec cites its ID in [`docs/rules/itf-notes.md`](../../docs/rules/itf-notes.md), written `[ITF: XX-00]`. Entries whose origin is *Not covered* are product decisions approved by Denys.

Out of scope: user interface, haptics, HealthKit, timing and pause, where the event list is stored, and sync. The engine does own the saved format of the event list, including its format version. The engine is used by both apps but depends on none of them.

## User Scenarios & Testing *(mandatory)*

The "user" of the engine is the player keeping score on the watch, through the app. Each story is independently testable by feeding event lists to the engine and checking the resulting state.

In the scenarios below, a score written "Me–Opponent" lists the games or points of Me first. "Me serves first" means the setup's first server is Me.

### User Story 1 - Score a match point by point (Priority: P1)

The player taps "my point" or "opponent's point" after every rally. The engine keeps the game, set and match score correctly for every supported format and declares the set and match winners.

**Why this priority**: Correct scoring is the product. Nothing else works without it.

**Independent Test**: Feed the setup and a sequence of points, then check the point display, games, sets and winners after each point.

**Acceptance Scenarios**:

*Standard game, Advantage format* [ITF: GM-01, GM-02]
1. **Given** a new game, **When** Me wins 0, 1, 2 and 3 points in a row, **Then** Me's point display reads "0", "15", "30", "40", and it never reads "love".
2. **Given** 40–30, **When** Me wins the point, **Then** Me wins the game and both point displays reset to "0".
3. **Given** 3 points each, **Then** both displays read "40" and the deuce flag is on.
4. **Given** deuce, **When** the Opponent wins a point, **Then** the Opponent's display reads "AD", Me's reads "40", and the deuce flag is off.
5. **Given** advantage Opponent, **When** Me wins the point, **Then** the score is deuce again.
6. **Given** advantage Opponent, **When** the Opponent wins the point, **Then** the Opponent wins the game.
7. **Given** 10 consecutive deuces, **When** a player then wins two points in a row, **Then** that player wins the game. There is no cap on the number of deuces.

*Standard game, No-Ad format* [ITF: NA-01]

8. **Given** No-Ad and 3 points each, **Then** both displays read "40", the deciding-point flag is on and the deuce flag is off.
9. **Given** the No-Ad deciding point, **When** either player wins it, **Then** that player wins the game.

*Sets* [ITF: ST-03, ST-04, ST-06, ST-07]

10. **Given** set length 6, **When** a player reaches 6 games with the opponent on 4 or fewer, **Then** that player wins the set (e.g. 6–4).
11. **Given** set length 6 at 5–5, **When** Me wins the next two games, **Then** Me wins the set 7–5.
12. **Given** set length 6 at 6–6, **Then** the next game is a tie-break, and its winner wins the set 7–6.
13. **Given** set length 4, **Then** the set is won at 4–0, 4–1, 4–2 or 5–3. At 4–4 a tie-break is played, and its winner wins the set 5–4.
14. **Given** set length 8, **Then** the set is won at 8–0 to 8–6 or at 9–7. At 8–8 a tie-break is played, and its winner wins the set 9–8.

*Match* [ITF: MT-01, MT-02, MT-03]

15. **Given** a 1-set match, **When** a player wins the set, **Then** that player wins the match.
16. **Given** best of 3, **When** a player wins 2 sets, **Then** that player wins the match. That happens at 2–0 or after the third set at 2–1.
17. **Given** best of 3 with the match tie-break option at 1 set each, **Then** the deciding set is a single match tie-break and no third standard set is played.
18. **Given** best of 3 without the match tie-break option at 1 set each, **Then** a normal third set is played.
19. **Given** a setup with a 1-set match and the match tie-break option, **Then** the setup is rejected as invalid [ITF: MT-02].
20. **Given** a setup with a set length other than 4, 6 or 8 (e.g. 5), including one restored from a saved event list, **Then** the setup is rejected as invalid [ITF: ST-07].

---

### User Story 2 - Know who serves and from which side (Priority: P1)

The score screen marks the server and shows a court-side pill ("Right", "Left" or "Choice"). The engine provides both after every point.

**Why this priority**: Players regularly lose track of the server and the side. Showing them correctly is a core promise of the score screen.

**Independent Test**: Feed point sequences and check the current server and court side after each point.

**Acceptance Scenarios**:

*Service order* [ITF: SV-01, SV-02, SV-04, TB-02, TB-03, MT-04]
1. **Given** a setup with Me serving first, **Then** Me serves game 1.
2. **Given** any standard game ends (not a tie-break), **Then** the other player serves the next game. This also holds across set boundaries.
3. **Given** a tie-break whose first point is served by player A, **Then** player B serves points 2 and 3, player A serves points 4 and 5, and so on, alternating every two points until the tie-break ends.
4. **Given** set length 6, Me serving game 1 and a 6–6 score, **Then** Me serves the first point of the tie-break (Me is due to serve game 13).
5. **Given** a set decided by a tie-break whose first point was served by Me, **Then** the Opponent serves game 1 of the next set, whatever the score of the tie-break.
6. **Given** best of 3 with the match tie-break option and set 2 ended by a standard game, **Then** the first point of the match tie-break is served by the player due to serve the next game.
7. **Given** best of 3 with the match tie-break option and set 2 ended by a tie-break, **Then** the first point of the match tie-break is served by the player who received first in set 2's tie-break [ITF: TB-03, MT-04].
8. **Given** a match tie-break, **Then** serving follows the same one-then-two-each rotation as any tie-break [ITF: TB-02].

*Court side* [ITF: SV-03, TB-04, NA-02]

9. **Given** a new standard game (0 points played), **Then** the court side is Right.
10. **Given** a standard game where an odd number of points has been played (e.g. 15–0, 30–15, 40–30), **Then** the court side is Left. With an even number of points played (e.g. 15–15, 30–0, 40–40 in Advantage), it is Right.
11. **Given** an Advantage game at advantage (7 points played, e.g. 40–AD after deuce), **Then** the court side is Left. At the next deuce (8 points played), it is Right.
12. **Given** a No-Ad game at the deciding point (40–40), **Then** the court side is "receiver's choice", not Right or Left [ITF: NA-02].
13. **Given** a tie-break or a match tie-break, **Then** the court side is Right when the number of tie-break points played is even and Left when it is odd. The first point is from the right.

---

### User Story 3 - Undo any mistake, and resume after a crash (Priority: P1)

A player who taps the wrong zone can undo, as many times as needed, even across game and set boundaries and after the match has ended. Undo removes the last event other than the setup: a point, an early end or a server correction. If the app is killed mid-match, the match comes back exactly as it was, and a match saved by an older version of the app still opens.

**Why this priority**: Mis-taps happen on court with wet fingers. Without reliable undo, the score can't be trusted. Crash recovery is on the device checklist.

**Independent Test**: For any event list, undo must give the same state as rebuilding from scratch with the last non-setup event removed, and restoring a saved event list must give the identical state.

**Acceptance Scenarios**:

1. **Given** any match with at least one event after the setup, **When** the player undoes, **Then** the last event is removed, whatever its kind (point, early end or server correction), and the state equals the state computed from the remaining events. This applies to every exposed value, including server, court side, flags, change-of-ends and stats.
2. **Given** Me just won set 1 6–4 and set 2 is at 0–0, **When** the player undoes, **Then** set 1 is back in progress at 5–4 with the game score before the last point, and the set-1 winner is cleared.
3. **Given** the match has ended, **When** the player undoes, **Then** the match is back in progress at match point, the match winner is cleared, and new points can be added.
4. **Given** a tie-break at 6–6 in points, **When** the player undoes, **Then** the tie-break score is 6–5 or 5–6 with the server and court side for that point.
5. **Given** the first point of the match was just played, **When** the player undoes, **Then** the state is the start of the match: 0–0, the first server serving, from the right.
6. **Given** only the setup event (no other events), **When** the player undoes, **Then** nothing changes. Undo never removes the setup.
7. **Given** the last point triggered a change of ends, **When** the player undoes, **Then** the state no longer reports that change of ends.
8. **Given** any recorded event list, **When** it is saved and restored (encoded and decoded), **Then** the restored list is identical, including the format version and every point's recorded time, and produces the identical state.
9. **Given** the match has ended (won or ended early), **When** a further point is submitted, **Then** it is rejected and the state is unchanged.
10. **Given** an event list without a setup event, or with a second setup event, **Then** it is rejected as invalid.
11. **Given** the last event is a match-ended-early event, **When** the player undoes, **Then** the match is back in progress at the same score and new points can be added (Story 7).
12. **Given** the last event is a first-server correction, **When** the player undoes, **Then** only the correction is removed: the server, court side and serve stats return to the uncorrected values, and the last point is still there (Story 8).
13. **Given** an event list saved with the current format version, or with any older format version the engine has ever written, **When** it is restored, **Then** it is accepted and produces the state that version recorded. A saved example of every released format version is kept as a test fixture.
14. **Given** an event list saved with a newer format version than the engine knows, **When** it is restored, **Then** it is rejected with an "unsupported version" result, the engine does not crash, and no state is produced from it.
15. **Given** two event lists with the same events but different recorded times on the points (including times out of order), **Then** both produce the identical state and stats. Recorded times are stored and restored but never used to compute state.
16. **Given** a saved event list with a point or a second match-ended-early event after a match-ended-early event, or with any point after the match-winning point, **When** it is restored, **Then** it is rejected as invalid [ITF: MT-08].

---

### User Story 4 - Tie-breaks and the match tie-break (Priority: P1)

Tie-breaks are scored with numbers, need a 2-point margin, and decide the set. The optional match tie-break to 10 replaces the deciding set in best of 3.

**Why this priority**: Every set that reaches N–N, and every match that reaches 1–1 with the match tie-break option, depends on this. It is also the most error-prone part of manual scorekeeping.

**Independent Test**: Feed points into a set at N–N, or into a match at 1–1 with the option on, and check the point display, flags, winners and set score.

**Acceptance Scenarios**:

1. **Given** a tie-break, **Then** the tie-break flag is on and the point displays are numbers ("0", "1", "2", …), not 15/30/40.
2. **Given** a tie-break at 6–5, **When** the leader wins the point, **Then** the leader wins the tie-break 7–5 and the set [ITF: TB-01].
3. **Given** a tie-break at 6–6, **When** a player wins the point, **Then** the score is 7–6 and the tie-break continues. It ends only with a 2-point margin, with no upper limit (e.g. 15–13).
4. **Given** a match tie-break, **Then** the match-tie-break flag is on, the tie-break flag is on, and the point displays are numbers [ITF: MT-03].
5. **Given** a match tie-break at 9–8, **When** the leader wins the point, **Then** the leader wins 10–8, which wins the match.
6. **Given** a match tie-break at 9–9 or 10–10, **Then** it continues until a 2-point margin (e.g. 12–10).
7. **Given** a match won by a match tie-break, **Then** the match result lists set 1, set 2 and the deciding match tie-break with its point score (e.g. 6–4, 3–6, 10–7) [ITF: MT-05].
8. **Given** a tie-break, **Then** no point in it is ever a break point [ITF: BP-02].
9. **Given** a set won in a tie-break, for each set length, **Then** the completed set score is N+1–N and also records the tie-break's own point score (e.g. 7–6 with the tie-break won 7–5, 5–4 with 9–7, 9–8 with 7–3) [ITF: TB-01, ST-07].
10. **Given** a tie-break or match tie-break at equal scores (e.g. 3–3, 6–6, 9–9), in an Advantage match and in a No-Ad match, **Then** the deuce and deciding-point flags are both off, and the court side is Right or Left, never "receiver's choice". In an Advantage standard game the deciding-point flag is never on [ITF: GM-02, NA-01, NA-02, TB-04].

---

### User Story 5 - Change ends at the right time (Priority: P2)

The watch reminds the players to change ends with a haptic. The engine reports, after each event, whether the players must change ends now. Only point events can report a change of ends.

**Why this priority**: It's a convenience, not part of the score itself, but players expect it and it's on the device checklist.

**Independent Test**: Feed point sequences and check the change-of-ends signal after each point.

**Acceptance Scenarios**:

1. **Given** a set in progress, **When** a game ends and the number of games played in that set becomes odd (1, 3, 5, …), **Then** a change of ends is reported [ITF: EN-01].
2. **Given** a set that ends with an even total of games (e.g. 6–4 = 10), **Then** no change of ends is reported at the end of the set. The change comes after game 1 of the next set [ITF: EN-02].
3. **Given** a set that ends with an odd total of games (e.g. 6–3 = 9) and does not end the match, **Then** a change of ends is reported at the end of the set [ITF: EN-02].
4. **Given** a set won in a tie-break that does not end the match, **Then** its total is 2N+1 games (7–6 = 13, 5–4 = 9, 9–8 = 17), and a change of ends is reported after it. This is an explicit test case for each set length [ITF: EN-03, EN-04].
5. **Given** a tie-break, **When** the total number of tie-break points played reaches 6, 12, 18, … and the tie-break has not ended, **Then** a change of ends is reported [ITF: TB-05].
6. **Given** a tie-break that does not end the match and whose final point is also a multiple of 6 (e.g. 7–5 = 12 points), **Then** exactly one change of ends is reported for that point (the end-of-set change), not two [ITF: TB-05, EN-03].
7. **Given** best of 3 with the match tie-break option, set 2 won in a tie-break (2N+1 games for set length N, e.g. 7–6, 5–4 or 9–8), **Then** a change of ends is reported after set 2, before the match tie-break, for each set length [ITF: EN-03, EN-04].
8. **Given** best of 3 with the match tie-break option, set 2 won with an even total of games (e.g. 6–4, 4–2, 8–6), **Then** no change of ends is reported before the match tie-break; the first change comes after 6 match-tie-break points [ITF: EN-02, EN-04, TB-05].
9. **Given** the point that wins the match, **Then** no change of ends is reported, even where EN-01, EN-02, EN-03 or TB-05 would otherwise call for one. Explicit cases: a 1-set match won 6–3; a 1-set match won 7–6; a best-of-3 match won 2–0 with set 2 won in a tie-break; a match tie-break won 10–8 (18 points) [ITF: EN-05].

---

### User Story 6 - See match stats without typing anything (Priority: P2)

After the match, the iPhone shows stats derived only from the points: points won on serve and on return, service games held, and break points converted and saved.

**Why this priority**: Free stats with no extra input set the product apart. They aren't needed to score a match, though.

**Independent Test**: Feed a known point sequence and compare the stats with hand-counted values.

**Acceptance Scenarios**:

*Points on serve and return*
1. **Given** any match, **Then** for each player "points won on serve" is X/Y. Y is the number of points that player served, including tie-break points, and X is how many of those they won. "Points won on return" is the same count for the points they received.
2. **Given** any match, **Then** Me's points served equal the Opponent's points received, and each player's points won on serve plus the other player's points won on return equal that player's points served.

*Service games held* [ITF: BP-03]

3. **Given** a completed standard game, **Then** it counts as a service game for its server, and as held if the server won it.
4. **Given** a tie-break or match tie-break, **Then** it is never counted as a service game.
5. **Given** a game in progress, **Then** it is not counted yet.

*Break points* [ITF: BP-01, BP-02]

6. **Given** the server trails 30–40, 15–40 or 0–40, or the receiver has advantage, **Then** the next point is a break point for the receiver.
7. **Given** a No-Ad deciding point, **Then** it is a break point for the receiver.
8. **Given** 0–40 on the server's serve, **When** the server wins the next three points, **Then** three break points were played and all three were saved by the server.
9. **Given** advantage receiver, **When** the receiver wins the point, **Then** that break point is converted, and the receiver's break points converted and break-point opportunities each increase by 1.
10. **Given** an Advantage game with several deuces, **Then** every advantage to the receiver counts as a separate break point.
11. **Given** a tie-break point, **Then** it is never a break point, whatever the score.
12. **Given** any match, **Then** each player's break points converted equal the other player's break points faced minus break points saved.

---

### User Story 7 - End a match early (Priority: P2) [ITF: MT-08]

Court time runs out or a player is injured. The player ends the match early; the match is kept as unfinished, with its score and stats so far.

**Why this priority**: Club matches often stop before they are decided. Without this, the match stays "in progress" forever or has to be discarded.

**Independent Test**: Feed points, then a match-ended-early event, and check the status, winner, stats and the rejection of further points; then undo it.

**Acceptance Scenarios**:

1. **Given** a match in progress at 6–4, 3–2, 30–15, **When** a match-ended-early event is added, **Then** the match status is unfinished, there is no match winner, set 1 keeps its winner, and the score shown is 6–4, 3–2, 30–15.
2. **Given** an unfinished match, **Then** stats count every point played before the early end. The game in progress at the early end is not counted as a service game (as for any game in progress).
3. **Given** an unfinished match, **When** a further point is submitted, **Then** it is rejected and the state is unchanged.
4. **Given** an unfinished match, **When** the player undoes, **Then** the early-end event is removed and the match is back in progress at the same score, server and court side.
5. **Given** a match with no points played yet, **When** a match-ended-early event is added, **Then** it is accepted: the match is unfinished at 0–0 with empty stats.
6. **Given** a match that has already been won, or already ended early, **When** a match-ended-early event is submitted, **Then** it is rejected and the state is unchanged.
7. **Given** an unfinished match, **Then** no change of ends is reported for the early-end event.
8. **Given** the last point reported a change of ends, **When** a match-ended-early event follows, **Then** the change-of-ends signal is off; **when** the player undoes the early end, **Then** the signal is on again.

---

### User Story 8 - Correct the first server (Priority: P2) [ITF: CE-02]

A few games in, the players notice the wrong player was recorded as serving first. The player corrects the first server; the whole match is recomputed as if the corrected player had served first from the start.

**Why this priority**: A wrong first server makes the server mark, court side and every serve stat wrong for the rest of the match. Undoing all points to fix it is not acceptable.

**Independent Test**: Feed points, then a first-server-corrected event, and compare the state with a match built from scratch with the corrected first server and the same points.

**Acceptance Scenarios**:

1. **Given** Me recorded as first server and 2 completed games (Me won both), **When** the first server is corrected to Opponent, **Then** the state equals a match set up with Opponent serving first followed by the same points: the score is still 2–0, game 1 counts as the Opponent's service game (lost, so broken) and game 2 as Me's (held), and the Opponent serves game 3.
2. **Given** the correction in scenario 1, **Then** points won on serve and on return, service games held, and break points are all recomputed for both players as if the Opponent had served first.
3. **Given** any match, **When** the first server is corrected, **Then** the point displays, games, sets, set winners, match winner, court side, the deuce, deciding-point and tie-break flags, and the change-of-ends signal reported by each point are unchanged; only server-dependent values change (current server, serve and return stats, service games, break points).
4. **Given** a correction during a tie-break, **Then** the tie-break serving rotation and the first server of the next set follow the corrected order [ITF: TB-02, TB-03].
5. **Given** a corrected match, **When** further points are added, **Then** service continues in the corrected order.
6. **Given** two corrections in a row (to Opponent, then back to Me), **Then** the latest correction applies, and the state equals the uncorrected match.
7. **Given** a correction to the current first server (the setup's, or the latest correction's), **Then** it is rejected and the state is unchanged.
8. **Given** a finished or unfinished match, **When** the first server is corrected, **Then** the correction is accepted and recomputes the stats; the result and the match status are unchanged.
9. **Given** a correction, **When** the player undoes, **Then** the correction is removed and the state equals the uncorrected match (Story 3, scenario 12).
10. **Given** an unfinished match followed by a first-server correction, **Then** the event list is valid, the match stays unfinished, and the stats are recomputed. **When** the player undoes once, **Then** only the correction is removed; **when** the player undoes again, **Then** the early end is removed and the match is back in progress [ITF: MT-08, CE-02].
11. **Given** the last point reported a change of ends, **When** the first server is corrected, **Then** the change-of-ends signal is off, because the correction is now the last event; **when** the player undoes the correction, **Then** the signal is on again.

---

### Edge Cases

- **Undo across boundaries:** undo across game, set and tie-break boundaries, across the start of the match tie-break, and after the match ends (Story 3).
- **Undo at the start:** with no points played, undo is a no-op (Story 3, scenario 6).
- **Point after the match ends:** rejected, and the state is unchanged (Story 3, scenario 9).
- **Invalid setup:** set length other than 4, 6 or 8; match tie-break with a 1-set match; missing or repeated setup. All are rejected (Story 1, scenarios 19 and 20; Story 3, scenario 10).
- **Long games and tie-breaks:** unlimited deuces and unlimited tie-break length (Story 1, scenario 7; Story 4, scenario 3).
- **Deciding point:** court side is "receiver's choice", and the point is a break point (Story 2, scenario 12; Story 6, scenario 7).
- **Change of ends at the end of a tie-break:** only one change when the final tie-break point is also a multiple of 6 (Story 5, scenario 6).
- **Ends before the match tie-break:** depends on whether set 2's game total is odd or even (Story 5, scenarios 7 and 8).
- **Server after a tie-break set:** the next set starts with the tie-break's first receiver serving (Story 2, scenario 5), including into the match tie-break (scenario 7).
- **Set-length boundaries:** 4–2 and 5–3 win, 4–3 continues (N = 4). 8–6 and 9–7 win, 8–7 continues (N = 8).
- **Very long matches:** a best-of-3 match of up to 500 points restores and undoes correctly (Success Criteria).
- **Early end:** at 0–0, mid-game, mid-tie-break; points after it are rejected; undo resumes the match (Story 7).
- **Server correction:** after some games, during a tie-break, after the match ends, twice in a row, to the same server (Story 8).
- **Saved format versions:** older versions restore; a newer version is rejected without a crash (Story 3, scenarios 13 and 14).
- **Recorded times:** never affect state, even when out of order (Story 3, scenario 15).

## Requirements *(mandatory)*

### Functional Requirements

*Events and state*
- **FR-001**: A match MUST be represented as an ordered list of events. The first and only setup event fixes the format and the first server. Every following event is one of: "point won by Me", "point won by Opponent", "match ended early", or "first server corrected to Me / Opponent".
- **FR-002**: Every value the engine exposes MUST be computed from the event list alone. The same event list MUST always produce the same state.
- **FR-003**: The event list MUST be savable and restorable without loss. A restored list MUST produce the identical state.
- **FR-004**: Undo MUST remove the last event other than the setup: a point, a match-ended-early event or a first-server correction. The resulting state MUST equal the state computed from the shortened list. Undo with only the setup MUST change nothing, and undo MUST never remove the setup.
- **FR-005**: The engine MUST reject:
  - an event list that lacks a setup event or has more than one;
  - a setup with an unsupported format;
  - any point after the match has been won or ended early;
  - a match-ended-early event after the match has been won or ended early;
  - a first-server correction to the current first server (the setup's, or the latest correction's).
  Rejected input MUST leave the state unchanged.

*Format*
- **FR-006**: The setup MUST specify:
  - match length: 1 set or best of 3 [ITF: MT-01, MT-02];
  - set length N: 4, 6 or 8 games [ITF: ST-04, ST-06, ST-07];
  - game scoring: Advantage or No-Ad [ITF: GM-02, NA-01];
  - match tie-break instead of the deciding set: on or off, allowed only for best of 3 [ITF: MT-02, MT-03];
  - first server: Me or Opponent [ITF: SV-01].
- **FR-007**: All sets MUST be tie-break sets: a set is won at N games with a 2-game lead, or N+1 to N−1, and at N–N a 7-point tie-break decides the set N+1–N [ITF: ST-03, ST-04, ST-06, ST-07, TB-01].

*Scoring*
- **FR-008**: Standard games MUST be scored 0, 15, 30, 40, game. "0" is never displayed as "love" [ITF: GM-01].
- **FR-009**: In Advantage games, at 3 points each the score MUST be deuce. The leader after deuce shows "AD" (the other player shows "40"), and a game MUST need two consecutive points after deuce [ITF: GM-02].
- **FR-010**: In No-Ad games, at 3 points each the next point MUST decide the game [ITF: NA-01].
- **FR-011**: Tie-breaks MUST be scored with numbers. A tie-break is won by the first player to reach 7 points with a 2-point margin, with no upper limit [ITF: TB-01].
- **FR-012**: When the match tie-break option is on and the sets are 1–1, the deciding set MUST be a single tie-break won by the first player to reach 10 points with a 2-point margin, with no upper limit [ITF: MT-03].
- **FR-013**: The match MUST end when a player wins 1 set (1-set match) or 2 sets (best of 3). The match tie-break counts as the deciding set [ITF: MT-01, MT-02, MT-05].

*Exposed state*
- **FR-014**: After every event the engine MUST expose:
  - the point display for each player (0/15/30/40/AD, or numbers in a tie-break);
  - games in the current set, and the completed set scores (including tie-break and match-tie-break point scores);
  - the match status: in progress, won (with the match winner), or unfinished (ended early, no winner);
  - the winner of each completed set;
  - the current server;
  - the serving court side;
  - flags for deuce, deciding point, tie-break and match tie-break;
  - whether the players must change ends after the last event. Only point events can report a change of ends; match-ended-early and first-server-corrected events never do.
- **FR-015**: The deuce flag MUST be on only in standard (non-tie-break) Advantage games at equal scores of 3 or more points each. The deciding-point flag MUST be on only in standard (non-tie-break) No-Ad games at 3–3. Both flags MUST be off in every tie-break and match tie-break [ITF: GM-02, NA-01, TB-01].

*Service and court side*
- **FR-016**: The first server from the setup MUST serve game 1. After every standard game, the other player MUST serve the next game, across set boundaries too [ITF: SV-01, SV-02].
- **FR-017**: In a tie-break (including a match tie-break), the player due to serve MUST serve the first point. After that, the server MUST change after points 1, 3, 5, … (one point, then two each) [ITF: TB-02, MT-04].
- **FR-018**: After a set decided by a tie-break, the player who served first in that tie-break MUST receive in the first game of the next set. The same rule decides the first server of a match tie-break that follows a tie-break set [ITF: TB-03, SV-04, MT-04].
- **FR-019**: The serving court side MUST be:
  - Right when the number of points already played in the current game or tie-break is even, Left when it is odd [ITF: SV-03, TB-04];
  - "receiver's choice" on the No-Ad deciding point of a standard game, never in a tie-break [ITF: NA-02].

*Change of ends*
- **FR-020**: A change of ends MUST be reported after a game that makes the number of games played in the current set odd. That covers the end of a set with an odd total, including every set won in a tie-break (2N+1 games), unless that game wins the match (FR-023) [ITF: EN-01, EN-02, EN-03, EN-04, EN-05].
- **FR-021**: During a tie-break or match tie-break, a change of ends MUST be reported after every 6th point (6, 12, 18, …). When the tie-break's final point coincides with this, exactly one change of ends MUST be reported [ITF: TB-05]. No change of ends is reported when that point wins the match (FR-023) [ITF: EN-05].
- **FR-022**: Before a match tie-break, ends MUST change only if set 2 ended with an odd total of games [ITF: EN-04].
- **FR-023**: No change of ends MUST be reported after the point that wins the match [ITF: EN-05].

*Stats*
- **FR-024**: For each player the engine MUST provide points won on serve and points won on return, each as won/played, including tie-break points.
- **FR-025**: For each player the engine MUST provide service games held, as held/played. It counts completed standard games only; tie-breaks are excluded [ITF: BP-03].
- **FR-026**: For each player the engine MUST provide:
  - break points converted, as converted/opportunities, as the receiver;
  - break points saved, as saved/faced, as the server.
  A break point is any point in a standard game where the receiver wins the game by winning that point, including the No-Ad deciding point. Tie-break points are never break points [ITF: BP-01, BP-02].
- **FR-027**: Stats MUST be available at any moment of the match, counting only what has happened so far, and MUST follow undo exactly. For an unfinished match they count every point played before the early end.

*Traceability*
- **FR-028**: Every rule-based test MUST cite the ITF note ID it checks (`// ITF: <ID>`), and every scenario in this spec MUST be covered by at least one test.

*Early end and server correction*
- **FR-029**: A match-ended-early event MUST make the match unfinished. Only first-server corrections MAY follow it; an event list with a point or a second early end after it is invalid. An unfinished match has no match winner, completed sets keep their winners, the score stays as it was, and no change of ends is reported for it. Undo MUST remove it and resume the match [ITF: MT-08].
- **FR-030**: A first-server-corrected event MUST make the engine recompute the whole match as if the corrected player had served first from the setup on, including the server of every game and tie-break point and all serve, return, service-game and break-point stats. Point displays, games, sets, winners, match status, court side, the deuce, deciding-point and tie-break flags, and the change-of-ends signal reported by each point MUST NOT change. The latest correction applies. It is allowed at any time, including after the match has been won or ended early [ITF: CE-02].

*Saved format*
- **FR-031**: The saved event list MUST carry a format version. The engine MUST restore lists saved with its own version and with every older version it has written. A list with a newer version MUST be rejected with an "unsupported version" result, without crashing and without producing a state.
- **FR-032**: Every point event MUST carry the time it was recorded. The engine MUST store and restore it unchanged, and MUST NOT use it to compute any state or stat.

### Key Entities

- **Match format**: match length (1 set or best of 3), set length (4, 6 or 8), game scoring (Advantage or No-Ad), and the match tie-break option (best of 3 only).
- **Setup event**: the match format plus the first server (Me or Opponent). Exactly one per match, always first.
- **Point event**: which player won the point (Me or Opponent), and the time it was recorded (stored, never used for state).
- **Match-ended-early event**: marks the match as unfinished. At most one; only first-server corrections may follow it.
- **First-server-corrected event**: names the player who really served first. The latest one applies.
- **Match record**: the format version plus the ordered list of events. It is the only thing that needs to be saved.
- **Match state**: everything computed from the match record: score, match status (in progress, won, unfinished), server, court side, flags, change-of-ends signal, set scores and winners.
- **Match stats**: per-player counts computed from the match record: points on serve and return, service games held, break points converted and saved.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of the acceptance scenarios in this spec pass as automated tests, and each rule-based test cites its ITF note ID.
- **SC-002**: For every prefix of at least 1,000 randomly generated valid matches (all supported formats), undo followed by re-adding the same point returns exactly the previous state. Undoing to the start returns the initial state.
- **SC-003**: Saving and restoring the event list of any of those matches reproduces the identical state, including stats, in 100% of cases.
- **SC-004**: Performance has two checks:
  - **CI:** on the macOS CI runner, a full recompute of the state and stats of a 500-point best-of-3 match from its event list takes under 10 ms (median of 10 runs). The CI test fails above this threshold.
  - **Device checklist (Denys):** on the oldest supported Apple Watch, after the app is killed during a 500-point match and relaunched, the score screen shows the restored score without a loading indicator.
- **SC-005**: Stats for 5 reference matches (one per format family: 1 set, best of 3, best of 3 with match tie-break, No-Ad, set length 4 or 8) match their expected counts exactly. At least one reference match is hand-scored by Denys (point sequence and expected stats counted by hand). The others are built by the agent, marked as agent-built in the test fixtures, and cross-checked by the SC-006 invariants.
- **SC-006**: In stats, totals are consistent for every generated match. Points served by one player equal points received by the other, and break points converted plus saved equal break points faced, per player pair.

## Assumptions

- **Coin toss:** the toss is resolved by the app before the match starts. The setup records only the resulting first server [ITF: SV-01].
- **Match tie-break in the result:** it is recorded as the deciding set, won 1–0, with its point score (e.g. "10–7"). This follows ITF MT-05 (Not covered; approved by Denys on 2026-10-12).
- **No change of ends after the match-winning point** (FR-023). This is our decision, since nothing remains to be played: ITF EN-05 (Not covered; approved by Denys on 2026-10-12).
- **Tie-break points count in serve and return stats** (FR-024). Break-point stats exclude them, per BP-02. Approved by Denys on 2026-10-12.
- **Not modelled:** officiating corrections such as Rule 27. Undo is the correction mechanism [ITF: CE-01]. The first-server correction (Story 8) is a scorekeeping fix, not Rule 27: it rewrites who served from the start, whereas Rule 27 keeps the points played and fixes the order from then on [ITF: CE-02] (Not covered; approved by Denys on 2026-10-13).
- **Early end:** a match ended early is unfinished, with no winner. Unfinished matches are excluded from head-to-head records. **Note for the iPhone feature**, which owns head-to-head; the engine only exposes the status. The engine accepts an early end at 0–0, but the watch and iPhone features MUST NOT save a 0-point unfinished match to history (**note for the watch and iPhone features**) [ITF: MT-08] (Not covered; approved by Denys on 2026-10-13).
- **Saved format:** older versions are migrated on restore. The first released version is 1. Where and when the list is saved is the apps' concern.
- **Out of scope:**
  - doubles;
  - best of 5;
  - advantage sets (no tie-break);
  - Fast4 and the 3–3 short-set tie-break (v1.1);
  - the 5-point short-set tie-break;
  - the 7-point match tie-break;
  - the final-set 10-point tie-break;
  - the alternative tie-break change-of-ends pattern [ITF: ST-02, ST-04, ST-05, MT-06, MT-07, TB-06].
- **Not part of the engine:** timing, pause, haptics, heart rate, storing the event list and sync. The engine only provides the state those features need.
- **"Me" and "Opponent"** are the only two players. Names are attached outside the engine (on the iPhone, after the match).
