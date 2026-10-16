import Foundation
import SwiftUI
import Testing

@testable import TennisBeat_Watch_App

/// The heart rate in the score header (spec 003 Story 3, FR-012; data-model
/// § HeartRateDisplay; T037).
struct HeartRateDisplayTests {
  static let en = Locale(identifier: "en")
  static let pl = Locale(identifier: "pl")
  static let uk = Locale(identifier: "uk")
  static let now = Date(timeIntervalSinceReferenceDate: 10_000)

  static func display(
    _ state: WorkoutState = .running, bpm: Int? = 142, age: TimeInterval = 5,
    isDimmed: Bool = false
  ) -> HeartRateDisplay {
    HeartRateDisplay(
      workoutState: state, reading: bpm.map { HeartRateReading(bpm: $0, date: now - age) },
      now: now, isDimmed: isDimmed)
  }

  @Test("US3 s1 a running workout with a reading 5 s old shows the number")
  func freshReading() {
    let display = Self.display()
    #expect(display == .value(142))
    #expect(display.text == "142")
  }

  @Test("US3 s3 no reading, a stale reading or a pause shows \"--\"")
  func unavailable() {
    #expect(Self.display(bpm: nil) == .unavailable)
    #expect(Self.display(bpm: nil).text == "--")
    #expect(Self.display(age: 30) == .value(142))  // the boundary still shows
    #expect(Self.display(age: 30.001) == .unavailable)
    #expect(Self.display(.paused) == .unavailable)
    #expect(Self.display(.paused, bpm: nil) == .unavailable)
  }

  @Test(
    "US3 s4 no row without a running workout",
    arguments: [
      WorkoutState.none, .failed, .discarded, .saving, .saved,
      .summary(openedAt: Date(timeIntervalSinceReferenceDate: 9_000)),
    ])
  func hidden(state: WorkoutState) {
    #expect(Self.display(state) == .hidden)
    #expect(Self.display(state).text == nil)
    #expect(Self.display(state).accessibilityLabel(locale: Self.en) == nil)
  }

  @Test("US3 s5 Always On hides the row")
  func alwaysOn() {
    #expect(Self.display() == .value(142))  // positive control
    #expect(Self.display(isDimmed: true) == .hidden)
    #expect(Self.display(.paused, isDimmed: true) == .hidden)
  }

  @Test(
    "US3 s6 VoiceOver reads the heart rate with plural forms",
    arguments: [
      (en, 142, "Heart rate, 142 beats per minute"),
      (en, 1, "Heart rate, 1 beat per minute"),
      (pl, 1, "Tętno, 1 uderzenie na minutę"),
      (pl, 2, "Tętno, 2 uderzenia na minutę"),
      (pl, 5, "Tętno, 5 uderzeń na minutę"),
      (pl, 22, "Tętno, 22 uderzenia na minutę"),
      (uk, 1, "Пульс, 1 удар на хвилину"),
      (uk, 2, "Пульс, 2 удари на хвилину"),
      (uk, 5, "Пульс, 5 ударів на хвилину"),
      (uk, 22, "Пульс, 22 удари на хвилину"),
    ])
  func spoken(locale: Locale, bpm: Int, expected: String) {
    #expect(Self.display(bpm: bpm).accessibilityLabel(locale: locale) == expected)
  }

  @Test("US3 s6 \"--\" is read as \"Heart rate unavailable\"")
  func spokenUnavailable() {
    let display = Self.display(bpm: nil)
    #expect(display.accessibilityLabel(locale: Self.en) == "Heart rate unavailable")
    #expect(display.accessibilityLabel(locale: Self.pl) == "Tętno niedostępne")
    #expect(display.accessibilityLabel(locale: Self.uk) == "Пульс недоступний")
    // Positive control: the translation is used, not the English source.
    #expect(
      Self.display().accessibilityLabel(locale: Self.pl)
        != Self.display().accessibilityLabel(locale: Self.en))
  }

  @Test("Edge: heart rate above 199 shows all three digits")
  func threeDigits() {
    #expect(Self.display(bpm: 205).text == "205")
  }

  @Test("US3 s2 a new reading is shown without animation")
  func noAnimation() {
    for display in [Self.display(), Self.display(bpm: nil), Self.display(.none)] {
      #expect(display.animation == nil)
    }
  }
}
