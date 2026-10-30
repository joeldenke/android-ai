# Android AI — Agent Skills for Android

Expert Android development skills, agents and hooks for **every** AI coding agent: Claude Code, Codex, GitHub Copilot, Cursor, Gemini CLI and Windsurf.
Skills use the open [Agent Skills](https://agentskills.io) format (`skills/<name>/SKILL.md`). The setup is DI-framework agnostic (Hilt, Koin, Anvil, Metro or manual) and design-system agnostic.

---

## Install

### Claude Code (plugin: skills + agents + hooks)

```
/plugin install android-ai --marketplace joeldenke/android-ai
```

On older Claude Code versions, run the same thing in two steps:

```
/plugin marketplace add joeldenke/android-ai
/plugin install android-ai@android-ai
```

### Other agents

Run from your Android project root. Re-running is safe: generated sections in existing files are replaced between markers.

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/joeldenke/android-ai/main/scripts/install.sh) <tool>
```

| `<tool>` | What you get |
|---|---|
| `cursor` | `.agents/skills/` + `.cursor/rules/` (standards always on, skills glob/agent-attached) |
| `copilot` | `.agents/skills/` + `.github/skills` link + `.github/copilot-instructions.md` |
| `codex` | `.agents/skills/` + an android-ai section in `AGENTS.md` |
| `gemini` | `.agents/skills/` + an android-ai section in `GEMINI.md` |
| `windsurf` | `.agents/skills/` + `.windsurf/rules/` + `.windsurfrules` |
| `claude` | `.claude/skills` + `.claude/agents` (fallback without hooks; prefer the plugin) |
| `all` | Everything above |

### Google tooling (optional)

```bash
install.sh mcp <claude|cursor|copilot|gemini|codex|windsurf> [servers]   # MCP servers from mcp/servers.json
install.sh google-skills                                                  # expose Google's official Android skills to every agent
```

| MCP server | What it gives the agent |
|---|---|
| `google-developer-knowledge` | Search of current docs on developer.android.com, firebase.google.com and cloud docs (needs `GOOGLE_DEVELOPER_KNOWLEDGE_API_KEY`) |
| `firebase` | Crashlytics, Remote Config, App Distribution, Firestore, Auth… (uses `firebase login`) |
| `gcloud`, `gcp-observability` | Google Cloud CLI and logs/metrics/traces (uses gcloud ADC) |

Google's official Android skills (AGP 9 upgrade, edge-to-edge, Navigation 3, R8 analyzer, XML→Compose…) are installed with `android skills add <name>` and live side by side with these skills. See [`skills/google-integrations`](skills/google-integrations/SKILL.md) for which one wins when they overlap.

---

## What each agent gets

| Capability | Claude Code | Codex | Copilot | Cursor | Gemini | Windsurf |
|---|:---:|:---:|:---:|:---:|:---:|:---:|
| Skills (native Agent Skills) | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ via rules |
| Always-on standards | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Specialist sub-agents | ✅ | — | — | — | — | — |
| Lifecycle hooks | ✅ | — | — | — | — | — |
| MCP servers (`install.sh mcp`) | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |

Where agents have no hooks, the same gates are enforced by Gradle tasks (`/static-analysis`) and CI (`/github-actions-android`).

---

## Skills

| Skill | What it does |
|---|---|
| `android-standards` | House rules for every task, plus a router to the right skill |
| `new-feature` | Full MVVM feature slice: screen, ViewModel, use case, repository, DI, tests |
| `compose-component` | Production Composable with preview, state hoisting and accessibility |
| `navigation` | Type-safe Navigation 2.x / Navigation 3, deep links, back stack |
| `data-layer` | Offline-first repositories, Room + migrations, DataStore, networking, WorkManager sync |
| `coroutine-flow` | Coroutine/Flow pipeline design |
| `dependency-injection` | Hilt, Koin, Anvil, Metro or manual DI setup and audit |
| `refactor-kotlin` | Modernise to idiomatic Kotlin |
| `architecture-audit` | Layer violations, coupling, module graph |
| `code-review` | Review against all rules with severities |
| `write-tests` | Unit, integration, Compose UI and screenshot tests (JUnit Jupiter, Turbine, MockK, Roborazzi) |
| `static-analysis` | ktlint + Detekt + Compose rules + Android Lint, baselines, CI gates |
| `gradle` | AGP 9 / Gradle 9: upgrades, convention plugins, configuration cache, build speed, supply chain, R8 |
| `gradle-best-practices` | Gradle's official skill: audits a build against the Gradle best practices and applies the fixes |
| `gradle-wrapper-upgrade` | Gradle's official skill: upgrades the wrapper with a pinned checksum, rolls back if the build breaks |
| `github-actions-android` | CI with `gradle/actions`, SHA-pinned actions, Firebase Test Lab |
| `release` | Signing, Play tracks, versioning, GitHub releases |
| `security` | OWASP Mobile Top 10, pinning, secrets, Play Integrity |
| `baseline-profile` | Macrobenchmark + Baseline Profiles |
| `debug-performance` | Recomposition, leaks, jank, startup |
| `performance-analyzer` | Perfetto / Android Performance Analyzer traces |
| `adb` | Device inspection, logcat, profiling |
| `android-cli` | Google's Android CLI: build, emulators, docs, skills, Journeys |
| `auto-mobile` | AI-driven QA on device via the AutoMobile MCP |
| `figma-verify` / `figma-sync` | Compare to and sync with Figma via the Figma MCP |
| `google-integrations` | Google's official skills + Developer Knowledge / Firebase / GCP MCP |

In Claude Code, invoke them as `/skill-name`. Other agents load them automatically when a task matches the description, or you can name the skill in the prompt ("use the gradle skill to upgrade AGP").

## Agents (Claude Code)

| Agent | Use when… |
|---|---|
| `@android-lead` | Multi-domain tasks; delegates to the team |
| `@android-architect` | Architecture, modules, ADRs |
| `@kotlin-expert` | Kotlin idioms and code quality |
| `@compose-expert` | Composables, state, recomposition, Slack rules |
| `@coroutine-flow-expert` | Coroutines, Flow, concurrency |
| `@testing-engineer` | Unit, integration and UI tests |

## Hooks (Claude Code)

`hooks/hooks.json` runs real scripts. See [hooks/README.md](hooks/README.md).

- **SessionStart** puts a build summary (versions, lint setup, AGP 9 red flags) into context.
- **PostToolUse** (`.kt`/`.kts` edits) runs `ktlint --format`, blocks on `!!`, `GlobalScope` and Android imports in the domain layer, and warns on other anti-patterns.
- **PreToolUse** (`git push`) runs `ktlintCheck`, `detekt` and `testDebugUnitTest`, and blocks on failure.

---

## Repository layout

```
skills/<name>/SKILL.md      ← source of truth (Agent Skills format; optional references/)
skills/gradle-*/            ← Gradle's official skills, vendored by scripts/vendor-gradle-skills.sh — do not edit
agents/                     ← Claude Code sub-agents
hooks/hooks.json + scripts/ ← Claude Code hooks
mcp/servers.json            ← canonical MCP server list (used by install.sh mcp)
.claude-plugin/             ← plugin + marketplace manifests
.claude/skills  -> ../skills   .claude/agents -> ../agents
.agents/skills  -> ../skills   (Codex, Gemini, Cursor, Copilot)
.cursor/rules/  .windsurf/rules/  .windsurfrules  .github/copilot-instructions.md  GEMINI.md
                            ← generated by scripts/sync-rules.sh — do not edit
AGENTS.md                   ← index + Codex instructions
scripts/install.sh          ← installer (--help)
scripts/sync-rules.sh       ← regenerate adapters; --check validates skills and detects drift (CI)
scripts/smoke-test.sh       ← behavioural tests for the hooks + installer (CI)
```

After editing a skill:

```bash
bash scripts/sync-rules.sh
claude plugin validate .        # if Claude Code is installed
```
