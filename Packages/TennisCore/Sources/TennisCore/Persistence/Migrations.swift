import Foundation

/// Upgrades saved match JSON from an older `formatVersion` to the current one.
///
/// Versioning rules (`specs/001-scoring-engine/contracts/saved-format.md`):
/// - Any change to the saved layout bumps `MatchCodec.currentFormatVersion` and adds one step
///   here, from the previous version to the new one.
/// - Each released version keeps a frozen fixture in `Tests/TennisCoreTests/Fixtures/saved-format/`
///   that the tests restore. Fixtures are never edited after release.
enum Migrations {
  /// `steps[k]` turns a version `k + 1` JSON object into a version `k + 2` one.
  /// Empty: version 1 is the first released version.
  static let steps: [@Sendable (inout [String: Any]) -> Bool] = []

  /// Returns `data` upgraded to `MatchCodec.currentFormatVersion`, or `nil` if a step fails.
  static func migrate(_ data: Data, from version: Int) -> Data? {
    guard version < MatchCodec.currentFormatVersion else { return data }
    guard var object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
      return nil
    }
    for step in steps[(version - 1)...] {
      guard step(&object) else { return nil }
    }
    object["formatVersion"] = MatchCodec.currentFormatVersion
    return try? JSONSerialization.data(withJSONObject: object)
  }
}
