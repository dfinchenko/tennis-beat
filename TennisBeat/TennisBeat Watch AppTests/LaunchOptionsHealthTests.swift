import Foundation
import Testing

@testable import TennisBeat_Watch_App

/// The DEBUG-only Health launch arguments (contract §2, T003).
struct LaunchOptionsHealthTests {
  @Test("Contract §2: no -uiTestHealth means production HealthKit")
  func noArgumentMeansHealthKit() {
    let options = LaunchOptions(arguments: [])
    #expect(options.healthMode == nil)
    #expect(options.heartRate == nil)
    #expect(options.workoutStats == nil)
    #expect(!options.saveFails)
  }

  @Test(
    "Contract §2: -uiTestHealth selects the fake's mode",
    arguments: [
      ("denied", FakeHealthMode.denied), ("shouldRequest", .shouldRequest),
      ("granted", .granted), ("failing", .failing),
    ])
  func healthModes(argument: String, mode: FakeHealthMode) {
    #expect(LaunchOptions(arguments: ["-uiTestHealth", argument]).healthMode == mode)
  }

  @Test("Contract §2: an unknown or missing mode is ignored")
  func unknownMode() {
    #expect(LaunchOptions(arguments: ["-uiTestHealth", "maybe"]).healthMode == nil)
    #expect(LaunchOptions(arguments: ["-uiTestHealth"]).healthMode == nil)
  }

  @Test("Contract §2: -uiTestHeartRate gives one reading")
  func heartRate() {
    #expect(LaunchOptions(arguments: ["-uiTestHeartRate", "142"]).heartRate == 142)
    #expect(LaunchOptions(arguments: ["-uiTestHeartRate", "x"]).heartRate == nil)
  }

  @Test("Contract §2: -uiTestWorkoutStats, an empty field hides its row")
  func workoutStats() {
    #expect(
      LaunchOptions(arguments: ["-uiTestWorkoutStats", "138,171,612"]).workoutStats
        == WorkoutStatistics(averageHeartRate: 138, maximumHeartRate: 171, activeEnergy: 612))
    #expect(
      LaunchOptions(arguments: ["-uiTestWorkoutStats", "138,171,"]).workoutStats
        == WorkoutStatistics(averageHeartRate: 138, maximumHeartRate: 171, activeEnergy: nil))
    #expect(
      LaunchOptions(arguments: ["-uiTestWorkoutStats", ",,612"]).workoutStats
        == WorkoutStatistics(averageHeartRate: nil, maximumHeartRate: nil, activeEnergy: 612))
    #expect(LaunchOptions(arguments: ["-uiTestWorkoutStats", "138,171"]).workoutStats == nil)
  }

  @Test("Contract §2: -uiTestSaveFails")
  func saveFails() {
    #expect(LaunchOptions(arguments: ["-uiTestSaveFails"]).saveFails)
  }
}
