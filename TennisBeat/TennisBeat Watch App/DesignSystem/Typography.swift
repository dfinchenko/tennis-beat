import SwiftUI

/// Text styles from `docs/design/typography.md` (Apple Watch).
///
/// Each one is built on the nearest SwiftUI text style, so Dynamic Type scales it.
/// The design sizes (in points) are for the default text size. Numbers use the
/// `.rounded` design; apply `.monospacedDigit()` where digits change in place.
extension Font {
  /// Watch/Large Title: 20 pt bold.
  static let watchLargeTitle = Font.system(.title3, design: .default, weight: .bold)
  /// Watch/Title: 17 pt semibold.
  static let watchTitle = Font.system(.body, design: .default, weight: .semibold)
  /// Watch/Headline: 15 pt semibold.
  static let watchHeadline = Font.system(.headline, design: .default, weight: .semibold)
  /// Watch/Body: 15 pt regular.
  static let watchBody = Font.system(.subheadline, design: .default, weight: .regular)
  /// Watch/Footnote: 13 pt regular.
  static let watchFootnote = Font.system(.footnote, design: .default, weight: .regular)
  /// Watch/Label: 13 pt semibold.
  static let watchLabel = Font.system(.footnote, design: .default, weight: .semibold)
  /// Watch/Caption: 11 pt regular.
  static let watchCaption = Font.system(.caption2, design: .default, weight: .regular)
  /// Watch/Score: 48 pt bold rounded (the point display).
  static let watchScore = Font.system(.largeTitle, design: .rounded, weight: .bold)
  /// Watch/Number: 15 pt semibold rounded (sets, games, summary values).
  static let watchNumber = Font.system(.headline, design: .rounded, weight: .semibold)
}
