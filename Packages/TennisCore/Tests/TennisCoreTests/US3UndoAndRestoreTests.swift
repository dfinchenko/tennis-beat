import Foundation
import Testing

@testable import TennisCore

@Suite("US3 Undo any mistake, and resume after a crash")
struct US3UndoAndRestoreTests {

  // ITF: MT-01
  @Test("US3 s9 a point after the match is won is rejected and nothing changes")
  func s9Won() throws {
    var m = try Match.make(.oneSet)
    m.winSet(.me)
    #expect(m.state.status == .won(.me))
    let before = m
    #expect(throws: MatchError.matchNotInProgress) {
      try m.recordPoint(wonBy: .opponent, at: m.nextTime)
    }
    #expect(m == before)
  }
}
