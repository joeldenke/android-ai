---
name: gradle
description: Gradle build system expert for Android — Kotlin DSL, Version Catalogs, build optimization, R8/ProGuard, dependency management, and multi-module build configuration.
---

When the user runs `/gradle [task]`, analyse the Gradle setup and perform the requested task. Default to a full build health check if no task is specified.

## Tasks

| Command | Action |
|---|---|
| `/gradle` | Full build health check — DSL, catalog, performance, R8 |
| `/gradle optimize` | Diagnose and fix slow builds |
| `/gradle add-dep <artifact>` | Add dependency to version catalog + module |
| `/gradle new-module <name> <type>` | Scaffold convention plugin + module |
| `/gradle r8 <module>` | Tune R8/ProGuard rules for a module |
| `/gradle versions` | Check all dependencies for newer versions |
| `/gradle lint` | Configure and enforce lint with zero-warnings policy |
| `/gradle signing` | Set up signing with keystore.properties / env-var fallback |

---

## Rule 1 — Kotlin DSL Only

All build files must be `build.gradle.kts`. Convert any Groovy files found.

```kotlin
// build.gradle.kts — correct
plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.ksp)          // if your DI framework needs KSP (Hilt, Anvil, etc.)
    // alias(libs.plugins.hilt)      // Hilt — add if using Hilt
    // alias(libs.plugins.kotlin.kapt) // KAPT — only if your DI framework still requires it
}

android {
    namespace = "com.example.app"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.example.app"
        minSdk = 26
        targetSdk = 35
        versionCode = 1
        versionName = "1.0.0"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions { jvmTarget = "17" }

    buildFeatures { compose = true }
}
```

---

## Rule 2 — Version Catalogs (`libs.versions.toml`)

All versions and dependencies must live in `gradle/libs.versions.toml`. Zero hardcoded versions anywhere.

