# Android AI — Claude Code Plugin

Expert-level Android development agents, skills, and hooks for Claude Code.

## Install

Copy the plugin into your Android project:

```bash
cd your-android-project

git clone https://github.com/joeldenke/android-ai /tmp/android-ai
cp -r /tmp/android-ai/.claude .
cp /tmp/android-ai/CLAUDE.md .
rm -rf /tmp/android-ai
```

Then open with Claude Code:

```bash
claude .
```

That's it. The agents, skills, and hooks are active automatically.

---

## Agents

Use `@agent-name` to invoke a specialist:

| Agent | Use when... |
|---|---|
| `@android-lead` | Complex tasks spanning multiple domains — delegates to the full team |
| `@android-architect` | Architecture decisions, module design, ADRs |
| `@kotlin-expert` | Kotlin idioms, code quality, language questions |
| `@compose-expert` | Composables, state, recomposition, Slack rules |
| `@coroutine-flow-expert` | Coroutines, Flow pipelines, concurrency |
| `@testing-engineer` | Unit, integration, and Compose UI tests |

## Skills

Use `/skill-name` as a slash command:

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

## Hooks

Run automatically — no setup needed:

- **session-start** — validates ktlint, Detekt, and module structure on open
- **post-tool-lint** — runs ktlint + Detekt after every file edit
- **pre-push-check** — runs full lint, tests, and build before `git push`
