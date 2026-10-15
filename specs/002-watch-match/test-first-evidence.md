# Test-first evidence: 002-watch-match

For each added test, a run against the code before the implementation it checks, or, for a test of existing code, against a recorded mutation (rule: `docs/harness.md` § Test-first evidence). One section per PR, newest last. The reviewer checks each entry against the diff. Simulator: Apple Watch SE 3, watchOS 27.0 (40 mm for UI tests, 44 mm where noted; unit tests and the audits' "no description" check don't depend on the screen size).

## PR #24 `feat/002-always-on` (PR 5: Always On), recorded after merge

#24's tests were written before the Always On code but first run after it (Denys asked for this record in the follow-up PR). Each run uses #24's final test files (`ea0d1b0`, the tree merged as `c69e196`) on top of the app code at **`201d54a`**, the commit before the Always On code (`3a3e531`). Command: `git worktree add --detach <dir> 201d54a`, `git checkout ea0d1b0 -- <test files>`, then `xcodebuild test -only-testing:<tests>`.

**Run 1, unit tests as they are:** the test target doesn't compile. `AlwaysOnTests.swift`: extra argument `acceptsPoints`; no member `zonesAcceptTaps`. `ScoreScreenModelTests.swift`: extra argument `isDimmed`; no members `dimmedElapsed`, `showsUndo`, `Zone.showsServeMark`; cannot find `ElapsedMinuteSchedule`.

**Run 2, unit tests against signature-only stubs** (the API the tests call, with the behaviour from before Always On: nothing dimmed, zones take taps, an m:ss header, a redraw every second; never committed):

```diff
diff --git a/TennisBeat/TennisBeat Watch App/Match/ScoreScreenModel.swift b/TennisBeat/TennisBeat Watch App/Match/ScoreScreenModel.swift
index 675aa97..c83618b 100644
--- a/TennisBeat/TennisBeat Watch App/Match/ScoreScreenModel.swift	
+++ b/TennisBeat/TennisBeat Watch App/Match/ScoreScreenModel.swift	
@@ -14,6 +14,7 @@ nonisolated struct ScoreScreenModel: Hashable, Sendable {
     let games: Int
     let sets: Int
     let isServer: Bool
+    let showsServeMark: Bool
     /// "Right" / "Left" / "Choice" for the server, nil for the receiver.  ITF: SV-03, TB-04, NA-02
     let courtSide: String?
     let accessibilityLabel: String
@@ -24,6 +25,8 @@ nonisolated struct ScoreScreenModel: Hashable, Sendable {
   let zones: [Zone]
   /// The status line: "Paused", a game state, or empty (FR-008).
   let statusText: String
+  let showsUndo: Bool = true
+  let acceptsPoints: Bool
   /// "Paused. <state>", "<state>" or empty (R1-3).
   let statusAccessibilityText: String
   /// Read first: the server's score, who serves and the side, then the status (Story 7 s1, s2).
@@ -33,7 +36,11 @@ nonisolated struct ScoreScreenModel: Hashable, Sendable {
     zones.first { $0.player == player }!
   }
 
-  init(state: MatchState, isPaused: Bool, locale: Locale) {
+  init(
+    state: MatchState, isPaused: Bool, locale: Locale, acceptsPoints: Bool = true,
+    isDimmed: Bool = false
+  ) {
+    self.acceptsPoints = acceptsPoints
     func text(_ resource: LocalizedStringResource) -> String {
       Self.text(resource, locale: locale)
     }
@@ -87,13 +94,19 @@ nonisolated struct ScoreScreenModel: Hashable, Sendable {
         } else { nil }
       return Zone(
         player: player, label: label, points: Self.display(state.points[player], locale: locale),
-        games: games, sets: sets, isServer: isServer,
+        games: games, sets: sets, isServer: isServer, showsServeMark: isServer,
         courtSide: isServer ? text(Self.side(state.courtSide)) : nil,
         accessibilityLabel: [sentence, serving].compactMap(\.self).joined(separator: " "),
         accessibilityHint: text("score.zone.hint \(label)"))
     }
   }
 
+  func zonesAcceptTaps(isLuminanceReduced: Bool) -> Bool { acceptsPoints }
+
+  static func dimmedElapsed(_ seconds: TimeInterval, locale: Locale) -> String {
+    Duration.seconds(Int(seconds)).formatted(.time(pattern: .minuteSecond))
+  }
+
   // MARK: Pieces (also used by the session's announcements)
 
   static func text(_ resource: LocalizedStringResource, locale: Locale) -> String {
diff --git a/TennisBeat/TennisBeat Watch App/Score/ElapsedMinuteSchedule.swift b/TennisBeat/TennisBeat Watch App/Score/ElapsedMinuteSchedule.swift
new file mode 100644
index 0000000..08b3057
--- /dev/null
+++ b/TennisBeat/TennisBeat Watch App/Score/ElapsedMinuteSchedule.swift	
@@ -0,0 +1,13 @@
+import SwiftUI
+
+struct ElapsedMinuteSchedule: TimelineSchedule {
+  let clock: MatchClock
+
+  func entries(from startDate: Date, mode: TimelineScheduleMode) -> AnyIterator<Date> {
+    var next = startDate
+    return AnyIterator {
+      defer { next += 1 }
+      return next
+    }
+  }
+}
```

