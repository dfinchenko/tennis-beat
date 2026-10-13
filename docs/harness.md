# AI harness

How Tennis Beat is built: Claude Code implements, Denys owns product decisions, review and device testing.

## Tools
- **Claude Code** with project settings in `.claude/settings.json` (permission allowlist, hooks) and subagents in `.claude/agents/`.
- **Xcode MCP** (`xcrun mcpbridge`, project-scoped in `.mcp.json`) and **XcodeBuildMCP** for builds, simulators, UI automation and screenshots.
- **GitHub Spec Kit** for spec-driven development; tasks become GitHub Issues.
- **GitHub**: public repo, squash-only merging, a ruleset on `main` (PR only, green CI, no force push or deletion), secret scanning and push protection.
- **Figma** as a showcase only. The design was exported once into `docs/design/`, which is now the source of truth; agents do not call Figma tools because the Starter MCP limit is exhausted.
- **fastlane** for screenshots, metadata and TestFlight (added later).

## Task cycle and gates
1. `/speckit-specify` → Denys sets `Status: Approved` in `spec.md`. **Gate 1 (human).**
2. `/speckit-plan`, `/speckit-tasks`, `/speckit-analyze`; `scripts/gates/check-artifacts.sh` must pass.
3. Implementation in a dedicated worktree, tests first; hooks format on edit and run engine tests before the agent stops.
4. Build and simulator run via XcodeBuildMCP, screenshots in the PR.
5. `reviewer` subagent in a fresh context → `Reviewed-SHA`. Each report is posted as a PR comment: verdict, SHA, numbered findings (R<review>-<n>) with severity and outcome. The reviewer also verifies the PR's **Test expectation changes** list (see below).
6. PR + CI. Evidence is valid only for the reviewed SHA. The PR body starts with `Reviewed-SHA: <full 40-character SHA>`; the **review-gate** CI job fails unless it equals the PR head SHA (see below).
7. Denys reviews and merges. **Gate 2 (human).**
8. Before TestFlight: device checklist below. **Gate 3 (human).**

