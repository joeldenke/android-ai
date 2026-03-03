# Android AI — Claude Plugin Marketplace

This repository is a **Claude Code plugin marketplace** for expert-level Android development.
It provides agents, skills, and hooks that encode the best practices from Google, JetBrains,
and the Slack Compose rules into every interaction.

## Quick Start

```bash
# Use an agent for architecture decisions
@android-architect "Design the data layer for offline-first sync"

# Run a skill for a new feature
/new-feature UserProfile screen with MVVM

# Let hooks enforce quality automatically on every tool use
```

## Structure

```
.claude/
  agents/               # Specialist sub-agents
    android-architect.md
    kotlin-expert.md
    compose-expert.md
    coroutine-flow-expert.md
    testing-engineer.md
  skills/               # Reusable slash commands
    new-feature.md
    compose-component.md
    code-review.md
    refactor-kotlin.md
    coroutine-flow.md
    architecture-audit.md
    debug-performance.md
    write-tests.md
  hooks/                # Lifecycle automation
    session-start.md
    post-tool-lint.md
    pre-push-check.md
agents.md               # This marketplace index
CLAUDE.md               # This file
```

## Coding Standards (enforced everywhere)

- **Language**: Kotlin only — no Java in new code
- **Min SDK**: 26+ (use modern APIs freely)
- **Architecture**: MVVM + Clean Architecture (UI / Domain / Data layers)
- **DI**: Hilt
- **Async**: Kotlin Coroutines + Flow (no RxJava, no callbacks)
- **UI**: Jetpack Compose (Material3 only — no M2 APIs)
- **Testing**: JUnit5 + Turbine + Mockk + Compose UI test
- **Lint**: ktlint + Detekt + Slack Compose rules (zero warnings policy)
- **Build**: Kotlin DSL (`build.gradle.kts`) + Version Catalogs (`libs.versions.toml`)

## Key References

- [Android Architecture](https://developer.android.com/topic/architecture)
- [Kotlin Coroutines best practices](https://developer.android.com/kotlin/coroutines/coroutines-best-practices)
- [Jetpack Compose performance](https://developer.android.com/jetpack/compose/performance)
- [Slack Compose rules](https://slackhq.github.io/compose-lints/rules/)
- [Kotlin coding conventions](https://kotlinlang.org/docs/coding-conventions.html)
