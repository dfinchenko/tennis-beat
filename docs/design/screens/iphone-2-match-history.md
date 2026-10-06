# iPhone 2 — Match history

![iPhone 2 — Match history](iphone-2-match-history.png)

- **Figma:** node `11:111` "2 · Історія матчів", 390×844 pt (PNG @2x: 780×1688). The UK mock-up texts are copy drafts. EN (source) and PL go into the String Catalog later, following `docs/glossary.md`.
- **Tokens:** `../tokens.json`. **Type:** `../typography.md`.

## Layout
Grouped background (`ios/background-grouped`).
1. Large title "Матчі" (iOS/Large Title).
2. A monthly summary card (`ios/surface`, radius ≈ 24) with the month label (iOS/Subheadline Emphasized, `ios/text-secondary`) and three stats. Each stat has a number (iOS/Number L) and a caption (iOS/Subheadline, `ios/text-secondary`).
3. Section header "Останні матчі" (iOS/Headline).
4. A list card. Each row (≈ 64 pt, separators `ios/separator`) shows:
   - Opponent name (iOS/Headline).
   - Date and duration (iOS/Subheadline, `ios/text-secondary`).
   - Set scores on the right (iOS/Number S).
   - A result badge: "Перемога" on `brand/ball` with `brand/on-ball` text, or "Поразка" on `ios/separator` with `ios/text-badge` text.
   - A chevron (`ios/chevron`).
5. A floating Liquid Glass tab bar with two tabs: Матчі (selected) and Налаштування.

## Texts (UK)
| Element | Text |
| --- | --- |
| Title | Матчі |
| Summary | Вересень — 5 матчів · 3 перемоги · 6:46 год на корті |
| Section | Останні матчі |
| Row example | Олег К. — 28 вер · 1:24 — 6:4 3:6 10:7 — Перемога |
| Badges | Перемога · Поразка |
| Tabs | Матчі · Налаштування |

## Notes for the spec
- Counts need plural variations ("5 матчів", "3 перемоги"). Dates and durations use `FormatStyle`.
- The result badge has a text label, so it is not colour-only.
