import Testing

@testable import TennisCore

@Suite struct TennisCoreTests {
  @Test func moduleVersion() {
    #expect(TennisCore.version == "0.1.0")
  }
}