| Test | Result at `201d54a` + stubs |
| --- | --- |
| `ScoreScreenModelTests` "US6 s1 the dimmed time is whole minutes …" | **Failed:** "42:59" ≠ "42 min", "42:00" ≠ "42 хв" (5 cases) |
| `ScoreScreenModelTests` "US6 s2 Q8 dimmed: no Undo, no serve icon, no court-side pill, no status line" | **Failed:** `showsUndo`, `showsServeMark` true; `courtSide` "Right"; `statusText` "Deuce", "Paused" |
| `ScoreScreenModelTests` "R5 the dimmed redraws fall on whole elapsed minutes, after a 90 s pause" | **Failed:** redraws 29, 88, 147 s off the minute |
| `ScoreScreenModelTests` "R5 while paused the dimmed time doesn't change …" | **Failed:** redraws every second while paused |
| `AlwaysOnTests` "US6 s3 dimmed, the zones take no taps …" | **Failed:** `zonesAcceptTaps(isLuminanceReduced: true)` true |
| `ScoreScreenModelTests` "US6 s2 positive control: not dimmed, …" | Passed, as a positive control should |
| `AlwaysOnTests` "US6 s3 positive control: …" | Passed, as a positive control should |
| `ScoreScreenModelTests` "US6 s2 dimmed keeps the score and the VoiceOver texts" | Passed. It checks that dimming changes nothing in the score, which code without Always On satisfies; it guards against the dimmed rendering dropping the score |

**Run 3, UI tests:** `AlwaysOnUITests` and `AccessibilityAuditUITests` (40 mm). `-uiTestAlwaysOn` and `-uiTestPoints` didn't exist at `201d54a`, so in the first run `testUS6s1s2DimmedShowsMinutesOnly` and the lit positive control failed at their first step (no points played). Run 3 adds only those two debug launch hooks from `ea0d1b0` (`LaunchOptions.swift`, `TennisBeatApp.swift`, `MatchPagesView.swift`); no Always On rendering.

| Test | Result at `201d54a` + launch hooks |
| --- | --- |
| `AlwaysOnUITests.testUS6s1s2DimmedShowsMinutesOnly` | **Failed:** header "0:02", not whole minutes |
| `AlwaysOnUITests.testDimmedControlsShowMinutesOnly` | **Failed:** Controls time "0:02" |
| `AlwaysOnUITests.testUS6s3DimmedZonesTakeNoTaps` | **Failed:** the tap scored 15 |
| `AlwaysOnUITests.testUS6s1PositiveControlLitShowsSecondsUndoAndServe` | Passed (positive control) |
| `AlwaysOnUITests.testUS6s3PositiveControlLitZonesTakeTaps` | Passed (positive control) |
| `AccessibilityAuditUITests.testSC005AuditSummary` (run 1, no hooks needed) | **Failed:** "Hit area is too small", `summary.duration` 19.5 pt tall, PL and UK; fixed by T074 in `3a3e531` |
| `AccessibilityAuditUITests` New match, picker, First server, coin-toss result, Score, Controls, End confirmation (run 1) | Passed: they audit screens that existed before #24 and had no issue. That they can fail is shown under the mutation in the section below |

`ScreenshotUITests.testAlwaysOnScreens` is opt-in and asserts nothing; not run. `SummaryModelTests` "spoken duration" belongs to #23 R1-3 (`201d54a`), not Always On, and predates this rule.

## Branch `feat/002-always-on-followups` (#24 follow-ups)

Tests committed in **`91414ff`** before the implementation in `b8c14f5`; `91414ff` already has the colour values as testable properties (`7c91afc`, no change in behaviour).

