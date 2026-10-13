---
description: "Task list for the scoring engine (001)"
---

# Tasks: Scoring engine

**Input**: Design documents from `specs/001-scoring-engine/`: [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md), [data-model.md](data-model.md), [contracts/](contracts/), [quickstart.md](quickstart.md)

**Tests**: REQUIRED. Constitution III (test first, non-negotiable) and FR-028 apply.
- In every phase, the test tasks come first. Run them and **see them fail** before the implementation tasks of that phase start.
- A test is written in the phase whose implementation makes it pass, even when its scenario belongs to another story. For example, US3 s7 (undo and change of ends) is written in the US5 phase. No test is ever `.disabled` to wait for later code. The only exception is the hand-scored SC-005 case, which waits for data, not code (T050, T051).
- Every scenario has at least one `@Test`, and each `@Test` covers exactly one scenario. Its name starts with the scenario ID (`"US2 s7 …"`); use parameterized arguments for variants. A scenario's checks may be split across tests only when they land in different phases (e.g. `"US4 s10 …"` in T018 and T022). Plan-level tests use `"SC-00n …"` or `"P-1 …"`. Contract-guarantee tests use `"G1 …"`–`"G3 …"`, and codec tests outside a scenario use `"Codec …"`.
- No vacuous tests: when the stub value (zero stats, a no-op mutator) would already satisfy an assertion, the test adds a positive control that fails against the stub.
- Every rule-based test carries `// ITF: <ID>` from `docs/rules/itf-notes.md`.
- When the full suite runs at a phase checkpoint, all earlier phases' tests stay green.

**Organization**:
- One phase per user story in priority order.
- US1 and US4 share a phase: both are P1 and both test the score track, so writing all their tests before the score track keeps test-first honest.
- Plan-level property tests are written in the phase whose code they exercise.

**Paths**:
- `Sources/` means `Packages/TennisCore/Sources/TennisCore/`.
- `Tests/` means `Packages/TennisCore/Tests/TennisCoreTests/`.

Run the tests with `swift test --package-path Packages/TennisCore`.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can run in parallel (different files, no dependency on an incomplete task)
- **[Story]**: the user story the task belongs to
- **Owner**: the agent, unless a task says **Owner: Denys**

---

## Phase 1: Setup

**Purpose**: Prepare the package and the test support. No engine logic yet.

- [X] T001 Create the implementation worktree and branch from the latest `origin/main` (`.worktrees/001-impl`, branch `feat/001-scoring-engine-impl`). Set `.specify/feature.json` to `specs/001-scoring-engine`. Run `scripts/gates/check-artifacts.sh specs/001-scoring-engine`, and STOP if it fails.
- [X] T002 Add test resources to `Packages/TennisCore/Package.swift`: `.testTarget(name: "TennisCoreTests", dependencies: ["TennisCore"], resources: [.copy("Fixtures")])`. Create `Tests/Fixtures/saved-format/` and `Tests/Fixtures/reference/`, each with a `.gitkeep`. Add no package `dependencies:` (constitution IX).
- [X] T003 Create the source folders from plan.md: `Sources/Model/`, `Sources/Engine/`, `Sources/Persistence/`. Keep `Sources/TennisCore.swift` (module doc and `version`), and bump `version` to `"0.1.0"`.
- [X] T004 [P] Write `Tests/Support/SplitMix64.swift`:
  - a `RandomNumberGenerator` seeded by a `UInt64`;
  - a computed `static var testSeed: UInt64 { … }` (no stored mutable global, which Swift 6 strict concurrency rejects), read from the `TENNISCORE_SEED` environment variable, with a fixed default constant otherwise (research R8).

---

## Phase 2: Foundational (blocks every story)

**Purpose**: Public types, safe stubs and the test DSL that every story needs. The signatures come from [contracts/public-api.md](contracts/public-api.md), exactly as written there.

**⚠️ CRITICAL**: No story work starts before this phase is complete.

- [X] T005 [P] Create `Sources/Model/Player.swift`:
  - `Player` (`me`, `opponent`, `other`);
  - `PlayerPair<Value>` with `subscript(Player)`. "Order is always Me, then Opponent".
- [X] T006 [P] Create `Sources/Model/MatchFormat.swift`: `MatchLength`, `SetLength` (raw values 4, 6, 8), `GameScoring`, `MatchFormat`, `MatchSetup`.
  - `MatchFormat.init` is declared `throws(MatchError)` but **does not validate yet**: it accepts every combination. The `.invalidFormat` check is added in T019, after the US1 s19 test (T016) has failed against it (constitution III).
