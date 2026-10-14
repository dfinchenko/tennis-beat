import Foundation
import TennisCore
import Testing

@testable import TennisBeat_Watch_App

/// User Story 6 s3: the zones take no taps in Always On (FR-021).
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
}
