# Watch 6 — Summary

![Watch 6 — Summary](watch-6-summary.png)

- **Figma:** node `10:117` "6 · Підсумок", 208×248 pt (PNG @2x: 416×496). The UK mock-up texts are copy drafts. EN (source) and PL go into the String Catalog later, following `docs/glossary.md`.
- **Tokens:** `../tokens.json`. **Type:** `../typography.md`.

## Layout
Black background.
1. The result title "Перемога" (Watch/Large Title, `brand/ball`).
2. A row of set-score chips ("6:4", "3:6", "10:7") on `watch/surface-raised`. Sets I lost use `watch/text-tertiary`; sets I won use `watch/text-primary`.
3. Key–value rows: label (Watch/Body, `watch/text-secondary`) on the left, value (Watch/Number style, right-aligned) on the right:
   - Тривалість: 1:24:10
   - Пульс сер. / макс.: 138 / 171 (`status/heart`)
   - Активні ккал: 612
4. A primary capsule button "Готово" (`brand/ball`).

## Changes by spec 002
- **Undo under Done** (changed by spec 002, Q7, Story 5 s9): a secondary capsule button "Undo" («Скасувати», «Cofnij») on `watch/surface-raised` under Done. It removes the match-winning point or the early end and returns to the score screen; the time on the summary is not counted. *Changed by spec 003 (FR-007, R1-2, R3-2):* with a workout, Undo is hidden once the workout save starts (Done, or the summary left open for 10 minutes) and stays gone after the save; if the save fails it shows again. Without a workout it is always shown.
- **Unfinished chip** (changed by spec 002, Q5, Story 5 s5): after an early end during a set, a chip with the current games and an asterisk ("3:2*"); during a match tie-break, its points ("7:5*"). VoiceOver reads it as unfinished. No chip for a set in which no point was played.
- **Title** for an early end: "Match ended early" («Матч перервано», «Mecz przerwany»), never Win or Loss (Story 5 s3).
- **VoiceOver chips** (Story 5 s6, R2-4): "Set 2: 3–6, lost"; a match tie-break reads "Match tie-break: 10–7, won".
- The chips wrap at large text sizes, and the whole summary scrolls.

## Changes by spec 003
- **Heart-rate and energy rows** (changed by spec 003, FR-013, Story 4 s1–s3): under Duration, "Heart rate avg / max" · ♥ 138 / 171 (`status/heart` icon before the numbers) and "Active energy" · 612 kcal, laid out like Duration (label left, value right; stacked when they don't fit). The values are the workout's own statistics, the same as in Health. A row without a value is hidden; without a workout (no permission, or it failed) the summary shows Duration only, as in spec 002.
- **"Active energy"** («Активна енергія», «Aktywna energia») replaces the mock-up's «Активні ккал» (Q5); the value is in kilocalories with the system's unit format ("612 kcal", «612 ккал»).
- **VoiceOver**: each row is one element of at least 44 pt: "Heart rate: average 138, maximum 171 beats per minute", "Active energy: 612 kilocalories" (Story 4 s8).
- Row order: title, chips, Duration, Heart rate, Active energy, Done, Undo (contract §3).

## Texts (UK)
| Element | Text |
| --- | --- |
| Title | Перемога / Поразка |
| Rows | Тривалість · Пульс сер. / макс. · Активна енергія (spec 003, Q5; the mock-up's «Активні ккал» is replaced) |
| Buttons | Готово · Скасувати (spec 002) |

## Notes for the spec
- The match tie-break is shown as a "10:7" chip (see ITF MT-05, a Not covered decision).
- The heart-rate and calories rows come from HealthKit and are hidden without permission. Active kcal is not in the plan's summary list (duration and average/max heart rate), so the spec must confirm it.
- Lost sets are dimmed, but the chip order also carries the meaning, and VoiceOver must read the full scores.