- [X] T007 [P] Create `Sources/Model/MatchError.swift` with exactly `missingSetup`, `duplicateSetup`, `invalidFormat`, `matchNotInProgress`, `sameFirstServer`.
- [X] T008 [P] Create `Sources/Model/MatchEvent.swift`: `setup(MatchSetup)`, `point(winner: Player, recordedAt: Date)`, `matchEndedEarly`, `firstServerCorrected(Player)`.
- [X] T009 [P] Create `Sources/Model/MatchState.swift` with `MatchState`, `MatchStatus`, `SetScore`, `PointDisplay` (`.zero … .advantage`, `.tieBreak(Int)`) and `CourtSide`. Fields as in data-model.md "Derived: match state".
- [X] T010 [P] Create `Sources/Model/MatchStats.swift` with `Tally` ("`0 ≤ won ≤ of`"), `PlayerStats` and `MatchStats` with `subscript(Player)`.
- [X] T011 Create safe stubs with the full public API, so that story tests compile and fail by assertion, never by a trap. **No `fatalError`, `precondition` or `try!`** (contract G6): a trap kills the whole `swift test` run. Depends on T005–T010.
  - `Sources/Engine/Match.swift`: `Match` with `init(setup:)`, `init(events:)`, `record`, `recordPoint`, `endEarly`, `correctFirstServer`, `undo`, `state`, `stats`, `effectiveFirstServer`. In the stub:
    - `init(events:)` stores the events unvalidated;
    - the mutators do nothing;
    - `undo` returns `nil`;
    - `state` returns a fixed placeholder (status in progress, 0–0, Me serving, right);
    - `stats` returns all-zero tallies.
  - `Sources/Persistence/MatchCodec.swift`: `RestoreError` and `MatchCodec`, with `currentFormatVersion = 1`. In the stub, `encode` returns empty `Data()` and `decode` returns `.failure(.malformed)`.
- [X] T012 Write `Tests/Support/MatchBuilder.swift`, a test DSL:
  - `Match.make(_ length:, setLength:, scoring:, matchTieBreak:, firstServer:)`;
  - `.play("MMOM …")`, where `M` = Me won the point, `O` = Opponent won the point, and spaces are ignored;
  - helpers `.winGame(_ p:)`, `.winGames(me:opponent:)` (alternating order, never deciding the set early), `.winSet(_ p:)` and `.reach(games:)`;
  - a fixed `recordedAt` clock that advances 1 s per point.
- [X] T013 Remove the placeholder `moduleIsLinked()` test from `Tests/TennisCoreTests.swift`, keeping a version test for `TennisCore.version`. Run `swift test` and confirm that it compiles and passes.

**Checkpoint**: The package compiles, the API surface is fixed, and the suite is green with no story tests yet.

---

## Phase 3: User Stories 1 and 4 – Score a match; tie-breaks and the match tie-break (P1) 🎯 MVP

**Goal**: Correct point, game, set and match score for every supported format, including numeric tie-breaks, the 2-point margin, the match tie-break to 10, and the recorded set scores.

**Independent Test**: Feed a setup and points, then check `points`, `games`, `completedSets`, the flags and `status` after each point.

### Tests for US1 and US4 (write first, run, must FAIL against the stubs)

- [X] T014 [P] [US1] In `Tests/US1ScoringTests.swift`, write tests US1 s1–s9 for the standard game (`// ITF: GM-01, GM-02, NA-01`):
  - s1 checks `.zero, .fifteen, .thirty, .forty`;
  - s7 plays 10 deuces;
  - s8 checks `isDecidingPoint` on and `isDeuce` off.
- [X] T015 [P] [US1] In `Tests/US1ScoringTests.swift`, write tests US1 s10–s14 for sets (`// ITF: ST-01, ST-03, ST-04, ST-06, ST-07`; ST-01 because every set is a tie-break set, FR-007), with the edge cases as parameterized arguments:
  - N = 4: 4–2 and 5–3 win, 4–3 continues;
  - N = 8: 8–6 and 9–7 win, 8–7 continues.
- [X] T016 [P] [US1] In `Tests/US1ScoringTests.swift`, write tests US1 s15–s19 for the match (`// ITF: MT-01, MT-02, MT-03`). s19 expects `MatchFormat.init` to throw `.invalidFormat`; it fails against T006, which doesn't validate yet. (US1 s20 needs the codec and is written in T028.) Also, in `Tests/US3UndoAndRestoreTests.swift`, write test US3 s9 here, because T020 implements it: after the match-winning point, `recordPoint` throws `.matchNotInProgress` and the `Match` is unchanged.
- [X] T017 [P] [US4] In `Tests/US4TieBreakTests.swift`, write tests US4 s1–s6 (`// ITF: TB-01, MT-03`): numeric displays, 7–5, 6–6 → 7–6 continues, 15–13, match tie-break 10–8, and 12–10.
- [X] T018 [P] [US4] In `Tests/US4TieBreakTests.swift`, write tests US4 s7, s9 and s10 (`// ITF: MT-05, TB-01, ST-07, GM-02, NA-01`; NA-02 and TB-04 go on the court-side test in T022):
  - s7: `completedSets` reads 6–4, 3–6, then a match-tie-break entry with games 1–0, `tieBreak` 10–7 and `isMatchTieBreak`;
  - s9: per set length, 7–6 (7–5), 5–4 (9–7) and 9–8 (7–3);
  - s10: the flags are off at 3–3, 6–6 and 9–9 in Advantage and No-Ad matches, and the court side is never `.receiversChoice`. That last check stays red until T023, so assert it in a separate `@Test` named `"US4 s10 court side …"` and write it in T022 instead.

  (US4 s8 needs break points and is written in T046.)

### Implementation for US1 and US4

