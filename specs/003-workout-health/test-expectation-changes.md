# Test expectation changes: 003-workout-health

Expectations changed after the code they check was written (rule: CLAUDE.md, Hard rules; `docs/harness.md`). One section per branch, newest last.

## `feat/003-onboarding` (PR 1)

| Test | Old → new expectation | Source |
| --- | --- | --- |
| `InfoPlistTextTests` "FR-004 the EN read text names heart rate and active energy" → "FR-004 each catalog's EN read text names heart rate and active energy" | Checked the copy-table constant in the test → checks the EN value read from each `InfoPlist.xcstrings` (one case per catalog). The condition is the same (names "heart rate" and "active energy"); it now checks the product. The positive control is kept. Reviewer finding #29 R1-3. | FR-004 |

No other expectation changed. Helper and wait changes that leave every expectation as it was, and so are not listed above:
- the UI-test helper's default `-uiTestHealth denied` (SC-005);
- the onboarding UI tests waiting for the title instead of Continue;
- the injected `workout:` argument in the 002 unit tests.
- the new `dragUp()` UI-test helper, used by the onboarding scrolling test and the screenshot test instead of `swipeUp()`.
