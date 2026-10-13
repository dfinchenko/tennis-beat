# Test expectation changes: 002-watch-match

Changes to what a test asserts, made after the code it checks was written (rule: `docs/harness.md` § Test expectation changes). One section per PR, newest last. The reviewer reads this file with the diff and checks each entry against `docs/rules/itf-notes.md`.

## Branch `feat/002-setup` (PR 1: New match + First server)

None. All tests in this branch are new and were written before the code they check. Two changes were made while the tests were still failing against stubs, before any implementation:
- `US1 s6 an unknown or missing value falls back …` (`FormatChoiceTests.swift`) reads the stored dictionary with `try #require` instead of a force cast. A missing value now fails the test instead of crashing the test host. The expected values are unchanged.
- `US1 s6 a format that can't be built never starts a match` gained a positive control (a buildable format does start), so it can't pass against a no-op `start`.

UI-test helpers changed after the code existed. The navigation taps now go through a shared helper (`UITests/Support/XCUIApplication+Helpers.swift`) that allows one retry when the next screen doesn't appear within 3 s, because the watch simulator sometimes swallows a tap right after launch. The scroll helper also scrolls until an element's frame is on screen, because the watch simulator reports elements below the visible area as hittable. Each accessibility audit is the last step of its own test. Every assertion and expected value is unchanged.