```toml
[versions]
agp                 = "8.7.0"
kotlin              = "2.1.0"
ksp                 = "2.1.0-1.0.29"
compose-bom         = "2025.01.00"
# DI — uncomment/replace the block that matches your framework:
# hilt              = "2.53"   # Hilt (Dagger)
# koin              = "4.0.0"  # Koin
# anvil             = "2.5.0"  # Anvil
coroutines          = "1.10.1"
lifecycle           = "2.9.0"
navigation          = "2.9.0"
room                = "2.7.0"
retrofit            = "2.11.0"
okhttp              = "4.12.0"
coil                = "3.0.4"
turbine             = "1.2.0"
mockk               = "1.13.14"
junit5              = "5.11.4"
detekt              = "1.23.8"
ktlint              = "12.1.2"

[libraries]
# Compose BOM — controls all compose artifact versions
compose-bom              = { group = "androidx.compose", name = "compose-bom", version.ref = "compose-bom" }
compose-ui               = { group = "androidx.compose.ui", name = "ui" }
compose-ui-tooling       = { group = "androidx.compose.ui", name = "ui-tooling" }
compose-ui-tooling-preview = { group = "androidx.compose.ui", name = "ui-tooling-preview" }
compose-material3        = { group = "androidx.compose.material3", name = "material3" }
compose-activity         = { group = "androidx.activity", name = "activity-compose", version = "1.10.0" }

# DI — add the libraries for your chosen framework:
# Hilt (Dagger)
# hilt-android             = { group = "com.google.dagger", name = "hilt-android", version.ref = "hilt" }
# hilt-compiler            = { group = "com.google.dagger", name = "hilt-android-compiler", version.ref = "hilt" }
# hilt-navigation-compose  = { group = "androidx.hilt", name = "hilt-navigation-compose", version = "1.2.0" }
# Koin
# koin-android             = { group = "io.insert-koin", name = "koin-android", version.ref = "koin" }
# koin-compose             = { group = "io.insert-koin", name = "koin-androidx-compose", version.ref = "koin" }
# Anvil / Metro / Dagger bare — add equivalent entries for your chosen framework

# Coroutines
coroutines-core          = { group = "org.jetbrains.kotlinx", name = "kotlinx-coroutines-core", version.ref = "coroutines" }
coroutines-android       = { group = "org.jetbrains.kotlinx", name = "kotlinx-coroutines-android", version.ref = "coroutines" }
coroutines-test          = { group = "org.jetbrains.kotlinx", name = "kotlinx-coroutines-test", version.ref = "coroutines" }

# Lifecycle
lifecycle-viewmodel      = { group = "androidx.lifecycle", name = "lifecycle-viewmodel-ktx", version.ref = "lifecycle" }
lifecycle-runtime        = { group = "androidx.lifecycle", name = "lifecycle-runtime-ktx", version.ref = "lifecycle" }
lifecycle-compose        = { group = "androidx.lifecycle", name = "lifecycle-runtime-compose", version.ref = "lifecycle" }

# Room
room-runtime             = { group = "androidx.room", name = "room-runtime", version.ref = "room" }
room-ktx                 = { group = "androidx.room", name = "room-ktx", version.ref = "room" }
room-compiler            = { group = "androidx.room", name = "room-compiler", version.ref = "room" }

# Network
retrofit-core            = { group = "com.squareup.retrofit2", name = "retrofit", version.ref = "retrofit" }
retrofit-kotlin-serialization = { group = "com.squareup.retrofit2", name = "converter-kotlinx-serialization", version.ref = "retrofit" }
okhttp-core              = { group = "com.squareup.okhttp3", name = "okhttp", version.ref = "okhttp" }
okhttp-logging           = { group = "com.squareup.okhttp3", name = "logging-interceptor", version.ref = "okhttp" }

# Testing
turbine                  = { group = "app.cash.turbine", name = "turbine", version.ref = "turbine" }
mockk-core               = { group = "io.mockk", name = "mockk", version.ref = "mockk" }
mockk-android            = { group = "io.mockk", name = "mockk-android", version.ref = "mockk" }
junit5-api               = { group = "org.junit.jupiter", name = "junit-jupiter-api", version.ref = "junit5" }
junit5-engine            = { group = "org.junit.jupiter", name = "junit-jupiter-engine", version.ref = "junit5" }
junit5-params            = { group = "org.junit.jupiter", name = "junit-jupiter-params", version.ref = "junit5" }

[plugins]
android-application  = { id = "com.android.application", version.ref = "agp" }
android-library      = { id = "com.android.library", version.ref = "agp" }
kotlin-android       = { id = "org.jetbrains.kotlin.android", version.ref = "kotlin" }
kotlin-compose       = { id = "org.jetbrains.kotlin.plugin.compose", version.ref = "kotlin" }
kotlin-serialization = { id = "org.jetbrains.kotlin.plugin.serialization", version.ref = "kotlin" }
ksp                  = { id = "com.google.devtools.ksp", version.ref = "ksp" }
# DI plugins — uncomment for your framework:
# hilt               = { id = "com.google.dagger.hilt.android", version.ref = "hilt" }
# anvil              = { id = "com.squareup.anvil", version.ref = "anvil" }
detekt               = { id = "io.gitlab.arturbosch.detekt", version.ref = "detekt" }
ktlint               = { id = "org.jlleitschuh.gradle.ktlint", version.ref = "ktlint" }

[bundles]
compose      = ["compose-ui", "compose-ui-tooling-preview", "compose-material3", "compose-activity", "lifecycle-compose"]
compose-debug = ["compose-ui-tooling"]
testing      = ["turbine", "mockk-core", "junit5-api", "junit5-params", "coroutines-test"]
```

---

## Rule 3 — Convention Plugins (Shared Build Logic)

Extract common configuration into `build-logic/` convention plugins. Never copy build logic across modules.

```
build-logic/
  convention/
    src/main/kotlin/
      AndroidApplicationConventionPlugin.kt
      AndroidLibraryConventionPlugin.kt
      AndroidComposeConventionPlugin.kt
      DiConventionPlugin.kt        # wraps your chosen DI framework's plugin + deps
      KtlintConventionPlugin.kt
    build.gradle.kts
```

```kotlin
// build-logic/convention/src/main/kotlin/AndroidLibraryConventionPlugin.kt
class AndroidLibraryConventionPlugin : Plugin<Project> {
    override fun apply(target: Project) {
        with(target) {
            with(pluginManager) {
                apply("com.android.library")
                apply("org.jetbrains.kotlin.android")
            }
            extensions.configure<LibraryExtension> {
                compileSdk = 35
                defaultConfig.minSdk = 26
                compileOptions {
                    sourceCompatibility = JavaVersion.VERSION_17
                    targetCompatibility = JavaVersion.VERSION_17
                }
            }
        }
    }
}

// Feature module — uses convention plugin, zero boilerplate
plugins { id("convention.android.library.compose") }
android { namespace = "com.example.feature.home" }
dependencies {
    implementation(project(":core:ui"))
    implementation(project(":core:domain"))
}
```

