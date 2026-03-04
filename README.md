# Android AI — Claude Code Plugin

Expert-level Android development agents, skills, and hooks for Claude Code.
DI-framework agnostic — works with Hilt, Koin, Anvil, Metro, or manual injection.

---

## Install

### Claude Code

Plugin marketplace — run inside Claude Code, step 1:
```
/plugin marketplace add joeldenke/android-ai/claude
```
Step 2:
```
/plugin install android-ai
```

Bash fallback — run in your terminal:
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/joeldenke/android-ai/main/scripts/install.sh) claude
```

### Other tools

Run from your Android project root:

| Tool | Command | What you get |
|---|---|---|
| **Cursor** | `bash <(curl -fsSL https://raw.githubusercontent.com/joeldenke/android-ai/main/scripts/install.sh) cursor` | `.cursor/rules/` — 15 MDC rules |
| **GitHub Copilot** | `bash <(curl -fsSL https://raw.githubusercontent.com/joeldenke/android-ai/main/scripts/install.sh) copilot` | `.github/copilot-instructions.md` |
| **Codex CLI** | `bash <(curl -fsSL https://raw.githubusercontent.com/joeldenke/android-ai/main/scripts/install.sh) codex` | `AGENTS.md` |
| **Gemini CLI** | `bash <(curl -fsSL https://raw.githubusercontent.com/joeldenke/android-ai/main/scripts/install.sh) gemini` | `skills/` |
| **Windsurf** | `bash <(curl -fsSL https://raw.githubusercontent.com/joeldenke/android-ai/main/scripts/install.sh) windsurf` | `.windsurfrules` |
| **All tools** | `bash <(curl -fsSL https://raw.githubusercontent.com/joeldenke/android-ai/main/scripts/install.sh) all` | Everything above |

> Run `install.sh --help` for the full capability matrix.

---

## What Each Tool Gets

| Capability | Claude Code | Cursor | Copilot | Codex | Gemini | Windsurf |
|---|:---:|:---:|:---:|:---:|:---:|:---:|
| Skills (slash commands / rules) | ✅ | ✅ | ✅ | — | ✅ | ✅ |
| Agents (specialist delegation) | ✅ | — | — | ✅ | — | — |
| Hooks (lifecycle automation) | ✅ | — | — | — | — | — |

---

## Structure

```
agents/               ← source of truth — edit these
skills/               ← source of truth — edit these
hooks/                ← source of truth — edit these
.claude/              ← Claude Code local config (plugin root = repo root)
  agents  -> ../agents
  skills  -> ../skills
  hooks   -> ../hooks
  settings.json
.claude-plugin/       ← Claude Code marketplace metadata
  marketplace.json
  plugin.json
.cursor/
  rules/              (Cursor MDC rules — auto-generated from skills/, do not edit)
.windsurfrules        (auto-generated — do not edit)
CLAUDE.md             (Claude Code instructions)
AGENTS.md             (marketplace index / Codex AGENTS.md)
scripts/
  install.sh          (one-liner installer — run with --help for usage)
  sync-rules.sh       (regenerates .cursor/rules/ and .windsurfrules from skills/)
```

**`skills/` is the single source of truth.** After updating a skill, regenerate the tool adapters:

```bash
bash scripts/sync-rules.sh
git add .cursor/rules/ .windsurfrules
git commit -m "chore: sync tool adapters"
```

---

## Quick Start

### Claude Code
```bash
@android-architect "Design the data layer for offline-first sync"
/new-feature UserProfile screen with MVVM
/gradle optimize
/adb logcat com.example.app
/figma-verify https://www.figma.com/file/ABC123?node-id=42:100
```

### GitHub Copilot
```bash
@workspace /new-feature UserProfile screen with MVVM
@workspace /code-review src/feature/home/
@workspace /architecture-audit
@workspace /write-tests HomeViewModel
```

### Cursor
```
# Rules auto-loaded from .cursor/rules/ — just chat naturally
Add a new UserProfile feature following MVVM Clean Architecture
```

### Codex CLI
```bash
codex "Scaffold a UserProfile feature with MVVM and Clean Architecture per AGENTS.md"
codex "Write unit tests for UserProfileViewModel using JUnit5 and Turbine"
```

### Gemini CLI
```bash
gemini "$(cat skills/new-feature.md)" "Scaffold a UserProfile feature"
gemini "$(cat skills/code-review.md)" "Review this file: $(cat HomeViewModel.kt)"
```

### Windsurf
```
# Rules auto-loaded from .windsurfrules — just chat naturally
Create a new UserProfile feature following the project architecture
```

---

## Agents

Use `@agent-name` to invoke a specialist (Claude Code only):

| Agent | Use when... |
|---|---|
| `@android-lead` | Complex tasks spanning multiple domains — delegates to the full team |
| `@android-architect` | Architecture decisions, module design, ADRs |
| `@kotlin-expert` | Kotlin idioms, code quality, language questions |
| `@compose-expert` | Composables, state, recomposition, Slack rules |
| `@coroutine-flow-expert` | Coroutines, Flow pipelines, concurrency |
| `@testing-engineer` | Unit, integration, and Compose UI tests |

---

## Skills

Use `/skill-name` as a slash command (Claude Code), or reference `skills/<name>.md` directly (other tools):

| Command | What it does |
|---|---|
| `/new-feature <name>` | Scaffolds a full MVVM feature (screen, VM, use case, repo, DI, tests) |
| `/compose-component <name>` | Creates a Composable with preview and accessibility |
| `/code-review` | Reviews code against Android best practices |
| `/refactor-kotlin <target>` | Modernizes to idiomatic Kotlin |
| `/coroutine-flow <scenario>` | Designs a Flow/coroutine pipeline |
| `/architecture-audit` | Audits for layer violations and anti-patterns |
| `/debug-performance <area>` | Finds recomposition, memory, or jank issues |
| `/write-tests <target>` | Generates unit + integration + UI tests |
| `/gradle [task]` | Build health check, optimize, manage deps, R8 |
| `/github-actions-android [task]` | PR check, release, Firebase Test Lab |
| `/adb [task]` | Device inspection, logcat, performance profiling |
| `/auto-mobile [task]` | AI-driven bug reproduction and UX verification |
| `/figma-verify [url]` | Compare implementation against Figma designs |
| `/figma-sync [task]` | Push screenshots to Figma, sync tokens |

---

## Hooks

Run automatically in Claude Code — no setup needed:

- **session-start** — validates ktlint, Detekt, and module structure on open
- **post-tool-lint** — runs ktlint + Detekt after every file edit
- **pre-push-check** — runs full lint, tests, and build before `git push`
