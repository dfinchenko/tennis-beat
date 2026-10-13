# Implementation Plan: Scoring engine

**Branch**: `feat/001-plan` | **Date**: 2026-10-13 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/001-scoring-engine/spec.md` (Status: Approved, 2026-10-13, Denys)

## Summary

Build the event-sourced tennis scoring engine in `Packages/TennisCore`:
- **Record**: a match is a record of Codable events (setup, point, match ended early, first server corrected).
- **State**: score, status, server, court side, flags and the most recent point's change-of-ends value, all a pure reduction of that record.
- **Stats**: points on serve and return, service games held, break points, computed in the same fold.

The reduction has two parts (research R1):
- a **score track** that depends only on the point winners;
- a **service track** that replays the score track from the *effective* first server.

This makes a first-server correction a recompute that cannot touch scores or change of ends. Appending a point is one incremental step. Undo and corrections replay the list (R2). Property test P-1 checks, for every prefix of every generated match, that the incremental state equals the replayed state, so the two paths can't diverge. Live input and restored lists go through one validation path (R3). The saved format is versioned JSON with a frozen fixture per version (R5, R11). Tests come first, in Swift Testing, with one suite per user story, plus seeded property tests and a CI timing test (R8, R9).

## Technical Context

**Language/Version**: Swift 6.2 (language mode 6, strict concurrency), typed throws

**Primary Dependencies**: Foundation only (`Date`, `JSONEncoder`/`JSONDecoder`). No package dependencies.

**Storage**: N/A in the engine. It produces and restores a versioned JSON `Data` blob ([contracts/saved-format.md](contracts/saved-format.md)); the apps store it.

**Testing**: Swift Testing via `swift test --package-path Packages/TennisCore`. Property tests use an in-repo seeded SplitMix64 generator. JSON fixtures are test resources.

**Target Platform**: iOS 26, watchOS 26 (app targets), and macOS 26 (package tests and CI on `macos-26`)

**Project Type**: Swift package (library), linked by the iOS and watchOS apps

**Performance Goals**: A full recompute of state and stats for a 500-point best-of-3 match takes < 10 ms (median of 10) on the CI runner in the debug build (SC-004). Appending a point is O(1).

**Constraints**:
- Pure: no SwiftUI, HealthKit or WatchConnectivity imports, no I/O, no clock reads.
- Deterministic: the same events give the same state, and `recordedAt` is ignored by the reducer.
- No traps on any input.
- No user-facing strings.

**Scale/Scope**:
- 8 user stories, 99 acceptance scenarios, 32 FRs, 7 SCs.
- Matches of up to ~500 points.
- ≥ 1,000 generated matches in the property tests.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-checked after Phase 1 design.*

| Principle | Status | Evidence |
| --- | --- | --- |
| I. Spec before code | PASS | `spec.md` has `Status: Approved (2026-10-13, Denys)` (commit `e0c959f`, PR #8). The plan changes no acceptance criteria. The artifact gate passes (`GATE PASS: specs/001-scoring-engine`). |
| II. Tennis rules are the source of truth | PASS | The data model cites the ITF IDs for every rule. Tests carry `// ITF: <ID>` (R12). The implementation fills in the **Tests** column of `itf-notes.md`. No Conflict found: all rules used are Rule, Derived or approved Not covered entries. |
| III. Test first | PASS | `tasks.md` will order each story as tests (failing) first, then code. Boundary tests are explicit: undo across game, set and match tie-break boundaries and after the match ends (US3), restore from persisted events (US3 s8, s13). "Pause during a tie-break" is out of engine scope (no timing); it is the watch feature's test. |
| IV. Evidence bound to a commit | PASS | The PR carries `Reviewed-SHA` equal to its head. CI runs the engine tests on every push. |
| V. Independent review | PASS | The `reviewer` subagent gets only `specs/001-scoring-engine` and the base branch. |
| VI. One writer per worktree | PASS | Plan work is in `.worktrees/001-plan`; implementation will be in its own worktree and branch. |
| VII. Green tests ≠ accepted build | PASS | No UI or HealthKit change. The SC-004 device check is listed for Denys and deferred to the watch feature (approved by Denys, 2026-10-13; [quickstart](quickstart.md) §5). |
| VIII. AI never invents numbers | PASS | The engine is the single source of the stats numbers. |
| IX. Privacy by default | PASS | No dependency, no network, no health data, no secrets. |
| X. Three languages | PASS (N/A) | The engine exposes enums, not strings (R7). The apps localize `PointDisplay`, `CourtSide` and the status per `glossary.md`. |
| XI. Accessibility and HIG | PASS (N/A) | No UI. The state exposes the server, so the apps can read the server's score first (GM-01) in VoiceOver labels. |
| XII. Honest metrics | PASS | Each PR for this feature appends the metrics row of the previous merged PR (CLAUDE.md step 8). |

**Post-design re-check (after Phase 1)**: PASS, with no new violations. The design adds no dependency. The `resources:` entry for test fixtures is a `Package.swift` change, not a dependency. The design keeps the module pure (contract G7) and keeps every rejection a typed error (G6).

