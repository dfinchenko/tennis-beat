# Research: Scoring engine (001)

**Date**: 2026-10-13 | **Spec**: [spec.md](spec.md) | **Plan**: [plan.md](plan.md)

The Technical Context had no open `NEEDS CLARIFICATION` items: the spec, the constitution and `docs/product/plan.md` fix the language, platforms and package. The decisions below settle how to build the engine. Each one lists what was chosen, why, and what was rejected.

## R1. Reduction model and where corrections fit

- **Decision**: Split each match into two parts:
  - a **score track**, which depends only on the order of point winners and the format;
  - a **service track**, which depends on the score track plus the *effective first server*: the latest `firstServerCorrected` value, or the setup's first server if there is none.

  `state = reduce(setup, effectiveFirstServer, points, endedEarly)`. A correction's position in the list doesn't matter for the state, because a correction rewrites who served from the start (CE-02). Its position matters only for validation and undo.
- **Rationale**: FR-030 requires a correction to leave every score value and every per-point change-of-ends value untouched. Change of ends depends only on game and tie-break counts (EN-01..05, TB-05), never on who serves. So it belongs to the score track, and a correction cannot change it. Scenarios US8 s3/s6/s11 and SC-007(a) hold by construction.
- **Alternatives rejected**:
  - Applying the correction "from this point on": that is Rule 27 (CE-01), which the spec explicitly rejects.
  - Storing the server inside each point event: a correction would then have to rewrite history, which breaks event sourcing.

## R2. Incremental append, full replay for undo and correction

- **Decision**: `Match` keeps the event list plus a cached reduction:
  - **Appending a point** runs one pure `step` on the cached state.
  - **Undo** and **first-server correction** replay the list from scratch.
  - **Match ended early** only flips the status.
- **Rationale**: FR-002 and FR-004 need "state equals the state of the shortened list", and a replay gives exactly that. A 500-point replay is a few thousand integer operations, far below SC-004's 10 ms, even in the debug build CI runs. Incremental append keeps every tap O(1).
- **Guard against divergence (approved by Denys, 2026-10-13)**: the two code paths are kept in step by a property test, **P-1 (incremental equals replay)**. For every prefix of every generated match (R8), the `Match` built by recording the events one by one must equal the `Match` from a full replay of the same prefix: every `state` value, every `stats` value and the cached reduction. This is a plan-level test that adds to SC-002 and SC-003. It changes no acceptance criterion. The replay side is `Reducer.replay` called directly, not `Match(events:)`, which records event by event (R3) and so uses the incremental path.
- **Alternatives rejected**:
  - A snapshot stack per event: more memory, and an extra source of truth that could drift from the replay.
  - Always replaying, even on append: simpler, but O(n²) over the property tests' prefixes, which slows CI for no gain.

## R3. Validation is the same code path for live input and restored lists

- **Decision**: `Match(events:)` builds the match by recording the events one by one through the same `record` method the app uses. Its cached reduction therefore comes from the incremental `step` path. `Reducer.replay` is used for undo and corrections, and P-1 (R2) compares the two. Any rejection rule (FR-005, FR-029, US3 s10/s16) therefore applies identically to live input and to restored data.
- **Rationale**: A single rule implementation, so the two cannot disagree.
- **Alternative rejected**: a separate validator for decoded lists, which duplicates the rules.

## R4. Error model

- **Decision**: Swift 6 typed throws:
  - `throws(MatchError)` for rejected events and invalid setups;
  - `Result<Match, RestoreError>` from the codec, where `RestoreError` is `.unsupportedVersion(found:supported:)`, `.malformed` or `.invalid(MatchError)`.

  Rejected input leaves the value unchanged; value semantics guarantee it.
- **Rationale**: FR-005 says rejected input must not change state. FR-031 needs an explicit "unsupported version" result and no crash. With typed throws, tests can match exact cases.
- **Alternatives rejected**:
  - Returning `Bool`: callers can't tell why an event was rejected.
  - `preconditionFailure`: it crashes, which FR-031 forbids.

## R5. Saved format (JSON, version 1)

- **Decision**: JSON with an envelope `{ "formatVersion": 1, "events": [ … ] }`. Events use a `"type"` discriminator. The engine writes its own `Codable` implementations, so the result doesn't depend on the caller's `JSONEncoder`/`JSONDecoder` settings. Restoring is two-phase:
  1. Decode only `formatVersion`. If it is greater than the current version, return `.unsupportedVersion`.
  2. Run migrations up to the current version, then decode and validate the events.

  See [contracts/saved-format.md](contracts/saved-format.md).
- **Rationale**: FR-031 needs a newer version detected before the payload is parsed. JSON is human-readable for fixtures and for debugging device reports. `formatVersion` 1 is the first released version (spec Assumptions).
- **Alternatives rejected**:
  - Property lists: harder to read in fixtures and diffs.
  - Synthesized `Codable` for enums with associated values: the key layout is a compiler detail, which is risky for a format that must stay readable forever.

