import SwiftUI

/// Switches on the session's route (research R6).
struct RootView: View {
  @Environment(MatchSession.self) private var session
  @Environment(HealthOnboarding.self) private var onboarding

  var body: some View {
    // Spec 003 Story 1: nothing until the Health status is read (at most 1 s), then the
    // onboarding while the sheet was never answered, then the match flow.
    if !onboarding.isReady {
      Color.black.ignoresSafeArea()
    } else if onboarding.needsOnboarding {
      HealthOnboardingView()
    } else {
      matchFlow
    }
  }

  @ViewBuilder private var matchFlow: some View {
    switch session.route {
    case .setup:
      SetupFlowView()
    case .playing:
      MatchPagesView()
    case .summary:
      SummaryView()
    }
  }
}

#if DEBUG
  #Preview {
    RootView()
      .environment(MatchSession.preview)
      .environment(HealthOnboarding.preview)
  }
#endif
