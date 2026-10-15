import Foundation
import SwiftUI
import TennisCore
import Testing

@testable import TennisBeat_Watch_App

/// User Story 6: the zones take no taps in Always On (s3, FR-021), and the dimmed colours (s1).
@MainActor
struct AlwaysOnTests {
  private func model(acceptsPoints: Bool) -> ScoreScreenModel {
    let match = MatchScript.match(PointOutcomeTests.format(), points: "M")
    return ScoreScreenModel(
      state: match.state, isPaused: false, locale: ScoreScreenModelTests.en,
      acceptsPoints: acceptsPoints)
  }

  @Test("US6 s3 dimmed, the zones take no taps even while the match accepts points")
  func dimmedZonesTakeNoTaps() {
    #expect(!model(acceptsPoints: true).zonesAcceptTaps(isLuminanceReduced: true))
  }

  @Test("US6 s3 positive control: not dimmed, the zones take taps while the match accepts points")
  func litZonesTakeTaps() {
    #expect(model(acceptsPoints: true).zonesAcceptTaps(isLuminanceReduced: false))
    #expect(!model(acceptsPoints: false).zonesAcceptTaps(isLuminanceReduced: false))
  }

  @Test(
    "US6 s1 dimmed, the current games are in the dimmed player colour and the completed sets grey",
    arguments: [Player.me, .opponent])
  func dimmedGamesAndSets(player: Player) {
    let brand: Color = player == .me ? .brandBall : .brandOpponent
    let palette = PlayerZoneView.Palette(player: player, isDimmed: true)
    #expect(palette.games == brand.opacity(0.6))
    #expect(palette.games == palette.accent)
    #expect(palette.sets == .watchTextSecondary)
  }

  @Test(
    "US6 s1 positive control: lit, the games are in the player colour and the sets white",
    arguments: [Player.me, .opponent])
  func litGamesAndSets(player: Player) {
    let brand: Color = player == .me ? .brandBall : .brandOpponent
    let palette = PlayerZoneView.Palette(player: player, isDimmed: false)
    #expect(palette.games == brand)
    #expect(palette.sets == .watchTextPrimary)
  }

  @Test("US6 s1 dimmed, the header minutes are tertiary grey; lit, the ball colour")
  func headerColour() {
    #expect(ElapsedTimeView.color(isDimmed: true) == .watchTextTertiary)
    #expect(ElapsedTimeView.color(isDimmed: false) == .brandBall)
  }
}