## R6. Recorded time stored losslessly

- **Decision**: A point's `recordedAt: Date` is encoded as a JSON number, `Date.timeIntervalSinceReferenceDate` (seconds since 2001-01-01T00:00:00Z), and decoded with `Date(timeIntervalSinceReferenceDate:)`.
- **Rationale**: That `Double` is the `Date`'s own stored value. Swift's JSON number encoding writes the shortest string that reads back to the same `Double`, so the round trip is bit-exact (FR-032, US3 s8).
- **Alternatives rejected**:
  - ISO 8601: drops sub-millisecond precision, so the restored value wouldn't be identical.
  - `timeIntervalSince1970`: the extra conversion can lose the last bit.
  - Integer milliseconds: the restored `Date` would differ from the original.

## R7. Point display: the engine exposes values, not text

- **Decision**: `PointDisplay` is an enum: `.zero`, `.fifteen`, `.thirty`, `.forty`, `.advantage`, `.tieBreak(Int)`. The apps turn it into localized text ("0" always, never "love"; "AD" and its PL/UK forms come from the String Catalog per `docs/glossary.md`). Spec wording such as "reads 'AD'" maps one-to-one to these cases in the tests.
- **Rationale**: Constitution X: user-facing strings go through String Catalog in the apps. The engine has no strings to localize, which keeps it pure (constitution, Technical Constraints).
- **Alternative rejected**: a `String` display in the engine, which would put localization in the wrong layer.

## R8. Test framework and property-based testing without dependencies

- **Decision**:
  - **Framework**: Swift Testing (`import Testing`), already used by the package's placeholder test.
  - **Property tests (SC-002, SC-003, SC-006, SC-007, and P-1 from R2)**: a small in-repo generator, a seeded SplitMix64 PRNG.
    - It picks a random supported format and first server, then generates point winners with a per-match bias. The bias makes long deuces, tie-breaks and match tie-breaks common.
    - It sprinkles in first-server corrections and, sometimes, an early end.
    - It is built in stages: points only with US3, early ends added with US7, corrections with US8. Each stage's property tests then fail before the code they exercise (constitution III).
    - It produces at least 1,000 matches, with a fixed default seed. `TENNISCORE_SEED` can override the seed, and failures print it.
- **Rationale**: Constitution IX and CLAUDE.md forbid adding a dependency without approval. A deterministic generator is reproducible in CI and enough for these invariants.
- **Alternative rejected**: SwiftCheck and similar libraries, which are third-party dependencies.

## R9. Performance check (SC-004, CI part)

- **Decision**: A Swift Testing test builds a fixed 500-point best-of-3 event list. It replays state and stats 10 times, measuring each run with `ContinuousClock`, and asserts that the median is under 10 ms. It runs in the default (debug) configuration, as CI runs `swift test`.
- **Rationale**: This is the configuration CI actually uses, and passing in debug implies passing in release.
- **Alternative rejected**: XCTest `measure` blocks. They report but don't fail on an absolute threshold without baselines, which aren't portable to CI runners.

## R10. Stats computed in the same fold

- **Decision**: Each `step` reports a per-point context:
  - who served;
  - whether the point was a break point (standard game only, BP-01/02);
  - whether a standard game completed, and who held it.

  `MatchStats` aggregates these contexts. Since the service track depends on the effective first server, stats are recomputed on replay (correction, undo) and accumulated on append.
- **Rationale**: Stats are "functions over events" (constitution). Computing them in the same reduction guarantees they agree with the score and follow undo exactly (FR-027).
- **Alternative rejected**: a second, independent pass over events. It duplicates the rules for game ends and tie-breaks and could drift from the score.

## R11. Fixtures

- **Decision**: The test target gets a `Fixtures/` resource folder (`resources: [.copy("Fixtures")]` in `Package.swift`). It is not a dependency. It holds:
  - `saved-format/v1.json`: frozen, never edited. It keeps US3 s13 honest for every future version.
  - `reference/*.json`: the 5 SC-005 reference matches, as a compact point string such as `"MMOM…"`, the format, and the expected stats. Each carries `"origin": "hand-scored (Denys)"` or `"origin": "agent-built"`.
- **Rationale**: SC-005 requires the origin to be visible in the fixtures. US3 s13 requires one example per released format version.
- **Open input (not a blocker for planning)**: Denys provides at least one hand-scored reference match: the point sequence and the expected stats. Until then, that test is listed as pending in `tasks.md`, and the PR can't claim SC-005.

## R12. ITF notes traceability

- **Decision**:
  - Every rule-based test carries `// ITF: <ID>`.
  - Every test's display name starts with its scenario reference (e.g. `"US2 s7 …"`), so the coverage check for FR-028 and SC-001 is a grep.
  - The implementation PR fills in the **Tests** column of `docs/rules/itf-notes.md` with the test files covering each ID, as that file asks ("filled in by the engine feature").
- **Rationale**: Constitution II, FR-028, SC-001.