- [X] T019 [US1] Add the `.invalidFormat` check to `MatchFormat.init` in `Sources/Model/MatchFormat.swift` ("`matchTieBreak` is allowed only with `bestOfThree`", MT-02). Implement the score track in `Sources/Engine/ScoreTrack.swift`, a value type with:
  - the standard game (Advantage: "won with ≥ 4 points and a 2-point lead"; No-Ad: the 4th point wins at 3–3);
  - the set (won at N with a 2-game lead, N+1–N−1, or the N–N tie-break);
  - the 7-point tie-break ("first to 7, +2", no cap);
  - the 10-point match tie-break at 1–1 when `matchTieBreak` is on;
  - the match status;
  - `completedSets`, including `SetScore.tieBreak` and `isMatchTieBreak` (MT-05);
  - point displays, and the `isDeuce`, `isDecidingPoint`, `isTieBreak` and `isMatchTieBreak` flags exactly as in FR-015.
- [X] T020 [US1] Implement `Sources/Engine/Reducer.swift`:
  - `step(_ state:, winner:) -> (state, PointContext)` on the score track;
  - `replay(setup:, effectiveFirstServer:, events:)`.

  Wire up `Match.init(setup:)`, `recordPoint`, `record(.point)` and `state` in `Sources/Engine/Match.swift`. Rejecting a point when `status != .inProgress` → `.matchNotInProgress`. Make T014–T018 pass, including US3 s9 from T016.

**Checkpoint**: US1 and US4 pass (except the parts noted for later phases). The engine scores every format.

---

## Phase 4: User Story 2 – Know who serves and from which side (P1)

**Goal**: The current server and court side after every point.

**Independent Test**: Feed point sequences and check `server` and `courtSide` after each point.

### Tests for US2 (write first, must FAIL)

- [X] T021 [P] [US2] In `Tests/US2ServiceAndSideTests.swift`, write tests US2 s1–s8 for service order (`// ITF: SV-01, SV-02, SV-04, TB-02, TB-03, MT-04`). Positive control for the stub (Me serving): s1 is parameterized over both first servers, so the Opponent-first case fails against the stub.
  - s4 for each set length;
  - s5 for several tie-break scores;
  - s7 for set 2 ended by a tie-break before the match tie-break.
- [X] T022 [P] [US2] In `Tests/US2ServiceAndSideTests.swift`, write tests US2 s9–s13 for court side (`// ITF: SV-03, TB-04, NA-02`). Positive control for the stub (always Right): s9 also checks that after one point of the new game the side is Left. s12 expects `.receiversChoice`, and s13 checks a set tie-break and a match tie-break. In `Tests/US4TieBreakTests.swift`, also write `"US4 s10 court side …"` (`// ITF: NA-02, TB-04`): never `.receiversChoice` at equal tie-break scores.

### Implementation for US2

- [X] T023 [US2] Implement `Sources/Engine/ServiceTrack.swift`:
  - the standard-game server alternates (SV-02);
  - tie-break point k: the server changes "after k = 0, 2, 4, …" (TB-02);
  - the next set (or match tie-break) after a tie-break set is started by the tie-break's first receiver (TB-03, SV-04, MT-04);
  - court side: `.right` if the points played are even, `.left` if odd, `.receiversChoice` only at the No-Ad 3–3 in a standard game (SV-03, TB-04, NA-02).

  Feed it from `Reducer.step`. Expose `server` and `courtSide` in `MatchState`. Make T021–T022 pass.

**Checkpoint**: US1, US2 and US4 pass.

---

## Phase 5: User Story 3 – Undo any mistake, and resume after a crash (P1)

**Goal**: Unlimited undo, validated restore, the versioned saved format, and the replay/increment equivalence.

**Independent Test**: Undo equals a rebuild from the shortened list. Encode and decode reproduce the list and the state exactly.

### Tests for US3 (write first, must FAIL)

- [X] T024 [P] [US3] In `Tests/US3UndoAndRestoreTests.swift`, write tests US3 s1–s6 for undo:
  - across game, set, tie-break and match-tie-break boundaries and after the match is won;
  - s6: with only the setup, `undo()` returns `nil` and changes nothing. Positive control (the stub `undo` always returns `nil`): on the same match after one point, `undo()` returns that point event.

  (s7 is written in T042, s11 in T054, s12 in T060.)
- [X] T025 [P] [US3] In `Tests/US3UndoAndRestoreTests.swift`, write tests US3 s10 and s16 (the point-after-a-win case). (s9 was written in T016.)
  - `Match(events: [])` and a list starting with a point → `.missingSetup`;
  - a second setup → `.duplicateSetup`;
  - any point after the match-winning point in a restored list → `.matchNotInProgress` (`// ITF: MT-08`).

  (The early-end cases of s16 are written in T054.)
