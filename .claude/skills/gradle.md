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

---

## Rule 1 — Kotlin DSL Only

All build files must be `build.gradle.kts`. Convert any Groovy files found.

```kotlin
// build.gradle.kts — correct
plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.hilt)
    alias(libs.plugins.ksp)
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
hilt                = "2.53"
compose-bom         = "2025.01.00"
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

# Hilt
hilt-android             = { group = "com.google.dagger", name = "hilt-android", version.ref = "hilt" }
hilt-compiler            = { group = "com.google.dagger", name = "hilt-android-compiler", version.ref = "hilt" }
hilt-navigation-compose  = { group = "androidx.hilt", name = "hilt-navigation-compose", version = "1.2.0" }

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
hilt                 = { id = "com.google.dagger.hilt.android", version.ref = "hilt" }
ksp                  = { id = "com.google.devtools.ksp", version.ref = "ksp" }
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
      HiltConventionPlugin.kt
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

## Rule 4 — Build Speed Optimisation

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

## Rule 5 — R8 / ProGuard

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

# Hilt
-keep class dagger.hilt.** { *; }

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

## Rule 6 — Build Variants for Multi-Flavour Apps

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

## Health Check Output Format

```
## Gradle Build Health Report
**Project:** <name>
**Date:** <today>

### Critical 🔴
- Groovy DSL found in :feature:profile/build.gradle — must convert to Kotlin DSL
- Hardcoded version "2.1.0" in :core:data/build.gradle.kts:14 — move to libs.versions.toml

### Warnings 🟠
- Configuration cache not enabled — add org.gradle.configuration-cache=true
- R8 full mode disabled — add android.enableR8.fullMode=true

### Opportunities 🟡
- 3 dependency bundles can be extracted in libs.versions.toml
- :feature:home and :feature:profile share identical build config — extract convention plugin

### Good ✅
- All modules use Kotlin DSL
- Version catalog present and complete
- Parallel builds enabled
```
