# Android AI — Claude Plugin Marketplace

This repository is a **Claude Code plugin marketplace** for expert-level Android development.
It provides agents, skills, and hooks that encode the best practices from Google, JetBrains,
and the Slack Compose rules into every interaction.

## Quick Start

### Claude Code
```bash
@android-architect "Design the data layer for offline-first sync"  # Architecture decisions
/new-feature UserProfile screen with MVVM                          # Scaffold a full feature
/gradle optimize                                                   # Build system
/adb logcat com.example.app                                        # Device debugging
/figma-verify https://www.figma.com/file/ABC123?node-id=42:100    # Design system
```

### GitHub Copilot
```bash
# In Copilot Chat — paste the skill content as a prompt or reference the rules file directly:
@workspace /new-feature UserProfile screen with MVVM
@workspace /code-review src/feature/home/
@workspace /architecture-audit
@workspace /write-tests HomeViewModel
```

### Cursor
```bash
# Rules auto-loaded from .cursor/rules/ — just chat naturally:
Add a new UserProfile feature following MVVM Clean Architecture
Review HomeScreen.kt for Compose correctness
Audit the project for architecture violations
```

### Codex CLI
```bash
codex "Scaffold a UserProfile feature with MVVM and Clean Architecture per AGENTS.md"
codex "Review HomeViewModel.kt for coroutine and architecture issues"
codex "Write unit tests for UserProfileViewModel using JUnit5 and Turbine"
```

> See [agents.md](agents.md) for the full agent index used by Codex CLI.

### Gemini CLI / AI Studio
```bash
# Reference the skill file inline:
gemini "$(cat skills/new-feature.md)" "Scaffold a UserProfile feature"
gemini "$(cat skills/code-review.md)" "Review this file: $(cat HomeViewModel.kt)"
gemini "$(cat skills/write-tests.md)" "Write tests for UserProfileViewModel"
```

### Windsurf
```bash
# Rules auto-loaded from .windsurfrules — just chat naturally:
Create a new UserProfile feature following the project architecture
Review this PR for Android best practices
Optimise the Gradle build configuration
```

## Structure

```
skills/                       # ← source of truth for all rule content
agents/                       # ← source of truth for all sub-agents
hooks/                        # ← source of truth for lifecycle hooks
claude/                       # ← all Claude Code config consolidated here
  CLAUDE.md                   #   this file (source)
  .claude/                    #   Claude Code reads this folder
    agents -> ../../agents    #   symlink
    hooks  -> ../../hooks     #   symlink
    skills -> ../../skills    #   symlink
    settings.json
  .claude-plugin/             #   marketplace plugin definition
    marketplace.json
    plugin.json
CLAUDE.md -> claude/CLAUDE.md # root symlink — Claude Code resolves here
.claude -> claude/.claude     # root symlink — Claude Code resolves to claude/.claude/
.claude-plugin -> claude/.claude-plugin
.cursor/rules/                # auto-generated from skills/ — do not edit
.windsurfrules                # auto-generated from skills/ — do not edit
scripts/
  install.sh                  # one-liner installer per tool (--help for usage)
  sync-rules.sh               # regenerates .cursor/rules/ and .windsurfrules from skills/
agents.md                     # marketplace index (also serves as Codex AGENTS.md)
```

## Coding Standards (enforced everywhere)

- **Language**: Kotlin only — no Java in new code
- **Min SDK**: 26+ (use modern APIs freely)
- **Architecture**: MVVM + Clean Architecture (UI / Domain / Data layers)
- **DI**: Framework-agnostic — works with Hilt, Koin, Anvil, Metro, Dagger, or manual injection; patterns use constructor injection and interfaces throughout
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
