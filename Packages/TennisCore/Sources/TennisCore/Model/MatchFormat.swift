/// Match length [ITF: MT-01, MT-02].
public enum MatchLength: String, Sendable, Hashable {
  case oneSet
  case bestOfThree
}

/// Games needed to win a set, N [ITF: ST-04, ST-06, ST-07].
public enum SetLength: Int, Sendable, Hashable {
  case four = 4
  case six = 6
  case eight = 8
}

/// Game scoring [ITF: GM-02, NA-01].
public enum GameScoring: String, Sendable, Hashable {
  case advantage
  case noAd
}

/// The format of a match. All sets are tie-break sets [ITF: ST-01].
public struct MatchFormat: Sendable, Hashable {
  public let length: MatchLength
  public let setLength: SetLength
  public let gameScoring: GameScoring
  /// A 10-point match tie-break replaces the deciding set [ITF: MT-03].
  public let matchTieBreak: Bool

  /// Throws `.invalidFormat` when `matchTieBreak` is set for a 1-set match [ITF: MT-02].
  public init(
    length: MatchLength,
    setLength: SetLength,
    gameScoring: GameScoring,
    matchTieBreak: Bool
  ) throws(MatchError) {
    self.length = length
    self.setLength = setLength
    self.gameScoring = gameScoring
    self.matchTieBreak = matchTieBreak
  }
}

/// The format plus the first server. The coin toss is resolved by the app [ITF: SV-01].
public struct MatchSetup: Sendable, Hashable {
  public let format: MatchFormat
  public let firstServer: Player

  public init(format: MatchFormat, firstServer: Player) {
    self.format = format
    self.firstServer = firstServer
  }
}
