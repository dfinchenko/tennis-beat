# iPhone 3 — Match detail

![iPhone 3 — Match detail](iphone-3-match-detail.png)

- **Figma:** node `11:192` "3 · Деталі матчу", 390×1099 pt (PNG @2x: 780×2198). The UK mock-up texts are copy drafts. EN (source) and PL go into the String Catalog later, following `docs/glossary.md`.
- **Tokens:** `../tokens.json`. **Type:** `../typography.md`.

## Layout
Scrolling screen on `ios/background-grouped`:
1. A round back button (≈ 44 pt, `ios/surface`).
2. Result badge "Перемога" (`brand/ball`), opponent name as the title (iOS/Title 1), and the date with the format (iOS/Subheadline, `ios/text-secondary`).
3. A head-to-head pill (`ios/surface`): "Особисті зустрічі з Олегом К. **1–1**".
4. **Score card** (`ios/surface`): a table with columns Сет 1 · Сет 2 · Тай-брейк and rows Я and opponent. Scores use iOS/Number L; the losing score in each column is in `ios/text-tertiary`.
5. **Stats card** with the header "Статистика матчу" and the note "з рахунку, без вводу". It has four comparison rows. Each row shows a centred label, my value on the left and the opponent's value on the right, with a split bar between them: mine in `brand/ball`, the opponent's in `ios/separator`.
   - Очки на подачі: 41/66 · 62% vs 37/58 · 64%
   - Очки на прийомі: 21/58 · 36% vs 25/66 · 38%
   - Утримані подачі: 7/10 vs 7/9
   - Брейк-пойнти реалізовано: 2/5 vs 3/6
6. **Health card** "Тренування з Apple Health" (heart icon in `status/heart`) with a 2×2 grid of tiles (`ios/background-grouped`): Тривалість 1:24:10 · Активні ккал 612 · Пульс середній 138 уд/хв · Пульс максимальний 171 уд/хв.
7. Buttons:
   - Primary "Поділитися результатом" (`ios/ink` fill, `brand/ball` text, share glyph).
   - Secondary "Відкрити в Apple Health" (`ios/surface`).
   - Destructive text button "Видалити матч" (`status/destructive`).

## Texts (UK)
| Element | Text |
| --- | --- |
| Meta | 28 вересня 2026 · одиночка, 2 з 3 сетів |
| Head-to-head | Особисті зустрічі з Олегом К. 1–1 |
| Stats | Статистика матчу · з рахунку, без вводу · Очки на подачі · Очки на прийомі · Утримані подачі · Брейк-пойнти реалізовано |
| Health | Тренування з Apple Health · Тривалість · Активні ккал · Пульс середній · Пульс максимальний · уд/хв |
| Buttons | Поділитися результатом · Відкрити в Apple Health · Видалити матч |

## Notes for the spec
- The stats definitions follow ITF notes BP-01..BP-03 (Not covered, pending Denys).
- The Health card is read from HealthKit by workout UUID and is hidden without permission. Nothing from it is stored.
- "Видалити матч" needs a confirmation.
- The column header «Тай-брейк» (approved spelling; the mock-up's «Тайбрейк» is superseded) is the match tie-break played instead of the deciding set (ITF MT-03).
- The opponent's name appears in the Ukrainian instrumental case ("з Олегом К.") in the head-to-head line, which needs a grammar-safe string pattern. The plan's example is "With Oleh K.: 1–1".
