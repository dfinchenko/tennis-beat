/// A won/played count, `0 ≤ won ≤ of`.
public struct Tally: Sendable, Hashable {
  public internal(set) var won: Int
  public internal(set) var of: Int

  public init(won: Int, of: Int) {
    self.won = won
    self.of = of
  }

  static let zero = Tally(won: 0, of: 0)
}

/// One player's stats (FR-024 to FR-026).
public struct PlayerStats: Sendable, Hashable {
  public internal(set) var pointsWonOnServe: Tally
  public internal(set) var pointsWonOnReturn: Tally
  /// Completed standard games served [ITF: BP-03].
  public internal(set) var serviceGamesHeld: Tally
  /// Converted / opportunities, as the receiver [ITF: BP-01, BP-02].
  public internal(set) var breakPointsConverted: Tally
  /// Saved / faced, as the server [ITF: BP-01, BP-02].
  public internal(set) var breakPointsSaved: Tally

  static let zero = PlayerStats(
    pointsWonOnServe: .zero,
    pointsWonOnReturn: .zero,
    serviceGamesHeld: .zero,
    breakPointsConverted: .zero,
    breakPointsSaved: .zero
  )
}

/// Stats for both players, computed from the match record.
public struct MatchStats: Sendable, Hashable {
  public internal(set) var me: PlayerStats
  public internal(set) var opponent: PlayerStats

  public subscript(player: Player) -> PlayerStats {
    player == .me ? me : opponent
  }

  static let zero = MatchStats(me: .zero, opponent: .zero)
}