- [X] T026 [P] [US3] Create `Tests/Fixtures/saved-format/v1.json`, the saved-format fixture: setup (best of 3, Advantage, set length 6, match tie-break on, first server Me), then at least one completed set of points with non-integer `recordedAt` values. Create `v1.expected.json` with the state values the test checks. T056 and T062 extend this fixture with an early end and corrections. It is frozen from the merge of this feature onward: "Fixtures are never edited after release".
- [X] T027 [P] [US3] In `Tests/SavedFormatTests.swift`, write tests US3 s8, s13, s14 and s15 (`FR-031`, `FR-032`):
  - s8: encode, then decode, gives an equal `Match`, and `recordedAt` is bit-exact (compare `timeIntervalSinceReferenceDate.bitPattern`);
  - s13: `v1.json` restores to `v1.expected.json`;
  - s14: `"formatVersion": 2` gives `.unsupportedVersion(found: 2, supported: 1)`, with no crash. To prove that nothing else is parsed, the same result comes back for a version-2 payload whose `events` would be malformed under v1;
  - s15: the same points with shuffled or out-of-order times give an identical `state` and `stats`;
  - `"Codec malformed …"`: an unknown `type` and a missing `formatVersion` give `.malformed`.
- [X] T028 [P] [US3] In `Tests/US1ScoringTests.swift`, write test US1 s20 (`// ITF: ST-07`): decoding a saved list with `"setLength": 5` gives `.invalid(.invalidFormat)`, and so does a setup with `oneSet` plus `matchTieBreak: true`.
- [X] T029 [P] [US3] Write tests `"G1 …"`, `"G2 …"` and `"G3 …"` for the contract guarantees in `Tests/US3UndoAndRestoreTests.swift`:
  - `Match(events: m.events) == m`;
  - after `undo()`, the match equals `Match(events: dropLast)`;
  - a throwing call leaves `m` unchanged.
- [X] T030 [US3] Write `Tests/Support/MatchGenerator.swift` (research R8), points only for now:
  - for each seeded match, pick a random format (3 set lengths × 2 scorings × match length × the match tie-break option where valid) and a random first server;
  - generate point winners with a per-match bias in 0.3–0.7, so long deuces, tie-breaks and match tie-breaks are common;
  - stop at the match's end or at a random length;
  - expose `matches(count: 1000, seed:)` and print the seed on failure.

  T055 adds early ends to the generator, and T061 adds corrections.
- [X] T031 [US3] In `Tests/PropertyTests.swift`, write test **P-1 (incremental equals replay)**, approved by Denys on 2026-10-13 (research R2):
  - for every prefix of every generated match, compare the `Match` built by `record`ing events one by one (the incremental `step` path) with the reduction built directly by `Reducer.replay(setup:effectiveFirstServer:events:)` over the same prefix (via `@testable import`). `Match(events:)` is **not** the replay side: it records event by event (R3), so comparing against it would compare a path with itself;
  - the comparison covers every `state` field, every `stats` field and the whole cached reduction;
  - print the seed and the match index on failure.
- [X] T032 [US3] In `Tests/PropertyTests.swift`, write tests SC-002 and SC-003:
  - SC-002: for every prefix, undo followed by re-recording the same event returns the previous `Match`, and undoing to the start gives `Match(setup:)`;
  - SC-003: `MatchCodec` round trip equals the original, including stats, in 100% of the generated matches.

  The spec's wording "the same point" is backlog #6 R4-7.
- [X] T033 [US3] In `Tests/PerformanceTests.swift`, write test SC-004 (CI part):
  - build a fixed best-of-3 event list of **exactly 500 points** with `MatchBuilder`: long deuce games plus tie-break sets, with no generator involved. Assert `points == 500` and the expected final `completedSets` and `status`;
  - time two paths, each 10 times with `ContinuousClock`: `Match(events:)` plus `stats` (validation, the incremental path), and `Reducer.replay` plus stats (the full recompute that undo and corrections run, via `@testable import`);
  - `#expect(median < .milliseconds(10))` for each path, and print both medians.

### Implementation for US3

- [X] T034 [US3] Implement validation in `Sources/Engine/Match.swift`:
  - `init(events:)` validates by recording through `record(_:)` (research R3); its cache comes from the incremental `step` path. Undo and correction rebuild it with `Reducer.replay`, and P-1 (T031) keeps the two paths equal;
  - `record(.setup)` → `.duplicateSetup`;
  - an empty list, or a first event that is not `setup` → `.missingSetup`;
  - `record` mutates only on success (G3);
  - until T057 and T063, `record(.matchEndedEarly)` and `record(.firstServerCorrected)` keep the stub behaviour (no change, no throw).
- [X] T035 [US3] Implement `undo()` in `Sources/Engine/Match.swift`:
  - it removes the last event when `events.count ≥ 2` and returns it;
  - otherwise it returns `nil`;
  - afterwards it rebuilds the cached reduction with `Reducer.replay` (research R2).
- [X] T036 [US3] Implement `MatchCodec.encode` in `Sources/Persistence/MatchCodec.swift`, with the JSON layout exactly as in [contracts/saved-format.md](contracts/saved-format.md):
  - hand-written `Codable` for the events, with the `"type"` discriminator;
  - `recordedAt` as `timeIntervalSinceReferenceDate`;
  - the encoder uses `.sortedKeys`;
  - `encode` is `throws(EncodingError)`: catch the `JSONEncoder` error; rethrow it when it is an `EncodingError`, otherwise wrap it as `EncodingError.invalidValue(match, .init(codingPath: [], debugDescription: "\(error)", underlyingError: error))`. No force cast (contract G6).
