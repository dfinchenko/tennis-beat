import HealthKit
import Testing

@testable import TennisBeat_Watch_App

/// The workout's statistics from HealthKit quantities (research R7; #30 R1-4).
struct HealthKitStatisticsTests {
  private let beatsPerMinute = HKUnit.count().unitDivided(by: .minute())

  @Test("R7 heart rate is rounded to whole beats per minute; energy is in kilocalories")
  func values() throws {
    let statistics = HealthKitWorkoutService.statistics(
      averageHeartRate: HKQuantity(unit: beatsPerMinute, doubleValue: 137.6),
      maximumHeartRate: HKQuantity(unit: beatsPerMinute, doubleValue: 171.4),
      activeEnergy: HKQuantity(unit: .jouleUnit(with: .kilo), doubleValue: 2560.608))
    #expect(statistics.averageHeartRate == 138)
    #expect(statistics.maximumHeartRate == 171)
    let energy = try #require(statistics.activeEnergy)
    #expect(abs(energy - 612) < 0.001)  // 2560.608 kJ = 612 kcal
  }

  @Test("R7 missing values stay missing")
  func missing() {
    let statistics = HealthKitWorkoutService.statistics(
      averageHeartRate: nil, maximumHeartRate: nil, activeEnergy: nil)
    #expect(statistics == WorkoutStatistics())
  }
}
