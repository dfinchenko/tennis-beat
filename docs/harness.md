# AI harness

How Tennis Beat is built: Claude Code implements, Denys owns product decisions, review and device testing.

## Tools
- **Claude Code** with project settings in `.claude/settings.json` (permission allowlist, hooks) and subagents in `.claude/agents/`.
- **Xcode MCP** (`xcrun mcpbridge`, project-scoped in `.mcp.json`) and **XcodeBuildMCP** for builds, simulators, UI automation and screenshots.
- **GitHub Spec Kit** for spec-driven development; tasks become GitHub Issues.
- **GitHub**: public repo, squash-only merging, a ruleset on `main` (PR only, green CI, no force push or deletion), secret scanning and push protection.
- **Figma** as a showcase; design is exported once into `docs/design/`.
- **fastlane** for screenshots, metadata and TestFlight (added later).

## Task cycle and gates
1. `/speckit-specify` → Denys sets `Status: Approved` in `spec.md`. **Gate 1 (human).**
2. `/speckit-plan`, `/speckit-tasks`, `/speckit-analyze`; `scripts/gates/check-artifacts.sh` must pass.
3. Implementation in a dedicated worktree, tests first; hooks format on edit and run engine tests before the agent stops.
4. Build and simulator run via XcodeBuildMCP, screenshots in the PR.
5. `reviewer` subagent in a fresh context → `Reviewed-SHA`.
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
One row per merged PR. Count defects by where they were caught. No speed-up claims without measurement.

| PR | Feature | Tests added | Caught by tests | Caught by reviewer | Caught on device | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| #1 | Bootstrap harness | 1 (placeholder) | 1 (CI) | 4 | 0 | CI on Xcode 26.6 caught the Xcode 27 project format (110, from `validationLevel`) that the runner cannot open. Reviewer found: Swift 5 app targets, missing screens export, missing `healthkit.access`, two copies of the permission texts. The Figma MCP limit blocked the screen export (frames exported manually). |