| Test | Run | Result |
| --- | --- | --- |
| `AlwaysOnTests` "US6 s1 dimmed, the current games are in the dimmed player colour and the completed sets grey" (Me, Opponent) | `91414ff`, all unit tests, 44 mm | **Failed:** `palette.games` #A1A1A6 ≠ 60 % #DFFF4F (Me) and ≠ 60 % #6CB6FF (Opponent); `palette.games` ≠ `palette.accent` |
| `AlwaysOnTests` "US6 s1 dimmed, the header minutes are tertiary grey; lit, the ball colour" | `91414ff` | **Failed:** `ElapsedTimeView.color(isDimmed: true)` #A1A1A6 ≠ `.watchTextTertiary` #8E8E93 |
| `AlwaysOnTests` "US6 s1 positive control: lit, …" | `91414ff` | Passed (positive control; the lit colours don't change) |
| `ScoreScreenModelTests` "R5 once the clock has stopped the dimmed time doesn't change …" (#24 R2-3) | Existing code. `b8c14f5` with the mutation below, `ScoreScreenModelTests`, 44 mm | **Failed:** 3 redraws instead of 1, for a stopped clock and for one stopped during a pause. Passes without the mutation |
| `AccessibilityAuditUITests` New match, picker, First server, coin-toss result, Score: new settings PL and UK at the largest accessibility size (#24 R2-1) | Existing screens. `b8c14f5` with the mutation below, these 5 tests, 44 mm | **Failed**, all 5, in every setting including each new PL and UK AX XXXL one: "Element has no description" on `setup.format`, `setup.setLength`, `picker.option.*`, `firstServer.me`/`.opponent`, `coinToss.start`, `zone.me`/`.opponent` |

`SummaryUITests.testUS5s2s4s7WinShowsTitleChipsAndDuration` (#24 R2-2) is a changed test, not an added one; see `test-expectation-changes.md`.

Mutation for R2-3 (reverted after the run):

```diff
diff --git a/TennisBeat/TennisBeat Watch App/Score/ElapsedMinuteSchedule.swift b/TennisBeat/TennisBeat Watch App/Score/ElapsedMinuteSchedule.swift
index 0d833d8..4da989a 100644
--- a/TennisBeat/TennisBeat Watch App/Score/ElapsedMinuteSchedule.swift	
+++ b/TennisBeat/TennisBeat Watch App/Score/ElapsedMinuteSchedule.swift	
@@ -8,7 +8,7 @@ struct ElapsedMinuteSchedule: TimelineSchedule {
   let clock: MatchClock
 
   func entries(from startDate: Date, mode: TimelineScheduleMode) -> AnyIterator<Date> {
-    let isRunning = !clock.isPaused && clock.stoppedAt == nil
+    let isRunning = !clock.isPaused
     let elapsed = clock.elapsed(at: startDate)
     // Running, the elapsed time grows one second per second from here.
     let toNextMinute = 60 - elapsed.truncatingRemainder(dividingBy: 60)
```

Mutation for R2-1 (in a scratch worktree, never committed): empty VoiceOver labels on one visible element of each screen.

```diff
diff --git a/TennisBeat/TennisBeat Watch App/Score/ScoreView.swift b/TennisBeat/TennisBeat Watch App/Score/ScoreView.swift
index ed53f09..5d481e5 100644
--- a/TennisBeat/TennisBeat Watch App/Score/ScoreView.swift	
+++ b/TennisBeat/TennisBeat Watch App/Score/ScoreView.swift	
@@ -36,7 +36,7 @@ struct ScoreView: View {
           // Q4: the zones dim while paused; "Paused" in the status line says why.
           .opacity(session.isPaused ? 0.5 : 1)
           .modifier(ExposeChildren(isOn: exposeValues))
-          .accessibilityLabel(zone.accessibilityLabel)
+          .accessibilityLabel(Text(verbatim: ""))
           .accessibilityHint(zone.accessibilityHint)
           .accessibilityIdentifier("zone.\(zone.player.rawValue)")
         }
diff --git a/TennisBeat/TennisBeat Watch App/Setup/NewMatchView.swift b/TennisBeat/TennisBeat Watch App/Setup/NewMatchView.swift
index e9b9503..e056ed1 100644
--- a/TennisBeat/TennisBeat Watch App/Setup/NewMatchView.swift	
+++ b/TennisBeat/TennisBeat Watch App/Setup/NewMatchView.swift	
@@ -59,8 +59,8 @@ private struct SettingRow: View {
       .contentShape(.rect(cornerRadius: 16))
     }
     .buttonStyle(.plain)
-    .accessibilityLabel(Text(row.caption))
-    .accessibilityValue(Text(value))
+    .accessibilityLabel(Text(verbatim: ""))
+    .accessibilityValue(Text(verbatim: ""))
     .accessibilityIdentifier(row.identifier)
   }
 }
@@ -74,6 +74,7 @@ struct CapsuleButtonStyle: ButtonStyle {
 
   func makeBody(configuration: Configuration) -> some View {
     configuration.label
+      .accessibilityLabel(Text(verbatim: ""))
       .foregroundStyle(text)
       .padding(.vertical, 7)
       .frame(maxWidth: .infinity, minHeight: minHeight)
diff --git a/TennisBeat/TennisBeat Watch App/Setup/OptionPickerView.swift b/TennisBeat/TennisBeat Watch App/Setup/OptionPickerView.swift
index dc2d831..d2413fd 100644
--- a/TennisBeat/TennisBeat Watch App/Setup/OptionPickerView.swift	
+++ b/TennisBeat/TennisBeat Watch App/Setup/OptionPickerView.swift	
@@ -25,6 +25,7 @@ struct OptionPickerView: View {
           }
         }
       }
+      .accessibilityLabel(Text(verbatim: ""))
       .accessibilityAddTraits(isSelected ? .isSelected : [])
       .accessibilityIdentifier("picker.option.\(option.raw)")
     }
```

A first R2-1 mutation did **not** fail the audits: capping the capsule buttons at 20 pt, Undo at 20 × 20 pt and the picker rows at 20 pt. The audit didn't report these: Start is below the fold on New match, Undo is disabled at 0–0, and the First server buttons and picker rows weren't reported as small. So these audits check naming on visible elements but don't reliably catch a small button here.