---

## Rule 4 — App Badging Convention Plugin (Device Availability Guard)

Package the three badging tasks into a convention plugin so any application module gets them for free. This guards against dependency updates that silently add hardware feature requirements (`android.hardware.camera`, `android.hardware.telephony`, etc.) which reduce availability across tablets, TVs, Wear OS, foldables, and cars.

```kotlin
// build-logic/convention/src/main/kotlin/AndroidApplicationBadgingConventionPlugin.kt

import com.android.build.api.artifact.SingleArtifact
import com.android.build.api.variant.ApplicationAndroidComponentsExtension
import org.gradle.api.DefaultTask
import org.gradle.api.Plugin
import org.gradle.api.Project
import org.gradle.api.file.RegularFileProperty
import org.gradle.api.provider.Property
import org.gradle.api.tasks.CacheableTask
import org.gradle.api.tasks.Exec
import org.gradle.api.tasks.Input
import org.gradle.api.tasks.InputFile
import org.gradle.api.tasks.OutputFile
import org.gradle.api.tasks.PathSensitive
import org.gradle.api.tasks.PathSensitivity
import org.gradle.api.tasks.TaskAction
import org.gradle.kotlin.dsl.register

class AndroidApplicationBadgingConventionPlugin : Plugin<Project> {
    override fun apply(target: Project) {
        val androidComponents = target.extensions
            .getByType(ApplicationAndroidComponentsExtension::class.java)

        androidComponents.onVariants { variant ->
            val variantName     = variant.name.replaceFirstChar { it.uppercaseChar() }
            val goldenFile      = target.rootDir.resolve("app/badging/${variant.name}.txt")
            val generatedFile   = target.layout.buildDirectory.file("badging/${variant.name}.txt")
            val apkArtifacts    = variant.artifacts.get(SingleArtifact.APK)

            // 1. Generate — runs aapt2 against the built universal APK
            val generate = target.tasks.register<GenerateBadgingTask>("generate${variantName}Badging") {
                apkDirectory.set(apkArtifacts)
                aapt2Executable.set(resolveAapt2(target))
                badgingOutput.set(generatedFile)
            }

            // 2. Update — copies generated → golden file (run locally, then commit)
            target.tasks.register<Copy>("update${variantName}Badging") {
                group       = "badging"
                description = "Updates app/badging/${variant.name}.txt — commit the result for code review"
                dependsOn(generate)
                from(generatedFile)
                into(goldenFile.parentFile.also { it.mkdirs() })
                rename { goldenFile.name }
            }

            // 3. Check — CI runs this; fails if generated ≠ golden
            target.tasks.register<CheckBadgingTask>("check${variantName}Badging") {
                group       = "verification"
                description = "Fails if the ${variant.name} APK's required features differ from the committed golden file"
                dependsOn(generate)
                generatedBadging.set(generatedFile)
                this.goldenBadging.set(goldenFile)
                variantNameProp.set(variant.name)
            }
        }
    }

    private fun resolveAapt2(project: Project): String {
        val android = project.extensions.getByType(
            com.android.build.gradle.AppExtension::class.java
        )
        return android.sdkDirectory
            .resolve("build-tools/${android.buildToolsVersion}/aapt2")
            .absolutePath
    }
}

@CacheableTask
abstract class GenerateBadgingTask : DefaultTask() {
    @get:InputFile
    @get:PathSensitive(PathSensitivity.NONE)
    abstract val apkDirectory: RegularFileProperty

    @get:Input
    abstract val aapt2Executable: Property<String>

    @get:OutputFile
    abstract val badgingOutput: RegularFileProperty

    @TaskAction
    fun generate() {
        val apkFile = apkDirectory.get().asFile.parentFile
            .listFiles { f -> f.extension == "apk" }
            ?.firstOrNull()
            ?: error("No APK found in ${apkDirectory.get().asFile.parentFile}")

        val output  = project.exec {
            commandLine(aapt2Executable.get(), "dump", "badging", apkFile.absolutePath)
            standardOutput = badgingOutput.get().asFile.also { it.parentFile.mkdirs() }.outputStream()
        }
        output.assertNormalExitValue()
    }
}

@CacheableTask
abstract class CheckBadgingTask : DefaultTask() {
    @get:InputFile
    @get:PathSensitive(PathSensitivity.NONE)
    abstract val generatedBadging: RegularFileProperty

    @get:InputFile
    @get:PathSensitive(PathSensitivity.NONE)
    abstract val goldenBadging: RegularFileProperty

    @get:Input
    abstract val variantNameProp: Property<String>

    @TaskAction
    fun check() {
        val generated = generatedBadging.get().asFile.readText()
        val golden    = goldenBadging.get().asFile.readText()

        if (generated != golden) {
            error(
                """
                |Badging mismatch for variant '${variantNameProp.get()}'.
                |
                |A dependency update or manifest change has altered the APK's required features.
                |This may reduce availability on tablets, TVs, Wear OS, foldables, or cars.
                |
                |Diff:
                |  generated: ${generatedBadging.get().asFile}
                |  golden:    ${goldenBadging.get().asFile}
                |
                |To review: diff app/badging/${variantNameProp.get()}.txt build/badging/${variantNameProp.get()}.txt
                |
                |If intentional: ./gradlew update${variantNameProp.get().replaceFirstChar { it.uppercaseChar() }}Badging
                |Then commit app/badging/${variantNameProp.get()}.txt and include it in your PR.
                |
                |Common culprits:
                |  android.hardware.camera required='true'      → blocks tablets, TVs
                |  android.hardware.telephony required='true'   → blocks Wi-Fi tablets
                |  android.hardware.location.gps required='true' → blocks TVs, PCs
                |
                |Override in AndroidManifest.xml if the requirement comes from a library:
                |  <uses-feature android:name="android.hardware.camera" android:required="false" />
                """.trimMargin()
            )
        }
    }
}
```

