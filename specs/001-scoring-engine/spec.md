# Feature Specification: Scoring engine

**Feature Branch**: `feat/001-scoring-engine`

**Created**: 2026-10-07

**Status**: Draft

**Input**: User description: "Scoring engine in Packages/TennisCore (pure Swift; no UI, HealthKit or persistence). A match is an ordered list of Codable events: setup (format, first server) and pointWon(by: me | opponent). State is a pure reduction of events. Undo removes the last event and works across game/set boundaries and after the match has ended. Formats: singles; 1 set or best of 3; set length 4, 6 or 8 games; Advantage or No-Ad; tie-break at N–N (ST-04, ST-06; 7-point tie-break); optional 10-point match tie-break instead of the deciding set, only for best of 3 (MT-02). State exposes: point display per player (0/15/30/40/AD; numbers in tie-breaks), games, sets, set and match winner, current server, serving court side (right when points already played in the current game or tie-break are even, left when odd; at the No-Ad deciding point it is "receiver's choice", NA-02), flags for deuce, deciding point, tie-break and match tie-break, and change-of-ends events (Rule 10, EN-02, EN-04; a set won in a tie-break has 2N+1 games, so ends change after it). Serve rotation: alternate each game; in a tie-break the first server serves one point, then two each; the player who served first in a tie-break receives first in the next set. Derived stats: points won on serve and on return, service games held (BP-03), break points converted and saved (BP-01, BP-02; tie-break points are never break points). Every rule references its ID in docs/rules/itf-notes.md. Acceptance criteria list these edge cases as testable scenarios."

## Overview

The scoring engine is the part of Tennis Beat that knows the rules of tennis. The watch app tells it who won each point. The engine answers everything the score screen, haptics, history and stats need: the score, who serves and from which side of the court, when the players change ends, who won, and the match stats.

A match is recorded as an ordered list of events: one **setup** event (the format and the first server), then one **point won** event per point (by **Me** or by the **Opponent**). Every answer is computed from that list alone. Recording the list is therefore enough to restore a match exactly after a crash or relaunch, to undo any number of points, and to recompute stats later.

Every rule in this spec cites its ID in [`docs/rules/itf-notes.md`](../../docs/rules/itf-notes.md), written `[ITF: XX-00]`. Entries whose origin is *Not covered* are product decisions approved by Denys.

Out of scope: user interface, haptics, HealthKit, timing and pause, storage of the event list, and sync. The engine is used by both apps but depends on none of them.

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

A player who taps the wrong zone can undo, as many times as needed, even across game and set boundaries and after the match has ended. If the app is killed mid-match, the match comes back exactly as it was.

**Why this priority**: Mis-taps happen on court with wet fingers. Without reliable undo, the score can't be trusted. Crash recovery is on the device checklist.

**Independent Test**: For any event list, undo must give the same state as rebuilding from scratch with the last point removed, and restoring a saved event list must give the identical state.

**Acceptance Scenarios**:

1. **Given** any match with at least one point, **When** the player undoes, **Then** the last point is removed and the state equals the state computed from the remaining events. This applies to every exposed value, including server, court side, flags, change-of-ends and stats.
2. **Given** Me just won set 1 6–4 and set 2 is at 0–0, **When** the player undoes, **Then** set 1 is back in progress at 5–4 with the game score before the last point, and the set-1 winner is cleared.
3. **Given** the match has ended, **When** the player undoes, **Then** the match is back in progress at match point, the match winner is cleared, and new points can be added.
4. **Given** a tie-break at 6–6 in points, **When** the player undoes, **Then** the tie-break score is 6–5 or 5–6 with the server and court side for that point.
5. **Given** the first point of the match was just played, **When** the player undoes, **Then** the state is the start of the match: 0–0, the first server serving, from the right.
6. **Given** only the setup event (no points), **When** the player undoes, **Then** nothing changes. Undo never removes the setup.
7. **Given** the last point triggered a change of ends, **When** the player undoes, **Then** the state no longer reports that change of ends.
8. **Given** any recorded event list, **When** it is saved and restored (encoded and decoded), **Then** the restored list is identical and produces the identical state.
9. **Given** the match has ended, **When** a further point is submitted, **Then** it is rejected and the state is unchanged.
10. **Given** an event list without a setup event, or with a second setup event, **Then** it is rejected as invalid.

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

---

### User Story 5 - Change ends at the right time (Priority: P2)

The watch reminds the players to change ends with a haptic. The engine reports, after each point, whether the players must change ends now.

**Why this priority**: It's a convenience, not part of the score itself, but players expect it and it's on the device checklist.

**Independent Test**: Feed point sequences and check the change-of-ends signal after each point.

**Acceptance Scenarios**:

