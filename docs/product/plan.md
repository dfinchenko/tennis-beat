# Tennis Beat — product plan

Repo copy of the working plan (the detailed Ukrainian version lives in Claude Docs). Agents treat this file as the scope source of truth.

## Positioning
Free tennis score keeper for Apple Watch + iPhone: no paywall on scoring, history, stats or head-to-head; English, Polish and Ukrainian; privacy label "Data Not Collected"; no accounts.

## MVP (v1.0)

### Apple Watch
- Match setup: singles; 1 set or best of 3; set length 4, 6 or 8 games; Advantage or No-Ad; tie-break when a set reaches N–N (N = set length; confirm against ITF notes); optional match tie-break to 10 instead of a deciding set.
- First server: me / opponent / coin toss.
- Scoring screen: two full-height tap zones (opponent on top, me at the bottom); tap = point won; game points large, sets and games smaller; server and side (deuce / ad court) indicator.
- Undo: unlimited, across game and set boundaries and after the match has ended.
- Haptics: distinct patterns for game, set and match; change-of-ends reminder.
- Workout session (`.tennis`): live heart rate and elapsed time, saved to Health, Always On support.
- Pause, end match (with confirmation), event persisted after every point, recovery after a crash or relaunch.
- Summary screen: set scores, duration, average and max heart rate.
- Works standalone without the iPhone nearby (finished match is delivered later).
- Works without Health permission (no heart rate and no workout then).
- Opponent is shown as "Opponent" on the watch.

### iPhone
- Match history received from the watch: date, opponent, set scores, duration.
- Opponent name entered after the match, with autocomplete from names entered before.
- Match detail: heart rate read from HealthKit by workout UUID.
- Match stats derived from engine events, no extra input: points won on serve and on return, service games held, break points converted and saved.
- Head-to-head line by opponent name, e.g. "With Oleh K.: 1–1" (group saved matches by name; no profiles).
- Share card (9:16) with set scores and key numbers, rendered with `ImageRenderer` and shared via `ShareLink`.
- Defaults (match format, my name) and Health permission onboarding.

### Both
- Localization: EN (source), PL, UK from day one; String Catalog; plural variations; `FormatStyle`; glossary.
- No analytics or third-party SDKs.

### Out of MVP
Doubles; manual-input stats (first/second serve, aces, double faults); opponent profiles; iCloud sync; shot detection; padel.

## Roadmap
| Version | Scope |
| --- | --- |
| v1.1 | Doubles with 4-player serve rotation; iPhone-only scoring; Double Tap gesture for "my point"; complication and Smart Stack widget; best of 5 and Fast4; voice score announcements in EN/PL/UK (`AVSpeechSynthesizer`); screen lock against accidental taps; picker of 5 recent opponents on the watch |
| v1.2 | iCloud sync of scores and match metadata only (SwiftData + CloudKit); opponent profiles with duplicate-name merge and extended head-to-head; match flow chart (Swift Charts); manual-input stats |
| v1.3 | Live Activity with the score on iPhone; Siri / App Intents "start match" |
| v2.0 | Shot detection (`CMBatchedSensorManager` + Core ML); padel mode; on-device match summary via Foundation Models (numbers come from the engine only); optional tip jar (StoreKit 2) |

## Constraints
- HealthKit: no false data; personal health data never stored in iCloud (App Review 5.1.3(ii)); heart rate is never persisted outside HealthKit.
- Health integration is named in the App Store description and visible in the UI; privacy policy required.
- Workout session runs only during a real match.
- Builds use the iOS 26 SDK / Xcode 26 or newer.
- HIG: full-height tap zones on watch; destructive actions confirmed; monospaced digits; meaning never carried by color alone; Always On dimming; 44 pt minimum targets on iPhone; Liquid Glass only for navigation and controls.

## Architecture
- Swift 6, SwiftUI; minimum iOS 26 and watchOS 26.
- `Packages/TennisCore`: event-sourced engine. A match is a list of events (`pointWon(by:)` …); state = reduce(events). Undo = drop last event; crash recovery = persisted events; stats = functions over events.
- Watch: `HKWorkoutSession` + `HKLiveWorkoutBuilder`; SwiftData for local history; finished matches sent with `WCSession.transferUserInfo`.
- iPhone: SwiftData history; HealthKit queries by workout UUID.

## Identifiers
- iOS app bundle ID: `com.dfinchenko.TennisBeat`
- watchOS app bundle ID: `com.dfinchenko.TennisBeat.watchkitapp`

## Design
- Figma (showcase only; agents do not call Figma tools — the Starter MCP limit is exhausted): https://www.figma.com/design/A1oDA98m8ErPUKbIwN465y
- Interactive prototype: https://claude.ai/artifact/PHMLfPVteBT4kumJEa2At8
- Agents use the export in `docs/design/`, which is the source of truth for design. Figma text styles use Inter as a stand-in; production uses system SF (SF Compact on watch, `.rounded` design for numbers). Each style description names the production font.
