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
5. `reviewer` subagent in a fresh context → `Reviewed-SHA`. Each report is posted as a PR comment: verdict, SHA, numbered findings (R<review>-<n>) with severity and outcome.
6. PR + CI. Evidence is valid only for the reviewed SHA.
7. Denys reviews and merges. **Gate 2 (human).**
8. Before TestFlight: device checklist below. **Gate 3 (human).**

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

## Metrics log
One row per merged PR. Count defects by where they were caught. No speed-up claims without measurement. Every number must be traceable: reviewer counts come from the reviewer-report comments on the PR (linked in Notes), CI counts from the PR's check runs.

| PR | Feature | Tests added | Caught by tests | Caught by reviewer | Caught on device | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| #1 | Bootstrap harness | 1 (placeholder) | 1 (CI build) | 3 blocker/major + 14 minor | — (no device testing) | [Reviewer reports](https://github.com/dfinchenko/tennis-beat/pull/1#issuecomment-6035355595) (4 reviews). The CI build failure on Xcode 26.6 (project format 110) is the reviewer's R1-2 confirmed. Fixed before merge: R1-1 (screens; Denys exported the frames), R1-2, R1-3, R1-5, R1-6, R1-7, R2-2, R2-3, R3-3. |
| #2 | README and harness metrics (docs) | 0 | 0 (CI green) | 1 major + 11 minor | — (docs only) | [Reviewer reports](https://github.com/dfinchenko/tennis-beat/pull/2#issuecomment-6035356064) (2 reviews). R1-1 (major, ruleset check names) was fixed by Denys in GitHub settings. 4 fixed before merge (R1-2..R1-5); 6 deferred (R2-1..R2-6: 5 README items, 1 harness.md settings check); 1 raised to Denys (R1-6). |
| #3 | Approve ITF, glossary and design decisions (docs) | 0 | 0 (CI green) | 1 major + 5 minor | — (docs only) | [Reviewer report](https://github.com/dfinchenko/tennis-beat/pull/3#issuecomment-6035356561) (1 review). None fixed before merge. R1-1 (major, No-Ad deciding point vs ITF NA-02) was decided by Denys and applied in the follow-up PR, as were R1-2, R1-3 and R1-5. R1-6 was confirmed by Denys; R1-4 is not a defect. |
