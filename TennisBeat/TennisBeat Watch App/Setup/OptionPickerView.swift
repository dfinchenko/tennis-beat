import SwiftUI

/// The values of one setting row; the current one is checked. Picking returns to New match.
struct OptionPickerView: View {
  @Environment(MatchSession.self) private var session
  @Environment(\.dismiss) private var dismiss
  let row: SetupRow

  var body: some View {
    @Bindable var session = session
    List(row.options) { option in
      let isSelected = row.selectedOption(in: session.formatChoice).raw == option.raw
      Button {
        row.select(option.raw, in: &session.formatChoice)
        dismiss()
      } label: {
        HStack {
          Text(option.title)
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
      .accessibilityIdentifier("picker.option.\(option.raw)")
    }
    .navigationTitle(Text(row.caption))
  }
}

#if DEBUG
  #Preview {
    NavigationStack {
      OptionPickerView(row: .setLength)
    }
    .environment(MatchSession.preview)
  }
#endif
