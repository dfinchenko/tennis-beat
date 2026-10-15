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
  @State private var session = Self.makeSession()

  var body: some Scene {
    WindowGroup {
      RootView()
        .environment(session)
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

  private static func makeSession() -> MatchSession {
    let options = LaunchOptions.current
    let store = FormatStore(defaults: .standard)
    if options.resetFormat { store.reset() }
    let coinToss: () -> Player =
      if let fixed = options.coinToss { { fixed } } else { CoinToss.systemToss }
    return MatchSession(
      store: store, haptics: WatchHaptics(), announcer: VoiceOverAnnouncer(), now: Date.init,
      coinToss: coinToss)
  }
}
