//
//  TennisBeatApp.swift
//  TennisBeat Watch App
//
//  Created by Denys Finchenko on 06/10/2026.
//

import SwiftUI
import TennisCore

@main
struct TennisBeat_Watch_AppApp: App {
  @State private var session: MatchSession
  @State private var onboarding: HealthOnboarding

  init() {
    let workout = Self.makeWorkoutService()
    _session = State(initialValue: Self.makeSession(workout: workout))
    _onboarding = State(initialValue: HealthOnboarding(service: workout))
  }

  var body: some Scene {
    WindowGroup {
      RootView()
        .environment(session)
        .environment(onboarding)
        .task { await onboarding.load() }
        .modifier(ForcedAlwaysOn(isOn: LaunchOptions.current.alwaysOn))
    }
  }

  /// `-uiTestAlwaysOn`: as if the wrist were lowered.
  private struct ForcedAlwaysOn: ViewModifier {
    let isOn: Bool

    func body(content: Content) -> some View {
      if isOn { content.environment(\.isLuminanceReduced, true) } else { content }
    }
  }

  /// HealthKit, or the fake for `-uiTestHealth` (contract §2).
  private static func makeWorkoutService() -> WorkoutService {
    let options = LaunchOptions.current
    guard let mode = options.healthMode else { return HealthKitWorkoutService() }
    let fake = FakeWorkoutService(mode: mode, now: Date.init, saveFails: options.saveFails)
    if let stats = options.workoutStats { fake.stats = stats }
    return fake
  }

  private static func makeSession(workout: WorkoutService) -> MatchSession {
    let options = LaunchOptions.current
    let store = FormatStore(defaults: .standard)
    if options.resetFormat { store.reset() }
    let coinToss: () -> Player =
      if let fixed = options.coinToss { { fixed } } else { CoinToss.systemToss }
    return MatchSession(
      store: store, haptics: WatchHaptics(), announcer: VoiceOverAnnouncer(), workout: workout,
      now: Date.init,
      coinToss: coinToss)
  }
}
