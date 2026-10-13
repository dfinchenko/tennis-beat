import SwiftUI

/// Colour tokens from `docs/design/tokens.json` (watch, brand and status groups).
/// Do not edit by hand: the values mirror the design export.
extension Color {
  /// `brand/ball` #DFFF4F
  static let brandBall = Color(.sRGB, red: 0.8745, green: 1, blue: 0.3098, opacity: 1)
  /// `brand/on-ball` #000000
  static let brandOnBall = Color(.sRGB, red: 0, green: 0, blue: 0, opacity: 1)
  /// `brand/opponent` #6CB6FF
  static let brandOpponent = Color(.sRGB, red: 0.4235, green: 0.7137, blue: 1, opacity: 1)
  /// `watch/background` #000000
  static let watchBackground = Color(.sRGB, red: 0, green: 0, blue: 0, opacity: 1)
  /// `watch/surface` #1C1C1E
  static let watchSurface = Color(.sRGB, red: 0.1098, green: 0.1098, blue: 0.1176, opacity: 1)
  /// `watch/surface-raised` #2C2C2E
  static let watchSurfaceRaised = Color(.sRGB, red: 0.1725, green: 0.1725, blue: 0.1804, opacity: 1)
  /// `watch/text-primary` #FFFFFF
  static let watchTextPrimary = Color(.sRGB, red: 1, green: 1, blue: 1, opacity: 1)
  /// `watch/text-secondary` #A1A1A6
  static let watchTextSecondary = Color(.sRGB, red: 0.6314, green: 0.6314, blue: 0.651, opacity: 1)
  /// `watch/text-tertiary` #8E8E93
  static let watchTextTertiary = Color(.sRGB, red: 0.5569, green: 0.5569, blue: 0.5765, opacity: 1)
  /// `watch/zone-me` #DFFF4F29
  static let watchZoneMe = Color(.sRGB, red: 0.8745, green: 1, blue: 0.3098, opacity: 0.16)
  /// `watch/zone-opponent` #6CB6FF29
  static let watchZoneOpponent = Color(.sRGB, red: 0.4235, green: 0.7137, blue: 1, opacity: 0.16)
  /// `watch/button-opponent` #6CB6FF2E
  static let watchButtonOpponent = Color(.sRGB, red: 0.4235, green: 0.7137, blue: 1, opacity: 0.18)
  /// `watch/control-pause` #DFFF4F2E
  static let watchControlPause = Color(.sRGB, red: 0.8745, green: 1, blue: 0.3098, opacity: 0.18)
  /// `watch/control-end` #FF9F0A33
  static let watchControlEnd = Color(.sRGB, red: 1, green: 0.6235, blue: 0.0392, opacity: 0.2)
  /// `status/end` #FF9F0A
  static let statusEnd = Color(.sRGB, red: 1, green: 0.6235, blue: 0.0392, opacity: 1)
  /// `status/heart` #FF6B4A
  static let statusHeart = Color(.sRGB, red: 1, green: 0.4196, blue: 0.2902, opacity: 1)
  /// `status/destructive` #C4320A
  static let statusDestructive = Color(.sRGB, red: 0.7686, green: 0.1961, blue: 0.0392, opacity: 1)
}
