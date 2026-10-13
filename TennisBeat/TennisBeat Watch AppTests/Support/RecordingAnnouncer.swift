@testable import TennisBeat_Watch_App

/// Records VoiceOver announcements in order. The announce method arrives with the score screen (PR 2).
final class RecordingAnnouncer: Announcing {
  private(set) var announcements: [String] = []
}
