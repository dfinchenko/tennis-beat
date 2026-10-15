# Feature Specification: Workout and Health on Apple Watch

**Feature Branch**: `feat/003-workout-health`

**Created**: 2026-10-15

**Status**: Approved (2026-10-15, Denys; re-approved with the plan-review decisions in [#28](https://github.com/dfinchenko/tennis-beat/pull/28#issuecomment-6201412560))

**Input**: User description: "Spec 003: Workout and Health on the watch, not the iPhone side (iPhone comes after persistence and sync in 004). Every match runs a workout session (activity type tennis) that keeps the app frontmost on the wrist for the whole match; it pauses with the match. Live heart rate in the score-screen header; average/max heart rate and active energy on the summary when available. The workout is saved to Health when the match ends (won or ended early). A match ended with 0 points saves no workout. Health permission onboarding on the watch before the first match; everything works without permission (no heart rate, no workout saved). Health integration is named in the UI and strings (App Review 2.5.1). Out of scope: iPhone, sync, crash recovery (spec 004). Open questions: indoor vs outdoor court; when exactly the workout ends, given that undo works after the match has ended (at the winning point or on Done); what the header shows when heart rate is unavailable. List the device-only checks."

## Overview

This feature turns every match on the watch into a tennis workout. While a match runs, a workout session keeps the app on screen when the wrist is raised, shows live heart rate in the score-screen header, and measures active energy. When the match ends, the summary shows average and maximum heart rate and active energy, and the workout is saved to the Health app. Before the first match, the watch explains what the app reads from and writes to Health and asks for permission. Without permission, the match flow of spec 002 works unchanged, with no heart rate and no workout.

The match flow itself (setup, scoring, controls, summary, Always On) is spec 002 and does not change, except where this spec says so. The workout never affects the score: the scoring engine (spec 001) knows nothing about it, and nothing in this feature changes `Packages/TennisCore`.

Screens follow the design export in [`docs/design/screens/`](../../docs/design/screens/README.md): Watch 3 (heart-rate row in the header) and Watch 6 (heart-rate and energy rows). There is no watch design for the Health onboarding: the export has only the iPhone version (iPhone 1). The watch onboarding screen is described here and added to `docs/design/screens/` in its implementation PR, as spec 002 did with its design changes.

Items marked **(Qn)** were open questions; Denys decided them on 2026-10-15. They are listed under **Decisions** at the end.

**Out of scope:** the iPhone (onboarding on iPhone 1, history, detail, stats); saving matches on the watch, sync to the iPhone and crash recovery (spec 004); heart rate in Always On; heart-rate zones, graphs or any data beyond those listed here; workouts for anything other than a match.

## User Scenarios & Testing *(mandatory)*

"Me" is the person wearing the watch. Screen names refer to spec 002 and the design export: New match, First server, Score (Watch 3), Controls (Watch 4), Always On (Watch 5), Summary (Watch 6). "Health onboarding" is the new screen of Story 1. "Workout" means the workout session the app runs during a match and the workout it saves to Health.

### User Story 1 - Decide about Health before the first match (Priority: P1)

Before the first match, the watch says what Tennis Beat reads from and saves to the Health app, and lets the player allow it or skip it.

**Why this priority**: The system asks for Health permission only once per data type. Asking with context, before the first match, is the only good chance to get it, and App Review requires the Health integration to be named clearly (guideline 2.5.1).

**Independent Test**: Install fresh, launch, and check the onboarding and the system permission sheet; then repeat choosing "Not now" and check that New match works.

**Acceptance Scenarios**:

1. **Given** the app is launched and the system permission sheet has never been shown for this app, **Then** the Health onboarding appears before New match (Q4).
2. **Given** the Health onboarding, **Then** it names the Health app, says the app saves each match as a tennis workout, reads heart rate and active energy to show them during and after the match, and keeps the data in the Health app; it offers Continue and Not now. Text scrolls when it doesn't fit.
3. **Given** the Health onboarding, **When** the player taps Continue, **Then** the system Health permission sheet appears; whatever the player answers, New match opens next.
4. **Given** the Health onboarding, **When** the player taps Not now, **Then** New match opens and no system sheet is shown; the onboarding returns on the next app launch (Q4).
5. **Given** the system permission sheet has been answered once (any answer), **Then** the Health onboarding never appears again; the player changes access in the system settings (Q4).
6. **Given** the onboarding is shown, **Then** it never blocks scoring: the remembered format and Start work exactly as in spec 002 once it is closed.

---

### User Story 2 - A match is a workout (Priority: P1)

When a match starts, a tennis workout starts with it. The app stays on screen when the wrist is raised for the whole match, pauses its workout when the match is paused, and finishes it when the match ends.

**Why this priority**: Without a workout session, watchOS returns to the watch face during a long match (spec 002, Q10): the player loses the score screen between points. This is the main reason for the feature.

**Independent Test**: With a fake workout service (no HealthKit), start, pause, resume, undo, end early and finish matches, and check the workout state after each step. On a device, play a long match and raise the wrist repeatedly (device checks).

**Acceptance Scenarios**:

1. **Given** workout permission is granted, **When** the match starts (first server chosen, or the coin-toss result confirmed), **Then** a workout with activity type tennis starts. No court type (indoor or outdoor) is set, and New match gets no extra row (Q1).
2. **Given** a workout is running, **When** the player lowers and raises the wrist at any time during the match, paused or not, **Then** the score screen (or Controls) is shown, not the watch face (device check).
3. **Given** a workout is running, **When** the player taps Pause, **Then** the workout pauses; **When** they tap Resume, **Then** it resumes. The workout's active time equals the match's elapsed time (spec 002, FR-022) to within 1 second.
4. **Given** the match is won, or ended early with at least one point played, **When** the summary opens, **Then** the workout pauses, and its end time is recorded at that moment: the winning point for a won match, the confirmed End for an early end (Q2, R1-1, R2-1).
5. **Given** the summary, **When** the player taps Undo, **Then** the match returns and the workout resumes.
6. **Given** the summary, **When** the player taps Done, **Then** the workout is saved to Health, ending at the moment the summary opened (Q2, R1-1).
7. **Given** the summary stays open for 10 minutes without Done or Undo, **Then** the workout is finished and saved as on Done, and the summary no longer offers Undo; Done still returns to New match (Q2). Without a workout (Story 5), the summary keeps Undo as in spec 002 FR-020, however long it is open (R1-2). A match whose workout failed to start or to save counts as without a workout: the summary keeps Undo, and after a failed 10-minute save Undo returns and the match continues with no workout (R3-2).
8. **Given** End is confirmed with no point in the event list (no point played, or every point undone), **Then** the match is discarded as in spec 002, and the workout is discarded: nothing is saved to Health.
9. **Given** the workout could not start (permission missing, another app's workout running, or a system error), **Then** the match starts and runs exactly as in spec 002, with no heart rate and no workout saved, and no error blocks the player (Story 5).
10. **Given** the workout ends unexpectedly during a match (a system error), **Then** the match continues unchanged, the heart-rate row disappears, and no workout is saved for that match.

---

### User Story 3 - See heart rate during the match (Priority: P2)

The score-screen header shows the current heart rate next to the elapsed time.

**Why this priority**: Useful between points, but scoring works without it.

**Independent Test**: Feed heart-rate readings through a fake workout service and check the header and its VoiceOver label; check the "no reading" states.

**Acceptance Scenarios**:

1. **Given** a workout is running and a heart-rate reading has arrived, **Then** the header shows the heart icon and the latest reading in beats per minute with monospaced digits, on the elapsed-time line, after the time (Watch 3). The status line keeps its place under the elapsed time (spec 002). The layout at the largest standard size on 40 mm is recorded in `watch-3-score.md` in the implementation PR (Q3).
2. **Given** a new reading arrives, **Then** the header shows it without animation.
3. **Given** a workout is running but no reading is available (none yet, no new reading for 30 seconds, the match is paused, or heart-rate access was not given), **Then** the header shows the heart icon and "--" (Q3).
4. **Given** no workout is running, **Then** the header has no heart-rate row (as in spec 002).
5. **Given** Always On, **Then** heart rate is not shown (Watch 5; unchanged from spec 002).
6. **Given** VoiceOver, **Then** the heart rate is read as "Heart rate, 142 beats per minute" (plural forms), and "--" is read as "Heart rate unavailable". A new reading is not announced.

---

### User Story 4 - See and keep the workout after the match (Priority: P1)

The summary shows average and maximum heart rate and active energy, and the match is saved as a tennis workout in the Health app.

**Why this priority**: Saving the workout is what the player gives Health permission for; the summary rows are its visible result.

**Independent Test**: Finish matches with a fake workout service that reports known statistics; check the summary rows, their VoiceOver labels, and that a workout is saved exactly once per finished match and never for a 0-point match.

**Acceptance Scenarios**:

1. **Given** the summary of a match with a workout, **Then** under Duration it shows "Heart rate avg / max" (e.g. "138 / 171", with the heart icon) and "Active energy" (e.g. "612 kcal", system formatting) (Q5), from the workout's own statistics over the same time span as the workout that is saved (Story 2 s6).
2. **Given** the workout has no heart-rate reading, **Then** the heart-rate row is hidden; **given** it has no active-energy value, **Then** the energy row is hidden. Duration is always shown.
3. **Given** a match without a workout (Story 5), **Then** the summary is the spec 002 summary: Duration only.
4. **Given** a won match or an early end with at least one point, **When** the workout is saved (Done, or the 10-minute timeout), **Then** exactly one tennis workout is saved to Health with: start time = match start, end time = the moment the summary opened (the winning point, or the confirmed End), the match's pauses recorded as paused intervals, no court type, and the heart rate and active energy the session measured (Q1, Q2, R1-1).
5. **Given** Undo on the summary returns to the match and the match is later won or ended again, **Then** still only one workout is saved for that match, covering the whole match; the time spent on the summary before Undo is a paused interval, and the workout ends when the summary opens for the last time.
6. **Given** a won match or an early end, **Then** the saved workout's duration in Health equals the summary's Duration to within 1 second, and its average and maximum heart rate and active energy equal the summary's values (R1-1; device check).
7. **Given** saving to Health fails (on Done, or at the 10-minute save while the summary is still open), **Then** the next New match after Done shows a one-time notice "Workout not saved to Health", dismissable with OK; the match flow is not blocked (R1-6).
8. **Given** VoiceOver on the summary, **Then** the rows read "Heart rate: average 138, maximum 171 beats per minute" and "Active energy: 612 kilocalories" (plural forms, system unit formatting).

---

### User Story 5 - Play without Health permission (Priority: P1)

A player who doesn't give Health access, or gives only part of it, keeps the full match flow.

**Why this priority**: Constitution IX: the app must work without Health permission.

**Independent Test**: Run every spec 002 scenario with the workout service reporting "not authorized", and with workouts allowed but heart rate denied.

**Acceptance Scenarios**:

1. **Given** workout saving is not allowed (Not now, or denied in the sheet or in settings), **Then** every spec 002 scenario behaves as specified there: no workout starts, the header has no heart-rate row, the summary shows Duration only, and nothing is saved to Health.
2. **Given** workout saving is allowed but heart-rate or energy reading is not, **Then** the workout runs and is saved, and the missing values show as in Story 3 s3 and Story 4 s2. (The system does not tell apps whether reading was denied, so this looks the same as "no reading yet".)
3. **Given** no workout is running, **Then** watchOS may return to the watch face with the wrist down, as accepted in spec 002 (Q10). Nothing in this feature claims otherwise.
4. **Given** permission changes in settings between matches, **Then** the next match follows the new permission; a running match keeps its state until it ends.

---

### User Story 6 - Use the Health parts with VoiceOver, larger text and any supported language (Priority: P1)

The onboarding, the heart-rate row and the summary rows work with VoiceOver, larger text on the smallest watch, and in English, Polish and Ukrainian.

**Why this priority**: Constitution X and XI.

**Independent Test**: Audit the onboarding, Score with a heart-rate reading, and the summary with both rows in each language at the largest agreed text size on the 40 mm simulator.

**Acceptance Scenarios**:

1. **Given** the onboarding, the score header with heart rate, or the summary with the new rows, **Then** each passes an accessibility audit with no missing labels, and every button is at least 44 pt tall.
2. **Given** the largest text size agreed in spec 002 (Q9) on the 40 mm watch, **Then** no text on the onboarding or the summary is truncated (screens scroll), and the score header shows the elapsed time and heart rate without truncation, without shrinking the tap zones below spec 002's layout (Q3).
3. **Given** the watch language is English, Polish or Ukrainian, **Then** every new string is in that language and follows the copy table; heart rate and energy use plural forms and system unit formatting; the Health app is named as the system names it in that language.
4. **Given** any new element, **Then** no meaning is carried by colour alone: the heart icon is always next to a text label or VoiceOver phrase.

---

### Edge Cases

- **Another app's workout is running** when a match starts: the match starts anyway; whether the other workout ends or ours fails to start is the system's decision. If ours doesn't start, Story 2 s9 applies (device check).
- **Undo from the summary after the match is won:** the match is back at match point and the workout resumes; the time on the summary is a paused interval of the workout, and the saved workout ends when the summary opens again (Q2, R1-1).
- **Early end long after the last point** (e.g. rain, then End): the time until End counts as activity unless the match was paused; the saved workout and the summary's Duration both end at the confirmed End (R1-1).
- **Summary left open, then Undo after the 10-minute save:** not possible; Undo is no longer offered once the workout is saved (Q2).
- **Undo of every point, then End:** 0 points in the event list, so the match and the workout are discarded (Story 2 s8).
- **Pause during a tie-break:** the workout pauses; the score is unaffected (spec 002).
- **Long pause (e.g. 20 minutes for rain):** the workout stays paused and the app stays on screen (device check); the saved workout records one paused interval.
- **The watch is taken off mid-match:** heart-rate readings stop and the header shows the Q3 no-reading state; the match continues. (Wrist detection may lock the watch; that is system behaviour.)
- **Heart rate above 199:** three digits fit in the header at every supported text size.
- **The app is ended by the system or crashes with a workout running:** the match is lost (crash recovery is spec 004). When watchOS relaunches the app and hands it the running workout, the app finishes it at that moment and saves it to Health as it is, whatever the number of points played, since it is real exercise (Q6). No summary is shown; New match opens. Spec 004 replaces this with resuming the workout together with the recovered match.
- **Language changes during a match:** new strings use the new language on the next draw; the workout is unaffected.
- **The iPhone is not nearby:** everything works; the workout is saved to Health on the watch and the system syncs it to the iPhone later.

## Requirements *(mandatory)*

### Functional Requirements

*Onboarding and permission*
- **FR-001**: Before New match, the app MUST show the Health onboarding once per app launch while the system Health permission sheet has never been answered for this app; after it has been answered, never again (Q4).
- **FR-002**: The onboarding MUST name the Health app, state that each match is saved as a tennis workout, state that heart rate and active energy are read to show them during and after the match, and state that the data stays in Health and nothing is sent anywhere. It MUST offer Continue (shows the system permission sheet) and Not now (no sheet).
- **FR-003**: The app MUST request permission to save workouts and to read heart rate and active energy, and nothing else.
- **FR-004**: The Info.plist permission texts MUST name the Health app and match what the app reads and saves: the read text MUST mention heart rate and active energy (it mentions only heart rate today). The iOS and watch apps share these texts, so both apps' `InfoPlist.xcstrings` and all their build configurations get the same text (R1-3). Each text changes in the catalogs first (EN, PL, UK), then the build settings (CI gate).

*Workout lifecycle*
- **FR-005**: When a match starts and workout saving is allowed, a workout with activity type tennis MUST start, with no court type set (Q1).
- **FR-006**: The workout MUST pause when the match pauses and resume when it resumes, so its active time equals the match's elapsed time to within 1 second.
- **FR-007**: The workout MUST pause when the summary opens (the winning point, or the confirmed End), with its end time recorded at that moment, and resume when Undo on the summary returns to the match. It MUST be saved on Done, or 10 minutes after the summary opened without Done or Undo, and the saved workout MUST end at the moment the summary opened (the last time, after any Undo). After that save succeeds the summary MUST NOT offer Undo. Without a workout, the summary's Undo stays as in spec 002 FR-020; a workout that failed to start or to save counts as no workout, and a failed save also shows the FR-015 notice (Q2, R1-1, R1-2, R3-2).
- **FR-008**: A match discarded with 0 points in its event list MUST NOT save a workout; its workout MUST be discarded.
- **FR-009**: A match MUST save at most one workout, from the match start to the moment the summary opened (the last time, after any Undo), with its paused intervals.
- **FR-009a**: When watchOS hands the app a running workout after the app was ended mid-match, the app MUST finish it at that moment and save it to Health as it is (Q6), then open New match.
- **FR-010**: If the workout can't start or ends unexpectedly, the match MUST continue as in spec 002, with no heart-rate row from then on and no workout saved for it. No error may block scoring.
- **FR-011**: The workout's state MUST follow the match's state only. The scoring engine MUST NOT know about the workout, and no workout event may change the score, the elapsed time or the summary's Duration.

*Heart rate and energy*
- **FR-012**: While a workout runs and a reading is available, the score header MUST show the latest heart rate (heart icon, beats per minute, monospaced digits) next to the elapsed time, and the heart icon with "--" when no reading is available: before the first one, after 30 seconds without a new one, and while paused (Q3). Without a running workout there MUST be no heart-rate row. Always On MUST NOT show heart rate.
- **FR-013**: The summary MUST show "Heart rate avg / max" and "Active energy" (kcal, system formatting) from the same statistics as the saved workout, so the summary and Health show equal values, each only when it has a value, after Duration (Q5).
- **FR-014**: Heart rate and energy values MUST be read live from the workout session and MUST NOT be written to any app storage, file or preference (constitution IX). After the match they exist only in Health.
- **FR-015**: If saving the workout fails, the next New match after Done MUST show a one-time notice that the workout was not saved to Health (R1-6).

*Accessibility and localization*
- **FR-016**: Every new string MUST come from the String Catalog in EN, PL and UK, follow the copy table, and use plural forms for beats per minute and kilocalories; numbers with units MUST use system formatting.
- **FR-017**: The onboarding, the heart-rate row and the summary rows MUST have VoiceOver labels as in Stories 3, 4 and 6, support Dynamic Type up to spec 002's Q9 limits on the 40 mm watch without truncation, and carry no meaning by colour alone.

*Scope*
- **FR-018**: This feature MUST NOT store a match, send anything to the iPhone, make network calls or change `Packages/TennisCore`. It MUST work with no iPhone nearby.

### Copy table (drafts for approval)

All rows are drafts. PL drafts go to the Polish native review ([#22](https://github.com/dfinchenko/tennis-beat/issues/22)). No string addresses the player as "ти" or "ви": the onboarding is written impersonally, so the design README's tone question doesn't arise here. The Health app is named as the system names it: "Health" (EN), «Zdrowie» (PL), «Здоров’я» (UK), as in the existing Info.plist texts.

| Where | EN (source) | PL | UK | Status |
| --- | --- | --- | --- | --- |
| Onboarding title | Matches as workouts in Health | Mecze jako treningi w Zdrowiu | Матчі як тренування в «Здоров’ї» | draft |
| Onboarding line 1 | Each match is saved as a tennis workout in the Health app. | Każdy mecz zapisuje się w aplikacji Zdrowie jako trening tenisowy. | Кожен матч зберігається в програмі «Здоров’я» як тренування з тенісу. | draft |
| Onboarding line 2 | Heart rate and active energy are shown during and after the match. | Tętno i aktywna energia są widoczne w trakcie meczu i po nim. | Пульс і активну енергію видно під час матчу й після нього. | UK approved by Denys 2026-10-15 (R1-4); rest draft |
| Onboarding line 3 | Data stays in Health. Tennis Beat sends nothing anywhere. | Dane zostają w Zdrowiu. Tennis Beat niczego nigdzie nie wysyła. | Дані лишаються в «Здоров’ї». Tennis Beat нікуди нічого не надсилає. | second sentence: EN and UK decided by Denys 2026-10-15 (R1-5), PL draft (#22); first sentence draft |
| Onboarding buttons | Continue · Not now | Dalej · Nie teraz | Продовжити · Не зараз | draft |
| Header heart rate | %d (with heart icon) | %d | %d | number only, as Watch 3 |
| Header, no reading | -- (with heart icon) | -- | -- | Q3 |
| VoiceOver: heart rate | Heart rate, %d beats per minute | Tętno, %d uderzeń na minutę (plural) | Пульс, %d ударів на хвилину (plural) | draft |
| VoiceOver: no reading | Heart rate unavailable | Tętno niedostępne | Пульс недоступний | draft |
| Summary row: heart rate | Heart rate avg / max | Tętno śr. / maks. | Пульс сер. / макс. | UK from mock-up; rest draft |
| Summary row: energy | Active energy · %@ (e.g. 612 kcal, system format) | Aktywna energia · %@ | Активна енергія · %@ | draft; replaces the mock-up's «Активні ккал» (Q5) |
| VoiceOver: summary heart rate | Heart rate: average %1$d, maximum %2$d beats per minute | Tętno: średnio %1$d, maksymalnie %2$d uderzeń na minutę | Пульс: середній %1$d, максимальний %2$d ударів на хвилину | draft; plural on %2$d |
| VoiceOver: summary energy | Active energy: %@ | Aktywna energia: %@ | Активна енергія: %@ | draft; %@ spoken in full units by the system |
| Save failure notice | Workout not saved to Health · OK | Trening nie został zapisany w Zdrowiu · OK | Тренування не збережено в «Здоров’ї» · OK | draft |
| Info.plist: read | Tennis Beat reads your heart rate and active energy to show them during and after a match. Health data stays in the Health app. | Tennis Beat odczytuje Twoje tętno i aktywną energię, aby pokazać je w trakcie meczu i po nim. Dane zdrowotne pozostają w aplikacji Zdrowie. | Tennis Beat зчитує ваш пульс і активну енергію, щоб показати їх під час матчу й після нього. Дані про здоров’я залишаються в програмі «Здоров’я». | change approved by Denys 2026-10-15; translations draft; keeps the existing formal tone |
| Info.plist: save | Tennis Beat saves your matches as tennis workouts in the Health app. | (unchanged) | (unchanged) | existing |

### Key Entities

- **Workout**: the session the app runs during a match: activity type tennis, start, pauses, end (the moment the summary opened). Its heart rate and energy live in Health. In this feature the app holds only its state in memory, and its identifier until the match is final; spec 004 links a saved match to it by that identifier.
- **Health onboarding state**: whether the system sheet has been answered (Q4). No health data.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: With permission granted, the app stays on screen at every wrist raise for a full 90-minute match including a 10-minute pause (device check).
- **SC-002**: For scripted matches covering start, pause, resume, summary Undo, the 10-minute summary timeout, early end with and without points, and a won match, the workout state after every step matches Story 2 in 100% of cases, and exactly one workout is saved per final match with points and none otherwise (automated, with a fake workout service).
- **SC-003**: The saved workout ends at the moment the summary opened, and its duration differs from the summary's Duration by no more than 1 second, for won matches and early ends (automated with a controllable clock; confirmed in Health on a device).
- **SC-004**: The first heart-rate reading appears in the header within 30 seconds of the match start with the watch worn normally (device check).
- **SC-005**: Every spec 002 UI test passes unchanged with the workout service in its "not authorized" state.
- **SC-006**: The onboarding, the score header with heart rate, and the summary with both rows pass the accessibility audit and show no truncated text at the largest agreed size on the 40 mm simulator in EN, PL and UK (screenshots in the PRs).
- **SC-007**: 100% of new strings exist in the String Catalog in EN, PL and UK, and no heart-rate or energy value is found in the app's storage after a match (test that inspects the app's stored data).

## Device-only checks

These can't be verified in the simulator; each implementation PR lists the ones it touches, and they join the device checklist in `docs/harness.md`.

1. The app stays frontmost at every wrist raise for a whole match, during play, while paused (including a pause over 10 minutes) and on the summary until the workout is saved.
2. The system permission sheet appears after Continue, and each answer leads to New match; after Not now the onboarding returns on the next launch; after the sheet has been answered, it never returns.
3. The first heart-rate reading appears within 30 seconds; the header value roughly tracks the system Workout app's heart rate in a side-by-side check (same watch, a later session).
4. The saved workout appears in the Fitness app and in Health as Tennis, starting at the match start and ending when the summary opened (the winning point or the confirmed End), with paused intervals, heart-rate graph and active energy, and counts toward the Activity rings.
5. Health's duration (Story 4 s6), average and maximum heart rate and active energy equal the summary's values.
6. Undo from the summary, then finishing the match again, leaves exactly one workout in Health.
7. A match ended with 0 points leaves no workout in Health.
8. With permission denied: a full match scores normally, there is no heart-rate row, the summary shows Duration only, and Health has no workout.
9. With workouts allowed but heart rate denied in settings: the workout is saved, the header shows the no-reading state, and the summary has no heart-rate row.
10. Starting a match while the system Workout app has a workout running: the match starts; record which workout survives.
11. Taking the watch off mid-match: the header shows the no-reading state; the match continues.
12. Battery: a 90-minute match with a workout uses an amount of battery comparable to the system Workout app's tennis workout (record the percentage).
13. Without the iPhone nearby: the workout saves on the watch and appears on the iPhone once they reconnect.
14. Ending the app mid-match (e.g. force-quit) with a workout running: on relaunch the workout is saved as it is and New match opens.
15. Leaving the summary open for 10 minutes saves the workout; Undo is gone afterwards.

## Assumptions

- **Engine:** no change to spec 001; the workout follows the app's match state (started, paused, summary, final, discarded), which spec 002 already has.
- **Summary time:** in spec 002 the time on the summary is not part of the match's elapsed time. The workout follows that: it pauses when the summary opens, its end time is recorded at that moment, and the saved workout ends at that time (Q2, R1-1, R2-1).
- **Energy unit:** the summary shows kilocalories with system formatting ("612 kcal" / «612 ккал»); the player's Health energy-unit preference (kJ) is not followed in this feature.
- **Heart-rate values on the summary** are the workout session's own statistics for the match, not a separate Health query; after the match they are read from Health by workout identifier only (spec 004 / iPhone).
- **Heart rate is not stored** anywhere by the app: the header and summary hold it in memory while shown (constitution IX).
- **Always On** keeps spec 002's layout: no heart rate (Watch 5).
- **Health permission on the iPhone** (iPhone 1) is a later spec; the watch asks on its own.
- **The first-match tap count** (spec 002, SC-001: two taps) holds from the second launch on; on first use the onboarding adds one or two taps.
- **Water Lock, auto-pause and segment markers** are not used.
- **Delivery:** after approval, implementation in small PRs: (1) Health onboarding with the permission request, (2) workout lifecycle with the fake service, saving included, (3) heart rate in the header, (4) summary rows and the save-failure notice, with the device checks each PR touches (order decided by Denys in the plan review, 2026-10-15).

## Decisions

Denys decided the open questions on 2026-10-15.

- **Q1** — No court type: the workout's indoor/outdoor value is left unset, and New match gets no extra row.
- **Q2** — A, with one change: the workout pauses when the summary opens, Undo on the summary resumes it, and Done saves it; if the summary stays open for 10 minutes, the workout is saved automatically and Undo is no longer offered. The saved workout ends at the time of the match's last point (point events carry their time), not when Done is tapped. *Superseded by R1-1 below.*
- **Q3** — While a workout runs, the header shows the heart icon and "--" before the first reading, after 30 seconds without a new one, and while paused; with no workout there is no row. Heart rate sits on the elapsed-time line, after the time.
- **Q4** — After Not now, the onboarding returns on the next app launch until the system sheet has been answered once; never again after that.
- **Q5** — Summary label "Active energy", value in kcal with system formatting.
- **Q6** — A workout left running after the app was ended mid-match is real exercise: the app finishes it and saves it as it is. In spec 004, crash recovery resumes that workout with the recovered match instead of saving it.
- **Health read text** — Adding active energy to the Info.plist read text (FR-004) is approved.

### Review 1 decisions

Denys decided the review 1 findings on 2026-10-15 ([report](https://github.com/dfinchenko/tennis-beat/pull/26#issuecomment-6196279852)).

- **R1-1** — Q2 is simplified: the workout ends when the summary opens, at the winning point for a won match and at the confirmed End for an early end (that time on court is real activity). The summary's values equal the saved workout's. The "last point's time" rule is dropped. Undo on the summary still resumes the workout (Story 2 s4–s7, Story 4 s1, s4–s6, FR-007, FR-009, FR-013, SC-003).
- **R1-2** — Without a workout, the summary keeps Undo as in spec 002 FR-020. The implementation PR adds "changed by spec 003" notes to spec 002 FR-020 and `docs/design/screens/watch-6-summary.md` (Story 2 s7, FR-007).
- **R1-3** — The new read text goes into both apps' Info.plist catalogs and build settings, since the texts are shared (FR-004).
- **R1-4** — UK onboarding line 2: «Пульс і активну енергію видно під час матчу й після нього.»
- **R1-5** — Onboarding line 3, second sentence: "Tennis Beat sends nothing anywhere." / «Tennis Beat нікуди нічого не надсилає.» / «Tennis Beat niczego nigdzie nie wysyła.» (PL draft, added to #22).
- **R1-6** — A failed save shows its notice on the next New match after Done (Story 4 s7, FR-015).

### Review 2 decisions

Denys decided these review 2 findings on 2026-10-15 ([#27 approval](https://github.com/dfinchenko/tennis-beat/pull/27#issuecomment-6199523700): "Approved, with R2-1 and R2-3"); the wording below and in Story 2 s4, FR-007, FR-009 and Assumptions is his approved decision, applied in the plan branch.

- **R2-1** — The workout pauses when the summary opens, and its end time is recorded at that moment; the saved workout ends at that recorded time, not at Done. A paused workout can resume after Undo, which an ended one can't (Story 2 s4, FR-007, Assumptions).
- **R2-3** — The moment that counts is the last time the summary opened, after any Undo (FR-007, FR-009; as Story 4 s5).

### Review 3 and plan decisions

Denys decided these on 2026-10-15 in the 003 plan review, recorded in his [#28 comment](https://github.com/dfinchenko/tennis-beat/pull/28#issuecomment-6201412560).

- **R3-2** — A match whose workout failed to start or to save counts as "without a workout": the summary keeps Undo (spec 002 FR-020); after a failed 10-minute auto-save, Undo returns; the save-failure notice follows R1-6 (Story 2 s7, FR-007).
- **R2-1, R2-3** — The wording from #27 is approved again (Review 2 decisions).
- **R5-2** — The workout ends at the later of the summary opening and HealthKit's last event (plan, research R2).
- **Copy table** — «Здоров’я» is written exactly as Apple writes it, with the typographic apostrophe.
- **Delivery order** — The onboarding PR comes first, then the workout lifecycle (Assumptions, Delivery).
- **Permissions** — As in Apple's sample: FR-003 as written (save workouts; read heart rate and active energy). Device check 4 decides; if the saved workout lacks heart-rate or energy data, a spec change to FR-003/FR-004 is opened instead of a workaround.