- [X] T037 [US3] Implement `MatchCodec.decode` in `Sources/Persistence/MatchCodec.swift`, following the 5-step restore algorithm in saved-format.md:
  1. decode the version only;
  2. a newer version → `.unsupportedVersion`;
  3. migrate;
  4. decode the events;
  5. `Match(events:)` → `.invalid`.

  No `try!` and no traps (G6).
- [X] T038 [US3] Create `Sources/Persistence/Migrations.swift`: an ordered list of `vK → vK+1` steps over the JSON object, empty for v1, with a doc comment that states the versioning rules from saved-format.md. Make T024–T033 pass.

**Checkpoint**: All P1 stories (US1–US4) pass, and so do P-1, SC-002, SC-003 and SC-004 over point-only matches. This is the MVP engine.

---

## Phase 6: User Story 5 – Change ends at the right time (P2)

**Goal**: A per-point change-of-ends value; the exposed value is that of the most recent point.

**Independent Test**: Feed point sequences and check each point's `changeOfEnds`.

### Tests for US5 (write first, must FAIL)

- [X] T039 [P] [US5] In `Tests/US5ChangeOfEndsTests.swift`, write tests US5 s1–s4 (`// ITF: EN-01, EN-02, EN-03, EN-04`). Positive control for s2 (the placeholder `changeOfEnds` is always `false`): the same test asserts the change after game 1 of the next set is `true`. s4 has one parameterized case per set length: 7–6 = 13, 5–4 = 9, 9–8 = 17.
- [X] T040 [P] [US5] In `Tests/US5ChangeOfEndsTests.swift`, write tests US5 s5–s8 (`// ITF: TB-05, EN-03, EN-02, EN-04`):
  - s6: a 7–5 tie-break (12 points) reports exactly one change;
  - s7: one case per set length;
  - s8: the first change comes after 6 match-tie-break points; the test asserts that point's value is `true` (positive control), not only that earlier ones are `false`.
- [X] T041 [P] [US5] In `Tests/US5ChangeOfEndsTests.swift`, write test US5 s9 (`// ITF: EN-05`) with all four explicit cases: 1-set 6–3, 1-set 7–6, best of 3 won 2–0 with set 2 won in a tie-break, and a match tie-break won 10–8 (18 points). Also check `changeOfEnds == false` before the first point. Positive control: in each case, an earlier point of the same match reports `true` (e.g. after game 1).
- [X] T042 [P] [US5] In `Tests/US3UndoAndRestoreTests.swift`, write test US3 s7 (`// ITF: EN-03, TB-05`): undoing a point that called for a change of ends exposes the previous point's value, or `false` if there is none. Cases: undo the point that ends game 1 (previous value `false`); and, as the positive control, undo the point that wins a set-1 tie-break **7–0** in best of 3. That point calls for a change (EN-03: 13 games), and the previous point (6–0, the 6th tie-break point) is `true` (TB-05), so the undo must expose `true` and the test fails against the always-`false` placeholder. Two consecutive points can both call for a change only here: games last at least 4 points, and a tie-break won after 6 points must be won 7–0 or 0–7.

### Implementation for US5

- [X] T043 [US5] In `Sources/Engine/ScoreTrack.swift`, compute each point's change of ends with the 4-rule order in data-model.md "Change of ends":
  1. the match-winning point → `false`;
  2. the end of a standard game or set tie-break → odd games in the set;
  3. inside a tie-break → points are a positive multiple of 6;
  4. otherwise `false`.

  Store it in the state as `changeOfEnds`. Make T039–T042 pass.

**Checkpoint**: US1–US5 pass.

---

## Phase 7: User Story 6 – See match stats without typing anything (P2)

**Goal**: Points on serve and return, service games held, and break points converted and saved, all derived from the points.

**Independent Test**: Feed a known point sequence and compare with hand-counted stats.

### Tests for US6 (write first, must FAIL)

- [X] T044 [P] [US6] In `Tests/US6StatsTests.swift`, write tests US6 s1–s5 (`// ITF: BP-03`): serve and return tallies include tie-break points, the s2 identities hold, and tie-breaks and games in progress are not service games.
- [X] T045 [P] [US6] In `Tests/US6StatsTests.swift`, write tests US6 s6–s12 (`// ITF: BP-01, BP-02`):
  - s8: 0–40 then three points saved → 3 faced, 3 saved;
  - s10: several deuces count each receiver's advantage;
  - s11: no tie-break point is a break point;
  - s12: converted = faced − saved.
