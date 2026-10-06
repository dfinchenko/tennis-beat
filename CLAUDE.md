# Tennis Beat — agent guide

Tennis Beat is a free, privacy-first tennis score keeper for Apple Watch and iPhone.
You (Claude Code) implement; Denys approves specs, reviews and merges PRs, and tests on real devices.

## Read first
- `docs/product/plan.md` — scope, roadmap, constraints, architecture. Source of truth for what to build.
- `.specify/memory/constitution.md` — non-negotiable principles (created from `docs/constitution-input.md`).
- `docs/rules/itf-notes.md` — tennis rules, the source of truth for the scoring engine.
- `docs/glossary.md` — approved EN / PL / UK terms. Never invent translations of tennis terms.
- `docs/design/` — design export (tokens, typography, screen specs, PNGs). Do NOT call Figma read tools: the Figma Starter plan allows 6 read calls per month.
- `docs/harness.md` — how this harness works and the metrics log you must append to.

## Repo map
- `TennisBeat/` (iOS app), `TennisBeat Watch App/` (watchOS app) — created from the Xcode template.
- `Packages/TennisCore/` — pure Swift package: event-sourced scoring engine and derived stats. No SwiftUI, HealthKit or WatchConnectivity imports.
- `specs/NNN-feature/` — Spec Kit artifacts (`spec.md`, `plan.md`, `tasks.md`).
- `scripts/` — hooks and gates. `.claude/agents/` — subagents.

## Commands
- Engine tests: `swift test --package-path Packages/TennisCore`
- Format: `swift format --in-place <file>` (runs automatically via hook)
- App builds, simulator runs, UI screenshots: XcodeBuildMCP tools; Xcode MCP (`xcrun mcpbridge`) for previews and project settings.
- Artifact gate: `scripts/gates/check-artifacts.sh specs/NNN-feature`

## Workflow for every task
1. Work in a dedicated git worktree and branch `feat/NNN-slug` (one agent session per worktree).
2. Run the artifact gate. If it fails (missing/empty artifact or spec not `Status: Approved`), STOP and report.
3. Write failing tests first, then code. Every bug fix starts with a failing regression test.
4. Engine tests cite the rule they check, e.g. `// ITF: Rule 5(b)` using the IDs in `docs/rules/itf-notes.md`.
5. Build both app targets and run the affected flow in the simulator via XcodeBuildMCP; attach screenshots to the PR.
6. Invoke the `reviewer` subagent. Do not pass it your own summary. It returns `Reviewed-SHA`.
7. Open/update the PR with the `Reviewed-SHA` line. If you change anything after review, re-run tests and review: evidence is only valid for the reviewed SHA.
8. Append a row to the metrics log in `docs/harness.md`.

## Hard rules
- Never write code for a spec that is not `Status: Approved`. Never change acceptance criteria yourself — propose changes to Denys.
- Never merge PRs, never push to `main`, never force-push.
- Heart rate and other health data are never stored in the app database or iCloud; read them from HealthKit on demand by workout UUID.
- No analytics, no third-party SDKs, no network calls. Add no dependency without asking.
- No secrets in the repo (`*.p8`, `.env`, tokens). App Store Connect keys live in GitHub Secrets only.
- Every user-facing string goes through String Catalog with EN (source), PL and UK; use plural variations and `FormatStyle` for dates/durations; follow `docs/glossary.md`.
- Accessibility and HIG are acceptance criteria: VoiceOver labels, Dynamic Type, no color-only meaning, full-height tap zones on watch, 44 pt minimum on iPhone.
- The app must work without Health permission and on the watch without the iPhone nearby.

## Definition of done
Tests green for the current SHA, reviewer PASS for the same SHA, CI green, PR with screenshots, and — if UI, HealthKit or sync changed — a list of device checks for Denys (see `docs/harness.md`).