Register the plugin in `build-logic`:

```kotlin
// build-logic/convention/build.gradle.kts
gradlePlugin {
    plugins {
        register("androidApplicationBadging") {
            id                  = "convention.android.application.badging"
            implementationClass = "AndroidApplicationBadgingConventionPlugin"
        }
    }
}
```

Apply in the app module (alongside the application plugin):

```kotlin
// app/build.gradle.kts
plugins {
    id("convention.android.application")
    id("convention.android.application.badging")   // ← one line opt-in
}
```

First-time setup:

```bash
# Generate and commit the initial golden files for all variants
./gradlew updateDebugBadging updateReleaseBadging
git add app/badging/
git commit -m "chore: add initial aapt2 badging golden files"
```

CI usage (add to `checkReleaseBadging` job in `pr-check.yml`):

```bash
./gradlew checkReleaseBadging
```

---

## Rule 5 — Build Speed Optimisation

Check and apply these settings in `gradle.properties`:

```properties
# gradle.properties — CI and local
org.gradle.caching=true
org.gradle.parallel=true
org.gradle.configuration-cache=true
org.gradle.configuration-cache.problems=warn
org.gradle.jvmargs=-Xmx4g -XX:+UseG1GC -XX:MaxMetaspaceSize=1g -Dfile.encoding=UTF-8

# Android
android.useAndroidX=true
android.enableJetifier=false
android.nonTransitiveRClass=true
android.nonFinalResIds=true

# Kotlin
kotlin.incremental=true
kotlin.incremental.java=true
kapt.incremental.apt=true
```

**Profile slow builds:**
```bash
./gradlew assembleDebug --scan         # Gradle Build Scan (requires Gradle Enterprise)
./gradlew assembleDebug --profile      # Local HTML report in build/reports/profile/
./gradlew dependencies --configuration debugRuntimeClasspath  # Dependency tree
```

---

## Rule 6 — R8 / ProGuard

```kotlin
// Release build type — always enable R8 full mode
buildTypes {
    release {
        isMinifyEnabled = true
        isShrinkResources = true
        proguardFiles(
            getDefaultProguardFile("proguard-android-optimize.txt"),
            "proguard-rules.pro",
        )
        signingConfig = signingConfigs.getByName("release")
    }
    debug {
        applicationIdSuffix = ".debug"
        versionNameSuffix = "-debug"
        isDebuggable = true
    }
}
```

