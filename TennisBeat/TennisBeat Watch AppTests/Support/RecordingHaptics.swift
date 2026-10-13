@testable import TennisBeat_Watch_App

/// Records haptic requests in order. The haptic methods arrive with the score screen (PR 2).
final class RecordingHaptics: HapticPlaying {
  private(set) var calls: [String] = []
}