- [X] T046 [P] [US6] In `Tests/US4TieBreakTests.swift`, write test US4 s8 (`// ITF: BP-02`): no point in a set tie-break or a match tie-break adds to break-point tallies. Positive control: the same match has break points before the tie-break, and they are counted (> 0).
- [X] T047 [P] [US6] In `Tests/PropertyTests.swift`, write test SC-006: the three stats identities in data-model.md hold for every prefix of every generated match. Positive control: the points served by both players add up to the number of points in the prefix.
- [X] T048 [P] [US6] Create the agent-built reference fixtures in `Tests/Fixtures/reference/`: `one-set.json`, `best-of-3.json`, `best-of-3-match-tie-break.json`, `no-ad.json` and `set-length-4.json`. Each has:
  - `"origin": "agent-built"`, the format and the first server;
  - `"sets": [{ "games": ["MMOM…", …] }]`, one string per game or tie-break;
  - the expected `PlayerStats` for both players.

  The expected values are **counted by hand, not by any script** (a script would be a second engine). Each fixture gets a sidecar `<name>.counting.md` with one row per game: server, points, break points, held or broken.
- [X] T049 [P] [US6] Create the fixture template `Tests/Fixtures/reference/hand-scored-denys.template.json`, for Denys to fill in by hand after a real match:

  ```json
  {
    "origin": "hand-scored (Denys)",
    "date": "YYYY-MM-DD",
    "format": { "matchLength": "oneSet | bestOfThree", "setLength": 6, "gameScoring": "advantage | noAd", "matchTieBreak": false },
    "firstServer": "me | opponent",
    "sets": [
      { "games": ["MMOM", "OOMOO", "…"] }
    ],
    "expectedStats": {
      "me":       { "pointsWonOnServe": [0, 0], "pointsWonOnReturn": [0, 0], "serviceGamesHeld": [0, 0], "breakPointsConverted": [0, 0], "breakPointsSaved": [0, 0] },
      "opponent": { "pointsWonOnServe": [0, 0], "pointsWonOnReturn": [0, 0], "serviceGamesHeld": [0, 0], "breakPointsConverted": [0, 0], "breakPointsSaved": [0, 0] }
    }
  }
  ```

  Add `Tests/Fixtures/reference/README.md` explaining:
  - `M` = I won the point, `O` = the opponent won it;
  - each set has one string per game in play order, and a tie-break is one string;
  - pairs are `[won, of]`;
  - count by hand, not with the app;
  - save the filled copy as `hand-scored-denys.json`;
  - the per-game strings let the test also check that game boundaries match the engine's.
- [ ] T050 [US6] **Owner: Denys.** After your next match, copy `hand-scored-denys.template.json` to `Tests/Fixtures/reference/hand-scored-denys.json`, fill in the format, the first server, the point winners per game and your hand-counted stats, and commit it, or send it to the agent to commit. Until this file exists, the hand-scored SC-005 case is skipped, and every PR states "SC-005: not claimed (hand-scored fixture pending, T050)".
- [X] T051 [US6] In `Tests/ReferenceMatchTests.swift`, write test SC-005:
  - one parameterized `@Test` over every `reference/*.json` except the template;
  - replay the games, and assert that each game string ends exactly when the engine says the game is won;
  - compare `stats` with `expectedStats`;
  - show each fixture's `origin` in the test arguments;
  - a separate `@Test("SC-005 hand-scored (Denys)")` uses `.enabled(if: handScoredFixtureExists)`. This is the only conditional test, and it waits for data (T050), not code.

### Implementation for US6

- [X] T052 [US6] Implement stats in `Sources/Engine/Reducer.swift` and `Sources/Engine/Match.swift`:
  - `Reducer.step` returns a `PointContext` with the server, `isBreakPoint` ("a standard-game point where the receiver wins the game by winning it", BP-01) and the game completed and held flags;
  - aggregate it into `MatchStats` as in data-model.md "Derived: match stats";
  - stats accumulate on append and are recomputed on replay.

  Make T044–T048 and T051 (agent-built cases) pass.

**Checkpoint**: US1–US6 pass. SC-005 is partly satisfied (agent-built only) until T050.

---

## Phase 8: User Story 7 – End a match early (P2)

**Goal**: An unfinished status with the score and stats kept; undo resumes the match.

**Independent Test**: Feed points, then `matchEndedEarly`; check the status, winner, stats and point rejection; then undo.

### Tests for US7 (write first, must FAIL)

- [X] T053 [P] [US7] In `Tests/US7EarlyEndTests.swift`, write tests US7 s1–s8 (`// ITF: MT-08`):
  - s1: 6–4, 3–2, 30–15;
  - s5: an early end at 0–0 gives empty stats;
  - s6: rejected after a win or after an early end;
  - s7 and s8: `changeOfEnds` unchanged by the early end and by undoing it. Positive control (a no-op `endEarly` keeps it unchanged too): after the early end, `status == .unfinished`; after the undo, `.inProgress`.

  Cover the edge cases "mid-game" and "mid-tie-break" as parameterized arguments of s1.
- [X] T054 [P] [US7] In `Tests/US3UndoAndRestoreTests.swift`, write test US3 s11 (undo of an early end resumes the match), test `"US3 s9 ended early …"` (a point after an early end throws `.matchNotInProgress` and leaves the `Match` unchanged; it intentionally covers the same behaviour as US7 s3 in T053, under the US3 ID, so US3 s9 is fully covered by its own ID), and the early-end cases of US3 s16: a restored list with a point or a second early end after an early end → `.invalid(.matchNotInProgress)`.
- [X] T055 [US7] Extend `Tests/Support/MatchGenerator.swift`: with probability 0.1, end a match early at a random point. In `Tests/PropertyTests.swift`, write test SC-007(b): for every in-progress prefix, an early end followed by undo leaves the entire state and stats unchanged. P-1, SC-002 and SC-003 now also cover early ends.
- [X] T056 [US7] Extend `Tests/Fixtures/saved-format/v1.json` and `v1.expected.json` with a `matchEndedEarly` event at the end (status `unfinished`).

