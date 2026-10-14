/// A `sleep` the test ends by hand, for `WatchHaptics`' delayed change-of-ends haptic.
@MainActor
final class ManualSleep {
  private var waiters: [CheckedContinuation<Void, Never>] = []

  var waiting: Int { waiters.count }

  /// Pass as `WatchHaptics(sleep:)`.
  var sleep: @Sendable (Duration) async throws -> Void {
    { @MainActor [self] _ in await withCheckedContinuation { self.waiters.append($0) } }
  }

  /// Ends every pending sleep.
  func release() {
    let current = waiters
    waiters = []
    current.forEach { $0.resume() }
  }

  /// Lets started tasks run until one is sleeping (or `limit` turns pass).
  func untilWaiting(limit: Int = 100) async {
    for _ in 0..<limit where waiters.isEmpty { await Task.yield() }
  }
}

/// Lets other main-actor tasks run.
@MainActor
func settle(_ turns: Int = 20) async {
  for _ in 0..<turns { await Task.yield() }
}
