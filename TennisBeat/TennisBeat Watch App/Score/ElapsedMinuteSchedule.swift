import SwiftUI

/// Always On redraws: the start date, then each wall-clock date at which the elapsed match
/// time reaches the next whole minute, so the dimmed minutes are never late (research R5,
/// R8). While the clock is paused or stopped the time doesn't change, so there is no later
/// entry; a pause or resume gives the view a new clock and so a new schedule.
struct ElapsedMinuteSchedule: TimelineSchedule {
  let clock: MatchClock

  func entries(from startDate: Date, mode: TimelineScheduleMode) -> AnyIterator<Date> {
    let isRunning = !clock.isPaused && clock.stoppedAt == nil
    let elapsed = clock.elapsed(at: startDate)
    // Running, the elapsed time grows one second per second from here.
    let toNextMinute = 60 - elapsed.truncatingRemainder(dividingBy: 60)
    var next: Date? = startDate
    var minute = 0
    return AnyIterator {
      guard let date = next else { return nil }
      next = isRunning ? startDate + toNextMinute + 60 * Double(minute) : nil
      minute += 1
      return date
    }
  }
}
