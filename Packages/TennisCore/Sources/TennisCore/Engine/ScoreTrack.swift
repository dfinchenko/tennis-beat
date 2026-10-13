/// The part of a match that depends only on who won each point and the format (research R1).
/// It never depends on who serves, so a first-server correction cannot change it.
struct ScoreTrack: Sendable, Hashable {
  /// What kind of game is being played.
  enum Mode: Sendable, Hashable {
    case standard
    /// A 7-point tie-break at N–N [ITF: TB-01].
    case tieBreak
    /// A 10-point match tie-break instead of the deciding set [ITF: MT-03].
    case matchTieBreak
  }

  /// What one point did to the score.
  struct Outcome: Sendable, Hashable {
    /// The mode the point was played in.
    var mode: Mode
    /// Points already played in the game or tie-break before this point.
    var pointsBefore: PlayerPair<Int>
    /// The point ended a standard game, a tie-break or the match tie-break.
    var gameEnded = false
    /// Games played in the set once that game ended (a tie-break counts as one game).
    var gamesInSetAfterGame = 0
    var matchEnded = false
  }

  let format: MatchFormat
  private(set) var completedSets: [SetScore] = []
  private(set) var setsWon: PlayerPair<Int> = .zero
  private(set) var games: PlayerPair<Int> = .zero
  /// Raw points in the current game or tie-break.
  private(set) var points: PlayerPair<Int> = .zero
  private(set) var mode: Mode = .standard
  private(set) var winner: Player?
  /// The most recent point's change-of-ends value; `false` before the first point.
  private(set) var changeOfEnds = false

  init(format: MatchFormat) {
    self.format = format
  }

  var pointsPlayedInGame: Int { points.me + points.opponent }

  // MARK: Exposed values

  /// [ITF: GM-01, GM-02, TB-01]
  var pointDisplays: PlayerPair<PointDisplay> {
    if mode != .standard {
      return PlayerPair(me: .tieBreak(points.me), opponent: .tieBreak(points.opponent))
    }
    if points.me >= 3 && points.opponent >= 3 {
      if points.me == points.opponent { return PlayerPair(me: .forty, opponent: .forty) }
      return points.me > points.opponent
        ? PlayerPair(me: .advantage, opponent: .forty)
        : PlayerPair(me: .forty, opponent: .advantage)
    }
    return PlayerPair(me: Self.display(points.me), opponent: Self.display(points.opponent))
  }

  /// Advantage standard games at equal scores of 3 or more each (FR-015) [ITF: GM-02].
  var isDeuce: Bool {
    mode == .standard && format.gameScoring == .advantage && points.me >= 3
      && points.me == points.opponent
  }

  /// No-Ad standard games at 3–3 (FR-015) [ITF: NA-01].
  var isDecidingPoint: Bool {
    mode == .standard && format.gameScoring == .noAd && points.me == 3 && points.opponent == 3
  }

  // MARK: Rules

  /// Whether `points` (for `player`) ends the current game or tie-break.
  func winsGame(_ player: Player, with points: PlayerPair<Int>) -> Bool {
    let mine = points[player]
    let theirs = points[player.other]
    switch mode {
    case .standard:
      switch format.gameScoring {
      case .advantage: return mine >= 4 && mine - theirs >= 2  // ITF: GM-02
      case .noAd: return mine >= 4  // ITF: NA-01
      }
    case .tieBreak: return mine >= 7 && mine - theirs >= 2  // ITF: TB-01
    case .matchTieBreak: return mine >= 10 && mine - theirs >= 2  // ITF: MT-03
    }
  }

  // MARK: Progression

  mutating func addPoint(_ player: Player) -> Outcome {
    var outcome = Outcome(mode: mode, pointsBefore: points)
    points[player] += 1
    defer { changeOfEnds = Self.changeOfEnds(after: outcome, pointsPlayed: points) }
    guard winsGame(player, with: points) else { return outcome }

    outcome.gameEnded = true
    switch mode {
    case .standard:
      games[player] += 1
      outcome.gamesInSetAfterGame = games.me + games.opponent
      let n = format.setLength.rawValue
      if games[player] >= n && games[player] - games[player.other] >= 2 {
        // ITF: ST-03, ST-04, ST-06, ST-07
        completeSet(winner: player, tieBreak: nil)
      } else if games.me == n && games.opponent == n {
        mode = .tieBreak
      }
    case .tieBreak:
      games[player] += 1
      outcome.gamesInSetAfterGame = games.me + games.opponent
      completeSet(winner: player, tieBreak: points)
    case .matchTieBreak:
      // ITF: MT-05 — recorded as the deciding set, won 1–0, with its point score.
      games[player] = 1
      outcome.gamesInSetAfterGame = 1
      completeSet(winner: player, tieBreak: points, isMatchTieBreak: true)
    }
    points = .zero
    outcome.matchEnded = winner != nil
    return outcome
  }

  private mutating func completeSet(
    winner setWinner: Player, tieBreak: PlayerPair<Int>?, isMatchTieBreak: Bool = false
  ) {
    completedSets.append(
      SetScore(
        games: games, tieBreak: tieBreak, isMatchTieBreak: isMatchTieBreak, winner: setWinner))
    setsWon[setWinner] += 1
    games = .zero
    let setsNeeded = format.length == .oneSet ? 1 : 2  // ITF: MT-01, MT-02
    if setsWon[setWinner] == setsNeeded {
      winner = setWinner
      mode = .standard
    } else if format.length == .bestOfThree && format.matchTieBreak && setsWon.me == 1
      && setsWon.opponent == 1
    {
      mode = .matchTieBreak  // ITF: MT-03
    } else {
      mode = .standard
    }
  }

  /// The change-of-ends value of the point that produced `outcome` (data-model rules 1–4).
  private static func changeOfEnds(after outcome: Outcome, pointsPlayed: PlayerPair<Int>) -> Bool {
    // 1. ITF: EN-05 — never after the match-winning point.
    if outcome.matchEnded { return false }
    // 2. ITF: EN-01, EN-02, EN-03, EN-04 — a game (or set tie-break) that makes the set's games odd.
    if outcome.gameEnded { return !outcome.gamesInSetAfterGame.isMultiple(of: 2) }
    // 3. ITF: TB-05 — every 6 points inside a tie-break or match tie-break.
    if outcome.mode != .standard {
      let played = pointsPlayed.me + pointsPlayed.opponent
      return played > 0 && played.isMultiple(of: 6)
    }
    // 4.
    return false
  }

  private static func display(_ points: Int) -> PointDisplay {
    switch points {
    case 0: .zero
    case 1: .fifteen
    case 2: .thirty
    default: .forty
    }
  }
}
