# Typography

Exported on 2026-10-06 via `use_figma` from the local text styles in Figma file `A1oDA98m8ErPUKbIwN465y`.

Figma uses **Inter** as a stand-in because SF is not available to the Figma agent. **Production uses the system font** named in each style's description:
- SF Compact on watchOS, SF Pro on iOS.
- Numbers use the `.rounded` design.
- Use SwiftUI text styles (`.font(.title3)` etc.) or `.system(size:weight:design:)` so Dynamic Type works.
- Use monospaced digits (`.monospacedDigit()`) for scores and timers.

For every style: line height is Auto (Score: 100%), letter spacing is 0%, case is Original, there is no decoration, and paragraph spacing is 0.

## Apple Watch
| Style | Production font | Size (pt) | Weight | Figma stand-in |
| --- | --- | --- | --- | --- |
| Watch/Large Title | SF Compact | 20 | Bold | Inter Bold |
| Watch/Title | SF Compact | 17 | Semibold | Inter Semi Bold |
| Watch/Headline | SF Compact | 15 | Semibold | Inter Semi Bold |
| Watch/Body | SF Compact | 15 | Regular | Inter Regular |
| Watch/Footnote | SF Compact | 13 | Regular | Inter Regular |
| Watch/Label | SF Compact | 13 | Semibold | Inter Semi Bold |
| Watch/Caption | SF Compact | 11 | Regular | Inter Regular |
| Watch/Score | SF Compact Rounded (`.rounded`) | 48 | Bold | Inter Bold, line height 100% |
| Watch/Number | SF Compact Rounded (`.rounded`) | 15 | Semibold | Inter Semi Bold |

## iPhone
| Style | Production font | Size (pt) | Weight | Figma stand-in |
| --- | --- | --- | --- | --- |
| iOS/Large Title | SF Pro | 34 | Bold | Inter Bold |
| iOS/Title 1 | SF Pro | 28 | Bold | Inter Bold |
| iOS/Headline | SF Pro | 17 | Semibold | Inter Semi Bold |
| iOS/Body | SF Pro | 17 | Regular | Inter Regular |
| iOS/Subheadline | SF Pro | 15 | Regular | Inter Regular |
| iOS/Subheadline Emphasized | SF Pro | 15 | Semibold | Inter Semi Bold |
| iOS/Footnote | SF Pro | 13 | Regular | Inter Regular |
| iOS/Footnote Emphasized | SF Pro | 13 | Semibold | Inter Semi Bold |
| iOS/Caption | SF Pro | 12 | Semibold | Inter Semi Bold |
| iOS/Number L | SF Pro Rounded (`.rounded`) | 28 | Bold | Inter Bold |
| iOS/Number M | SF Pro Rounded (`.rounded`) | 22 | Bold | Inter Bold |
| iOS/Number S | SF Pro Rounded (`.rounded`) | 15 | Semibold | Inter Semi Bold |
