import SwiftUI
import TennisCore

/// Watch 6 — Summary: the result, a chip per set, the duration, Done and Undo (Story 5,
/// FR-019, FR-020). It scrolls. Spec 003: the heart-rate and energy rows after Duration
/// (FR-013), and Undo hidden once the workout is being saved (FR-007).
struct SummaryView: View {
  @Environment(MatchSession.self) private var session
  @Environment(\.locale) private var locale

  var body: some View {
    if let match = session.match, let clock = session.clock {
      let model = SummaryModel(
        state: match.state, clock: clock, locale: locale, statistics: session.summaryStatistics)
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

          // One VoiceOver element over the whole row, read in spoken units, not the h:mm:ss
          // digits (#23 R1-3).
          SummaryRow(
            label: Text("summary.duration"), value: Text(model.duration),
            accessibilityLabel: Text("summary.duration"), accessibilityValue: model.spokenDuration,
            identifier: "summary.duration")

          // Spec 003: heart rate and active energy, each only with a value (Story 4 s1, s2).
          ForEach(model.health.rows, id: \.kind) { row in
            SummaryRow(
              label: Text(row.label), value: Text(row.value), showsHeart: row.kind == .heartRate,
              accessibilityLabel: Text(row.accessibilityLabel), accessibilityValue: nil,
              identifier: row.kind == .heartRate ? "summary.heartRate" : "summary.energy")
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
}

/// A label and a value (Watch 6 key–value rows): side by side when they fit, else stacked. One
/// VoiceOver element over the whole row, at least 44 pt (the audit's minimum, T074).
private struct SummaryRow: View {
  let label: Text
  let value: Text
  /// The `status/heart` icon before the value (the heart-rate row).
  var showsHeart = false
  let accessibilityLabel: Text
  let accessibilityValue: String?
  let identifier: String

  var body: some View {
    ViewThatFits(in: .horizontal) {
      HStack {
        styledLabel
        Spacer(minLength: 8)
        styledValue
      }
      VStack(alignment: .leading, spacing: 2) {
        styledLabel
        styledValue
      }
    }
    .accessibilityHidden(true)
    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
    .overlay {
      Color.clear
        .accessibilityElement()
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue.map { Text($0) } ?? Text(verbatim: ""))
        .accessibilityIdentifier(identifier)
    }
  }

  private var styledLabel: some View {
    label
      .font(.watchBody)
      .foregroundStyle(Color.watchTextSecondary)
      .fixedSize(horizontal: false, vertical: true)
  }

  private var styledValue: some View {
    HStack(alignment: .firstTextBaseline, spacing: 4) {
      if showsHeart {
        // Always with the numbers and the label: never color-only meaning (US6).
        Image(systemName: "heart.fill")
          .font(.watchFootnote)
          .foregroundStyle(Color.statusHeart)
      }
      value
        .font(.watchNumber)
        .monospacedDigit()
        .foregroundStyle(Color.watchTextPrimary)
    }
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