## Test expectation changes
Rule (Denys, 2026-10-13). A test's expectation is the encoded rule. Changing it after the code exists can make a test agree with a bug.
- **Applies to:** any change to what a test asserts (expected value, expected error, or a positive control's condition) made after the code that the test checks was written. This includes code already on `main` and code written earlier in the same branch. Writing a new test before its code, renaming, or changing a point sequence while keeping every expected value is not an expectation change. If in doubt, list it.
- **The PR body** has a section **Test expectation changes**, with one row per change: test name, old expectation → new expectation, ITF note ID (from `docs/rules/itf-notes.md`; `—` only for a non-rule property such as a stats identity, with a reason). Write "none" if there are none.
- **Order:** the PR is opened with `Reviewed-SHA: pending` before the final review, so the reviewer reads the list itself with `gh pr view <number>` (the PR number is passed to it, never a summary).
- **The reviewer** checks the list against the diff: every expectation change in the diff must be listed, and every listed change must agree with the cited entry in `docs/rules/itf-notes.md`. An unlisted change, or one that contradicts its note, is a blocker finding.

## Review gate and merge order
Added after PR #7 was merged at a head no reviewer had passed: nothing on GitHub enforced `Reviewed-SHA`.
- **review-gate** (`.github/workflows/review-gate.yml`, script `scripts/gates/check-review-gate.sh`) runs on every PR, spec PRs included. It passes only when the PR body has exactly one line `Reviewed-SHA: <40-hex SHA>` and that SHA equals the PR head. It re-runs on pushes and on PR body edits. Use `Reviewed-SHA: pending` until a review passes; the check fails on it by design.
- Denys makes review-gate a required check in the "Protect main" ruleset.
- **Merge order** for every PR:
  1. Denys's approval commit comes first. For a spec PR this is the commit that sets `Status: Approved`; for any PR, Denys's requested changes are committed before the final review.
  2. The agent runs the final review on that head, posts the report, and sets `Reviewed-SHA` to the head. Nothing is pushed after that.
  3. Denys merges once review-gate and CI are green on that head. Any later push invalidates the review and the gate fails until a new review passes.

## Xcode project format
- The project was created with Xcode 27 but is saved in **Xcode 26.3 format** (`objectVersion = 100`), because the CI runner image (`macos-26`) only has Xcode 26.x.
- **In Xcode 27, do not re-enable strict project validation.** Also decline "Update to recommended settings" if it offers to. Either one writes the root key `validationLevel` into `project.pbxproj`, which forces format 110. Xcode 26 refuses to open that ("future Xcode project file format"), and every app build in CI fails.
- `scripts/gates/check-project-format.sh` runs in CI and fails on `objectVersion > 100` or on `validationLevel`. To fix it, delete the `validationLevel = 1;` line and set `objectVersion = 100;`.
- Revisit this once the runner image ships Xcode 27.

## Example: starting a feature
The first feature is the scoring engine:
```text
/speckit-specify Scoring engine in Packages/TennisCore. A match is an ordered list of Codable
events (point won by me/opponent, plus setup: format, first server). Match state is a pure
reduction of events. Formats: singles; 1 set or best of 3; set length 4, 6 or 8 games;
Advantage or No-Ad; tie-break at N–N; optional match tie-break to 10 instead of the deciding
set. The state exposes: point display per player, games and sets, server, serving side
(deuce/ad), tie-break flags, change-of-ends events, set and match winner. Undo removes the
last event and must work across game/set boundaries and after the match ends. Derived stats:
points won on serve and on return, service games held, break points converted and saved.
Every rule must reference docs/rules/itf-notes.md. No UI, HealthKit or persistence code.
```
Then Denys reviews the spec and sets `Status: Approved`. After that: `/speckit-plan` → `/speckit-tasks` → `/speckit-analyze` → `/speckit-implement`.

## Device checklist (Denys, before every TestFlight build)
- [ ] Full match on court: scoring, undo, change-of-ends haptics
- [ ] Health permission denied: scoring still works, no crashes
- [ ] Always On: score readable, no seconds or animations
- [ ] Largest Dynamic Type on a 42 mm watch: nothing clipped
- [ ] iPhone far away during the match: match arrives later
- [ ] Wet fingers / towel: no accidental points
- [ ] App killed mid-match: match restored with the same score
- [ ] Oldest supported watch, app killed during a 500-point match and relaunched: the restored score shows without a loading indicator (spec 001, SC-004)

## Metrics log
One row per merged PR, added in the following PR (a PR cannot count its own review). No speed-up claims without measurement.

**Counting rule** (Denys, 2026-10-12): count each defect once, in the earliest pipeline stage that caught it: tests/hooks → simulator → reviewer → CI → device. If a later stage caught the same defect too, say so in Notes. Every number must be traceable: reviewer counts come from the reviewer-report comments on the PR (linked in Notes), CI counts from the PR's check runs.

| PR | Feature | Tests added | Caught by tests/hooks | Caught in simulator | Caught by reviewer | Caught by CI | Caught on device | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| #1 | Bootstrap harness | 1 (placeholder) | 0 | — (not recorded) | 3 blocker/major + 14 minor | 0 | — (no device testing) | [Reviewer reports](https://github.com/dfinchenko/tennis-beat/pull/1#issuecomment-6035355595) (4 reviews). The CI build failure on Xcode 26.6 (project format 110) is the same defect as the reviewer's R1-2, so it is counted once, under reviewer. Fixed before merge: R1-1 (screens; Denys exported the frames), R1-2, R1-3, R1-5, R1-6, R1-7, R2-2, R2-3, R3-3. |
| #2 | README and harness metrics (docs) | 0 | 0 | — (docs only) | 1 major + 11 minor | 0 | — (docs only) | [Reviewer reports](https://github.com/dfinchenko/tennis-beat/pull/2#issuecomment-6035356064) (2 reviews). R1-1 (major, ruleset check names) was fixed by Denys in GitHub settings. 4 fixed before merge (R1-2..R1-5); 6 deferred (R2-1..R2-6: 5 README items, 1 harness.md settings check); 1 raised to Denys (R1-6). |
| #3 | Approve ITF, glossary and design decisions (docs) | 0 | 0 | — (docs only) | 1 major + 5 minor | 0 | — (docs only) | [Reviewer report](https://github.com/dfinchenko/tennis-beat/pull/3#issuecomment-6035356561) (1 review). None fixed before merge. R1-1 (major, No-Ad deciding point vs ITF NA-02) was decided by Denys and applied in the follow-up PR, as were R1-2, R1-3 and R1-5. R1-6 was confirmed by Denys; R1-4 is not a defect. |
| #4 | Docs follow-up fixes (docs) | 0 | 0 | — (docs only) | 8 minor | 0 | — (docs only) | Reviewer reports: [review 1](https://github.com/dfinchenko/tennis-beat/pull/4#issuecomment-6035429618) (`cec7f9a`, PASS, 6 minor) and [review 2](https://github.com/dfinchenko/tennis-beat/pull/4#issuecomment-6132171843) (`1786a60`, PASS, 4 minor). R2-1 restates R1-5 and R2-4 restates R1-2, so 8 unique. Fixed before merge: R1-1, R1-3, R1-4; R1-6 confirmed by Denys. Merged at the reviewed head. |
| #5 | Spec 001 scoring engine (spec) | 0 | 0 | — (spec only) | 0 | 0 | — (spec only) | No reviewer run on the PR's own head: it was opened for Denys's review, and his review drove the changes (approvals of MT-05, EN-05, FR-024; US5 s7/s8; seven spec changes). Merged at `1f99356` while later commits were still being pushed. Reviews R1–R4 of those later commits are [posted here](https://github.com/dfinchenko/tennis-beat/pull/5#issuecomment-6146379528) and counted under #7. |
| #7 | Spec 001 decisions and consistency fixes (spec) | 0 | 0 | — (spec only) | 13 major + 20 minor | 0 | — (spec only) | Reviews R1–R4 ([comment on #5](https://github.com/dfinchenko/tennis-beat/pull/5#issuecomment-6146379528)) and R5 ([comment](https://github.com/dfinchenko/tennis-beat/pull/7#issuecomment-6146559804)); all CHANGES_REQUESTED. Majors: R1 3, R2 3, R3 2, R4 2 fixed before merge; R5 3 fixed in #8 (open). Minors deduplicated in #6. **Merged at `92ea1c1`, a head no review passed**; this led to the review-gate. |
| #8 | Spec 001 per-point change of ends, SC-007, haptic note (spec) | 0 | 0 | — (spec only) | 5 minor | 0 | — (spec only) | Reviewer reports: [review 6](https://github.com/dfinchenko/tennis-beat/pull/7#issuecomment-6146681770) (`87993e9`, the same tree as #8's `bde9e01`, PASS, R6-1..R6-4 minor), [review 7](https://github.com/dfinchenko/tennis-beat/pull/8#issuecomment-6147941027) (`4a20645`, PASS, 6 minor that all restate #6 items already counted under #7, so not counted again), and [review 8](https://github.com/dfinchenko/tennis-beat/pull/8#issuecomment-6148308661) (`e0c959f`, final, PASS, R8-1 minor; R8-2 is backlog bookkeeping, not a defect). 5 unique: R6-1..R6-4 and R8-1. R6-4 was fixed before merge (`4a20645`, approved by Denys); the others are in #6. The R5 majors fixed here are counted under #7. One `review-gate` run failed and a later run on the same PR passed; no defect counted. Merged as `ed870f0` at the reviewed head `e0c959f`. |
| #10 | Spec 001 plan, research, design and tasks (plan) | 0 | 0 | — (plan only) | 2 blocker + 1 major + 15 minor | 0 | — (plan only) | Reviewer reports: [review 1](https://github.com/dfinchenko/tennis-beat/pull/10#issuecomment-6150632455) (`bd27b90`, CHANGES_REQUESTED: R1-1, R1-2 blockers on test-first order; R1-3 major, P-1 compared a path with itself; R1-4..R1-11 minor) and [review 2](https://github.com/dfinchenko/tennis-beat/pull/10#issuecomment-6150633010) (`8dfbe7d`, final, PASS, R2-1..R2-7 minor). Fixed before merge: all of review 1 except R1-11 (tracked in #6). R2-1..R2-7 went to #6 and are fixed in the following PR. Before review, `/speckit-analyze` found 3 critical + 4 medium + 3 low issues, which were fixed in the reviewed commit and are not counted (no pipeline stage). Merged as `7c3666a` at the reviewed head `8dfbe7d`. |
| #11 | Spec 001 tasks: review fixes before implementation (tasks) | 0 | 0 | — (tasks only) | 1 major + 5 minor | 0 | — (tasks only) | Reviewer reports: [review 1](https://github.com/dfinchenko/tennis-beat/pull/11#issuecomment-6150773949) (`fd8c6ff`, CHANGES_REQUESTED: R1-1 major, the US3 s7 positive-control example contradicted the spec; R1-2, R1-3 minor; all fixed in `5f9927f`) and [review 2](https://github.com/dfinchenko/tennis-beat/pull/11#issuecomment-6150774595) (`5f9927f`, final, PASS, R2-1..R2-3 minor → #6). The reviewer's suggested fix for R1-1 (a tie-break "won 7–6") was itself impossible; the fix used a 7–0 tie-break. Merged as `15a5c62` at the reviewed head `5f9927f`. |
| #12 | Scoring engine (spec 001) | 118 | 0 | 0 | 5 minor | 0 | — (no UI; the SC-004 device check is deferred to the watch feature) | [Reviewer report](https://github.com/dfinchenko/tennis-beat/pull/12#issuecomment-6152626681) (`afb039d`, PASS, R1-1..R1-5 minor; R1-2 handled in the PR body, the rest went to #6 and are fixed in the following PR). Tests: 119 total (118 new; the placeholder was replaced by a version test). No engine defect was caught; running the tests did catch 5 errors in the tests themselves (3 point sequences, the US8 s4 server expectation, the SC-007(a) positive control), all fixed before review and listed in the PR body. Simulator: both app schemes built; no flow to run. CI green on the reviewed head. Merged as `5867163` at the reviewed head `afb039d`. |
