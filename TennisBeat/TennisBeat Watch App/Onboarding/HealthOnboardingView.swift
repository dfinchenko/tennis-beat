import SwiftUI

/// Health onboarding (spec 003 Story 1, FR-002; `docs/design/screens/watch-0-health-onboarding.md`):
/// what Tennis Beat saves to and reads from Health, with Continue (the system sheet) and Not
/// now. It scrolls and has no Dynamic Type cap (US6 s2).
struct HealthOnboardingView: View {
  /// Catalog keys, also the identifiers (contract §1).
  private static let lines = (1...3).map { "health.onboarding.line.\($0)" }
  @Environment(HealthOnboarding.self) private var onboarding
  @State private var isRequesting = false

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 8) {
        Text("health.onboarding.title")
          .font(.watchHeadline)
          .foregroundStyle(Color.brandBall)
          .fixedSize(horizontal: false, vertical: true)
          .accessibilityAddTraits(.isHeader)
          .accessibilityIdentifier("health.onboarding.title")

        ForEach(Self.lines, id: \.self) { key in
          Text(LocalizedStringKey(key))
            .font(.watchBody)
            .foregroundStyle(Color.watchTextSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier(key)
        }

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
        .padding(.top, 4)

        Button(action: onboarding.notNow) {
          Text("health.onboarding.notNow")
            .font(.watchTitle)
            .multilineTextAlignment(.center)
        }
        .buttonStyle(CapsuleButtonStyle(fill: .watchSurfaceRaised, text: .watchTextPrimary))
        .disabled(isRequesting)
        .accessibilityIdentifier("health.onboarding.notNow")
      }
    }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("health.onboarding")
  }
}

#Preview {
  let onboarding = HealthOnboarding.preview
  HealthOnboardingView()
    .environment(onboarding)
    .task { await onboarding.load() }
}
