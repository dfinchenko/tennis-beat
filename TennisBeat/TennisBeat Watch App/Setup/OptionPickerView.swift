import SwiftUI

/// The values of one setting row; the current one is checked. Picking returns to New match.
struct OptionPickerView: View {
  @Environment(MatchSession.self) private var session
  @Environment(\.dismiss) private var dismiss
  let row: SetupRow

  var body: some View {
    @Bindable var session = session
    List(row.options, id: \.self) { raw in
      let isSelected = row.selected(in: session.formatChoice) == raw
      Button {
        row.select(raw, in: &session.formatChoice)
        dismiss()
      } label: {
        HStack {
          Text(row.title(for: raw))
            .font(.watchTitle)
          Spacer()
          if isSelected {
            Image(systemName: "checkmark")
              .foregroundStyle(Color.brandBall)
              .accessibilityHidden(true)
          }
        }
      }
      .accessibilityAddTraits(isSelected ? .isSelected : [])
      .accessibilityIdentifier("picker.option.\(raw)")
    }
    .navigationTitle(Text(row.caption))
  }
}

#Preview {
  NavigationStack {
    OptionPickerView(row: .setLength)
  }
  .environment(MatchSession.preview)
}
