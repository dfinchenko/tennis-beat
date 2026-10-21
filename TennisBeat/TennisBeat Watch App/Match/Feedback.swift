import SwiftUI
import WatchKit

/// One haptic pattern (FR-011..FR-013, contract §4).
nonisolated enum Haptic: Hashable, Sendable {
  case point, game, set, match, changeOfEnds

  /// The patterns for one added point: its level, then change of ends if it calls for one.
  static func sequence(for outcome: PointOutcome) -> [Haptic] {
    let level: Haptic =
      switch outcome.level {
      case .point: .point
      case .game: .game
      case .set: .set
      case .match: .match
      }
    return outcome.changeOfEnds ? [level, .changeOfEnds] : [level]
  }
}

/// Haptic feedback for added points (research R3).
protocol HapticPlaying: AnyObject {
  /// Plays the point's haptic, and schedules change of ends if it calls for one.
  func play(_ outcome: PointOutcome)
  /// Drops a scheduled change-of-ends haptic (undo and the other non-point commands).
  func cancelPending()
  /// Plays a scheduled change-of-ends haptic now (before the next point's haptic).
  func flushPending()
}

/// VoiceOver announcements, at most one per command (research R4).
protocol Announcing: AnyObject {
  func announce(_ text: String)
}

/// Production haptics: `WKInterfaceDevice`, with change of ends about 0.8 s after the
/// point's haptic on a cancellable task (research R3).
final class WatchHaptics: HapticPlaying {
  static let changeOfEndsDelay = Duration.milliseconds(800)

  private let sink: (WKHapticType) -> Void
  private let sleep: @Sendable (Duration) async throws -> Void
  private var pending: Task<Void, Never>?

  init(
    sink: @escaping (WKHapticType) -> Void = { WKInterfaceDevice.current().play($0) },
    sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
  ) {
    self.sink = sink
    self.sleep = sleep
  }

  /// The production haptics, or, with `-uiTestHoldChangeOfEnds`, haptics whose change of ends
  /// stays pending until the next command plays or drops it (contract §2): UI tests tap while
  /// it is pending as long as they like, with no race against the 0.8 s.
  /// `sleep` is used only without the hold flag; with it the change of ends waits for the
  /// next command.
  static func launched(
    _ options: LaunchOptions,
    sink: @escaping (WKHapticType) -> Void = { WKInterfaceDevice.current().play($0) },
    sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
  ) -> WatchHaptics {
    guard options.holdChangeOfEnds else { return WatchHaptics(sink: sink, sleep: sleep) }
    return WatchHaptics(sink: sink, sleep: { _ in try await Task.sleep(for: .seconds(86_400)) })
  }

  /// The system pattern for each haptic (proposal; Denys may change it after the US3 s8
  /// device check).
  static func hapticType(for haptic: Haptic) -> WKHapticType {
    switch haptic {
    case .point: .click
    case .game: .directionUp
    case .set: .success
    case .match: .notification
    case .changeOfEnds: .retry
    }
  }

  func play(_ outcome: PointOutcome) {
    let sequence = Haptic.sequence(for: outcome)
    sink(Self.hapticType(for: sequence[0]))
    guard sequence.count > 1 else { return }
    #if DEBUG
      TapLog.log("change-of-ends haptic scheduled")
    #endif
    pending?.cancel()
    pending = Task { [weak self, sleep] in
      do { try await sleep(Self.changeOfEndsDelay) } catch { return }
      guard !Task.isCancelled else { return }
      self?.playPending()
    }
  }

  func cancelPending() {
    pending?.cancel()
    pending = nil
  }

  func flushPending() {
    guard pending != nil else { return }
    pending?.cancel()
    playPending()
  }

  private func playPending() {
    guard pending != nil else { return }
    pending = nil
    #if DEBUG
      TapLog.log("change-of-ends haptic plays")
    #endif
    sink(Self.hapticType(for: .changeOfEnds))
  }
}

/// Production announcer: one high-priority VoiceOver announcement (research R4).
final class VoiceOverAnnouncer: Announcing {
  func announce(_ text: String) {
    var announcement = AttributedString(text)
    announcement.accessibilitySpeechAnnouncementPriority = .high
    AccessibilityNotification.Announcement(announcement).post()
  }
}