```proguard
# proguard-rules.pro — baseline rules

# Kotlin serialization
-keepattributes *Annotation*, InnerClasses
-dontnote kotlinx.serialization.AnnotationsKt
-keepclassmembers class kotlinx.serialization.json.** { *** Companion; }
-keepclasseswithmembers class **$$serializer { OBJECT_FIELDS; }

# Retrofit + OkHttp
-dontwarn okhttp3.**
-dontwarn okio.**
-keepnames class okhttp3.internal.publicsuffix.PublicSuffixDatabase

# DI framework (add the keep rules for your chosen framework, e.g.:)
# -keep class dagger.hilt.** { *; }    # Hilt
# -keep class dagger.**  { *; }        # Dagger bare
# -keep class org.koin.** { *; }       # Koin

# Room
-keep class * extends androidx.room.RoomDatabase
-keep @androidx.room.Entity class *

# Keep Parcelables
-keepclassmembers class * implements android.os.Parcelable {
    static ** CREATOR;
}
```

Enable R8 full mode in `gradle.properties`:
```properties
android.enableR8.fullMode=true
```

---

## Rule 7 — Build Variants for Multi-Flavour Apps

```kotlin
flavorDimensions += listOf("environment")
productFlavors {
    create("dev") {
        dimension = "environment"
        applicationIdSuffix = ".dev"
        versionNameSuffix = "-dev"
        buildConfigField("String", "API_BASE_URL", "\"https://api-dev.example.com\"")
    }
    create("staging") {
        dimension = "environment"
        applicationIdSuffix = ".staging"
        buildConfigField("String", "API_BASE_URL", "\"https://api-staging.example.com\"")
    }
    create("prod") {
        dimension = "environment"
        buildConfigField("String", "API_BASE_URL", "\"https://api.example.com\"")
    }
}

buildFeatures { buildConfig = true }
```

---

## Rule 8 — Lint Configuration (Zero-Warnings Policy)

Enforce lint as part of every CI check. The zero-warnings policy is declared in the project-wide
CLAUDE.md — configure it here.

```kotlin
// app/build.gradle.kts (or a convention plugin shared across modules)
android {
    lint {
        abortOnError     = true         // fail the build on any error
        warningsAsErrors = true         // treat every warning as an error
        checkDependencies = true        // propagate lint checks into dependencies
        baseline         = file("lint-baseline.xml")   // suppress pre-existing issues only

        // Disable noisy rules that produce false positives in this project
        disable += setOf("TypographyFractions", "TypographyQuotes")

        // Enable RTL checks missed by default
        enable  += setOf("RtlHardcoded", "RtlCompat", "RtlEnabled")

        // Scope lint to the checks you actually care about on CI (optional — speeds up CI)
        // checkOnly += setOf("NewApi", "InlinedApi", "UseSdkSuppress")

        xmlReport  = false              // human report only on local runs
        htmlReport = true
        htmlOutput = file("${project.rootDir}/lint-report.html")
    }
}
```

**Generate a baseline to suppress existing issues when adopting lint on a brownfield project:**

```bash
# Run once, commit the baseline, then fix issues incrementally
./gradlew lintDebug -PgenerateBaseline=true
git add app/lint-baseline.xml
git commit -m "chore: add lint baseline"
```

**CI job:**

```yaml
# .github/workflows/pr-check.yml
- name: Run lint
  run: ./gradlew lintRelease
- name: Upload lint report
  if: always()
  uses: actions/upload-artifact@v4
  with:
    name: lint-report
    path: lint-report.html
```

---

## Rule 9 — Manifest Placeholders & Shared Build Values

Avoid duplicating values between `AndroidManifest.xml`, Kotlin source, and string resources.
Inject them from a single source of truth in `build.gradle.kts`.

```kotlin
// app/build.gradle.kts
android {
    defaultConfig {
        // Derive the FileProvider authority from applicationId so it's always unique
        val filesAuthority = "$applicationId.files"
        manifestPlaceholders["filesAuthority"] = filesAuthority
        buildConfigField("String", "FILES_AUTHORITY", "\"$filesAuthority\"")

        // Expose a stable API base URL per flavour — see Rule 7
        // (buildConfigField is set per productFlavor for environment-specific values)
    }

    buildTypes {
        release {
            // Timestamp baked in at build time (use "0" in debug to keep builds reproducible)
            val minutesSinceEpoch = (System.currentTimeMillis() / 60_000).toString()
            buildConfigField("String", "BUILD_TIME", "\"$minutesSinceEpoch\"")
            resValue("string", "build_time", minutesSinceEpoch)
        }
        debug {
            buildConfigField("String", "BUILD_TIME", "\"0\"")
            resValue("string", "build_time", "0")
        }
    }

    buildFeatures { buildConfig = true }
}
```

