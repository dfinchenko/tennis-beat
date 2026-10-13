/// Why the engine rejected an event or an event list (FR-005).
public enum MatchError: Error, Sendable, Hashable {
  /// The list is empty or does not start with a setup event.
  case missingSetup
  /// A second setup event.
  case duplicateSetup
  /// An unsupported format [ITF: MT-02, ST-07].
  case invalidFormat
  /// A point or an early end after the match was won or ended early [ITF: MT-08].
  case matchNotInProgress
  /// A correction to the current first server [ITF: CE-02].
  case sameFirstServer
}
