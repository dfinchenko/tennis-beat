# Test expectation changes: 002-watch-match

Changes to what a test asserts, made after the code it checks was written (rule: `docs/harness.md` § Test expectation changes). One section per PR, newest last. The reviewer reads this file with the diff and checks each entry against `docs/rules/itf-notes.md`.

## Branch `feat/002-setup` (PR 1: New match + First server)

None. All tests in this branch are new and were written before the code they check. Two changes were made while the tests were still failing against stubs, before any implementation:
- `US1 s6 an unknown or missing value falls back …` (`FormatChoiceTests.swift`) reads the stored dictionary with `try #require` instead of a force cast. A missing value now fails the test instead of crashing the test host. The expected values are unchanged.
- `US1 s6 a format that can't be built never starts a match` gained a positive control (a buildable format does start), so it can't pass against a no-op `start`.

UI-test helpers changed after the code existed. The navigation taps now go through a shared helper (`UITests/Support/XCUIApplication+Helpers.swift`) that allows one retry when the next screen doesn't appear within 3 s, because the watch simulator sometimes swallows a tap right after launch. The scroll helper also scrolls until an element's frame is on screen, because the watch simulator reports elements below the visible area as hittable. Each accessibility audit is the last step of its own test. Every assertion and expected value is unchanged.

## Branch `feat/002-ui-test-stability` (UI test stabilization, #18 R1-1)

None. Test harness only:
- `XCUIApplication.launched` waits, with an explicit 20 s timeout and no fixed sleep, until the first New match row exists and is hittable before returning. `ScreenshotUITests` launches through the same helper.
- The `TennisBeat Watch App` scheme runs the UI tests serially (`parallelizable = "NO"`), on the one simulator chosen. In parallel mode Xcode boots fresh simulator clones, and the screen recording of a failing run showed the clone still on its boot screen while the app already reported New match in its accessibility tree, so taps landed nowhere.
- CI boots the pinned 40 mm simulator and waits for `simctl bootstatus` before testing.

Every assertion and expected value is unchanged.

## Branch `feat/002-score` (PR 2: Score + haptics)

Changes to tests that existed before this branch (no ITF rule is involved in any of them):
- `SetupFlowUITests` — `testUS1s5FormatRememberedAfterRelaunch`, `testUS1s7s8FirstServerStartsMatch`, `testUS1s9CoinTossResult`, `testUS1s10BackNavigation`: the score screen is recognised by `zone.me` / `zone.opponent` instead of the PR 1 placeholder `score.placeholder`, which this PR removes. `testUS1s7s8…` and `testUS1s9…` also check the `score.summary` label at 0–0 ("0–0, I'm serving, from the right" / "0–0, Opponent serving, from the right"; ITF SV-01, SV-03). This is a stricter check than before, not a looser one.
- `XCUIApplication.launched` gained a `readyElement` parameter (default `setup.format`, unchanged behaviour), and `waitUntilNewMatchIsReady()` became `waitUntilReady(_:)` (#19 R1-2).

New tests in this branch were written before the code they check. One change was made while they were still failing, before the screen worked:
- `ScoringUITests.testR7GuardZoneValuesOnlyWithExposeArgument`: the expected element type of `zone.me` with `-uiTestExposeValues` is `.other` (a container), not `.button`. Research R7 said XCUITest "may report a zone as a container"; the simulator confirmed it. In production it is `.button`, as written. The same run showed that watchOS XCUITest lists texts that are hidden from VoiceOver, so the zone value identifiers are set only with `-uiTestExposeValues`; the guard's expectation (no `zone.me.points` in production) is unchanged.