1. **Given** a set in progress, **When** a game ends and the number of games played in that set becomes odd (1, 3, 5, …), **Then** a change of ends is reported [ITF: EN-01].
2. **Given** a set that ends with an even total of games (e.g. 6–4 = 10), **Then** no change of ends is reported at the end of the set. The change comes after game 1 of the next set [ITF: EN-02].
3. **Given** a set that ends with an odd total of games (e.g. 6–3 = 9), **Then** a change of ends is reported at the end of the set [ITF: EN-02].
4. **Given** a set won in a tie-break, **Then** its total is 2N+1 games (7–6 = 13, 5–4 = 9, 9–8 = 17), and a change of ends is reported after it. This is an explicit test case for each set length [ITF: EN-03, EN-04].
5. **Given** a tie-break, **When** the total number of tie-break points played reaches 6, 12, 18, … and the tie-break has not ended, **Then** a change of ends is reported [ITF: TB-05].
6. **Given** a tie-break whose final point is also a multiple of 6 (e.g. 7–5 = 12 points), **Then** exactly one change of ends is reported for that point (the end-of-set change), not two [ITF: TB-05, EN-03].
7. **Given** best of 3 with the match tie-break option, set 2 won in a tie-break (2N+1 games for set length N, e.g. 7–6, 5–4 or 9–8), **Then** a change of ends is reported after set 2, before the match tie-break, for each set length [ITF: EN-03, EN-04].
8. **Given** best of 3 with the match tie-break option, set 2 won with an even total of games (e.g. 6–4, 4–2, 8–6), **Then** no change of ends is reported before the match tie-break; the first change comes after 6 match-tie-break points [ITF: EN-02, EN-04, TB-05].
9. **Given** the point that wins the match, **Then** no change of ends is reported [ITF: EN-05].

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
9. **Given** advantage receiver, **When** the receiver wins the point, **Then** that break point is converted, and the receiver's break points converted read 1/1 for that point.
10. **Given** an Advantage game with several deuces, **Then** every advantage to the receiver counts as a separate break point.
11. **Given** a tie-break point, **Then** it is never a break point, whatever the score.
12. **Given** any match, **Then** each player's break points converted equal the other player's break points faced minus break points saved.

---

### Edge Cases

- **Undo across boundaries:** undo across game, set and tie-break boundaries, across the start of the match tie-break, and after the match ends (Story 3).
- **Undo at the start:** with no points played, undo is a no-op (Story 3, scenario 6).
- **Point after the match ends:** rejected, and the state is unchanged (Story 3, scenario 9).
- **Invalid setup:** set length other than 4, 6 or 8; match tie-break with a 1-set match; missing or repeated setup. All are rejected (Story 1, scenario 19; Story 3, scenario 10).
- **Long games and tie-breaks:** unlimited deuces and unlimited tie-break length (Story 1, scenario 7; Story 4, scenario 3).
- **Deciding point:** court side is "receiver's choice", and the point is a break point (Story 2, scenario 12; Story 6, scenario 7).
- **Change of ends at the end of a tie-break:** only one change when the final tie-break point is also a multiple of 6 (Story 5, scenario 6).
- **Ends before the match tie-break:** depends on whether set 2's game total is odd or even (Story 5, scenarios 7 and 8).
- **Server after a tie-break set:** the next set starts with the tie-break's first receiver serving (Story 2, scenario 5), including into the match tie-break (scenario 7).
- **Set-length boundaries:** 4–2 and 5–3 win, 4–3 continues (N = 4). 8–6 and 9–7 win, 8–7 continues (N = 8).
- **Very long matches:** a best-of-3 match of up to 500 points restores and undoes correctly (Success Criteria).

## Requirements *(mandatory)*

### Functional Requirements

*Events and state*
- **FR-001**: A match MUST be represented as an ordered list of events. The first and only setup event fixes the format and the first server. Every following event is "point won by Me" or "point won by Opponent".
- **FR-002**: Every value the engine exposes MUST be computed from the event list alone. The same event list MUST always produce the same state.
- **FR-003**: The event list MUST be savable and restorable without loss. A restored list MUST produce the identical state.
- **FR-004**: Undo MUST remove the last point event. The resulting state MUST equal the state computed from the shortened list. Undo with no point events MUST change nothing, and undo MUST never remove the setup.
- **FR-005**: The engine MUST reject an event list that lacks a setup event or has more than one, a setup with an unsupported format, and any point after the match has ended. Rejected input MUST leave the state unchanged.

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
  - the winner of each completed set, and the match winner once the match is over;
  - the current server;
  - the serving court side;
  - flags for deuce, deciding point, tie-break and match tie-break;
  - whether the players must change ends after the last point.
- **FR-015**: The deuce flag MUST be on only in Advantage games at equal scores of 3 or more points each. The deciding-point flag MUST be on only in No-Ad games at 3–3 [ITF: GM-02, NA-01].