Use the placeholder in `AndroidManifest.xml`:

```xml
<provider
    android:name="androidx.core.content.FileProvider"
    android:authorities="${filesAuthority}"
    android:exported="false"
    android:grantUriPermissions="true">
    <meta-data
        android:name="android.support.FILE_PROVIDER_PATHS"
        android:resource="@xml/file_paths" />
</provider>
```

Access in Kotlin:

```kotlin
// Always read from BuildConfig — never duplicate the string in Kotlin source
val uri = FileProvider.getUriForFile(context, BuildConfig.FILES_AUTHORITY, file)
Log.d(TAG, "Built at minute ${BuildConfig.BUILD_TIME}")
```

**Per-variant source sets** — use when a variant needs its own resources or manifest fragment:

```kotlin
android {
    sourceSets {
        getByName("dev") {
            res.srcDirs("src/dev/res")
            manifest.srcFile("src/dev/AndroidManifest.xml")
        }
    }
}
```

---

## Rule 10 — Signing Security (keystore.properties / env-var fallback)

Never commit credentials. Load signing config from a local file with a CI env-var fallback.

```kotlin
// app/build.gradle.kts
import java.util.Properties

// 1. Load keystore.properties (local dev) — file is in .gitignore
val keystoreProps = Properties().apply {
    rootProject.file("keystore.properties").takeIf { it.exists() }
        ?.inputStream()?.use { load(it) }
}

// 2. Helper reads the local file first, then falls back to a CI env var
fun keystoreValue(propKey: String, envKey: String): String? =
    keystoreProps.getProperty(propKey) ?: System.getenv(envKey)

android {
    signingConfigs {
        create("release") {
            storeFile   = keystoreValue("storeFile",    "KEYSTORE_FILE")?.let(::file)
            storePassword = keystoreValue("storePassword", "KEYSTORE_PASSWORD")
            keyAlias    = keystoreValue("keyAlias",     "KEY_ALIAS")
            keyPassword = keystoreValue("keyPassword",  "KEY_PASSWORD")
        }
    }
    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}
```

`keystore.properties` (local only — **add to `.gitignore`**):

```properties
storeFile=../release.jks
storePassword=myStorePassword
keyAlias=my-alias
keyPassword=myKeyPassword
```

`.gitignore` entry:

```gitignore
keystore.properties
*.jks
*.keystore
```

CI (GitHub Actions) — store secrets as repository secrets, then expose as env vars:

```yaml
- name: Assemble release APK
  env:
    KEYSTORE_FILE: ${{ secrets.KEYSTORE_FILE }}
    KEYSTORE_PASSWORD: ${{ secrets.KEYSTORE_PASSWORD }}
    KEY_ALIAS: ${{ secrets.KEY_ALIAS }}
    KEY_PASSWORD: ${{ secrets.KEY_PASSWORD }}
  run: ./gradlew assembleRelease
```

---

## Rule 11 — AGP Variant & Artifact APIs (from android/gradle-recipes)

