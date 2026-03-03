# Android AI — Claude Code Plugin Marketplace

Expert-level Android development agents, skills, and hooks for Claude Code.
Encodes best practices from Google, JetBrains, and the Slack Compose rules into every interaction.

---

## Installation

### Option 1 — Clone into your Android project (recommended)

Copy the `.claude/` folder from this repo into the root of your Android project:

```bash
# From your Android project root
git clone https://github.com/joeldenke/android-ai /tmp/android-ai
cp -r /tmp/android-ai/.claude .
cp /tmp/android-ai/CLAUDE.md .
rm -rf /tmp/android-ai
```

Then open the project in Claude Code:

```bash
claude .
```

### Option 2 — Clone as a standalone Claude Code project

```bash
git clone https://github.com/joeldenke/android-ai
cd android-ai
claude .
```

### Option 3 — Global install (available in all projects)

Copy the agents and skills into your global Claude config:

```bash
git clone https://github.com/joeldenke/android-ai /tmp/android-ai
mkdir -p ~/.claude/agents ~/.claude/skills
cp /tmp/android-ai/.claude/agents/* ~/.claude/agents/
cp /tmp/android-ai/.claude/skills/* ~/.claude/skills/
rm -rf /tmp/android-ai
```

> **Note:** Hooks and `settings.json` are project-specific — install those per-project only.

---

## What's Included

```
.claude/
  agents/                    # Specialist sub-agents (@agent-name)
    android-lead.md          # Principal Engineer — orchestrates the team
    android-architect.md     # Clean Architecture, ADRs, module graphs
    kotlin-expert.md         # Kotlin idioms, nullability, scope functions
    compose-expert.md        # Jetpack Compose, Slack rules, Material3
    coroutine-flow-expert.md # Structured concurrency, Flow operators
    testing-engineer.md      # JUnit5, Turbine, Mockk, Compose UI tests
  skills/                    # Slash commands (/skill-name)
    new-feature.md
    compose-component.md
    code-review.md
    refactor-kotlin.md
    coroutine-flow.md
    architecture-audit.md
    debug-performance.md
    write-tests.md
  hooks/                     # Lifecycle automation
    session-start.md
    post-tool-lint.md
    pre-push-check.md
  settings.json              # SubagentStart/Stop hooks + permissions
CLAUDE.md                    # Project coding standards (auto-loaded)
```

---

## Usage

### Agents

Invoke a specialist directly with `@agent-name`:

```
@android-lead Build the complete UserProfile feature with MVVM
@android-architect Design the data layer for offline-first sync
@kotlin-expert Is this idiomatic Kotlin?
@compose-expert Fix this recomposition issue
@coroutine-flow-expert Design a search Flow with debounce and cancellation
@testing-engineer Write full test suite for this ViewModel
```

The `@android-lead` agent coordinates the full team — it spawns the right specialists
in the right order and synthesizes their output into a unified implementation plan.

### Agent Team Topology

```
@android-lead  (coordinator, Opus)
├── @android-architect       — architecture, ADRs, module graphs
├── @kotlin-expert           — Kotlin idioms, language features
├── @compose-expert          — Compose UI, Slack rules, recomposition
├── @coroutine-flow-expert   — async, Flow pipelines, concurrency
└── @testing-engineer        — unit, integration, and UI tests
```

### Skills (slash commands)

| Command | What it does |
|---|---|
| `/new-feature <name>` | Scaffolds a full MVVM feature (screen, VM, use case, repo, DI, tests) |
| `/compose-component <name>` | Creates a production-ready Composable with preview and accessibility |
| `/code-review [file or PR]` | Deep review against all Android best-practice rules |
| `/refactor-kotlin <target>` | Modernizes code to idiomatic Kotlin |
| `/coroutine-flow <scenario>` | Designs the optimal Flow/coroutine pipeline |
| `/architecture-audit` | Audits project for layer violations, coupling, and anti-patterns |
| `/debug-performance <area>` | Identifies recomposition, memory, startup, or jank issues |
| `/write-tests <target>` | Generates comprehensive unit + integration + UI test suite |

### Hooks (automatic)

| Hook | Trigger | Action |
|---|---|---|
| `session-start` | Claude Code session opens | Validates ktlint, Detekt, module structure |
| `post-tool-lint` | After every file edit | Runs ktlint format + Detekt on changed file |
| `pre-push-check` | Before `git push` | Full lint, test, and build validation |

---

## Coding Standards

All agents and skills enforce these standards automatically:

| Concern | Standard |
|---|---|
| Language | Kotlin only — no Java in new code |
| Min SDK | 26+ |
| Architecture | MVVM + Clean Architecture (UI / Domain / Data) |
| DI | Hilt |
| Async | Kotlin Coroutines + Flow (no RxJava, no callbacks) |
| UI | Jetpack Compose + Material3 only |
| Testing | JUnit5 + Turbine + Mockk + Compose UI test |
| Lint | ktlint + Detekt + Slack Compose rules (zero warnings) |
| Build | Kotlin DSL + Version Catalogs |

---

## Requirements

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI installed
- An Anthropic API key (Opus access recommended for `@android-lead`)