*Service and court side*
- **FR-016**: The first server from the setup MUST serve game 1. After every standard game, the other player MUST serve the next game, across set boundaries too [ITF: SV-01, SV-02].
- **FR-017**: In a tie-break (including a match tie-break), the player due to serve MUST serve the first point. After that, the server MUST change after points 1, 3, 5, … (one point, then two each) [ITF: TB-02, MT-04].
- **FR-018**: After a set decided by a tie-break, the player who served first in that tie-break MUST receive in the first game of the next set. The same rule decides the first server of a match tie-break that follows a tie-break set [ITF: TB-03, SV-04, MT-04].
- **FR-019**: The serving court side MUST be:
  - Right when the number of points already played in the current game or tie-break is even, Left when it is odd [ITF: SV-03, TB-04];
  - "receiver's choice" on the No-Ad deciding point [ITF: NA-02].

*Change of ends*
- **FR-020**: A change of ends MUST be reported after a game that makes the number of games played in the current set odd. That covers the end of a set with an odd total, including every set won in a tie-break (2N+1 games) [ITF: EN-01, EN-02, EN-03, EN-04].
- **FR-021**: During a tie-break or match tie-break, a change of ends MUST be reported after every 6th point (6, 12, 18, …). When the tie-break's final point coincides with this, exactly one change of ends MUST be reported [ITF: TB-05].
- **FR-022**: Before a match tie-break, ends MUST change only if set 2 ended with an odd total of games [ITF: EN-04].
- **FR-023**: No change of ends MUST be reported after the point that wins the match [ITF: EN-05].

*Stats*
- **FR-024**: For each player the engine MUST provide points won on serve and points won on return, each as won/played, including tie-break points.
- **FR-025**: For each player the engine MUST provide service games held, as held/played. It counts completed standard games only; tie-breaks are excluded [ITF: BP-03].
- **FR-026**: For each player the engine MUST provide:
  - break points converted, as converted/opportunities, as the receiver;
  - break points saved, as saved/faced, as the server.
  A break point is any point in a standard game where the receiver wins the game by winning that point, including the No-Ad deciding point. Tie-break points are never break points [ITF: BP-01, BP-02].
- **FR-027**: Stats MUST be available at any moment of the match, counting only what has happened so far, and MUST follow undo exactly.

*Traceability*
- **FR-028**: Every rule-based test MUST cite the ITF note ID it checks (`// ITF: <ID>`), and every scenario in this spec MUST be covered by at least one test.

### Key Entities

- **Match format**: match length (1 set or best of 3), set length (4, 6 or 8), game scoring (Advantage or No-Ad), and the match tie-break option (best of 3 only).
- **Setup event**: the match format plus the first server (Me or Opponent). Exactly one per match, always first.
- **Point event**: which player won the point (Me or Opponent).
- **Match record**: the ordered list of events. It is the only thing that needs to be saved.
- **Match state**: everything computed from the match record: score, server, court side, flags, change-of-ends signal, set scores and winners.
- **Match stats**: per-player counts computed from the match record: points on serve and return, service games held, break points converted and saved.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of the acceptance scenarios in this spec pass as automated tests, and each rule-based test cites its ITF note ID.
- **SC-002**: For every prefix of at least 1,000 randomly generated valid matches (all supported formats), undo followed by re-adding the same point returns exactly the previous state. Undoing to the start returns the initial state.
- **SC-003**: Saving and restoring the event list of any of those matches reproduces the identical state, including stats, in 100% of cases.
- **SC-004**: For a best-of-3 match of up to 500 points, computing the full state from the saved events takes under 50 ms on the oldest supported Apple Watch. A crash-restored match shows the same score instantly to the player.
- **SC-005**: Stats for 5 hand-scored reference matches (one per format family: 1 set, best of 3, best of 3 with match tie-break, No-Ad, set length 4 or 8) match the hand counts exactly.
- **SC-006**: In stats, totals are consistent for every generated match. Points served by one player equal points received by the other, and break points converted plus saved equal break points faced, per player pair.

## Assumptions

- **Coin toss:** the toss is resolved by the app before the match starts. The setup records only the resulting first server [ITF: SV-01].
- **Match tie-break in the result:** it is recorded as the deciding set, won 1–0, with its point score (e.g. "10–7"). This follows ITF MT-05 (Not covered; approved by Denys on 2026-10-12).
- **No change of ends after the match-winning point** (FR-023). This is our decision, since nothing remains to be played: ITF EN-05 (Not covered; approved by Denys on 2026-10-12).
- **Tie-break points count in serve and return stats** (FR-024). Break-point stats exclude them, per BP-02. Approved by Denys on 2026-10-12.
- **Not modelled:** officiating corrections such as Rule 27. Undo is the correction mechanism [ITF: CE-01].
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
