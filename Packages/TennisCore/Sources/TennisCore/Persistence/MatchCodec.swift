import Foundation

/// Why a saved match could not be restored (FR-031).
public enum RestoreError: Error, Sendable, Hashable {
  case unsupportedVersion(found: Int, supported: Int)
  /// Not JSON, missing keys, or an unknown event type.
  case malformed
  /// Well-formed, but breaks a rule.
  case invalid(MatchError)
}

/// Saves and restores a match record. See `specs/001-scoring-engine/contracts/saved-format.md`.
///
/// Stub (T011): implemented in the US3 phase.
public enum MatchCodec {
  public static let currentFormatVersion = 1

  public static func encode(_ match: Match) throws(EncodingError) -> Data {
    Data()
  }

  public static func decode(_ data: Data) -> Result<Match, RestoreError> {
    .failure(.malformed)
  }
}