## Project Structure

### Documentation (this feature)

```text
specs/001-scoring-engine/
├── spec.md              # Approved spec
├── plan.md              # This file
├── research.md          # Phase 0: decisions R1–R12
├── data-model.md        # Phase 1: entities, state machine, stats rules
├── quickstart.md        # Phase 1: validation guide
├── contracts/
│   ├── public-api.md    # Swift API used by the apps + guarantees G1–G7
│   └── saved-format.md  # JSON formatVersion 1 + restore algorithm
├── checklists/requirements.md
└── tasks.md             # Phase 2 (/speckit-tasks)
```

### Source Code (repository root)

```text
Packages/TennisCore/
├── Package.swift                       # + test resources: .copy("Fixtures")
├── Sources/TennisCore/
│   ├── TennisCore.swift                # module doc + version
│   ├── Model/
│   │   ├── Player.swift                # Player, PlayerPair
│   │   ├── MatchFormat.swift           # MatchLength, SetLength, GameScoring, MatchFormat, MatchSetup
│   │   ├── MatchEvent.swift
│   │   ├── MatchError.swift
│   │   ├── MatchState.swift            # MatchState, MatchStatus, SetScore, PointDisplay, CourtSide
│   │   └── MatchStats.swift            # Tally, PlayerStats, MatchStats
│   ├── Engine/
│   │   ├── Match.swift                 # record / undo / correction; cached reduction
│   │   ├── ScoreTrack.swift            # game, tie-break, set, match progression; change of ends
│   │   ├── ServiceTrack.swift          # server, court side, break-point context
│   │   └── Reducer.swift               # step(state, winner) -> (state, PointContext); replay
│   └── Persistence/
│       ├── MatchCodec.swift            # envelope, version check, encode/decode
│       └── Migrations.swift            # vK -> vK+1 (empty for v1)
└── Tests/TennisCoreTests/
    ├── Support/
    │   ├── MatchBuilder.swift          # DSL: points "MMOM…", games, sets → Match
    │   ├── SplitMix64.swift
    │   └── MatchGenerator.swift        # seeded random matches (R8)
    ├── US1ScoringTests.swift
    ├── US2ServiceAndSideTests.swift
    ├── US3UndoAndRestoreTests.swift
    ├── US4TieBreakTests.swift
    ├── US5ChangeOfEndsTests.swift
    ├── US6StatsTests.swift
    ├── US7EarlyEndTests.swift
    ├── US8FirstServerCorrectionTests.swift
    ├── PropertyTests.swift             # SC-002, SC-003, SC-006, SC-007, P-1 (incremental == replay)
    ├── ReferenceMatchTests.swift       # SC-005
    ├── SavedFormatTests.swift          # FR-031, FR-032
    ├── PerformanceTests.swift          # SC-004 (CI)
    └── Fixtures/
        ├── saved-format/v1.json        # frozen
        └── reference/*.json            # 5 matches, origin labelled
```

Other files touched by the implementation PR:
- `docs/rules/itf-notes.md`: fill in the Tests column;
- `docs/harness.md`: add the metrics row.

**Structure Decision**: Everything lives in the existing `Packages/TennisCore` package (constitution, Technical Constraints). The app targets are not changed: they already link the package, and wiring the engine into UI belongs to the watch and iPhone features. The placeholder `moduleIsLinked()` test is replaced by the real suites.

## Implementation order (input for `/speckit-tasks`)

1. **Foundation**: model types, `MatchError`, safe stubs (no traps), the test DSL.
2. **US1 + US4** (scoring, tie-breaks): score track. All tests for both stories are written before it.
3. **US2** (server, court side): service track.
4. **US3** (undo, restore): validation, undo, `MatchCodec`, the v1 fixture. The generator, P-1 (incremental equals replay), SC-002, SC-003 and SC-004 are written here, before this code.
5. **US5** (change of ends): per-point value in the score track.
6. **US6** (stats): point context, aggregation, reference matches, SC-006.
7. **US7** (early end), then **US8** (correction). Each extends the generator and the v1 fixture before its code, and adds SC-007(b) and SC-007(a) respectively.
8. **Cross-cutting**: traceability check, ITF Tests column, both app builds, review, PR.

Each step: write tests citing their scenario and ITF ID, and see them fail. A test is written in the phase whose code makes it pass, so none waits behind `.disabled`. Then make them pass, keeping earlier suites green.

## Dependencies and open inputs

- **SC-005 hand-scored reference match (Denys)**: a task assigned to Denys, with a fixture template (format, first server, point winners per game, hand-counted stats), filled in after his next match. The implementation can proceed without it, but the PR does not claim SC-005 until it is added (research R11).
- **SC-004 device check (Denys)**: deferred to the watch feature, which first persists and restores a match. Deferral approved by Denys on 2026-10-13.
- **"Pause during a tie-break" boundary test (constitution III)**: the engine has no timing or pause, so this test belongs to the watch feature's spec and tasks. Tracked in backlog #6 as an input for the watch feature's spec.

## Complexity Tracking

No constitution violations to justify.
