# Watch 4 — Controls

![Watch 4 — Controls](watch-4-controls.png)

- **Figma:** node `10:60` "4 · Керування", 208×248 pt (PNG @2x: 416×496). The UK mock-up texts are copy drafts. EN (source) and PL go into the String Catalog later, following `docs/glossary.md`.
- **Tokens:** `../tokens.json`. **Type:** `../typography.md`.

## Layout
Black background. Elapsed time "42:18" centred at the top (Watch/Title, `brand/ball`). Below it, a 2×2 grid of round buttons (≈ 64 pt), each with a label underneath (Watch/Body, `watch/text-primary`):
| Position | Button | Fill | Glyph colour |
| --- | --- | --- | --- |
| Top left | Undo | `watch/surface-raised` | white |
| Top right | Pause | `watch/control-pause` | `brand/ball` |
| Bottom left | Server swap (⇆) | `watch/surface-raised` | white |
| Bottom right | End | `watch/control-end` | `status/end` (stop square) |

## Components
- Round control button with a label.

## Texts (UK)
| Element | Text |
| --- | --- |
| Labels | Скасувати · Пауза · Подача · Завершити |

## Notes for the spec
- "End" needs a confirmation (HIG, plan). The glossary label is "Завершити матч", shortened here to "Завершити".
- The "Подача" (manual server swap) control is not in the plan's MVP list. The spec must decide whether to keep it and how it interacts with the event log.