### Implementation for US7

- [X] T057 [US7] Implement `endEarly()` and `record(.matchEndedEarly)` in `Sources/Engine/Match.swift`:
  - the status becomes `.unfinished`, and nothing else changes;
  - rejected with `.matchNotInProgress` unless the status is `.inProgress`;
  - a replay after an early end restores `.unfinished`;
  - a point after it is rejected.

  Make T053–T056 and all earlier suites pass.

**Checkpoint**: US1–US7 pass.

---

## Phase 9: User Story 8 – Correct the first server (P2)

**Goal**: A correction recomputes the whole match from the corrected first server; scores and change of ends never change.

**Independent Test**: Compare a corrected match with one built from scratch with the corrected first server.

### Tests for US8 (write first, must FAIL)

- [ ] T058 [P] [US8] In `Tests/US8FirstServerCorrectionTests.swift`, write tests US8 s1–s6 (`// ITF: CE-02, TB-02, TB-03`):
  - s1: 2–0, game 1 broken, game 2 held, Opponent serves game 3;
  - s3: compare every server-independent field, and every point's change-of-ends value, with the uncorrected match (FR-030). Positive control (a no-op correction leaves everything unchanged too): `server` and `effectiveFirstServer` have changed;
  - s4: a correction during a tie-break;
  - s6: two corrections equal the uncorrected match, including `changeOfEnds`. Positive control: after the first correction, the server differs.
- [ ] T059 [P] [US8] In `Tests/US8FirstServerCorrectionTests.swift`, write tests US8 s7–s11 (`// ITF: CE-02, MT-08`):
  - s7: a correction to the current first server → `.sameFirstServer`, both for the setup's first server and after a correction;
  - s8: accepted after a win and after an early end;
  - s10: an early end, then a correction, then undo twice;
  - s11: `changeOfEnds` unchanged. Positive control: `server` has changed after the correction.
- [ ] T060 [P] [US8] In `Tests/US3UndoAndRestoreTests.swift`, write test US3 s12: undoing a correction restores the uncorrected server and serve stats, and the last point stays.
- [ ] T061 [US8] Extend `Tests/Support/MatchGenerator.swift` to insert `firstServerCorrected` (to the other player) with probability ~0.02 per event, including after an early end. In `Tests/PropertyTests.swift`, write test SC-007(a): a correction followed by the reverse correction leaves the entire state and stats unchanged, for every prefix. Positive control: after the first correction, `effectiveFirstServer` has changed, and so have the serve tallies whenever at least one point has been played. P-1, SC-002, SC-003 and SC-006 now also cover corrections.
- [ ] T062 [US8] Extend `Tests/Fixtures/saved-format/v1.json` and `v1.expected.json` with a `firstServerCorrected` event in mid-match and another after the early end, with the expected server and stats. The fixture is now final for formatVersion 1.

### Implementation for US8

- [ ] T063 [US8] Implement `correctFirstServer(to:)` and `record(.firstServerCorrected)` in `Sources/Engine/Match.swift`:
  - `effectiveFirstServer` is the latest correction, otherwise the setup's first server;
  - reject with `.sameFirstServer` when the requested player equals it;
  - accepted in any status;
  - on success, rebuild with `Reducer.replay` from the new effective first server (research R1).

  Make T058–T062 and all earlier suites pass.

**Checkpoint**: All 8 stories and every plan-level property pass.

---

## Phase 10: Cross-cutting – verification, traceability, delivery

**Purpose**: Final checks and the harness steps from CLAUDE.md.

- [ ] T064 Run the full suite: `swift test --package-path Packages/TennisCore`. Fix failures test-first: any bug found here gets a failing regression test before its fix (constitution III). Confirm that the only conditional test is the hand-scored SC-005 case:

  ```sh
  grep -rnE '\.(disabled|enabled)\(' Packages/TennisCore/Tests
  ```

- [ ] T065 Run the traceability check from quickstart.md §2. Both counts must be 99, and every `// ITF:` ID must exist in `docs/rules/itf-notes.md`. Run the purity grep from quickstart.md §3, which must print nothing.
- [ ] T066 [P] Fill in the **Tests** column of `docs/rules/itf-notes.md` for every ID used by the engine with the test files that cite it, using `grep -rl "ITF: <ID>"`. Leave out-of-scope IDs (ST-02, ST-05, MT-06, MT-07, TB-06, CE-01) as "— (out of MVP scope)". ST-01 is in scope (fixed tie-break-set method) and cites T015's tests.
- [ ] T067 Build both app schemes with XcodeBuildMCP (`TennisBeat`, `TennisBeat Watch App`), as in quickstart.md §4, and confirm that both succeed. No UI changed, so there are no screenshots; state that in the PR.
- [ ] T068 Append the metrics row for the previous merged PR to `docs/harness.md` (CLAUDE.md step 8).
- [ ] T069 Commit, then invoke the `reviewer` subagent with only `specs/001-scoring-engine` and the base branch `main`. Post its report as a PR comment with numbered findings (R<review>-<n>). Fix and re-review until PASS on the head SHA.
- [ ] T070 Push and open the implementation PR with `Reviewed-SHA: <full SHA>` equal to the head. The PR body states:
  - "SC-005: not claimed (hand-scored fixture pending, T050)", unless T050 is done;
  - "SC-004 device check: deferred to the watch feature (approved by Denys, 2026-10-13)";
  - no UI, HealthKit or sync change, so no other device checks.

  Push nothing after the final review.

