import SwiftUI

/// Health onboarding (spec 003 Story 1, FR-002; `docs/design/screens/watch-0-health-onboarding.md`):
/// what Tennis Beat saves to and reads from Health, with Continue (the system sheet) and Not
/// now. It scrolls and has no Dynamic Type cap (US6 s2); at the default size Continue is
/// pinned to the bottom so it shows without scrolling (Denys, #29).
struct HealthOnboardingView: View {
  /// Catalog keys, also the identifiers (contract §1).
  private static let lines = (1...3).map { "health.onboarding.line.\($0)" }
  @Environment(HealthOnboarding.self) private var onboarding
  @State private var isRequesting = false
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 8) {
        Text("health.onboarding.title")
          .font(.watchHeadline)
          .foregroundStyle(Color.brandBall)
          .fixedSize(horizontal: false, vertical: true)
          .accessibilityAddTraits(.isHeader)
          .accessibilityIdentifier("health.onboarding.title")
          .accessibilitySortPriority(4)

        ForEach(Self.lines, id: \.self) { key in
          Text(LocalizedStringKey(key))
            .font(.watchBody)
            .foregroundStyle(Color.watchTextSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier(key)
            .accessibilitySortPriority(3)
        }

        if !pinsContinue { continueButton }

        Button(action: onboarding.notNow) {
          Text("health.onboarding.notNow")
            .font(.watchTitle)
            .multilineTextAlignment(.center)
        }
        .buttonStyle(CapsuleButtonStyle(fill: .watchSurfaceRaised, text: .watchTextPrimary))
        .disabled(isRequesting)
        .accessibilityIdentifier("health.onboarding.notNow")
        .accessibilitySortPriority(1)
      }
    }
    // Denys's design condition on #29: at the default size Continue stays visible without
    // scrolling; at larger sizes it scrolls with the text, as on the Controls page.
    .safeAreaInset(edge: .bottom) {
      if pinsContinue {
        continueButton.background(Color.watchBackground)
      }
    }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("health.onboarding")
  }

  /// Continue is pinned at the default text size and smaller.
  private var pinsContinue: Bool { dynamicTypeSize <= .large }

  private var continueButton: some View {
    Button {
      isRequesting = true
      Task {
        await onboarding.allow()
        isRequesting = false
      }
    } label: {
      Text("health.onboarding.continue")
        .font(.watchTitle)
        .multilineTextAlignment(.center)
    }
    .buttonStyle(CapsuleButtonStyle(fill: .brandBall, text: .brandOnBall))
    .disabled(isRequesting)
    .accessibilityIdentifier("health.onboarding.continue")
    // Read after the text and before Not now, wherever it is drawn.
    .accessibilitySortPriority(2)
    .padding(.top, 4)
  }
}

#if DEBUG
  #Preview {
    let onboarding = HealthOnboarding.preview
    HealthOnboardingView()
      .environment(onboarding)
      .task { await onboarding.load() }
  }
#endif
