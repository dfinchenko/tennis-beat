import SwiftUI
import TennisCore

/// One tap zone: label, serve mark and court side, sets and games, and the point display
/// (Watch 3, FR-006, FR-007).
struct PlayerZoneView: View {
  let zone: ScoreScreenModel.Zone
  /// `-uiTestExposeValues`: the values carry identifiers for UI tests (research R7). On
  /// watchOS, XCUITest lists texts even when they are hidden from VoiceOver, so production
  /// sets no identifiers at all.
  var exposeValues = false

  private var accent: Color { zone.player == .me ? .brandBall : .brandOpponent }
  private var fill: Color { zone.player == .me ? .watchZoneMe : .watchZoneOpponent }
  private var id: String { "zone.\(zone.player.rawValue)" }

  var body: some View {
    HStack(alignment: .center, spacing: 4) {
      VStack(alignment: .leading, spacing: 2) {
        HStack(spacing: 4) {
          Text(zone.label)
            .font(.watchHeadline)
            .foregroundStyle(accent)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
          if zone.isServer {
            Image(systemName: "tennisball.fill")
              .font(.watchFootnote)
              .foregroundStyle(accent)
              .accessibilityIdentifier(exposeValues ? "\(id).serve" : "")
          }
          if let side = zone.courtSide {
            Text(side)
              .font(.watchCaption)
              .foregroundStyle(Color.brandOnBall)
              .lineLimit(1)
              .minimumScaleFactor(0.6)
              .padding(.horizontal, 6)
              .background(accent, in: .capsule)
              .accessibilityIdentifier(exposeValues ? "\(id).side" : "")
          }
        }
        HStack(spacing: 8) {
          Text(zone.sets, format: .number)
            .foregroundStyle(Color.watchTextPrimary)
            .accessibilityIdentifier(exposeValues ? "\(id).sets" : "")
          Text(zone.games, format: .number)
            .foregroundStyle(accent)
            .accessibilityIdentifier(exposeValues ? "\(id).games" : "")
        }
        .font(.watchNumber)
        .monospacedDigit()
      }

      Spacer(minLength: 0)

      // Up to 2 digits always fit (Edge "long tie-breaks").
      Text(zone.points)
        .font(.watchScore)
        .monospacedDigit()
        .foregroundStyle(accent)
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        // The points win the width; the label column shrinks first.
        .layoutPriority(1)
        .accessibilityIdentifier(exposeValues ? "\(id).points" : "")
    }
    .padding(.horizontal, 12)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(fill, in: .rect(cornerRadius: 24))
    .contentShape(.rect(cornerRadius: 24))
  }
}
