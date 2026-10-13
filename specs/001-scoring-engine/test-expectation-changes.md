# Test expectation changes: 001-scoring-engine

Changes to what a test asserts, made after the code it checks was written (rule: `docs/harness.md` § Test expectation changes). One section per PR, newest last. The reviewer reads this file with the diff and checks each entry against `docs/rules/itf-notes.md`.

## Branch `chore/001-followups` (PR #13)

| Test | Old expectation → new expectation | ITF note |
| --- | --- | --- |
| US6 s4 (positive control), `US6StatsTests.swift` | `before == (matchTieBreak ? 12 : 12)` → `before == 12` | BP-03 (expected value unchanged: 12 completed standard games before the tie-break; the redundant condition is removed) |

No other assertion changed in this branch. The argument renames (`inMatchTieBreak`) keep every expected value.
