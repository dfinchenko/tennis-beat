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

## Texts
The mock-up shows the UK copy. Row 2 and the row 3 value were approved by Denys on 2026-10-07 and replace the mock-up text.

| Element | UK | EN (source) | PL (draft) |
| --- | --- | --- | --- |
| Title | Новий матч | | |
| Row 1 caption / value | Формат / 2 з 3 сетів | | |
| Row 2 caption | При 40:40 | At 40–40 | Przy 40:40 |
| Row 2 values | Перевага · Вирішальне очко | Advantage · Deciding point | Przewaga · Punkt decydujący |
| Row 3 caption / value | Третій сет / Тай-брейк до 10 | | |
| Button | Почати | | |

Empty cells are written later in the String Catalog, using `docs/glossary.md` terms.

## Notes for the spec
- The plan's setup also has set length (4/6/8) and 1-set or best-of-3, but the mock-up shows no set-length row. The spec must decide where it goes.
- Row 2 chooses Advantage scoring (ITF GM-02) or No-Ad scoring (NA-01). It is captioned by the score where the two differ, not by "Game".
- Row 3 ("third set") offers the match tie-break instead of the deciding set (ITF MT-03). It applies only to best of 3, so it is hidden when Format is 1 set (ITF MT-02).
- The mock-up's «Тайбрейк» and "Advantage" are superseded by the texts above, which follow the glossary.
