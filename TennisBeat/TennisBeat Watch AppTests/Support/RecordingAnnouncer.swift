@testable import TennisBeat_Watch_App

/// Records VoiceOver announcements in order.
final class RecordingAnnouncer: Announcing {
  private(set) var announcements: [String] = []

  func announce(_ text: String) { announcements.append(text) }

  func reset() { announcements = [] }
}
