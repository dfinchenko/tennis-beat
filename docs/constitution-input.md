# Input for /speckit-constitution

Use these principles to generate `.specify/memory/constitution.md` for Tennis Beat.

1. **Spec before code.** No implementation starts until `spec.md` carries `Status: Approved` set by Denys. Acceptance criteria and priorities are set by the human, never by an agent.
2. **Tennis rules are the source of truth.** `docs/rules/itf-notes.md` holds paraphrased ITF rules with references. Every engine test cites the rule it checks. Specs are assessed against the rules on four levels: Full match, Partial (gap to resolve), Not covered by the source, Conflict. A Conflict stops the work.
3. **Test first.** Tests are written before code. Every bug becomes a failing regression test before it is fixed, with special attention to state boundaries: undo across a set, crash recovery, pause during a tie-break.
4. **Evidence is bound to a commit.** Test runs and reviews are valid only for the SHA they checked. Any change after review requires new tests and a new review.
5. **Independent review.** A reviewer subagent in a fresh context sees only the spec, the diff and the tests — never the implementer's summary — and reports a Reviewed-SHA.
6. **One writer per worktree.** One agent session works in one git worktree at a time.
7. **Green tests are not an accepted build.** Before every TestFlight build Denys runs the device checklist on a real Apple Watch and iPhone.
8. **AI never invents numbers.** Any generated text about a match uses numbers computed by the engine; text containing a number absent from the stats is rejected.
9. **Privacy by default.** No accounts, analytics, third-party SDKs or network calls. Health data stays in HealthKit. No secrets in the repository.
10. **Three languages, always.** Every user-facing string exists in EN, PL and UK, uses plural variations where needed and follows the glossary.
11. **Accessibility and HIG are acceptance criteria**, not polish.
12. **Honest metrics.** The harness log records defects found by tests, by the reviewer and on devices. No unmeasured productivity claims.
