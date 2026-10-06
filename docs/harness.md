# AI harness

How Tennis Beat is built: Claude Code implements, Denys owns product decisions, review and device testing.

## Tools
- **Claude Code** with project settings in `.claude/settings.json` (permission allowlist, hooks) and subagents in `.claude/agents/`.
- **Xcode MCP** (`xcrun mcpbridge`, project-scoped in `.mcp.json`) and **XcodeBuildMCP** for builds, simulators, UI automation and screenshots.
- **GitHub Spec Kit** for spec-driven development; tasks become GitHub Issues.
- **GitHub**: public repo, ruleset on `main` (PR only, green CI, no force push), secret scanning and push protection.
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
