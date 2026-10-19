---
name: static-analysis
description: Sets up and enforces static analysis for Android — ktlint (formatting), Detekt (code smells) with Compose rules (io.nlopez/Slack), and Android Lint — via convention plugins with a zero-warnings policy, baselines for legacy code, .editorconfig, and CI/pre-commit wiring. Use when adding or fixing lint tooling, triaging lint failures, or creating baselines.
---

When the user runs `/static-analysis [task]`, set up or audit the static-analysis stack. Default to `audit`.

## Tasks

| Command | Action |
|---|---|
| `/static-analysis audit` | Report which tools are configured, how, and what is missing |
| `/static-analysis setup` | Add ktlint + Detekt + compose rules + Android Lint config through convention plugins |
| `/static-analysis baseline` | Create baselines for legacy code (never for new code) |
| `/static-analysis fix` | Auto-format, then fix remaining findings in changed files |

## The stack

| Tool | Catches | Runs as |
|---|---|---|
| ktlint (via `org.jlleitschuh.gradle.ktlint`) | Formatting, import order, Kotlin style | `ktlintCheck` / `ktlintFormat` |
| Detekt + `io.nlopez.compose.rules:detekt` | Complexity, naming, coroutine misuse, Compose rule violations | `detekt` |
| Android Lint | API levels, resources, manifest, a11y, security, Compose lint checks shipped with AndroidX | `lintDebug` |

ktlint owns formatting. Disable Detekt's `formatting` rule set to avoid two tools fighting over whitespace.

## Rule 1 — `.editorconfig` is the single style config

```ini
# .editorconfig (repo root)
root = true

[*]
charset = utf-8
end_of_line = lf
insert_final_newline = true
indent_style = space
indent_size = 4

[*.{kt,kts}]
ktlint_code_style = ktlint_official
max_line_length = 120
ktlint_function_naming_ignore_when_annotated_with = Composable
ij_kotlin_allow_trailing_comma = true
ij_kotlin_allow_trailing_comma_on_call_site = true

[*.{yml,yaml,json,toml}]
indent_size = 2
```

## Rule 2 — Convention plugin (applied to every module)

```kotlin
// build-logic/convention/src/main/kotlin/StaticAnalysisConventionPlugin.kt
import com.example.buildlogic.lib
import com.example.buildlogic.libs
import io.gitlab.arturbosch.detekt.Detekt
import io.gitlab.arturbosch.detekt.extensions.DetektExtension
import org.gradle.api.Plugin
import org.gradle.api.Project
import org.gradle.kotlin.dsl.apply
import org.gradle.kotlin.dsl.configure
import org.gradle.kotlin.dsl.dependencies
import org.gradle.kotlin.dsl.withType
import org.jlleitschuh.gradle.ktlint.KtlintExtension

class StaticAnalysisConventionPlugin : Plugin<Project> {
    override fun apply(target: Project) = with(target) {
        apply(plugin = "org.jlleitschuh.gradle.ktlint")
        apply(plugin = "io.gitlab.arturbosch.detekt")

        val root = isolated.rootProject.projectDirectory

        extensions.configure<KtlintExtension> {
            android.set(true)
            filter { exclude { it.file.path.contains("/build/") } }
        }

        extensions.configure<DetektExtension> {
            buildUponDefaultConfig = true
            config.setFrom(root.file("config/detekt/detekt.yml"))
            baseline = layout.projectDirectory.file("detekt-baseline.xml").asFile
            parallel = true
        }
        tasks.withType<Detekt>().configureEach {
            jvmTarget = "17"
            reports { html.required.set(true); sarif.required.set(true); xml.required.set(false) }
        }
        dependencies {
            "detektPlugins"(libs.lib("compose-rules-detekt"))
        }
    }
}
```

Add `ktlint`, `detekt` and `compose-rules-detekt` to the catalog (see [`gradle`](../gradle/SKILL.md) Rule 4), plus `compileOnly` of both Gradle plugins in `build-logic/convention`. Have the Android application and library conventions apply `convention.static.analysis`.