---

## Requirement coverage

| Requirement | Tasks |
| --- | --- |
| FR-001 events | T008, T034, T057, T063 |
| FR-002 pure reduction | T020, T031 (P-1) |
| FR-003 save/restore | T027, T032 (SC-003), T036–T037 |
| FR-004 undo | T024, T029, T032 (SC-002), T035 |
| FR-005 rejections | T016, T025, T028, T053, T059, T034, T057, T063 |
| FR-006–FR-007 format, tie-break sets | T006, T015–T016, T019 |
| FR-008–FR-013 scoring, match end | T014–T018, T019 |
| FR-014–FR-015 exposed state, flags | T009, T014, T018, T019, T041 |
| FR-016–FR-019 service, court side | T021–T023 |
| FR-020–FR-023 change of ends | T039–T043 |
| FR-024–FR-027 stats | T044–T048, T051–T052 |
| FR-028 traceability | T065, T066 |
| FR-029 early end | T053–T057 |
| FR-030 first-server correction | T058–T063 |
| FR-031–FR-032 saved format, times | T026–T027, T036–T038, T056, T062 |
| SC-001 | T065 |
| SC-002, SC-003 | T030, T032 (extended by T055, T061) |
| SC-004 | T033 (CI part); device part deferred to the watch feature (approved by Denys, 2026-10-13) |
| SC-005 | T048–T051 (T050 owned by Denys) |
| SC-006 | T047 |
| SC-007 | T055 (b), T061 (a) |
| P-1 (plan) | T031 (extended by T055, T061) |

## Dependencies & Execution Order

### Phase dependencies

- Setup (T001–T004) → Foundational (T005–T013) → stories.
- **US1 + US4** (T014–T020) is required by every later phase, because they all score points.
- **US2** (T021–T023) depends on US1.
- **US3** (T024–T038) depends on US1 and US2 (the generated matches and fixtures include servers).
- **US5** (T039–T043) depends on US3 for its US3 s7 test.
- **US6** (T044–T052) depends on US2 (the server) and US3 (the generator). T050 (Denys) blocks only the hand-scored SC-005 case.
- **US7** (T053–T057) depends on US3 (undo, validation, codec).
- **US8** (T058–T063) depends on US2, US3, US6 (the stats assertions in s1/s2) and US7 (s8, s10).
- Cross-cutting (T064–T070) depends on all phases.

### Within each phase

1. Write the tests and fixtures.
2. Run them and confirm they fail.
3. Implement.
4. Run the full suite at the checkpoint: everything is green, including earlier phases.

### Parallel opportunities

- Setup: T004 runs alongside T002–T003.
- Foundational: T005–T010 are separate files, all [P]. T011 waits for them; T012 waits for T011.
- Within a phase, the test-writing tasks marked [P] can be written in parallel. When several go into one file, write them in sequence but independently.
- T048 and T049 (reference fixtures) can be prepared at any time after Phase 2.
- Implementation tasks run in sequence: they share `ScoreTrack.swift`, `Reducer.swift` and `Match.swift`.

## Parallel Example: User Story 6

```bash
Task: "Write tests US6 s1–s5 in Tests/US6StatsTests.swift"
Task: "Write tests US6 s6–s12 in Tests/US6StatsTests.swift"
Task: "Write test US4 s8 in Tests/US4TieBreakTests.swift"
Task: "Write test SC-006 in Tests/PropertyTests.swift"
Task: "Create agent-built reference fixtures with counting sidecars in Tests/Fixtures/reference/"
Task: "Create hand-scored-denys.template.json and README.md in Tests/Fixtures/reference/"
```

## Implementation Strategy

### MVP first (P1: US1–US4)

1. Phases 1–2, then US1 + US4. Stop and validate: the engine scores every format.
2. US2 and US3. Stop and validate: the server, side, undo and restore are correct, and P-1, SC-002, SC-003 and SC-004 pass. This is all the watch score screen needs.

### Incremental delivery

3. US5 (change-of-ends haptic), US6 (stats), US7 (early end), US8 (correction). Each extends the generator, so the properties cover the new events.
4. Cross-cutting: traceability, the ITF Tests column, both app builds, review, PR.

The engine ships as one PR: the plan has a single implementation branch, and the apps don't use the engine until the watch feature.

## Notes

- Never edit `spec.md` acceptance criteria. If a test reveals a spec gap, propose the change to Denys and add it to backlog #6.
- Run `swift format` automatically through the hook. Commit after each task or logical group.
