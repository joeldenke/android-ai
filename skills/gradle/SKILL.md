---
name: gradle
description: Gradle build expert for Android — AGP 9 (built-in Kotlin, new DSL), Gradle 9, Kotlin DSL, version catalogs, convention plugins in build-logic, configuration cache, build speed, dependency hygiene, supply-chain verification, R8, and test setup. Use when editing build.gradle.kts, settings.gradle.kts, gradle.properties, libs.versions.toml or build-logic, when a build is slow or failing, or when upgrading AGP/Gradle/Kotlin.
---

When the user runs `/gradle [task]`, analyse the Gradle setup and perform the requested task. Default to a full build health check if no task is specified.

## Tasks

| Command | Action |
|---|---|
| `/gradle` | Full build health check — versions, DSL, catalog, convention plugins, performance, supply chain, R8 |
| `/gradle optimize` | Diagnose and fix slow builds (configuration + execution) |
| `/gradle upgrade` | Upgrade AGP / Gradle / Kotlin / KSP together — see [references/agp9-migration.md](references/agp9-migration.md) |
| `/gradle add-dep <artifact>` | Add dependency to the version catalog + the right module/configuration |
| `/gradle new-module <name> <type>` | Scaffold a module that uses existing convention plugins |
| `/gradle convention` | Create or repair `build-logic/` — see [references/convention-plugins.md](references/convention-plugins.md) |
| `/gradle deps` | Dependency health — unused/misdeclared deps, `api` vs `implementation`, duplicates |
| `/gradle verify` | Supply-chain hardening — wrapper checksum, dependency verification, repository filtering |
| `/gradle r8 <module>` | Tune R8 keep rules for a module |
| `/gradle badging` | Add the app-badging guard — see [references/app-badging.md](references/app-badging.md) |
| `/gradle versions` | Report outdated dependencies and propose catalog updates |

## Gradle's official skills come first for audits and wrapper upgrades