Prefer the `androidComponents` DSL over the legacy `android.applicationVariants.all` iterator.
The recipes at [android/gradle-recipes](https://github.com/android/gradle-recipes) are the
canonical reference for all AGP 9.x public APIs.

### Disable unwanted variant combinations

```kotlin
// app/build.gradle.kts
androidComponents {
    beforeVariants { variantBuilder ->
        // Disable demo × minApi21 — no device coverage justifies this combination
        if (variantBuilder.productFlavors.containsAll(
                listOf("mode" to "demo", "api" to "minApi21")
            )
        ) {
            variantBuilder.enabled = false
        }

        // Disable unit tests for release builds on CI (saves ~40 % of test time)
        if (variantBuilder.buildType == "release") {
            variantBuilder.enableUnitTest = false
        }
    }
}
```

### Dynamic version codes per ABI split

```kotlin
// app/build.gradle.kts
import com.android.build.api.variant.FilterConfiguration.FilterType.ABI

val abiVersionCodes = mapOf("armeabi-v7a" to 1, "arm64-v8a" to 2, "x86" to 3, "x86_64" to 4)

androidComponents {
    onVariants { variant ->
        variant.outputs.forEach { output ->
            val abiName = output.filters.find { it.filterType == ABI }?.identifier
            val abiCode = abiVersionCodes[abiName] ?: return@forEach
            // Encode ABI in the high bits so Play always selects the right APK
            output.versionCode.set(abiCode * 100_000 + (output.versionCode.get() ?: 0))
        }
    }
}
```

### Programmatic BuildConfig fields

```kotlin
// build-logic/convention/src/main/kotlin/BuildConfigConventionPlugin.kt
// (recipe: addCustomBuildConfigFields)
androidComponents {
    onVariants { variant ->
        variant.buildConfigFields.put(
            "GIT_SHA",
            BuildConfigField("String", "\"${gitSha()}\"", "Current git commit SHA"),
        )
    }
}

fun gitSha(): String = ProcessBuilder("git", "rev-parse", "--short", "HEAD")
    .start().inputStream.bufferedReader().readLine()?.trim() ?: "unknown"
```

### Artifact transformation (worker-enabled, cacheable)

```kotlin
// (recipe: workerEnabledTransformation / transformAllClasses)
// Register a cacheable task that transforms all .class files (e.g., for custom instrumentation)
androidComponents {
    onVariants { variant ->
        val taskProvider = project.tasks.register<TransformClassesTask>(
            "transform${variant.name.replaceFirstChar { it.uppercaseChar() }}Classes"
        )
        variant.artifacts
            .forScope(ScopedArtifacts.Scope.PROJECT)
            .use(taskProvider)
            .toTransform(
                ScopedArtifact.CLASSES,
                TransformClassesTask::inputJars,
                TransformClassesTask::inputDirectories,
                TransformClassesTask::outputClasses,
            )
    }
}

@CacheableTask
abstract class TransformClassesTask : DefaultTask() {
    @get:Classpath abstract val inputJars: ListProperty<RegularFile>
    @get:InputFiles @get:PathSensitive(PathSensitivity.RELATIVE)
    abstract val inputDirectories: ListProperty<Directory>
    @get:OutputFile abstract val outputClasses: RegularFileProperty

    @get:Inject abstract val workers: WorkerExecutor

    @TaskAction
    fun transform() {
        // Use workers for parallel processing — see gradle-recipes/workerEnabledTransformation
        workers.noIsolation().submit(TransformAction::class.java) { params ->
            params.inputJars.set(inputJars)
            params.inputDirs.set(inputDirectories)
            params.output.set(outputClasses)
        }
    }
}
```

> For the full catalogue of AGP recipes (manifest transforms, custom source types, scoped
> artifacts, fused libraries, KMP), browse
> [github.com/android/gradle-recipes](https://github.com/android/gradle-recipes).

---

## Health Check Output Format

```
## Gradle Build Health Report
**Project:** <name>
**Date:** <today>

### Critical 🔴
- Groovy DSL found in :feature:profile/build.gradle — must convert to Kotlin DSL
- Hardcoded version "2.1.0" in :core:data/build.gradle.kts:14 — move to libs.versions.toml
- keystore.properties committed to git — remove immediately, rotate credentials, add to .gitignore

### Warnings 🟠
- Configuration cache not enabled — add org.gradle.configuration-cache=true
- R8 full mode disabled — add android.enableR8.fullMode=true
- lint.warningsAsErrors not set — zero-warnings policy not enforced (Rule 8)
- signingConfig uses hardcoded credentials — migrate to keystore.properties / env vars (Rule 10)
- android.applicationVariants.all used in :app — migrate to androidComponents.onVariants (Rule 11)

### Opportunities 🟡
- 3 dependency bundles can be extracted in libs.versions.toml
- :feature:home and :feature:profile share identical build config — extract convention plugin
- No lint baseline found — run ./gradlew lintDebug -PgenerateBaseline=true to suppress legacy issues
- manifestPlaceholders set inline as strings — derive from applicationId via buildConfigField (Rule 9)
- demo × minApi21 variant enabled but has zero test coverage — disable with beforeVariants (Rule 11)

### Good ✅
- All modules use Kotlin DSL
- Version catalog present and complete
- Parallel builds enabled
- Lint configured with abortOnError = true
- Signing credentials loaded from keystore.properties
```
