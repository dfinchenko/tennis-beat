# Watch 3 — Score

![Watch 3 — Score](watch-3-score.png)

- **Figma:** node `10:24` "3 · Рахунок", 208×248 pt (PNG @2x: 416×496). The UK mock-up texts are copy drafts. EN (source) and PL go into the String Catalog later, following `docs/glossary.md`.
- **Tokens:** `../tokens.json`. **Type:** `../typography.md`.

## Layout
Black background.
- **Header row:** an Undo button (circle ≈ 44 pt, `watch/surface-raised`, back-arrow glyph) at the top left. Next to it, elapsed time "42:18" (Watch/Title, `brand/ball`, monospaced digits) and below it heart rate "♡ 142" (Watch/Footnote, `status/heart` icon, `watch/text-secondary` number).
- **Two full-width tap zones** fill the rest of the screen, opponent on top and me at the bottom. Each is a rounded card, corner radius ≈ 24:
  - Opponent zone: `watch/zone-opponent` fill. Left side: label "Суперник" (Watch/Headline, `brand/opponent`); below it, sets and games "4  2" (Watch/Number; sets in `watch/text-primary`, games in `brand/opponent`). Right side: game points "15" (Watch/Score, `brand/opponent`).
  - My zone: `watch/zone-me` fill, same structure in `brand/ball`. The tennis-ball glyph next to "Я" marks the current server.
  - **Court-side pill** (approved by Denys on 2026-10-07; not in the mock-up). A small capsule next to the server's serve icon shows which half of the court the server serves from. Only the server's zone shows it.
    - The text is «справа» / «зліва» (UK), "Right" / "Left" (EN), «z prawej» / «z lewej» (PL draft), per `docs/glossary.md`.
    - The side comes from the number of points already played in the current game, or in the current tie-break: **right** when the count is even, **left** when it is odd.
    - Rule references: [ITF SV-03](../../rules/itf-notes.md#service-and-ends) for standard games, [ITF TB-04](../../rules/itf-notes.md#tie-break-game) for tie-breaks and match tie-breaks.
- Tapping a zone scores a point for that player.

## Components
- Player tap zone (label, server glyph, sets, games, point score).
- Round icon button (Undo).
- Timer and heart-rate header.

## Texts (UK)
| Element | Text |
| --- | --- |
| Zone labels | Суперник · Я |
| Court-side pill | справа · зліва (EN: Right · Left; PL: z prawej · z lewej) |
| Example values | 42:18 · 142 · 4 2 / 6 3 · 15 / 30 |

## Notes for the spec
- The deuce/ad side indicator the plan requires is the court-side pill above.
- **Open question for Denys: the No-Ad deciding point.** At 40–40 in No-Ad, 6 points have been played, so the even/odd rule says "right". ITF NA-02, however, lets the receiver choose the half. The spec must decide what the pill shows there: for example, keep "right", show nothing, or show "receiver's choice".
- VoiceOver reads the court side together with the server.
- The server is shown with a glyph, not only colour. VoiceOver must read the server and the full score.
- The heart-rate row is hidden when there is no Health permission.