> Detekt 1.23.x is the current stable line. Detekt 2.0 (plugin id `dev.detekt`, package `dev.detekt.*`) improves support for new Kotlin versions. Migrate when it is stable and verify with `./gradlew detekt` on the current Kotlin version.

## Rule 3 — `config/detekt/detekt.yml` (only overrides, defaults stay on)

```yaml
formatting:
  active: false            # ktlint owns formatting

naming:
  FunctionNaming:
    ignoreAnnotated: ['Composable']
  TopLevelPropertyNaming:
    constantPattern: '[A-Z][A-Za-z0-9_]*'

complexity:
  LongParameterList:
    ignoreAnnotated: ['Composable']
    functionThreshold: 8
  LongMethod:
    ignoreAnnotated: ['Composable']

style:
  MagicNumber:
    ignorePropertyDeclaration: true
    ignoreAnnotated: ['Preview', 'Composable']
  UnusedPrivateMember:
    ignoreAnnotated: ['Preview']
  ForbiddenComment:
    active: false

coroutines:
  GlobalCoroutineUsage:
    active: true
  InjectDispatcher:
    active: true

potential-bugs:
  UnsafeCallOnNullableType:
    active: true           # the `!!` ban

Compose:
  ModifierMissing:
    active: true
  ViewModelForwarding:
    active: true
  ViewModelInjection:
    active: true
  UnstableCollections:
    active: true
  CompositionLocalAllowlist:
    active: true
    allowedCompositionLocals: LocalAppColors,LocalAppTypography,LocalAppSpacing
```

The `allowedCompositionLocals` names are the project's design-token locals. Adjust them to the real names.

## Rule 4 — Android Lint as a gate

```kotlin
// inside the Android application/library convention plugins
lint {
    warningsAsErrors = true
    abortOnError = true
    checkDependencies = true            // app module reports issues of the modules it depends on
    checkReleaseBuilds = false          // CI runs lintDebug explicitly
    baseline = file("lint-baseline.xml")
    sarifReport = true
    disable += setOf("GradleDependency", "NewerVersionAvailable", "AndroidGradlePluginVersion") // Renovate handles updates
}
```

Run Lint on the app module only (`./gradlew :app:lintDebug`) when `checkDependencies = true`. Running it per module repeats the work.

## Rule 5 — Baselines are a one-time debt ledger

```bash
./gradlew detektBaseline              # writes detekt-baseline.xml per module
./gradlew :app:updateLintBaseline     # writes lint-baseline.xml
```

- Create baselines **once**, when introducing a tool to legacy code. Never regenerate a baseline to make a new PR pass.
- A PR may shrink a baseline but must never grow it. Reviewers check the diff.
- Never add suppressions in new code without a comment saying why: `@Suppress("MagicNumber") // dp values from the design spec`.

## Rule 6 — Wire it into the workflow

| Where | Command |
|---|---|
| Locally after editing | `./gradlew ktlintFormat` then `./gradlew detekt` (the plugin's post-edit hook does a fast single-file pass) |
| Pre-push (plugin hook) | `./gradlew ktlintCheck detekt` |
| CI PR job | `./gradlew ktlintCheck detekt :app:lintDebug`, then upload SARIF to code scanning |

```yaml
# PR workflow step (see /github-actions-android for the full job with pinned SHAs)
- run: ./gradlew ktlintCheck detekt :app:lintDebug --continue
- uses: github/codeql-action/upload-sarif@<sha>  # pin to a full SHA
  if: always()
  with:
    sarif_file: build/reports/
```

## Audit output

```
## Static Analysis Report
| Tool | Configured | Version | Gate in CI | Baseline size |
|---|---|---|---|---|
| ktlint | ✅ convention | 14.2.0 (plugin) | ✅ | — |
| Detekt + compose rules | ⚠️ no compose rules | 1.23.8 | ✅ | 214 issues |
| Android Lint | ❌ warningsAsErrors=false | AGP 9.4 | ❌ | 37 issues |

### Actions
1. Add io.nlopez.compose.rules:detekt to detektPlugins
2. Enable lint { warningsAsErrors = true } and add :app:lintDebug to the PR job
```
