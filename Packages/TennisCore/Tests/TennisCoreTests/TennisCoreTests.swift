import Testing

@testable import TennisCore

@Suite struct TennisCoreTests {
  // Placeholder until the scoring engine spec is approved.
  @Test func moduleIsLinked() {
    #expect(TennisCore.version == "0.0.0")
  }
}
