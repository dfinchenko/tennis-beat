# Quickstart: validate workout and Health on the watch (003)

**Spec**: [spec.md](spec.md) | **Plan**: [plan.md](plan.md) | **Contract**: [contracts/ui-contract.md](contracts/ui-contract.md)

## Prerequisites

- As for 002 ([quickstart](../002-watch-match/quickstart.md)): Xcode 26 or newer, the watchOS 26 runtime, the 40 mm watch simulator.
- `swift test --package-path Packages/TennisCore` passes, and `git diff main -- Packages/TennisCore` is empty (FR-018).
- For the device checks: a real Apple Watch paired with an iPhone, Health and Fitness on the iPhone.

## 1. Unit tests (fake workout service)

Run `TennisBeat Watch AppTests` on the 40 mm simulator (XcodeBuildMCP `test_sim`). Expected: all pass, including (research R12):
- `WorkoutLifecycleTests`: every Story 2 step and every row of the [contract §4](contracts/ui-contract.md) table, with dates (SC-002, SC-003);
- `WorkoutSaveTests`: one save per final match with points, none for 0 points (Story 4 s4, s5, s7);
- `HeartRateDisplayTests`, `SummaryHealthRowsTests`, `HealthOnboardingTests`;
- `HealthStorageTests`: no heart-rate or energy value in storage (SC-007);
- every 002 test, unchanged.

## 2. UI tests

Run `TennisBeat Watch AppUITests`. Expected: every 002 UI test passes with `-uiTestHealth denied`, added by the helper (SC-005); the new tests pass with `shouldRequest`, `granted`, `failing` and the scripted values; the accessibility audits pass in EN, PL and UK at XXXL (SC-006). CI `watch-tests` runs the same suites.

## 3. Manual flow in the simulator (screenshots for each PR)

1. Launch with `-uiTestHealth shouldRequest`. The onboarding shows before New match. Not now → New match. Relaunch → the onboarding again. Continue → New match; relaunch with `-uiTestHealth granted` (the fake keeps no state between launches) → no onboarding.
2. Launch with `-uiTestHealth granted -uiTestHeartRate 142`. Start a match: the header shows the time and `♥ 142`. Wait 30 s: `♥ --`. Pause: `♥ --`.
3. Launch with `-uiTestHealth granted -uiTestWorkoutStats 138,171,612`. Win a set or End after a point: the summary shows Duration, `♥ 138 / 171` and `612 kcal`.
4. `-uiTestWorkoutStats 138,171,` → no energy row; `,,612` → no heart-rate row.
5. `-uiTestHealth denied`: the 002 flow exactly, no heart-rate row, Duration only.
6. `-uiTestHealth granted -uiTestSaveFails`: Done → New match shows "Workout not saved to Health"; OK → gone, and it doesn't return.
7. Repeat 1–4 in Polish and Ukrainian at the largest standard size and an accessibility size on 40 mm; check the 3-digit heart rate (`-uiTestHeartRate 205`).

## 4. Gates

```bash
scripts/gates/check-artifacts.sh specs/003-workout-health
scripts/gates/check-project-format.sh
scripts/gates/check-infoplist-strings.sh
```

## 5. Device checks (Denys, real watch)

The spec's device-only checks 1–15; each PR lists the ones it touches ([plan](plan.md) § Delivery). They join the device checklist in `docs/harness.md` in the PR that first touches each one.
