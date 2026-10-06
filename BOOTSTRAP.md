# Старт Tennis Beat — одноразова інструкція

Цей файл потрібен лише для першого запуску. Після злиття першого PR його можна видалити.

## 1. Що в пакеті
- `CLAUDE.md` — правила для агента, Claude Code читає його автоматично.
- `docs/product/plan.md` — план продукту англійською (копія робочого плану для агентів).
- `docs/constitution-input.md` — принципи для `/speckit.constitution`.
- `docs/glossary.md` — терміни EN/PL/UK (чернетка, затверджуєш ти).
- `docs/rules/itf-notes.md` — каркас нотаток з правил ITF, агент заповнить.
- `docs/harness.md` — опис харнесу, чекліст на пристрої, журнал метрик.
- `.claude/settings.json` — дозволи та хуки; `.claude/agents/reviewer.md` — незалежний рев'юер.
- `scripts/` — хуки (формат, тести перед зупинкою) і гейт артефактів.
- `.mcp.json` — MCP до Xcode; `.github/workflows/ci.yml` — мінімальний CI; `.gitignore`; `LICENSE` (MIT).

## 2. Підготовка Мака
```bash
brew install gh jq uv
uv tool install specify-cli --from git+https://github.com/github/spec-kit.git
brew tap getsentry/xcodebuildmcp && brew install xcodebuildmcp
```
Потрібні macOS 26 і Xcode 26.3 або новіший (агентні можливості Xcode працюють лише на macOS 26).

## 3. Репозиторій і файли
```bash
git clone https://github.com/dfinchenko/tennis-beat.git && cd tennis-beat
# розпакуй сюди вміст архіву (з прихованими .claude, .github, .gitignore, .mcp.json)
chmod +x scripts/hooks/*.sh scripts/gates/*.sh
```

## 4. Xcode-проєкт (5 хвилин, вручну)
File → New → Project → вкладка **watchOS** → **App** → Next:
- Product Name: `TennisBeat`
- Team: твій Personal Team (безкоштовний Apple ID)
- Organization Identifier: `com.dfinchenko`
- Watch App: **Watch App with New Companion iOS App**
- Interface: SwiftUI, Language: Swift, Testing System: Swift Testing, Storage: None
- Збережи в корінь репозиторію `tennis-beat`, **зніми** галочку «Create Git repository»

Вийде `com.dfinchenko.TennisBeat` для iPhone і `com.dfinchenko.TennisBeat.watchkitapp` для годинника. Один раз запусти обидві схеми в симуляторі, щоб переконатися, що все збирається.

## 5. MCP для Claude Code
- **Xcode** уже описаний у `.mcp.json`; підтверди його при першому запуску `claude` в репозиторії.
- **XcodeBuildMCP**: додай за інструкцією з його README, з телеметрією вимкненою змінною `XCODEBUILDMCP_SENTRY_DISABLED=true`.
- **Figma** (для одноразового вивантаження дизайну):
  ```bash
  claude mcp add --transport http figma https://mcp.figma.com/mcp
  ```
  Потім у Claude Code `/mcp` → figma → авторизація.

## 6. Spec Kit
```bash
specify init --here --ai claude
```
Якщо спитає про непорожню папку — погоджуйся: файли пакета він не перезаписує, лише додає `.specify/` і команди `/speckit.*`.

## 7. Перша сесія Claude Code
Запусти `claude` у корені репозиторію і встав промпт нижче.

```text
You are the implementation agent for Tennis Beat. Read CLAUDE.md, docs/product/plan.md,
docs/constitution-input.md, docs/glossary.md and docs/harness.md first.

Bootstrap task — work in a git worktree on branch chore/bootstrap:

1. Run /speckit.constitution using docs/constitution-input.md as the input.
2. Xcode project (already created from the template): set minimum iOS 26 and watchOS 26;
   add the HealthKit capability to both targets and the Workout Processing background mode
   to the watch target; add NSHealthShareUsageDescription and NSHealthUpdateUsageDescription
   with EN/PL/UK texts via String Catalog (InfoPlist.xcstrings); set
   ITSAppUsesNonExemptEncryption = NO. Build both schemes for simulators via XcodeBuildMCP.
3. Create the local Swift package Packages/TennisCore (Swift 6) with an empty public module and
   one placeholder test; link it to both app targets. `swift test --package-path Packages/TennisCore`
   must pass.
4. Fill docs/rules/itf-notes.md from the current official ITF Rules of Tennis PDF on itftennis.com:
   record edition and URL, paraphrase (no long quotes), give every entry a stable ID and the rule
   or appendix reference. Where the source is silent (e.g. 8-game pro set, break point
   definition), say so explicitly. Keep Status: Draft.
5. Export the design from Figma file A1oDA98m8ErPUKbIwN465y using ONLY the use_figma tool
   (write tools are exempt from limits; read tools are capped at 6 calls/month on this plan):
   variables -> docs/design/tokens.json; text styles -> docs/design/typography.md (include the
   production SF font from each style description); every frame on the Screens page ->
   PNG in docs/design/screens/ plus a markdown spec per screen (layout, components, texts).
6. CI: pin .github/workflows/ci.yml to a macOS runner image with Xcode 26 and add simulator
   builds of both app schemes.
7. Run the reviewer subagent, then open a PR "chore: bootstrap harness" with the
   Reviewed-SHA line, a summary, and a list of what Denys must verify manually. Do not merge.
```

## 8. Після злиття першого PR — налаштування GitHub
- Settings → Rules → Rulesets → новий для `main`: тільки через PR, обов'язковий статус `engine-tests`, 0 обов'язкових апрувів, заборона force push і видалення.
- Settings → Code security: перевір, що увімкнені secret scanning, push protection і Dependabot alerts.
- Settings → Emails у профілі GitHub: «Keep my email addresses private» і «Block command line pushes that expose my email».

## 9. Друга сесія: перший spec
```text
/speckit.specify Scoring engine in Packages/TennisCore. A match is an ordered list of Codable
events (point won by me/opponent, plus setup: format, first server). Match state is a pure
reduction of events. Formats: singles; 1 set or best of 3; set length 4, 6 or 8 games;
Advantage or No-Ad; tie-break at N–N; optional match tie-break to 10 instead of the deciding
set. The state exposes: point display per player, games and sets, server, serving side
(deuce/ad), tie-break flags, change-of-ends events, set and match winner. Undo removes the
last event and must work across game/set boundaries and after the match ends. Derived stats:
points won on serve and on return, service games held, break points converted and saved.
Every rule must reference docs/rules/itf-notes.md. No UI, HealthKit or persistence code.
```
Потім ти читаєш spec, правиш, ставиш `Status: Approved`, і далі `/speckit.plan` → `/speckit.tasks` → `/speckit.analyze` → `/speckit.implement`.
