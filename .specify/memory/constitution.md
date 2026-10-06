# Tennis Beat Constitution

## Core Principles

### I. Spec Before Code

- No implementation starts until the feature's `spec.md` carries `Status: Approved`, set by Denys.
- Acceptance criteria and priorities are set by the human owner, never by an agent. An agent MAY
  propose changes to a spec; it MUST NOT apply them to acceptance criteria itself.
- `scripts/gates/check-artifacts.sh specs/NNN-feature` MUST pass before implementation begins.

Rationale: the human owns product decisions; agents own execution.

### II. Tennis Rules Are the Source of Truth

- `docs/rules/itf-notes.md` holds paraphrased ITF rules, each with a stable ID and a rule or
  appendix reference.
- Every engine test MUST cite the rule ID it checks (e.g. `// ITF: <ID>`).
- Specs are assessed against the rules on four levels: **Full** (matches), **Partial** (gap to
  resolve), **Not covered** (the source is silent; our decision, labelled as such), **Conflict**
  (contradicts the rule).
- A Conflict stops the work until Denys decides.

Rationale: scoring correctness is the product; rules must be traceable, not remembered.

### III. Test First (NON-NEGOTIABLE)

- Tests are written before code and MUST fail before the implementation makes them pass.
- Every bug becomes a failing regression test before it is fixed.
- State boundaries get explicit tests: undo across a game/set boundary and after match end, crash
  recovery from persisted events, pause during a tie-break.

Rationale: an event-sourced engine is only as trustworthy as its boundary tests.

### IV. Evidence Is Bound to a Commit

- Test runs and reviews are valid only for the SHA they checked.
- Any change after review requires a new test run and a new review on the new SHA.
- PRs carry a `Reviewed-SHA` line that MUST equal the PR head.

Rationale: stale evidence is no evidence.

### V. Independent Review

- A `reviewer` subagent in a fresh context sees only the spec, the diff and the tests — never the
  implementer's summary — and reports a `Reviewed-SHA` and a verdict.
- Any Conflict or blocker finding means CHANGES_REQUESTED.

Rationale: the implementer's narrative biases review; the diff does not.

### VI. One Writer per Worktree

- One agent session works in one git worktree and one branch at a time.
- Agents never merge PRs, never push to `main` and never force-push.

Rationale: parallel writers in one checkout corrupt state and evidence.

### VII. Green Tests Are Not an Accepted Build

- Before every TestFlight build Denys runs the device checklist in `docs/harness.md` on a real
  Apple Watch and iPhone.
- PRs that change UI, HealthKit or sync MUST list the device checks Denys needs to run.

Rationale: simulators do not reproduce wrists, sweat, sunlight or radio range.

### VIII. AI Never Invents Numbers

- Any generated text about a match uses only numbers computed by the engine.
- Text containing a number absent from the engine's stats is rejected.

Rationale: a score keeper that hallucinates scores is worse than none.

### IX. Privacy by Default

- No accounts, analytics, third-party SDKs or network calls. No dependency is added without
  Denys's approval.
- Health data (including heart rate) stays in HealthKit: it is never stored in the app database
  or iCloud and is read on demand by workout UUID.
- No secrets in the repository (`*.p8`, `.env`, tokens); signing keys live in GitHub Secrets.
- The app MUST work without Health permission, and the watch app without the iPhone nearby.

Rationale: the App Store privacy label is "Data Not Collected" and must stay true.

### X. Three Languages, Always

- Every user-facing string goes through String Catalog with EN (source), PL and UK.
- Plural variations are used where counts appear; dates and durations use `FormatStyle`.
- Tennis terms follow `docs/glossary.md`; agents never invent translations.

Rationale: localization added later is localization done badly.

### XI. Accessibility and HIG Are Acceptance Criteria

- VoiceOver labels, Dynamic Type, no color-only meaning, full-height tap zones on the watch,
  44 pt minimum targets on iPhone, confirmed destructive actions, Always On support.
- A feature that fails these is not done, regardless of test status.

Rationale: accessibility is part of correctness, not polish.

### XII. Honest Metrics

- The metrics log in `docs/harness.md` records defects by where they were caught: tests, reviewer,
  device.
- No productivity or speed-up claims without measurement.

Rationale: the harness is itself an experiment and must report truthfully.

## Technical Constraints

- Swift 6 and SwiftUI; minimum iOS 26 and watchOS 26; built with the iOS 26 SDK / Xcode 26 or
  newer.
- `Packages/TennisCore` is a pure Swift package (no SwiftUI, HealthKit or WatchConnectivity
  imports): match state = reduce(events); undo = drop the last event; stats = functions over events.
- Product scope comes from `docs/product/plan.md`; design from the export in `docs/design/`.

## Development Workflow & Quality Gates

1. **Gate 1 (human)**: spec approved by Denys.
2. Plan, tasks and analysis artifacts generated; artifact gate passes.
3. Implementation test-first in a dedicated worktree; hooks format code and run engine tests.
4. Both app targets build; affected flows run in the simulator with screenshots in the PR.
5. Independent review with `Reviewed-SHA`; CI green.
6. **Gate 2 (human)**: Denys reviews and merges.
7. **Gate 3 (human)**: device checklist before TestFlight.

## Governance

- This constitution supersedes other practices. `CLAUDE.md` and `docs/harness.md` MUST stay
  consistent with it.
- Amendments are proposed in a PR, approved and merged by Denys, and recorded with a version bump:
  MAJOR for removed or redefined principles, MINOR for added or materially expanded principles,
  PATCH for clarifications.
- Every review checks compliance with these principles; violations are blocker findings.

**Version**: 1.0.0 | **Ratified**: 2026-10-06 | **Last Amended**: 2026-10-06
