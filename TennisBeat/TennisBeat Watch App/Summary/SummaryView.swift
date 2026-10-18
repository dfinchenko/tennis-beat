import SwiftUI
import TennisCore

/// Watch 6 — Summary: the result, a chip per set, the duration, Done and Undo (Story 5,
/// FR-019, FR-020). It scrolls. Spec 003: Undo is hidden once the workout is being saved;
/// the heart-rate and energy rows come in 003 PR 4.
struct SummaryView: View {
  @Environment(MatchSession.self) private var session
  @Environment(\.locale) private var locale

  var body: some View {
    if let match = session.match, let clock = session.clock {
      let model = SummaryModel(state: match.state, clock: clock, locale: locale)
      ScrollView {
        VStack(alignment: .leading, spacing: 10) {
          Text(model.title)
            .font(.watchLargeTitle)
            .foregroundStyle(Color.brandBall)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("summary.title")

          // The chips wrap at large text sizes; order and VoiceOver carry the meaning too.
          FlowLayout(spacing: 6) {
            ForEach(Array(model.chips.enumerated()), id: \.offset) { index, chip in
              Text(chip.text)
                .font(.watchNumber)
                .monospacedDigit()
                .foregroundStyle(chip.isLost ? Color.watchTextTertiary : Color.watchTextPrimary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.watchSurfaceRaised, in: .capsule)
                .accessibilityLabel(chip.accessibilityLabel)
                .accessibilityIdentifier("summary.chip.\(index + 1)")
            }
          }

          ViewThatFits(in: .horizontal) {
            HStack {
              durationLabel
              Spacer(minLength: 8)
              durationValue(model.duration)
            }
            VStack(alignment: .leading, spacing: 2) {
              durationLabel
              durationValue(model.duration)
            }
          }
          .accessibilityHidden(true)
          .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
          .overlay {
            // One VoiceOver element over the whole row, at least 44 pt (the audit's minimum,
            // T074), read in spoken units, not the h:mm:ss digits (#23 R1-3).
            Color.clear
              .accessibilityElement()
              .accessibilityLabel(Text("summary.duration"))
              .accessibilityValue(model.spokenDuration)
              .accessibilityIdentifier("summary.duration")
          }

          Button(action: session.done) {
            Text("summary.done")
              .font(.watchTitle)
              .multilineTextAlignment(.center)
          }
          .buttonStyle(CapsuleButtonStyle(fill: .brandBall, text: .brandOnBall))
          .accessibilityIdentifier("summary.done")

          // Q7: a secondary Undo under Done. Spec 003: gone once a workout save has started;
          // back if it fails (FR-007, R3-2, #28 R6-3).
          if session.canUndo {
            Button(action: session.undo) {
              Text("score.undo")
                .font(.watchTitle)
                .multilineTextAlignment(.center)
            }
            .buttonStyle(CapsuleButtonStyle(fill: .watchSurfaceRaised, text: .watchTextPrimary))
            .accessibilityIdentifier("summary.undo")
          }
        }
      }
    }
  }

  private var durationLabel: some View {
    Text("summary.duration")
      .font(.watchBody)
      .foregroundStyle(Color.watchTextSecondary)
  }

  private func durationValue(_ duration: String) -> some View {
    Text(duration)
      .font(.watchNumber)
      .monospacedDigit()
      .foregroundStyle(Color.watchTextPrimary)
  }
}

/// Lays out children in rows, wrapping to the next row when one doesn't fit.
private struct FlowLayout: Layout {
  var spacing: CGFloat

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
    let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
    let width = rows.map(\.width).max() ?? 0
    return CGSize(width: proposal.width ?? width, height: height)
  }

  func placeSubviews(
    in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
  ) {
    var y = bounds.minY
    for row in arrange(width: bounds.width, subviews: subviews) {
      var x = bounds.minX
      for index in row.indices {
        let size = Self.size(of: subviews[index], width: bounds.width)
        subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
        x += size.width + spacing
      }
      y += row.height + spacing
    }
  }

  private struct Row {
    var indices: [Int] = []
    var width: CGFloat = 0
    var height: CGFloat = 0
  }

  /// A child's natural size, or its size at the full width when it would be wider, so a
  /// chip at a large text size wraps instead of running off the screen (#23 R1-4).
  private static func size(of subview: LayoutSubview, width: CGFloat) -> CGSize {
    let natural = subview.sizeThatFits(.unspecified)
    guard natural.width > width else { return natural }
    return subview.sizeThatFits(ProposedViewSize(width: width, height: nil))
  }

  private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
    var rows: [Row] = []
    var row = Row()
    for index in subviews.indices {
      let size = Self.size(of: subviews[index], width: width)
      let added = row.indices.isEmpty ? size.width : row.width + spacing + size.width
      if added > width, !row.indices.isEmpty {
        rows.append(row)
        row = Row()
      }
      row.width = row.indices.isEmpty ? size.width : row.width + spacing + size.width
      row.height = max(row.height, size.height)
      row.indices.append(index)
    }
    if !row.indices.isEmpty { rows.append(row) }
    return rows
  }
}

#if DEBUG
  #Preview {
    let session = MatchSession.preview
    session.start(firstServer: .me)
    session.addPoint(for: .me)
    session.endEarly()
    return SummaryView().environment(session)
  }
#endif
