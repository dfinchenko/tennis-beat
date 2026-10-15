import SwiftUI
import TennisCore

/// One tap zone: label, serve mark and court side, sets and games, and the point display
/// (Watch 3, FR-006, FR-007).
struct PlayerZoneView: View {
  let zone: ScoreScreenModel.Zone
  /// Always On (Watch 5): darker fills and dimmed colours, grey completed sets.
  var isDimmed = false
  /// `-uiTestExposeValues`: the values carry identifiers for UI tests (research R7). On
  /// watchOS, XCUITest lists texts even when they are hidden from VoiceOver, so production
  /// sets no identifiers at all.
  var exposeValues = false

  private var palette: Palette { Palette(player: zone.player, isDimmed: isDimmed) }
  private var accent: Color { palette.accent }
  private var fill: Color { palette.fill }
  private var setsColor: Color { palette.sets }
  private var gamesColor: Color { palette.games }
  private var id: String { "zone.\(zone.player.rawValue)" }

  /// A zone's colours, lit (Watch 3) or dimmed (Watch 5).
  struct Palette: Equatable {
    /// The label, serve mark, pill and point display.
    let accent: Color
    let fill: Color
    let sets: Color
    let games: Color

    init(player: Player, isDimmed: Bool) {
      let brand: Color = player == .me ? .brandBall : .brandOpponent
      // Watch 5 samples: the dimmed accents are the brand colours at 60 % on black (#86992F,
      // #416D99) and the fills at 10 % (#161908, #0A1119).
      accent = isDimmed ? brand.opacity(0.6) : brand
      if isDimmed {
        fill = brand.opacity(0.1)
      } else {
        fill = player == .me ? .watchZoneMe : .watchZoneOpponent
      }
      sets = isDimmed ? .watchTextSecondary : .watchTextPrimary
      // Always On: the current games keep the dimmed player colour, as in Watch 5; only the
      // completed sets go grey (Story 6 s1, #24 decisions).
      games = accent
    }
  }

  var body: some View {
    // The court-side pill goes after sets and games when it fits there, and on its own row
    // when it doesn't (long pills at the largest text size on the 40 mm watch), so no text
    // is truncated (Story 7 s6).
    ViewThatFits(in: .horizontal) {
      content(pillOnOwnRow: false)
      content(pillOnOwnRow: true)
    }
    .padding(.horizontal, 12)
    .frame(maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
    .background(fill, in: .rect(cornerRadius: 24))
    .contentShape(.rect(cornerRadius: 24))
  }

  private func content(pillOnOwnRow: Bool) -> some View {
    HStack(alignment: .center, spacing: 4) {
      VStack(alignment: .leading, spacing: pillOnOwnRow ? 0 : 2) {
        HStack(spacing: 4) {
          Text(zone.label)
            .font(.watchHeadline)
            .foregroundStyle(accent)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
          if zone.showsServeMark {
            Image(systemName: "tennisball.fill")
              .font(.watchFootnote)
              .foregroundStyle(accent)
              .accessibilityIdentifier(exposeValues ? "\(id).serve" : "")
          }
        }
        HStack(spacing: 8) {
          Text(zone.sets, format: .number)
            .foregroundStyle(setsColor)
            .accessibilityIdentifier(exposeValues ? "\(id).sets" : "")
          Text(zone.games, format: .number)
            .foregroundStyle(gamesColor)
            .accessibilityIdentifier(exposeValues ? "\(id).games" : "")
          if !pillOnOwnRow { pill }
        }
        .font(.watchNumber)
        .monospacedDigit()
        if pillOnOwnRow { pill }
      }

      Spacer(minLength: 0)

      // Up to 2 digits always fit (Edge "long tie-breaks").
      Text(zone.points)
        .font(.watchScore)
        .monospacedDigit()
        .foregroundStyle(accent)
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .accessibilityIdentifier(exposeValues ? "\(id).points" : "")
    }
  }

  @ViewBuilder private var pill: some View {
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
}
