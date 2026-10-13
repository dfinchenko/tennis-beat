/// One of the two players. Names are attached outside the engine.
public enum Player: String, Sendable, Hashable, CaseIterable {
  case me
  case opponent

  /// The other player.
  public var other: Player {
    self == .me ? .opponent : .me
  }
}

/// A value for each player. Order is always Me, then Opponent.
public struct PlayerPair<Value: Sendable & Hashable>: Sendable, Hashable {
  public var me: Value
  public var opponent: Value

  public init(me: Value, opponent: Value) {
    self.me = me
    self.opponent = opponent
  }

  public internal(set) subscript(player: Player) -> Value {
    get { player == .me ? me : opponent }
    set {
      if player == .me { me = newValue } else { opponent = newValue }
    }
  }
}

extension PlayerPair where Value == Int {
  static let zero = PlayerPair(me: 0, opponent: 0)
}
