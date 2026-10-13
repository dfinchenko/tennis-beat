# Quickstart: validating the scoring engine (001)

This is how to show that the feature works end to end. It references [contracts/public-api.md](contracts/public-api.md) and [data-model.md](data-model.md) rather than repeating them.

## Prerequisites

- Xcode 26 or newer selected (`xcode-select -p`), Swift 6.2 toolchain.
- The worktree for the implementation branch, with `specs/001-scoring-engine` passing the artifact gate:

  ```sh
  scripts/gates/check-artifacts.sh specs/001-scoring-engine
  ```

## 1. Run the engine tests

```sh
swift test --package-path Packages/TennisCore
```

Expected: every suite passes, and the summary shows 0 failures. The suites are:

| Suite | Covers |
| --- | --- |
| `US1 …` to `US8 …` | Every acceptance scenario in spec.md, named `"USn sK …"` |
| `Properties` | SC-002, SC-003, SC-006, SC-007, and P-1 (the incremental state equals a full replay for every prefix): ≥ 1,000 seeded matches and their prefixes |
| `ReferenceMatches` | SC-005: 5 fixtures, each labelled hand-scored or agent-built |
| `SavedFormat` | US3 s8, s13, s14, s15; FR-031, FR-032 |
| `Performance` | SC-004 (CI part): median of 10 recomputes of a 500-point match < 10 ms |

To reproduce a property-test failure, rerun with the seed printed in its message:

```sh
TENNISCORE_SEED=<seed> swift test --package-path Packages/TennisCore --filter Properties
```

## 2. Check traceability (FR-028, SC-001)

- Every scenario has at least one test whose name starts with its ID:

  ```sh
  grep -cE '^[0-9]+\. \*\*Given' specs/001-scoring-engine/spec.md          # scenarios in the spec: 99
  grep -rhoE '"US[1-8] s[0-9]+\b' Packages/TennisCore/Tests | sort -u | wc -l  # scenarios with a test
  ```

  Each `@Test` covers exactly one scenario, and its name starts with that scenario's ID (tasks.md, Tests), so the second count is exact.

  Expected: both print 99 unique scenario IDs (US1: 20, US2: 13, US3: 16, US4: 10, US5: 9, US6: 12, US7: 8, US8: 11).
- Every rule-based test cites an ITF ID that exists in `docs/rules/itf-notes.md`:

  ```sh
  grep -rhoE '// ITF: [A-Z]{2}-[0-9]{2}' Packages/TennisCore/Tests | sort -u
  ```

- The **Tests** column of `docs/rules/itf-notes.md` is filled in for every ID in MVP scope.

## 3. Check purity and privacy

```sh
grep -rnE '^import (SwiftUI|HealthKit|WatchConnectivity|UIKit)' Packages/TennisCore/Sources   # expect no output
grep -n 'dependencies:' Packages/TennisCore/Package.swift                                       # expect no package dependencies
```

## 4. Check that both apps still build

The apps link TennisCore. Build both schemes with XcodeBuildMCP (`TennisBeat`, `TennisBeat Watch App`) or as in CI:

```sh
xcodebuild build -project TennisBeat/TennisBeat.xcodeproj -scheme "TennisBeat" \
  -destination "generic/platform=iOS Simulator" CODE_SIGNING_ALLOWED=NO
xcodebuild build -project TennisBeat/TennisBeat.xcodeproj -scheme "TennisBeat Watch App" \
  -destination "generic/platform=watchOS Simulator" CODE_SIGNING_ALLOWED=NO
```

Expected: both succeed. This feature has no UI, so there are no simulator screenshots; the PR says so.

## 5. Device check for Denys (SC-004, second part)

This check waits for the watch scoring screen feature, which first restores a persisted match. Until then, it is listed in the PR as **deferred to the watch feature** (approved by Denys, 2026-10-13):

- On the oldest supported Apple Watch: start a match, add ~500 points (or load a 500-point debug fixture), kill the app and relaunch it. The score screen shows the restored score with no loading indicator.
