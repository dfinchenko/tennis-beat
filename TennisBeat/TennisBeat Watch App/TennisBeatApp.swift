//
//  TennisBeatApp.swift
//  TennisBeat Watch App
//
//  Created by Denys Finchenko on 06/10/2026.
//

import SwiftUI
import TennisCore

/// The one workout service, shared by the session, the onboarding and the workout recovery.
enum AppServices {
  static let workout: WorkoutService = makeWorkoutService()

  /// HealthKit, or the fake for `-uiTestHealth` (contract §2).
  private static func makeWorkoutService() -> WorkoutService {
    let options = LaunchOptions.current
    guard let mode = options.healthMode else { return HealthKitWorkoutService() }
    let fake = FakeWorkoutService(
      mode: mode, now: Date.init, saveFails: options.saveFails, heartRate: options.heartRate)
    if let stats = options.workoutStats { fake.stats = stats }
    return fake
  }
}

@main
struct TennisBeat_Watch_AppApp: App {
  @WKApplicationDelegateAdaptor private var appDelegate: AppDelegate
  @Environment(\.scenePhase) private var scenePhase
  @State private var session: MatchSession
  @State private var onboarding: HealthOnboarding

  init() {
    let workout = AppServices.workout
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
    .onChange(of: scenePhase) { _, phase in
      // Research R4: the 10-minute save, if the timer missed while the app was suspended.
      if phase == .active { session.checkSummaryTimeout() }
    }
  }

  /// `-uiTestAlwaysOn`: as if the wrist were lowered.
  private struct ForcedAlwaysOn: ViewModifier {
    let isOn: Bool

    func body(content: Content) -> some View {
      if isOn { content.environment(\.isLuminanceReduced, true) } else { content }
    }
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
