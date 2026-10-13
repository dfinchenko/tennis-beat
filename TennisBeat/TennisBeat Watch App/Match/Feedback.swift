/// Haptic feedback for match events (research R3). Its methods arrive with the score screen (PR 2).
protocol HapticPlaying: AnyObject {}

/// VoiceOver announcements for match events (research R4). Its method arrives with the score screen (PR 2).
protocol Announcing: AnyObject {}

/// Production haptics (WatchKit); filled in with the score screen (PR 2).
final class WatchHaptics: HapticPlaying {}

/// Production announcer (VoiceOver); filled in with the score screen (PR 2).
final class VoiceOverAnnouncer: Announcing {}
