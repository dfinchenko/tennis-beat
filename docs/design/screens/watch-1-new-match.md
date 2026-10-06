# Watch 1 — New match

![Watch 1 — New match](watch-1-new-match.png)

- **Figma:** node `10:3` "1 · Новий матч", 208×248 pt (PNG @2x: 416×496). The UK mock-up texts are copy drafts. EN (source) and PL go into the String Catalog later, following `docs/glossary.md`.
- **Tokens:** `../tokens.json`. **Type:** `../typography.md`.

## Layout
Black background (`watch/background`). Vertical stack with a 16 pt side inset:
1. Title "Новий матч": Watch/Large Title, `brand/ball`.
2. Three setting rows on `watch/surface`, corner radius ≈ 16. Each row has a caption (Watch/Footnote, `watch/text-secondary`) above a value (Watch/Title, `watch/text-primary`). Tapping a row opens a picker.
3. A full-width primary button "Почати": capsule, `brand/ball` fill, `brand/on-ball` text, Watch/Title.

## Components
- Setting row (caption + value), tappable.
- Primary capsule button.

## Texts (UK)
| Element | Text |
| --- | --- |
| Title | Новий матч |
| Row 1 caption / value | Формат / 2 з 3 сетів |
| Row 2 caption / value | Гейм / Advantage |
| Row 3 caption / value | Третій сет / Тайбрейк до 10 |
| Button | Почати |

## Notes for the spec
- The plan's setup also has set length (4/6/8) and 1-set or best-of-3, but the mock-up shows no set-length row. The spec must decide where it goes.
- The glossary gives "Перевага" for Advantage and "Матч-тай-брейк" for match tie-break. The mock-up uses "Advantage" and "Тайбрейк". Follow the glossary.
