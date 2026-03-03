# Android AI — Claude Plugin Marketplace

This repository is a **Claude Code plugin marketplace** for expert-level Android development.
It provides agents, skills, and hooks that encode the best practices from Google, JetBrains,
and the Slack Compose rules into every interaction.

## Quick Start

```bash
# Architecture decisions
@android-architect "Design the data layer for offline-first sync"

# Scaffold a full feature
/new-feature UserProfile screen with MVVM

# Build system
/gradle optimize
/github-actions-android pr-check

# Device debugging
/adb logcat com.example.app
/auto-mobile reproduce "NullPointerException in CheckoutViewModel on empty cart"

# Design system
/figma-verify https://www.figma.com/file/ABC123?node-id=42:100
/figma-sync screen ProfileScreen

# Quality hooks run automatically on every file edit and git push
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
    # Code & Architecture
    new-feature.md
    compose-component.md
    code-review.md
    refactor-kotlin.md
    coroutine-flow.md
    architecture-audit.md
    debug-performance.md
    write-tests.md
    # Build & CI/CD
    gradle.md
    github-actions-android.md
    # Device & QA
    adb.md
    auto-mobile.md
    # Design System
    figma-verify.md
    figma-sync.md
  hooks/                # Lifecycle automation
    session-start.md
    post-tool-lint.md
    pre-push-check.md
agents.md               # Marketplace index
CLAUDE.md               # This file
```

## Coding Standards (enforced everywhere)

- **Language**: Kotlin only — no Java in new code
- **Min SDK**: 26+ (use modern APIs freely)
- **Architecture**: MVVM + Clean Architecture (UI / Domain / Data layers)
- **DI**: Hilt
- **Async**: Kotlin Coroutines + Flow (no RxJava, no callbacks)
- **UI**: Jetpack Compose — design-system-agnostic token model (Material3 optional, not required)
- **Design tokens**: `@Immutable` data classes + `CompositionLocal` — components never read raw values
- **Testing**: JUnit5 + Turbine + Mockk + Compose UI test
- **Lint**: ktlint + Detekt + Slack Compose rules (zero warnings policy)
- **Build**: Kotlin DSL (`build.gradle.kts`) + Version Catalogs (`libs.versions.toml`) + convention plugins
- **CI**: `gradle/actions/setup-gradle` with SHA-pinned actions; config cache encryption

## Key References

- [Android Architecture](https://developer.android.com/topic/architecture)
- [Kotlin Coroutines best practices](https://developer.android.com/kotlin/coroutines/coroutines-best-practices)
- [Jetpack Compose performance](https://developer.android.com/jetpack/compose/performance)
- [Slack Compose rules](https://slackhq.github.io/compose-lints/rules/)
- [Kotlin coding conventions](https://kotlinlang.org/docs/coding-conventions.html)
- [AutoMobile — AI-driven device control](https://kaeawc.github.io/auto-mobile/)
- [Android MCP SDK](https://kaeawc.github.io/android-mcp-sdk/)
- [Figma MCP server](https://help.figma.com/hc/en-us/articles/32132100833559)
- [gradle/actions — official Gradle GHA](https://github.com/gradle/actions)