Two skills from Gradle, Inc. ([gradle/gradle-skills](https://github.com/gradle/gradle-skills)) ship alongside this one, vendored unchanged by `scripts/vendor-gradle-skills.sh`. They own their tasks; this skill owns the Android side (AGP, built-in Kotlin, R8, variants, badging).

| Task | Use |
|---|---|
| Audit a build ("check my build", "best practices review"), or apply the fixes | [`gradle-best-practices`](../gradle-best-practices/SKILL.md): Gradle's 48 best practices, each finding linked to the User Manual. Run it as part of `/gradle` and merge its findings into the health report below. |
| Upgrade the Gradle wrapper | [`gradle-wrapper-upgrade`](../gradle-wrapper-upgrade/SKILL.md): pins `distributionSha256Sum`, runs `wrapper` twice, rolls back when the build no longer configures. `/gradle upgrade` uses it for the Gradle step. |

When the two disagree with this skill, the official skill is right about Gradle, and this skill is right about AGP and Android. A project's own rules (its `CLAUDE.md`/`AGENTS.md`) beat both.

---

## Step 0 — Gather facts before changing anything

Never guess versions or structure. Read them:

```bash
./gradlew --version                                  # Gradle, Kotlin DSL, JVM running the daemon
cat gradle/wrapper/gradle-wrapper.properties         # distributionUrl + distributionSha256Sum
cat gradle/libs.versions.toml                        # AGP, Kotlin, KSP, BOMs
cat settings.gradle.kts gradle.properties
ls build-logic/ buildSrc/ 2>/dev/null                # where shared build logic lives
android describe --format json 2>/dev/null           # compact project map if Android CLI is installed
./gradlew help --configuration-cache                 # does configuration even pass the CC?
```

If the [Google Developer Knowledge MCP](../google-integrations/SKILL.md) is connected, use `search_documents` to confirm current AGP/Gradle compatibility before recommending an upgrade. Release notes move faster than any skill file.

---

## Rule 1 — Version baseline (keep AGP, Gradle, Kotlin, KSP, JDK aligned)

| Component | Baseline (Oct 2026) | Notes |
|---|---|---|
| AGP | 9.4.x | 9.0 made built-in Kotlin and the new DSL the default |
| Gradle wrapper | 9.8.x (AGP 9.4 needs ≥ 9.6.0) | AGP 9.0 needs 9.1, 9.1 → 9.3.1, 9.2 → 9.4.1, 9.3 → 9.5 |
| JDK for the daemon | 17+ (21 recommended) | Pin it with daemon JVM criteria (Rule 6) |
| Kotlin (KGP) | 2.4.x | AGP 9 bundles KGP ≥ 2.2.10 and upgrades lower versions automatically |
| KSP | 2.3.x | KSP 2.3+ is versioned independently of Kotlin; AGP 9 needs ≥ 2.2.10-2.0.2 |
| compileSdk / targetSdk | Latest stable API (36 at minimum) | Google Play requires a recent `targetSdk` for new apps and updates |
| minSdk | 26 | Project standard |

Upgrade these **together** in one PR with one green CI run. Never bump AGP alone. Anything older than AGP 9 should go through [references/agp9-migration.md](references/agp9-migration.md) first.

---

## Rule 2 — `settings.gradle.kts` is the single place for repositories

```kotlin
// settings.gradle.kts
pluginManagement {
    includeBuild("build-logic")                         // convention plugins: composite build, never buildSrc
    repositories {
        google {
            content {                                   // only resolve Google artifacts from Google Maven
                includeGroupByRegex("com\\.android.*")
                includeGroupByRegex("com\\.google.*")
                includeGroupByRegex("androidx.*")
            }
        }
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("org.gradle.toolchains.foojay-resolver-convention") version "1.0.0"   // auto-provision JDK toolchains
}

dependencyResolutionManagement {
    repositoriesMode = RepositoriesMode.FAIL_ON_PROJECT_REPOS   // modules may not declare repositories
    repositories {
        google {
            content {
                includeGroupByRegex("com\\.android.*")
                includeGroupByRegex("com\\.google.*")
                includeGroupByRegex("androidx.*")
            }
        }
        mavenCentral()
    }
}

enableFeaturePreview("TYPESAFE_PROJECT_ACCESSORS")    // projects.core.data instead of project(":core:data")

rootProject.name = "MyApp"
include(":app")
include(":core:data", ":core:domain", ":core:ui")
include(":feature:home")
```

- Repository content filtering is both a speed and a security win: Gradle stops probing every repository for every artifact, and nobody can publish a look-alike `androidx.*` artifact to another repository and have it picked up.
- No `jcenter()`, no `mavenLocal()` in committed code, no `maven { url = "https://jitpack.io" }` without a `content { includeGroup(...) }` filter.

---

## Rule 3 — Module build files: Kotlin DSL, AGP 9 style, zero logic

Every build file is `build.gradle.kts`. Convert any Groovy file you find. Module build files only declare **what** the module is. **How** to configure Android lives in convention plugins.

```kotlin
// feature/home/build.gradle.kts
plugins {
    alias(libs.plugins.convention.android.feature)    // library + compose + DI + test setup
}

android {
    namespace = "com.example.feature.home"
}

dependencies {
    implementation(projects.core.domain)
    implementation(projects.core.ui)
}
```

When there is no convention plugin yet (single-module app), the AGP 9 shape is:

```kotlin
// app/build.gradle.kts
plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.compose)                // Compose compiler plugin, still applied explicitly
    alias(libs.plugins.kotlin.serialization)          // only if used
    alias(libs.plugins.ksp)                           // only if a processor needs it (Room, Hilt, Metro…)
    // NO org.jetbrains.kotlin.android: AGP 9 compiles Kotlin itself (built-in Kotlin)
}

android {
    namespace = "com.example.app"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.example.app"
        minSdk = 26
        targetSdk = 36                                // set explicitly; AGP 9 defaults it to compileSdk
        versionCode = 1
        versionName = "1.0.0"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17  // Kotlin jvmTarget follows this automatically
    }

    buildFeatures {
        compose = true
        buildConfig = true                            // only in modules that read BuildConfig
    }
}

kotlin {
    compilerOptions {                                 // replaces android { kotlinOptions { } } (removed)
        allWarningsAsErrors = providers.gradleProperty("warningsAsErrors").map(String::toBoolean).orElse(false)
    }
}

dependencies {
    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.bundles.compose)
    debugImplementation(libs.androidx.compose.ui.tooling)
}
```

Hard rules:
- `android { kotlinOptions { } }` is gone in AGP 9. Use `kotlin { compilerOptions { } }`.
- `kotlin-kapt` does not work with built-in Kotlin. Migrate to KSP. `com.android.legacy-kapt` is only a temporary bridge for processors without KSP support.
- `android.applicationVariants`, `BaseExtension`, `AppExtension` and `variantFilter` are removed. Use `androidComponents { onVariants { } / beforeVariants { } }`.
- Pure JVM modules (`:core:domain`) use `alias(libs.plugins.kotlin.jvm)` + `kotlin { jvmToolchain(17) }`. They must not apply an Android plugin.

---

## Rule 4 — Version catalog: every coordinate and version in `gradle/libs.versions.toml`

Zero hardcoded versions in build files. Use BOMs where they exist. Name aliases `group-artifact` in kebab case so accessors read naturally (`libs.androidx.room.runtime`).

```toml
# Snapshot of current stable versions (Oct 2026). Run `/gradle versions` before copying.
[versions]
agp = "9.4.0"
kotlin = "2.4.21"
ksp = "2.3.12"
androidx-compose-bom = "2026.09.00"
androidx-activity = "1.13.0"
androidx-lifecycle = "2.11.0"
androidx-navigation = "2.10.2"
androidx-navigation3 = "1.2.0"
androidx-room = "2.8.5"
androidx-datastore = "1.2.1"
androidx-work = "2.12.0"
kotlinx-coroutines = "1.11.0"
kotlinx-serialization = "1.11.0"
kotlinx-collections-immutable = "0.5.2"
okhttp = "5.5.0"
retrofit = "3.0.0"
coil = "3.6.3"
junit = "6.1.3"
turbine = "1.2.1"
mockk = "1.14.11"
detekt = "1.23.8"
compose-rules = "0.6.8"
ktlint-gradle = "14.2.0"
dependency-analysis = "3.19.2"

[libraries]
androidx-compose-bom = { module = "androidx.compose:compose-bom", version.ref = "androidx-compose-bom" }
androidx-compose-ui = { module = "androidx.compose.ui:ui" }
androidx-compose-ui-tooling = { module = "androidx.compose.ui:ui-tooling" }
androidx-compose-ui-tooling-preview = { module = "androidx.compose.ui:ui-tooling-preview" }
androidx-compose-ui-test-junit4 = { module = "androidx.compose.ui:ui-test-junit4" }
androidx-compose-ui-test-manifest = { module = "androidx.compose.ui:ui-test-manifest" }
androidx-compose-material3 = { module = "androidx.compose.material3:material3" }   # optional: design-system agnostic
androidx-activity-compose = { module = "androidx.activity:activity-compose", version.ref = "androidx-activity" }
androidx-lifecycle-runtime-compose = { module = "androidx.lifecycle:lifecycle-runtime-compose", version.ref = "androidx-lifecycle" }
androidx-lifecycle-viewmodel-compose = { module = "androidx.lifecycle:lifecycle-viewmodel-compose", version.ref = "androidx-lifecycle" }
androidx-navigation-compose = { module = "androidx.navigation:navigation-compose", version.ref = "androidx-navigation" }
androidx-navigation3-runtime = { module = "androidx.navigation3:navigation3-runtime", version.ref = "androidx-navigation3" }
androidx-navigation3-ui = { module = "androidx.navigation3:navigation3-ui", version.ref = "androidx-navigation3" }
androidx-room-runtime = { module = "androidx.room:room-runtime", version.ref = "androidx-room" }
androidx-room-compiler = { module = "androidx.room:room-compiler", version.ref = "androidx-room" }
androidx-room-testing = { module = "androidx.room:room-testing", version.ref = "androidx-room" }
androidx-datastore-preferences = { module = "androidx.datastore:datastore-preferences", version.ref = "androidx-datastore" }
androidx-work-runtime = { module = "androidx.work:work-runtime", version.ref = "androidx-work" }
kotlinx-coroutines-core = { module = "org.jetbrains.kotlinx:kotlinx-coroutines-core", version.ref = "kotlinx-coroutines" }
kotlinx-coroutines-android = { module = "org.jetbrains.kotlinx:kotlinx-coroutines-android", version.ref = "kotlinx-coroutines" }
kotlinx-coroutines-test = { module = "org.jetbrains.kotlinx:kotlinx-coroutines-test", version.ref = "kotlinx-coroutines" }
kotlinx-serialization-json = { module = "org.jetbrains.kotlinx:kotlinx-serialization-json", version.ref = "kotlinx-serialization" }
kotlinx-collections-immutable = { module = "org.jetbrains.kotlinx:kotlinx-collections-immutable", version.ref = "kotlinx-collections-immutable" }
okhttp-bom = { module = "com.squareup.okhttp3:okhttp-bom", version.ref = "okhttp" }
okhttp = { module = "com.squareup.okhttp3:okhttp" }
okhttp-logging = { module = "com.squareup.okhttp3:logging-interceptor" }
retrofit = { module = "com.squareup.retrofit2:retrofit", version.ref = "retrofit" }
retrofit-kotlinx-serialization = { module = "com.squareup.retrofit2:converter-kotlinx-serialization", version.ref = "retrofit" }
coil-compose = { module = "io.coil-kt.coil3:coil-compose", version.ref = "coil" }
junit-bom = { module = "org.junit:junit-bom", version.ref = "junit" }
junit-jupiter = { module = "org.junit.jupiter:junit-jupiter" }
junit-platform-launcher = { module = "org.junit.platform:junit-platform-launcher" }
turbine = { module = "app.cash.turbine:turbine", version.ref = "turbine" }
mockk = { module = "io.mockk:mockk", version.ref = "mockk" }
mockk-android = { module = "io.mockk:mockk-android", version.ref = "mockk" }
compose-rules-detekt = { module = "io.nlopez.compose.rules:detekt", version.ref = "compose-rules" }

# Build-logic only (compileOnly in build-logic/convention)
android-gradlePlugin = { module = "com.android.tools.build:gradle", version.ref = "agp" }
kotlin-gradlePlugin = { module = "org.jetbrains.kotlin:kotlin-gradle-plugin", version.ref = "kotlin" }
compose-gradlePlugin = { module = "org.jetbrains.kotlin:compose-compiler-gradle-plugin", version.ref = "kotlin" }
ksp-gradlePlugin = { module = "com.google.devtools.ksp:com.google.devtools.ksp.gradle.plugin", version.ref = "ksp" }

[bundles]
compose = ["androidx-compose-ui", "androidx-compose-ui-tooling-preview", "androidx-activity-compose", "androidx-lifecycle-runtime-compose", "androidx-lifecycle-viewmodel-compose"]
unit-test = ["junit-jupiter", "turbine", "mockk", "kotlinx-coroutines-test"]

[plugins]
android-application = { id = "com.android.application", version.ref = "agp" }
android-library = { id = "com.android.library", version.ref = "agp" }
android-test = { id = "com.android.test", version.ref = "agp" }
kotlin-jvm = { id = "org.jetbrains.kotlin.jvm", version.ref = "kotlin" }
kotlin-compose = { id = "org.jetbrains.kotlin.plugin.compose", version.ref = "kotlin" }
kotlin-serialization = { id = "org.jetbrains.kotlin.plugin.serialization", version.ref = "kotlin" }
kotlin-parcelize = { id = "org.jetbrains.kotlin.plugin.parcelize", version.ref = "kotlin" }
ksp = { id = "com.google.devtools.ksp", version.ref = "ksp" }
room = { id = "androidx.room", version.ref = "androidx-room" }
detekt = { id = "io.gitlab.arturbosch.detekt", version.ref = "detekt" }
ktlint = { id = "org.jlleitschuh.gradle.ktlint", version.ref = "ktlint-gradle" }
dependency-analysis = { id = "com.autonomousapps.dependency-analysis", version.ref = "dependency-analysis" }

# Convention plugins (no version: provided by the included build-logic build)
convention-android-application = { id = "convention.android.application" }
convention-android-library = { id = "convention.android.library" }
convention-android-compose = { id = "convention.android.compose" }
convention-android-feature = { id = "convention.android.feature" }
convention-jvm-library = { id = "convention.jvm.library" }
```

DI plugins and libraries (Hilt, Koin, Anvil, Metro…) are added for the framework the project actually uses. See [`/dependency-injection`](../dependency-injection/SKILL.md). Never add more than one.

**Updates:** automate them with Renovate or Dependabot, both of which understand `libs.versions.toml`. Group AGP + Gradle + Kotlin + KSP into one update PR. Never use dynamic versions (`1.+`, `latest.release`), because they break reproducibility and the build cache.

---

## Rule 5 — Convention plugins in `build-logic/` (composite build)

Shared configuration lives in `build-logic/convention`. Feature modules apply **one** plugin. The full, AGP 9-compatible implementation is in [references/convention-plugins.md](references/convention-plugins.md).

- Use `includeBuild("build-logic")` inside `pluginManagement`, not `buildSrc`. A `buildSrc` change invalidates every module's configuration.
- Never configure other projects from the root build file: no `allprojects {}`, no `subprojects {}`. It breaks configuration-cache reuse and project isolation.
- Declare every plugin used by convention plugins in the root `build.gradle.kts` with `apply false` so all modules share one classloader:

```kotlin
// build.gradle.kts (root)
plugins {
    alias(libs.plugins.android.application) apply false
    alias(libs.plugins.android.library) apply false
    alias(libs.plugins.kotlin.jvm) apply false
    alias(libs.plugins.kotlin.compose) apply false
    alias(libs.plugins.kotlin.serialization) apply false
    alias(libs.plugins.ksp) apply false
    alias(libs.plugins.dependency.analysis)
}
```

---

## Rule 6 — `gradle.properties`, JDK and build speed

```properties
# gradle.properties
org.gradle.jvmargs=-Xmx4g -XX:MaxMetaspaceSize=1g -XX:+UseParallelGC -Dfile.encoding=UTF-8
org.gradle.parallel=true
org.gradle.caching=true
org.gradle.configuration-cache=true
org.gradle.configuration-cache.parallel=true
# Keep the default (fail). Never set configuration-cache.problems=warn permanently, because it hides regressions.

kotlin.daemon.jvmargs=-Xmx2g
kotlin.code.style=official
```

Delete properties that are now defaults or obsolete: `android.useAndroidX`, `android.enableJetifier` (remove after `./gradlew checkJetifier` passes), `android.nonTransitiveRClass`, `android.nonFinalResIds`, `android.enableR8.fullMode`, `kapt.*`, `kotlin.incremental*`. Do not set `android.builtInKotlin=false` or `android.newDsl=false` except as a temporary migration step. Both opt-outs disappear in AGP 10.

**Pin the daemon JDK** so every machine and CI runner builds with the same JVM:

```bash
./gradlew updateDaemonJvm --jvm-version=21   # writes gradle/gradle-daemon-jvm.properties, commit it
```

**Diagnose before optimising:**

```bash
./gradlew :app:assembleDebug --scan                    # free Build Scan (scans.gradle.com) or your Develocity server
./gradlew :app:assembleDebug --profile                 # offline HTML report in build/reports/profile/
./gradlew help --configuration-cache                   # configuration-time problems only
./gradlew :app:assembleDebug --dry-run                 # which tasks are scheduled
./gradlew :app:dependencies --configuration releaseRuntimeClasspath
```

| Symptom | Likely cause | Fix |
|---|---|---|
| Slow even with no changes | Configuration phase: eager task creation, `allprojects`, heavy `buildSrc` | Configuration cache; lazy APIs (Rule 7); move to `build-logic` |
| "Configuration cache entry discarded" | Build logic reads files/env/system properties eagerly | `providers.gradleProperty()`, `providers.environmentVariable()`, `ValueSource` |
| Everything recompiles after a small change | ABI change in a widely used module, `api` overuse | `implementation` by default; split `:core:*`; avoid `BuildConfig` in core modules |
| KAPT dominates | Annotation processing through KAPT stubs | KSP (Room, Hilt, Moshi, Metro all support it) |
| Low cache hit rate in CI | Non-relocatable inputs (absolute paths), timestamps in outputs | Build Scan → "Build cache" tab; `@PathSensitive(RELATIVE)` on custom task inputs |
| Too many variants | Flavors × build types never built | `androidComponents.beforeVariants { it.enable = … }` |

---

## Rule 7 — Writing build logic that survives Gradle 9 and project isolation

```kotlin
// ✅ Lazy: the task is only created if something needs it
tasks.register<Copy>("copyMappings") { … }
tasks.withType<Test>().configureEach { useJUnitPlatform() }
tasks.named("check") { dependsOn("detekt") }

// ❌ Eager: realises every task during configuration
tasks.create("copyMappings") { … }
tasks.withType<Test> { useJUnitPlatform() }          // without configureEach
tasks.getByName("check").dependsOn("detekt")
```

- Custom tasks are abstract classes with `Property`/`RegularFileProperty`/`DirectoryProperty` inputs, explicit `@Input`/`@InputFile(s)`/`@OutputFile`/`@OutputDirectory`, `@PathSensitive` on file inputs, and `@CacheableTask` when outputs are deterministic.
- Never touch `project` inside `@TaskAction`. `Project.exec` and `Project.javaexec` are removed in Gradle 9, so inject `ExecOperations`, `FileSystemOperations` or `ArchiveOperations` instead.
- Wire outputs to inputs with providers (`taskA.flatMap { it.outputFile }`), not with `dependsOn` and hardcoded paths.
- Read external state through `providers.*`, never `System.getenv()` or `File.readText()` at configuration time.
- Don't access another project's model (`rootProject.extensions`, `project(":x").tasks`). For root-level files use `isolated.rootProject.projectDirectory`.
- Verify with `./gradlew help --configuration-cache` and, for future-proofing, `-Dorg.gradle.unsafe.isolated-projects=true`.

---

## Rule 8 — Dependency hygiene

- **`implementation` by default.** Use `api` only when a type from the dependency appears in the module's public API.
- **KSP over KAPT**, always. Use `ksp(libs.androidx.room.compiler)` together with the Room Gradle plugin (`room { schemaDirectory("$projectDir/schemas") }`) so schemas are exported and migrations are testable.
- **BOMs** for Compose, OkHttp, Firebase and JUnit: `implementation(platform(libs.androidx.compose.bom))`, plus `androidTestImplementation(platform(...))` when instrumented tests use Compose.
- **No feature → feature dependencies.** Features depend on `:core:*` only, and navigation connects them in `:app`.
- **Find dead and misdeclared dependencies** with the Dependency Analysis Gradle Plugin:

```bash
./gradlew buildHealth                    # report: unused, used-transitively, wrong configuration
./gradlew :feature:home:fixDependencies  # apply the advice to one module
```

- **Resolve conflicts explicitly.** Inspect them with `./gradlew :app:dependencyInsight --dependency okhttp --configuration releaseRuntimeClasspath`, then fix them with a BOM or a `constraints { }` block, not `force`.

---

## Rule 9 — Supply chain: wrapper, verification, provenance

```properties
# gradle/wrapper/gradle-wrapper.properties
distributionUrl=https\://services.gradle.org/distributions/gradle-9.8.1-bin.zip
distributionSha256Sum=<sha256 from https://gradle.org/release-checksums/>
```

```bash
# Upgrade the wrapper the supported way (updates jar, scripts and checksum)
./gradlew wrapper --gradle-version 9.8.1 --gradle-distribution-sha256-sum <sha256>

# Dependency verification: checksums for every resolved artifact
./gradlew --write-verification-metadata sha256 help assembleDebug testDebugUnitTest
git add gradle/verification-metadata.xml
```

- Commit `gradle/verification-metadata.xml`. Dependency update PRs must update it, and a reviewer can see exactly which artifacts changed.
- `gradle/actions/setup-gradle` validates the wrapper JAR in CI. See [`/github-actions-android`](../github-actions-android/SKILL.md).
- Keep repository content filters from Rule 2.

---

## Rule 10 — R8 under AGP 9

```kotlin
buildTypes {
    release {
        isMinifyEnabled = true
        isShrinkResources = true
        proguardFiles(
            getDefaultProguardFile("proguard-android-optimize.txt"),  // proguard-android.txt is disallowed in AGP 9
            "proguard-rules.pro",
        )
    }
}
```

AGP 9 behaviour changes that break old rule files:
- Full mode is the default. Strict full-mode keep rules mean `-keep class A` **no longer keeps the default constructor**, so write `-keep class A { <init>(); }`.
- Keep rules no longer apply to companion-object methods implicitly.
- Library consumer rules may not contain global options (`-dontoptimize`, `-dontobfuscate`, `-dontshrink`). Publishing fails if they do.
- Resource shrinking always runs inside R8 with precise shrinking.
- Missing `proguardFiles` now fail the build (`android.proguard.failOnMissingFiles`).

Prefer libraries that ship their own consumer rules (Retrofit, OkHttp, kotlinx.serialization, Room, Hilt and Koin all do) over hand-written `-keep class com.lib.** { *; }`. Broad keeps disable shrinking for the whole library. For an audit, use Google's official `r8-analyzer` skill if it is installed (see [`/google-integrations`](../google-integrations/SKILL.md)), or `/gradle r8`.

---

## Rule 11 — Test setup

```kotlin
// in the Android convention plugin (unit tests on the JVM)
dependencies {
    "testImplementation"(platform(libs.findLibrary("junit-bom").get()))
    "testImplementation"(libs.findBundle("unit-test").get())
    "testRuntimeOnly"(libs.findLibrary("junit-platform-launcher").get())   // required since Gradle 9
}
tasks.withType<Test>().configureEach {
    useJUnitPlatform()
    maxParallelForks = (Runtime.getRuntime().availableProcessors() / 2).coerceAtLeast(1)
}
```

- AGP 9 creates unit-test tasks only for the tested build type (debug by default). Run `testDebugUnitTest`, not `test`, in CI.
- Use Gradle Managed Devices (`testOptions.managedDevices`) for reproducible instrumented tests in CI instead of hand-rolled emulator scripts.
- Screenshot tests (Roborazzi or Compose Preview Screenshot Testing) run as JVM tests and belong in the unit-test convention.

---

## Rule 12 — Variants and flavours

```kotlin
android {
    flavorDimensions += "environment"
    productFlavors {
        create("dev") { dimension = "environment"; applicationIdSuffix = ".dev"; versionNameSuffix = "-dev" }
        create("prod") { dimension = "environment" }
    }
}

androidComponents {
    beforeVariants { variant ->
        // never build devRelease: it is not shipped and doubles CI time
        if (variant.buildType == "release" && variant.productFlavors.contains("environment" to "dev")) {
            variant.enable = false
        }
    }
}
```

- Keep environment values (base URLs) in `buildConfigField` or resources per flavour. **Secrets never go in Gradle files or `BuildConfig`**; see [`/security`](../security/SKILL.md).
- `resValues` and `buildConfig` are off by default in AGP 9. Enable them per module, only where used.

---

## Rule 13 — App badging guard

A dependency update can silently add `<uses-feature android:required="true">` and remove the app from tablets, Chromebooks, TVs or cars. A golden `badging.txt` diffed in CI catches this. The config-cache-safe implementation is in [references/app-badging.md](references/app-badging.md).

---

## Anti-patterns to flag

| Anti-pattern | Severity | Fix |
|---|---|---|
| Groovy `build.gradle` | 🔴 | Convert to `.kts` |
| Hardcoded version in a build file | 🔴 | Move to `libs.versions.toml` |
| `org.jetbrains.kotlin.android` applied with AGP 9 | 🔴 | Remove; built-in Kotlin |
| `kotlinOptions { }` / `kotlin-kapt` | 🔴 | `kotlin { compilerOptions { } }` / KSP |
| `allprojects { }` / `subprojects { }` | 🔴 | Convention plugins |
| `Project.exec` or `project.*` inside a task action | 🔴 | `ExecOperations`, task properties |
| Missing `distributionSha256Sum` | 🟠 | Add checksum |
| Repositories declared in modules | 🟠 | `FAIL_ON_PROJECT_REPOS` |
| `tasks.create` / `withType {}` without `configureEach` | 🟠 | Lazy API |
| `configuration-cache.problems=warn` committed | 🟠 | Fix problems, keep `fail` |
| `api` used where `implementation` suffices | 🟡 | `buildHealth` advice |
| Dynamic versions (`+`) | 🟡 | Pin |
| Stale `gradle.properties` flags | 🟡 | Delete defaults |

---

## Health check output format

```
## Gradle Build Health Report
**Project:** <name>   **Date:** <today>
**Versions:** AGP 9.4.0 · Gradle 9.8.1 · Kotlin 2.4.21 · KSP 2.3.12 · Daemon JDK 21

### Critical 🔴
- :feature:profile applies org.jetbrains.kotlin.android — fails under AGP 9 built-in Kotlin
- Hardcoded "2.11.0" in core/data/build.gradle.kts:14 — move to libs.versions.toml

### Warnings 🟠
- gradle-wrapper.properties has no distributionSha256Sum
- Root build.gradle.kts uses subprojects {} — blocks configuration-cache reuse

### Opportunities 🟡
- buildHealth: 7 unused dependencies, 3 `api` → `implementation`
- 2 build variants are never shipped — disable in beforeVariants

### Good ✅
- Configuration cache enabled and passing
- Convention plugins in build-logic/ (composite build)
```
