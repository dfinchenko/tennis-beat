import SwiftUI

/// Watch 1 — New match: four setting rows (Set length second, Q1) and Start.
struct NewMatchView: View {
  @Environment(MatchSession.self) private var session
  @Binding var path: [SetupDestination]

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 8) {
        Text("setup.title")
          .font(.watchLargeTitle)
          .foregroundStyle(Color.brandBall)
          .accessibilityAddTraits(.isHeader)

        ForEach(SetupRow.visible(for: session.formatChoice)) { row in
          SettingRow(row: row, choice: session.formatChoice) {
            path.append(.picker(row))
          }
        }

        Button {
          path.append(.firstServer)
        } label: {
          Text("setup.start")
            .font(.watchTitle)
            .multilineTextAlignment(.center)
        }
        .buttonStyle(CapsuleButtonStyle(fill: .brandBall, text: .brandOnBall))
        .accessibilityIdentifier("setup.start")
        .padding(.top, 4)
      }
    }
  }
}

/// A setting row: caption above value on `watch/surface`. One button for VoiceOver,
/// read as "<caption>, <value>, button" (Story 7 s5).
private struct SettingRow: View {
  let row: SetupRow
  let choice: FormatChoice
  let action: () -> Void

  var body: some View {
    let value = row.selectedOption(in: choice).title
    Button(action: action) {
      VStack(alignment: .leading, spacing: 2) {
        Text(row.caption)
          .font(.watchFootnote)
          .foregroundStyle(Color.watchTextSecondary)
        Text(value)
          .font(.watchTitle)
          .foregroundStyle(Color.watchTextPrimary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .background(Color.watchSurface, in: .rect(cornerRadius: 16))
      .contentShape(.rect(cornerRadius: 16))
    }
    .buttonStyle(.plain)
    .accessibilityLabel(Text(row.caption))
    .accessibilityValue(Text(value))
    .accessibilityIdentifier(row.identifier)
  }
}

/// Full-width capsule button (Watch 1 Start, Watch 2 choices). The vertical padding keeps
/// a label that wraps at large text sizes off the capsule's ends (R1-4 of #18).
struct CapsuleButtonStyle: ButtonStyle {
  let fill: Color
  let text: Color
  var minHeight: CGFloat = 44

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .foregroundStyle(text)
      .padding(.vertical, 7)
      .frame(maxWidth: .infinity, minHeight: minHeight)
      .padding(.horizontal, 12)
      .background(fill, in: .capsule)
      .opacity(configuration.isPressed ? 0.7 : 1)
      .contentShape(.capsule)
  }
}

#Preview {
  NavigationStack {
    NewMatchView(path: .constant([]))
  }
  .environment(MatchSession.preview)
}
