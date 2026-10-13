# Feature Specification: Match on Apple Watch

**Feature Branch**: `feat/002-watch-match`

**Created**: 2026-10-13

**Status**: Draft (review 1 fixes; waiting for Denys's approval)

**Input**: User description: "Spec 002 — the match on Apple Watch. Watch match flow built on TennisCore, following docs/design/screens (setup, first server incl. coin toss, scoring, controls, Always On, summary). Setup: match length, set length 4/6/8, «При 40:40» (Перевага / Вирішальне очко), match tie-break option only for best of 3; defaults from the last match. Scoring: two full-height tap zones (opponent top, me bottom), point display, sets and games, serve icon and court-side pill (справа / зліва / на вибір), status line only for «Рівно», «Вирішальне очко», «Тай-брейк», «Матч-тай-брейк». Haptics: distinct for game, set, match; change of ends only when an added point calls for it (never on undo or correction). Controls page: undo, pause/resume (elapsed time stops), server correction, end match early with confirmation. Summary: result, set scores, duration; heart rate comes in spec 003. Always On: dimmed state as in the design. All strings via String Catalog in EN/PL/UK per docs/glossary.md; VoiceOver labels; Dynamic Type on 42 mm. Out of scope: HealthKit (003), persistence and crash recovery, sync to iPhone (004). A 0-point unfinished match is never saved. Deliver the implementation later in small PRs per screen."

## Overview

This feature is the watch app's match flow, from choosing the format to the result. The player sets up a match, chooses who serves first, keeps score by tapping one of two halves of the screen, uses a controls page to undo, pause, correct the server or end the match early, and sees a summary at the end.

All tennis logic comes from the scoring engine (spec 001). The watch app never computes a score, a server, a court side or a change of ends itself. It sends events to the engine and shows what the engine exposes. Rule references use the IDs in [`docs/rules/itf-notes.md`](../../docs/rules/itf-notes.md), written `[ITF: XX-00]`.

Screens follow the design export in [`docs/design/screens/`](../../docs/design/screens/README.md) (Watch 1–6). Where this spec departs from the export, it says so, and the design file gets the same change in the implementation PR for that screen.

Items marked **(Qn)** were open questions; Denys accepted every proposal on 2026-10-13. They are listed under **Decisions** at the end.

**Out of scope:** HealthKit, the workout session, heart rate and calories (spec 003); saving matches, history on the watch and crash recovery (a later spec); sync to the iPhone (spec 004). In this feature a match lives only while the app runs. Only the last setup choices are remembered (FR-004).

## User Scenarios & Testing *(mandatory)*

"Me" is the person wearing the watch. "Opponent" is the other player. Screen names refer to the design export: Watch 1 New match, Watch 2 First server, Watch 3 Score, Watch 4 Controls, Watch 5 Always On, Watch 6 Summary.

### User Story 1 - Set up and start a match (Priority: P1)

The player opens the app, checks or changes the format, taps Start, says who serves first (or lets the app toss a coin) and lands on the score screen.

**Why this priority**: No match can be scored without a setup. Remembering the last format makes the common case two taps.

**Independent Test**: Launch the app, change each setting, start, choose a first server, and check that the score screen opens at 0–0 with the right server. Relaunch and check that the last choices are preselected.

**Acceptance Scenarios**:

*New match (Watch 1)*
1. **Given** the app is opened for the first time, **Then** New match shows the default format: best of 3, sets of 6 games, Advantage at 40–40, deciding set played as a full set (Q2).
2. **Given** New match, **Then** it shows four setting rows (caption above value): Format (1 set / best of 3), Set length (4 / 6 / 8 games), At 40–40 (Advantage / Deciding point), Third set (Tie-break to 10 / Full set), and a Start button (Q1 the design has no set-length row).
3. **Given** Format is 1 set, **Then** the Third set row is hidden [ITF: MT-02]. **When** Format changes back to best of 3, **Then** the row reappears with its previous value.
4. **Given** a setting row, **When** the player taps it, **Then** a picker lists all its values with the current one selected; picking a value returns to New match with the row updated.
5. **Given** the player started a match with some format, **When** New match next appears (in the same run or after a relaunch), **Then** that format is preselected. The first server is never remembered.
6. **Given** a format the engine would reject (e.g. a remembered value that is no longer offered), **Then** New match falls back to the defaults for that row and never starts an invalid match.

*First server (Watch 2)* [ITF: SV-01]

7. **Given** New match, **When** the player taps Start, **Then** First server asks "Who serves first?" with three buttons: Me, Opponent, Coin toss.
8. **Given** First server, **When** the player taps Me or Opponent, **Then** the match starts with that first server and the score screen opens at 0–0, the first server marked, court side Right.
9. **Given** First server, **When** the player taps Coin toss, **Then** the app picks Me or Opponent at random with equal chance and shows the result (Q3); confirming it starts the match as in scenario 8.
10. **Given** First server, **When** the player goes back, **Then** New match shows with the settings unchanged, and no match has started. **Given** the coin-toss result, **When** the player goes back, **Then** First server shows again and no match has started; a new toss is made if Coin toss is tapped again.

---

### User Story 2 - Score points (Priority: P1)

During play the player taps the top half when the opponent wins a point and the bottom half when they win it. The screen shows the point score, sets and games for each player, who serves and from which side, and the game state when it matters.

**Why this priority**: This is the product. Everything else supports it.

**Independent Test**: Start a match, tap a known point sequence, and compare every displayed value with the engine state for the same events.

**Acceptance Scenarios**:

*Tap zones (Watch 3)*
1. **Given** the score screen, **Then** below the header the screen is split into two tap zones of equal height across the full width: Opponent on top, Me at the bottom. Each zone is one tap target over its whole area.
2. **Given** a match in progress, **When** the player taps the Me zone, **Then** one "point won by Me" is added; tapping the Opponent zone adds one "point won by Opponent". Each tap adds exactly one point.
3. **Given** the match is paused, won or ended early, **When** a zone is tapped, **Then** no point is added.

*What each zone shows*

4. **Given** any moment of the match, **Then** each zone shows the player's label (Opponent / Me), sets won, games in the current set, and the point display exactly as the engine exposes it: 0, 15, 30, 40, AD in standard games, numbers in tie-breaks. "0" is never shown as "love" [ITF: GM-01, GM-02, TB-01].
5. **Given** any moment of the match, **Then** the server's zone shows the serve icon and the court-side pill; the receiver's zone shows neither. The serve icon and the pill are never the only way the server is known: VoiceOver reads it (Story 7).
6. **Given** the court side is Right or Left, **Then** the pill reads Right / Left (EN), «справа» / «зліва» (UK), «z prawej» / «z lewej» (PL) [ITF: SV-03, TB-04].
7. **Given** the No-Ad deciding point, **Then** the pill reads Choice (EN), «на вибір» (UK), «wybór» (PL), and VoiceOver reads "Receiver chooses the side" [ITF: NA-02].

*Status line*

8. **Given** the engine's flags, **Then** a status line shows exactly one of: "Deuce" (deuce flag), "Deciding point" (deciding-point flag), "Tie-break" (tie-break flag, not a match tie-break), "Match tie-break" (match-tie-break flag). In every other state the status line is empty. The only other text that may appear in it is "Paused" (Q4, Story 4 s5): while paused, Paused replaces the game state on screen, and VoiceOver reads both ("Paused. Deuce") [ITF: GM-02, NA-01, TB-01, MT-03].
9. **Given** advantage in an Advantage game, **Then** the status line is empty; the AD point display shows the state.

*Header*

10. **Given** a match in progress, **Then** the header shows the Undo button and the elapsed match time (minutes and seconds, or hours, minutes and seconds past one hour, with monospaced digits). The heart-rate row is not shown in this feature (spec 003).

*Engine as the only source*

11. **Given** any sequence of taps, undos, corrections and pauses, **Then** every value on the score screen equals the engine's state for the same event list.

---

### User Story 3 - Feel the score without looking (Priority: P1)

The player feels a distinct haptic when a game, a set or the match is won, and a change-of-ends haptic when the players must change ends.

**Why this priority**: Players don't look at the watch between points. Haptics confirm the tap and announce the moments that matter.

**Independent Test**: Unit-test the outcome function (FR-010) with engine states before and after points that end a game, a set, the match, and that call for a change of ends; then check which haptics are requested after each tap, undo and correction.

**Acceptance Scenarios**:

1. **Given** an added point wins a game that does not win the set, **Then** the game haptic plays.
2. **Given** an added point wins a set that does not win the match (a tie-break included), **Then** the set haptic plays, not the game haptic.
3. **Given** an added point wins the match (a match tie-break included), **Then** the match haptic plays, and neither the set nor the game haptic.
4. **Given** an added point that wins no game, **Then** only the point haptic plays (Q6).
5. **Given** the engine reports that an added point calls for a change of ends, **Then** the change-of-ends haptic plays after that point's haptic (point, game or set), so both are felt as separate patterns. Example: the 6th point of a tie-break that does not end it plays the point haptic, then the change-of-ends haptic [ITF: EN-01, EN-02, EN-03, EN-04, TB-05].
6. **Given** the point that wins the match, **Then** no change-of-ends haptic plays [ITF: EN-05].
7. **Given** any undo, server correction, early end, undo of an early end, pause or resume, **Then** no game, set, match or change-of-ends haptic plays, even when the engine's exposed change-of-ends value reads "change" afterwards (spec 001, change-of-ends haptic note).
8. **Given** game, set, match and change-of-ends haptics, **Then** each is a different pattern that Denys can tell apart on a real watch without looking (device check).

---

### User Story 4 - Fix mistakes and control the match (Priority: P1)

A swipe from the score screen opens the controls page: Undo, Pause / Resume, Server (correction) and End. Undo is also on the score screen.

**Why this priority**: Mis-taps happen with wet fingers, and players stop for water. Without trustworthy undo and pause the score and the time can't be trusted.

**Independent Test**: Use each control during a match and check the engine state, the elapsed time and the screen.

**Acceptance Scenarios**:

*Navigation (Watch 4)*
1. **Given** the score screen during a match, **When** the player swipes horizontally, **Then** the controls page opens; swiping back returns to the score screen. The controls page shows the elapsed time and four round buttons with labels: Undo, Pause (Resume while paused), Server, End.

*Undo*

2. **Given** at least one event after the setup, **When** the player taps Undo (on the score screen or the controls page), **Then** the engine removes the last event (a point, a server correction or an early end) and the screen shows the resulting state. Undo has no confirmation.
3. **Given** no event after the setup, **Then** Undo is disabled (dimmed and announced as unavailable by VoiceOver) and does nothing.
4. **Given** the last point won a game, a set or a tie-break, **When** the player undoes, **Then** the previous game, set or tie-break returns with its point score, server and court side.

*Pause*

5. **Given** a match in progress, **When** the player taps Pause, **Then** the elapsed time stops, the tap zones stop adding points, and the score screen shows that the match is paused (Q4). The button changes to Resume.
6. **Given** a paused match, **When** the player taps Resume, **Then** the elapsed time continues from where it stopped and the tap zones add points again.
7. **Given** a paused match, **Then** Undo, Server and End still work, and none of them resumes the match.
8. **Given** a match paused for any length of time, **Then** the elapsed time and the summary duration exclude every paused interval.

*Server correction* [ITF: CE-02]

9. **Given** any moment of the match, **When** the player taps Server, **Then** the engine records a first-server correction to the other player: the whole match is recomputed as if that player had served first. The serve icon and court-side pill move as the engine says; the score does not change. There is no confirmation: Undo reverts it.
10. **Given** a server correction, **Then** VoiceOver announces the new server.

*End match early* [ITF: MT-08]

11. **Given** a match in progress, **When** the player taps End, **Then** a confirmation asks "End match?" with a destructive "End match" action and a Cancel action. Cancel leaves everything unchanged.
12. **Given** the confirmation, **When** the player confirms and at least one point has been played, **Then** the engine records a match-ended-early event, the elapsed time stops, and the summary opens showing an unfinished match (Story 5).
13. **Given** the confirmation, **When** the player confirms and no point has been played, **Then** the match is discarded without a summary and New match opens. A 0-point unfinished match is never kept or saved.

---

### User Story 5 - See the result (Priority: P2)

When the match is won or ended early, the summary shows the result, the set scores and the duration. Done returns to New match.

**Why this priority**: The result closes the match. It is not needed to keep score.

**Independent Test**: Finish matches in each format (and end one early) and check the title, the set chips, the duration and their VoiceOver labels.

**Acceptance Scenarios**:

1. **Given** the point that wins the match, **Then** after the match haptic the summary opens and the elapsed time stops.
2. **Given** a won match, **Then** the title reads Win if Me won the match and Loss if the Opponent won it.
3. **Given** a match ended early, **Then** the title reads "Match ended early" (Q5) and never Win or Loss.
4. **Given** the summary, **Then** a chip shows each completed set as Me's games, then the Opponent's (e.g. "6:4", "3:6"). A match tie-break shows its point score (e.g. "10:7") [ITF: MT-05]. A set won in a tie-break shows "7:6" (Q11).
5. **Given** a match ended early during a set, **Then** the unfinished set is shown as a chip with its current games and an asterisk marker (e.g. "3:2*"), and VoiceOver reads it as unfinished (Q5). **Given** it ended early during a match tie-break, **Then** the chip shows the match tie-break's point score with the marker (e.g. "7:5*") [ITF: MT-05, MT-08]. **Given** it ended early after a set was completed and before any point of the next set (or match tie-break) was played, **Then** no chip is shown for that next set.
6. **Given** set chips, **Then** sets Me lost are dimmed, and the chip order and VoiceOver carry the same meaning ("Set 2: 3–6, lost").
7. **Given** the summary, **Then** it shows Duration: the elapsed match time without pauses, formatted for the current language.
8. **Given** the summary, **Then** there are no heart-rate or calorie rows in this feature (spec 003).
9. **Given** the summary, **When** the player taps Undo (Q7), **Then** the last event is removed (the match-winning point or the early end), the score screen returns, and the elapsed time continues; the time spent on the summary is not counted.
10. **Given** the summary, **When** the player taps Done, **Then** New match opens with the last format preselected. In this feature the finished match is then gone (persistence is a later spec).

---

### User Story 6 - Glance at the score in Always On (Priority: P2)

With the wrist down, the dimmed screen still shows the score.

**Why this priority**: Players glance at the score between points, often without raising the wrist fully.

**Independent Test**: Enter the dimmed state in the simulator during a match and compare it with Watch 5; check on a real watch (device check).

**Acceptance Scenarios**:

1. **Given** the score screen enters the dimmed (Always On) state, **Then** it shows the same zones with darker fills, grey sets and games, point displays in dimmed player colours, and the elapsed time in whole minutes only (e.g. "42 min"), using the system's abbreviated minutes format for the current language.
2. **Given** the dimmed state, **Then** there are no seconds, no Undo button, no animations, no serve icon, no court-side pill and no status line (Q8).
3. **Given** the dimmed state, **When** a point is added after the wrist is raised, **Then** the full score screen is back before the tap is handled; taps are never handled in the dimmed state.
4. **Given** the dimmed state, **Then** the point displays, sets and games stay readable at arm's length (device check).

---

### User Story 7 - Use the match flow with VoiceOver, larger text and any supported language (Priority: P1)

Every screen works with VoiceOver, with larger text sizes on the smallest supported watch, and in English, Polish and Ukrainian.

**Why this priority**: Accessibility and localization are acceptance criteria for every feature (constitution X, XI).

**Independent Test**: Run every screen with VoiceOver, at the largest text sizes on the smallest simulator, and in each language; compare all strings with the glossary and the copy table.

**Acceptance Scenarios**:

1. **Given** the score screen with VoiceOver, **Then** the first element below the header is a score summary that reads the server's score first, then the server and the side, e.g. "30–15, Me serving from the right" ("advantage" for AD; on the deciding point "…, receiver chooses the side") [ITF: GM-01]. After it, each zone reads, as one element: the player, the point score, the games and sets, and whether that player serves and from which side, e.g. "Me, 30. 3 games, 1 set. Serving from the right." The action of the zone reads "Add point for Me". Exact wording is set in the copy table, with plural forms for games and sets.
2. **Given** the status line shows a state, **Then** VoiceOver reads it as part of the score, and announces it when it appears.
3. **Given** a game, set or match is won, or the server is corrected, **Then** VoiceOver announces it.
4. **Given** the change-of-ends haptic plays, **Then** VoiceOver also announces "Change ends".
5. **Given** any button or row, **Then** VoiceOver reads its label and current value (e.g. "Set length, 6 games, button").
6. **Given** the largest text size agreed in Q9 on the smallest supported watch (40 mm), **Then** no text on New match, First server, Controls or Summary is truncated or clipped (screens scroll if needed), and the score screen shows every value without truncation.
7. **Given** the watch language is English, Polish or Ukrainian, **Then** every user-facing string is in that language, follows `docs/glossary.md`, and uses plural forms where a count appears (games, minutes). Any other language shows English.
8. **Given** any screen, **Then** no meaning is carried by colour alone: the server has the serve icon and a VoiceOver phrase, lost sets have order and VoiceOver, Me and Opponent have labels and positions.

---

### Edge Cases

- **Very fast taps:** two taps in quick succession add two points; each is handled in order and the screen never shows a state the engine did not produce.
- **Tap while the summary is opening:** a tap that lands after the match-winning point adds nothing (the engine rejects it) [ITF: MT-08].
- **Undo after the match is won:** from the summary (Q7), the match is back at match point [spec 001, Story 3, scenario 3].
- **Undo of an early end:** the match is back in progress at the same score, not paused, and the elapsed time continues.
- **Server correction during a tie-break or while paused:** accepted [ITF: CE-02]. The summary has no Server control, so a correction after the match ends is not offered in this feature.
- **Pause during a tie-break:** the tie-break state, server and court side are unchanged by pause and resume.
- **Pause, then End:** the duration excludes the pause.
- **Early end at 0–0 or after only undone points:** if no point remains in the event list, the match is discarded without a summary (Story 4, scenario 13).
- **Change of ends on a game-winning point that is undone and played again:** the haptic plays again, since a point was added.
- **Long tie-breaks and long games:** point displays up to 2 digits in each zone (e.g. "15", "12") fit without truncation at every supported text size.
- **App sent to the background mid-match** (Digital Crown pressed): when it returns, the score is unchanged and the elapsed time includes the time away unless paused. If the system ends the app, the match is lost (crash recovery is out of scope) (Q10).
- **Language changes during a match:** the next time the screen is drawn it uses the new language; the match is unaffected.

## Requirements *(mandatory)*

### Functional Requirements

*Setup*
- **FR-001**: New match MUST let the player choose match length (1 set, best of 3), set length (4, 6, 8 games), scoring at 40–40 (Advantage, Deciding point) and, for best of 3 only, the third set (Tie-break to 10, Full set) [ITF: MT-01, MT-02, MT-03, ST-04, ST-06, ST-07, GM-02, NA-01].
- **FR-002**: The Third set row MUST be hidden for 1-set matches, and a 1-set match MUST never start with the match tie-break option on [ITF: MT-02].
- **FR-003**: First server MUST offer Me, Opponent and Coin toss. Coin toss MUST pick each player with equal chance and MUST show the result before the match starts [ITF: SV-01].
- **FR-004**: The last format the player started a match with MUST be preselected the next time New match appears, including after a relaunch. On first use the defaults are those in Story 1, scenario 1 (Q2). The first server MUST NOT be remembered. This is the only data this feature stores, and it contains no health data.

*Scoring and display*
- **FR-005**: The score screen MUST have two tap zones of equal height across the full width below the header: Opponent on top, Me at the bottom. A tap anywhere in a zone MUST add exactly one point for that player while the match is in progress and not paused.
- **FR-006**: Each zone MUST show the player label, sets won, games in the current set and the point display, all taken from the engine [ITF: GM-01, GM-02, NA-01, TB-01].
- **FR-007**: The server's zone MUST show the serve icon and the court-side pill (Right / Left / Choice) from the engine; the receiver's zone MUST show neither [ITF: SV-02, SV-03, TB-02, TB-04, NA-02].
- **FR-008**: The status line MUST show only "Deuce", "Deciding point", "Tie-break" or "Match tie-break", from the engine's flags, and MUST be empty otherwise. In a match tie-break it shows only "Match tie-break". The one exception is "Paused" (FR-016): while the match is paused it replaces the game state on screen, and VoiceOver reads "Paused" followed by the game state, if any.
- **FR-009**: The header MUST show an Undo button and the elapsed match time with monospaced digits.
- **FR-010**: The watch app MUST NOT compute score, server, court side, winners or change of ends itself; all of them come from the engine (spec 001). Which point, game, set and match outcome an added point produced, and whether it calls for a change of ends, MUST be derived by comparing the engine state before and after that point, in one pure function (state before, state after → point, game, set, match and change-of-ends outcomes) with its own unit tests. Haptics and announcements use only its result, so their logic is tested without UI. This comparison counts as "from the engine"; spec 001 is not changed.

*Haptics*
- **FR-011**: When an added point wins the match, the match haptic MUST play; else when it wins a set, the set haptic; else when it wins a game, the game haptic; else the point haptic (Q6). Exactly one of these plays per added point.
- **FR-012**: When the engine reports that an added point calls for a change of ends, the change-of-ends haptic MUST play after that point's haptic. It MUST NOT play for the match-winning point [ITF: EN-05], and MUST NOT play on undo, server correction, early end, undo of an early end, pause or resume.
- **FR-013**: Game, set, match and change-of-ends haptics MUST be four different patterns.

*Controls*
- **FR-014**: A controls page MUST be reachable from the score screen by a horizontal swipe and MUST offer Undo, Pause/Resume, Server and End, each with a text label under its icon, and show the elapsed time.
- **FR-015**: Undo MUST remove the last event other than the setup and MUST be disabled when there is none. Undo needs no confirmation.
- **FR-016**: Pause MUST stop the elapsed time and stop the tap zones from adding points until Resume. Undo, Server and End MUST stay available while paused. The paused state MUST be visible on the score screen as text, not colour alone (Q4).
- **FR-017**: Server MUST record a first-server correction to the player who is not the current first server, without confirmation [ITF: CE-02].
- **FR-018**: End MUST ask for confirmation. Confirming with at least one point played MUST record a match-ended-early event and open the summary. Confirming with no point played MUST discard the match and open New match without a summary [ITF: MT-08].

*Summary*
- **FR-019**: When the match is won or ended early, the elapsed time MUST stop and the summary MUST show: the title (Win / Loss / the unfinished title), a chip per set in Me–Opponent order (the match tie-break with its point score [ITF: MT-05]), and Duration. Lost sets MUST be dimmed and also identifiable without colour.
- **FR-020**: The summary MUST offer Done, which returns to New match. It MUST offer Undo (Q7), which returns to the score screen after removing the last event.

*Always On*
- **FR-021**: In the dimmed state the score screen MUST follow Watch 5: whole minutes only, no seconds, no Undo, no animations, dimmed colours, and the elements listed in Story 6, scenario 2 hidden (Q8).

*Time*
- **FR-022**: Elapsed time MUST start when the match starts (first server chosen) and MUST count wall-clock time minus pauses and minus time spent on the summary. It MUST stay correct after the app returns from the background or the screen wakes.

*Accessibility and localization*
- **FR-023**: Every user-facing string MUST come from the String Catalog in EN (source), PL and UK, follow `docs/glossary.md` and the copy table below, and use plural forms where counts appear. Durations and minutes MUST use system formatting for the current language.
- **FR-024**: Every interactive element and every score zone MUST have a VoiceOver label and value as in Story 7. Game, set and match wins, server corrections, change of ends and status-line changes MUST be announced.
- **FR-025**: All screens MUST support Dynamic Type up to the size agreed in Q9 on the smallest supported watch without truncating text. At accessibility sizes the score screen MUST keep the largest standard size. No information may be carried by colour alone.
- **FR-026**: The tap zones MUST each fill the full width and half the remaining height; no other control may overlap them.

*Scope and privacy*
- **FR-027**: This feature MUST NOT read or write health data, start a workout session, store a match or send anything to the iPhone. It MUST work with no iPhone nearby and no network.

### Copy table (drafts for approval)

Glossary terms are fixed. Rows marked *draft* are proposals for Denys; PL drafts also need a native tennis player's review (glossary status). No string addresses the player directly, so the "ти"/"ви" question in the design README does not arise in this feature.

| Where | EN (source) | PL | UK | Status |
| --- | --- | --- | --- | --- |
| New match title | New match | Nowy mecz | Новий матч | draft (UK from mock-up) |
| Format caption / values | Format / 1 set · Best of 3 | Format / 1 set · 2 z 3 setów | Формат / 1 сет · 2 з 3 сетів | draft (UK from mock-up) |
| Set length caption / value | Set length / %d games | Długość seta / %d gemów (plural) | Довжина сету / %d геймів (plural) | draft (Q1) |
| At 40–40 caption / values | At 40–40 / Advantage · Deciding point | Przy 40:40 / Przewaga · Punkt decydujący | При 40:40 / Перевага · Вирішальне очко | approved 2026-10-07 |
| Third set caption / values | Third set / Tie-break to 10 · Full set | Trzeci set / Tie-break do 10 · Pełny set | Третій сет / Тай-брейк до 10 · Повний сет | UK "Тай-брейк до 10" approved; rest draft |
| Start | Start | Start | Почати | draft (UK from mock-up) |
| First server title | Who serves first? | Kto serwuje pierwszy? | Хто подає першим? | draft (UK from mock-up) |
| Players | Me · Opponent | Ja · Przeciwnik | Я · Суперник | Opponent glossary; Me draft |
| Coin toss / result | Coin toss / First server: %@ | Losowanie / Pierwszy serwuje: %@ | Жеребкування / Першим подає: %@ | Coin toss glossary; result draft (Q3) |
| Court-side pill | Right · Left · Choice | z prawej · z lewej · wybór | справа · зліва · на вибір | approved (glossary) |
| Status line | Deuce · Deciding point · Tie-break · Match tie-break | Równowaga · Punkt decydujący · Tie-break · Super tie-break | Рівно · Вирішальне очко · Тай-брейк · Матч-тай-брейк | glossary |
| Paused indicator | Paused | Pauza | Пауза | draft (Q4) |
| Controls | Undo · Pause · Resume · Server · End | Cofnij · Pauza · Wznów · Serwis · Zakończ | Скасувати · Пауза · Продовжити · Подача · Завершити | Undo, Pause glossary; rest draft (UK from mock-up) |
| End confirmation | End match? / End match | Zakończyć mecz? / Zakończ mecz | Завершити матч? / Завершити матч | glossary-based draft; Cancel is the system button |
| Summary titles | Win · Loss · Match ended early | Wygrana · Porażka · Mecz przerwany | Перемога · Поразка · Матч перервано | Win/Loss glossary; unfinished draft (Q5) |
| Summary row / button | Duration · Done | Czas trwania · Gotowe | Тривалість · Готово | draft (UK from mock-up) |
| Always On time | %d min (system abbreviated format) | %d min | %d хв | system formatting |
| VoiceOver: choice pill | Receiver chooses the side | Stronę wybiera odbierający | Сторону обирає приймаючий | approved 2026-10-12 |
| VoiceOver: change ends | Change ends | Zmiana stron | Зміна сторін | glossary |
| Point display: advantage | AD | AD | AD | decided by Denys 2026-10-13 (glossary): "AD" on screen in all languages |
| VoiceOver: advantage | advantage | przewaga | перевага | decided by Denys 2026-10-13 (glossary) |
| VoiceOver: score summary | %1$@–%2$@, %3$@ serving from the right / left | %1$@–%2$@, serwuje %3$@, z prawej / z lewej | %1$@–%2$@, подає %3$@, справа / зліва | draft (R1-1); server's score first |
| VoiceOver: score summary, deciding point | %1$@–%2$@, %3$@ serving, receiver chooses the side | %1$@–%2$@, serwuje %3$@, stronę wybiera odbierający | %1$@–%2$@, подає %3$@, сторону обирає приймаючий | draft (R1-1) |
| VoiceOver: zone | %1$@, %2$@. %3$d games, %4$d sets. Serving from the right / left. | %1$@, %2$@. %3$d gemy, %4$d sety. Serwuje z prawej / z lewej. | %1$@, %2$@. %3$d гейми, %4$d сети. Подає справа / зліва. | draft; games and sets use plural forms |
| VoiceOver: zone action | Add point for %@ | Dodaj punkt: %@ | Додати очко: %@ | draft |
| VoiceOver: announcements | Game: %@ · Set: %@ · Match: %@ · Server: %@ | Gem: %@ · Set: %@ · Mecz: %@ · Serwuje: %@ | Гейм: %@ · Сет: %@ · Матч: %@ · Подає: %@ | draft; %@ is the winner or the new server |
| VoiceOver: paused | Paused. %@ | Pauza. %@ | Пауза. %@ | draft (R1-3); %@ is the game state, omitted if none |
| VoiceOver: set chip | Set %1$d: %2$d–%3$d, won / lost / unfinished | Set %1$d: %2$d–%3$d, wygrany / przegrany / niedokończony | Сет %1$d: %2$d–%3$d, виграний / програний / незавершений | draft (Q5, R1-2) |
| Coin-toss result button | Start | Start | Почати | same string as Start |

### Key Entities

- **Match format choice**: the four setup values (match length, set length, scoring at 40–40, third set). The last one used is remembered on the watch.
- **Current match**: the engine's event list for the match being played, plus its timing (start, pauses). Held in memory only in this feature.
- **Match timing**: when the match started, each pause and resume, and when it ended. Used for elapsed time and duration; never sent to the engine.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: From opening the app with the remembered format, a match starts in 2 taps (Start, then Me or Opponent).
- **SC-002**: For scripted tap sequences covering every format (1 set, best of 3, with and without match tie-break, set lengths 4, 6 and 8, Advantage and No-Ad), every value on the score screen equals the engine state after every tap, undo and correction (automated UI-level tests on the watch simulator).
- **SC-003**: Over the same sequences, the haptic requested after each event matches Story 3 in 100% of cases, including no change-of-ends haptic on undo, server correction or the match-winning point.
- **SC-004**: Elapsed time and duration differ from wall-clock time minus pauses by no more than 1 second over a scripted 30-minute match with pauses (automated with a controllable clock).
- **SC-005**: Every screen passes an accessibility audit on the watch simulator with no missing labels, and every screen is readable with no truncated text at the largest agreed text size on the 40 mm watch simulator (the smallest supported watch), in all three languages (screenshots in the PRs).
- **SC-006**: 100% of user-facing strings exist in the String Catalog in EN, PL and UK, and every tennis term matches `docs/glossary.md`.
- **SC-007**: Device checks (Denys, real watch): a player can score a full set without looking at the screen between points, relying on haptics; the four haptics are told apart; the score is readable in Always On at arm's length; Undo after a mis-tap takes under 3 seconds.

## Assumptions

- **Engine:** spec 001 (merged, `Packages/TennisCore`) provides everything the screens show, including the per-point change-of-ends value. If the engine lacks something this feature needs, that is a change to spec 001 proposed to Denys, not logic in the app.
- **Navigation:** the controls page sits next to the score screen and is reached by a horizontal swipe, like the system Workout app. Setup, first server and summary are full screens with no swipe pages.
- **Server button:** "Server" on the controls page is the first-server correction of spec 001 Story 8 [ITF: CE-02], not a Rule 27 order-of-service fix [ITF: CE-01]. This resolves the design README note on the "Подача" control.
- **Active kcal** on Watch 6 is not part of this feature; it is decided with HealthKit in spec 003.
- **Heart-rate row** on Watch 3 and Watch 6 is hidden in this feature; spec 003 adds it.
- **No-Ad and Advantage** are named "At 40–40: Advantage / Deciding point" as approved for Watch 1 (2026-10-07).
- **Accidental-tap protection** (screen lock) is roadmap v1.1 and not in this feature.
- **Persistence:** the remembered format choice is stored on the watch; the match itself is not. The rule "a 0-point unfinished match is never saved" is met here by never keeping it (FR-018), and the persistence spec must keep it.
- **Always On without a workout session:** until spec 003 starts a workout session, watchOS may return to the watch face after the wrist is lowered, so Always On and staying in the app during a long match can only be fully checked on a device after 003 (Q10).
- **Delivery:** after this spec is approved, implementation comes in small PRs per screen: (1) New match and First server, (2) Score screen with haptics, (3) Controls, (4) Summary, (5) Always On. Each PR carries screenshots and device checks.

## Decisions

Denys accepted all proposals on 2026-10-13 ("all as proposed").

- **Q1** — Set length is its own row, "Set length", second in the list. The design export gains this row in the New match implementation PR.
- **Q2** — First-use defaults: best of 3, sets of 6, Advantage, third set as a full set.
- **Q3** — Coin toss shows the result on its own screen ("First server: Opponent") with one Start button.
- **Q4** — While paused, "Paused" appears in the status line position and the zones are dimmed. This is the only exception to FR-008's four game states.
- **Q5** — Unfinished match title: "Match ended early" / «Матч перервано» / «Mecz przerwany». The unfinished set is a chip with an asterisk marker, e.g. "3:2*", and VoiceOver reads "unfinished".
- **Q6** — A light point haptic plays on every added point that wins no game.
- **Q7** — The summary has a secondary Undo button under Done. The design export gains this button in the Summary implementation PR.
- **Q8** — Always On hides the serve icon, the court-side pill and the status line.
- **Q9** — Dynamic Type on the score screen goes up to the largest standard (non-accessibility) size, and at accessibility sizes the score screen keeps that largest standard size; the other screens support every size and scroll. The smallest target is the smallest watch watchOS 26 supports, 40 mm (Series 6 / SE); the request's 42 mm came from an outdated note (confirmed by Denys on 2026-10-13). Layout checks run on the 40 mm simulator; real-device checks run on Denys's own watch.
- **Q10** — Without a workout session the app may return to the watch face with the wrist down, and the match is lost if the system ends the app. Accepted for 002; spec 003 adds the workout session.
- **Q11** — A set won in a tie-break shows "7:6", as designed.

### Review 1 decisions

Denys accepted all proposals for the review 1 findings on 2026-10-13 ([report](https://github.com/dfinchenko/tennis-beat/pull/15#issuecomment-6153690461)), with two notes (R1-4, R1-7).

- **R1-1** — A VoiceOver score summary before the zones reads the server's score first (Story 7 s1) [ITF: GM-01].
- **R1-2** — An early end during a match tie-break shows its point score with the marker ("7:5*"); no chip for a set with no points played (Story 5 s5).
- **R1-3** — "Paused" is the one exception to FR-008; it replaces the game state on screen, and VoiceOver reads both.
- **R1-4** — Point, game, set, match and change-of-ends outcomes come from one pure function over the engine states before and after a point, with its own unit tests; haptics are tested without UI (FR-010).
- **R1-5** — A server correction after the match ends is not offered (edge cases).
- **R1-6** — The change-of-ends haptic follows the point's haptic, whatever it is (Story 3 s5).
- **R1-7** — Missing strings added to the copy table as drafts. The point display shows "AD" in all three languages; VoiceOver reads "advantage" / «przewaga» / «перевага» (added to `docs/glossary.md`).
- **R1-8** — Always On minutes use the system's abbreviated format; no plural claim.
- **R1-9** — Design export changes land in each screen's implementation PR.
- **R1-10** — At accessibility sizes the score screen keeps the largest standard size (Q9, FR-025).
- **R1-11** — The harness device check names the Q9 limits.
- **R1-12** — Back from the coin-toss result returns to First server (Story 1 s10).
