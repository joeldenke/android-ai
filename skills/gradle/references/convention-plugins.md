# Convention plugins for AGP 9 (`build-logic/`)

Shared build configuration lives in an included build. Feature modules apply one plugin and declare only `namespace` and dependencies.

```
build-logic/
  settings.gradle.kts
  convention/
    build.gradle.kts
    src/main/kotlin/
      AndroidApplicationConventionPlugin.kt
      AndroidLibraryConventionPlugin.kt
      AndroidComposeConventionPlugin.kt
      AndroidFeatureConventionPlugin.kt
      JvmLibraryConventionPlugin.kt
      com/example/buildlogic/
        AndroidConfig.kt        # shared helpers
        Catalog.kt
```

## `build-logic/settings.gradle.kts`

```kotlin
dependencyResolutionManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
    versionCatalogs {
        create("libs") { from(files("../gradle/libs.versions.toml")) }
    }
}

rootProject.name = "build-logic"
include(":convention")
```

## `build-logic/convention/build.gradle.kts`

```kotlin
plugins {
    `kotlin-dsl`
}

kotlin { jvmToolchain(17) }

dependencies {
    // compileOnly: the real plugin versions come from the root build's classpath
    compileOnly(libs.android.gradlePlugin)
    compileOnly(libs.kotlin.gradlePlugin)
    compileOnly(libs.compose.gradlePlugin)
    compileOnly(libs.ksp.gradlePlugin)
}

tasks.validatePlugins {
    enableStricterValidation = true
    failOnWarning = true
}

gradlePlugin {
    plugins {
        register("androidApplication") {
            id = libs.plugins.convention.android.application.get().pluginId
            implementationClass = "AndroidApplicationConventionPlugin"
        }
        register("androidLibrary") {
            id = libs.plugins.convention.android.library.get().pluginId
            implementationClass = "AndroidLibraryConventionPlugin"
        }
        register("androidCompose") {
            id = libs.plugins.convention.android.compose.get().pluginId
            implementationClass = "AndroidComposeConventionPlugin"
        }
        register("androidFeature") {
            id = libs.plugins.convention.android.feature.get().pluginId
            implementationClass = "AndroidFeatureConventionPlugin"
        }
        register("jvmLibrary") {
            id = libs.plugins.convention.jvm.library.get().pluginId
            implementationClass = "JvmLibraryConventionPlugin"
        }
    }
}
```

## Shared helpers

```kotlin
// com/example/buildlogic/Catalog.kt
package com.example.buildlogic

import org.gradle.api.Project
import org.gradle.api.artifacts.VersionCatalog
import org.gradle.api.artifacts.VersionCatalogsExtension
import org.gradle.kotlin.dsl.getByType

internal val Project.libs: VersionCatalog
    get() = extensions.getByType<VersionCatalogsExtension>().named("libs")

internal fun VersionCatalog.lib(alias: String) = findLibrary(alias).get()
internal fun VersionCatalog.bundle(alias: String) = findBundle(alias).get()
```

```kotlin
// com/example/buildlogic/AndroidConfig.kt
package com.example.buildlogic

import org.gradle.api.JavaVersion
import org.gradle.api.Project
import org.gradle.api.tasks.testing.Test
import org.gradle.kotlin.dsl.dependencies
import org.gradle.kotlin.dsl.withType
import org.jetbrains.kotlin.gradle.tasks.KotlinJvmCompile

internal object Sdk {
    const val COMPILE = 36
    const val TARGET = 36
    const val MIN = 26
    val JAVA = JavaVersion.VERSION_17
}

/** Kotlin compiler options for every module. Built-in Kotlin (AGP 9) and kotlin("jvm") both produce KotlinJvmCompile tasks. */
internal fun Project.configureKotlin() {
    val warningsAsErrors = providers.gradleProperty("warningsAsErrors").map(String::toBoolean).orElse(false)
    tasks.withType<KotlinJvmCompile>().configureEach {
        compilerOptions {
            allWarningsAsErrors.set(warningsAsErrors)
            freeCompilerArgs.addAll(
                "-opt-in=kotlinx.coroutines.ExperimentalCoroutinesApi",
            )
        }
    }
}

/** JUnit Platform (Jupiter 5/6) for JVM unit tests. */
internal fun Project.configureUnitTests() {
    dependencies {
        "testImplementation"(platform(libs.lib("junit-bom")))
        "testImplementation"(libs.bundle("unit-test"))
        "testRuntimeOnly"(libs.lib("junit-platform-launcher"))
    }
    tasks.withType<Test>().configureEach {
        useJUnitPlatform()
        maxParallelForks = (Runtime.getRuntime().availableProcessors() / 2).coerceAtLeast(1)
    }
}
```

## Application and library plugins

AGP 9 removed `BaseExtension` and the type parameters on `CommonExtension`. Configure `ApplicationExtension` and `LibraryExtension` directly.

```kotlin
// AndroidApplicationConventionPlugin.kt
import com.android.build.api.dsl.ApplicationExtension
import com.example.buildlogic.Sdk
import com.example.buildlogic.configureKotlin
import com.example.buildlogic.configureUnitTests
import org.gradle.api.Plugin
import org.gradle.api.Project
import org.gradle.kotlin.dsl.apply
import org.gradle.kotlin.dsl.configure

class AndroidApplicationConventionPlugin : Plugin<Project> {
    override fun apply(target: Project) = with(target) {
        apply(plugin = "com.android.application")   // built-in Kotlin: no kotlin-android plugin

        extensions.configure<ApplicationExtension> {
            compileSdk = Sdk.COMPILE
            defaultConfig {
                minSdk = Sdk.MIN
                targetSdk = Sdk.TARGET
                testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
            }
            compileOptions {
                sourceCompatibility = Sdk.JAVA
                targetCompatibility = Sdk.JAVA
            }
            buildTypes {
                release {
                    isMinifyEnabled = true
                    isShrinkResources = true
                    proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
                }
            }
            packaging.resources.excludes += "/META-INF/{AL2.0,LGPL2.1}"
        }
        configureKotlin()
        configureUnitTests()
    }
}
```

```kotlin
// AndroidLibraryConventionPlugin.kt
import com.android.build.api.dsl.LibraryExtension
import com.example.buildlogic.Sdk
import com.example.buildlogic.configureKotlin
import com.example.buildlogic.configureUnitTests
import org.gradle.api.Plugin
import org.gradle.api.Project
import org.gradle.kotlin.dsl.apply
import org.gradle.kotlin.dsl.configure

class AndroidLibraryConventionPlugin : Plugin<Project> {
    override fun apply(target: Project) = with(target) {
        apply(plugin = "com.android.library")

        extensions.configure<LibraryExtension> {
            compileSdk = Sdk.COMPILE
            defaultConfig {
                minSdk = Sdk.MIN
                consumerProguardFiles("consumer-rules.pro")
                testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
            }
            compileOptions {
                sourceCompatibility = Sdk.JAVA
                targetCompatibility = Sdk.JAVA
            }
            lint.targetSdk = Sdk.TARGET
            testOptions.targetSdk = Sdk.TARGET
            // Resource prefix avoids clashes in non-transitive R classes
            resourcePrefix = path.split("""\W""".toRegex()).drop(1).distinct().joinToString("_").lowercase() + "_"
        }
        configureKotlin()
        configureUnitTests()
    }
}
```

## Compose plugin

```kotlin
// AndroidComposeConventionPlugin.kt
import com.android.build.api.dsl.ApplicationExtension
import com.android.build.api.dsl.LibraryExtension
import com.example.buildlogic.lib
import com.example.buildlogic.libs
import org.gradle.api.Plugin
import org.gradle.api.Project
import org.gradle.kotlin.dsl.apply
import org.gradle.kotlin.dsl.configure
import org.gradle.kotlin.dsl.dependencies
import org.jetbrains.kotlin.compose.compiler.gradle.ComposeCompilerGradlePluginExtension

class AndroidComposeConventionPlugin : Plugin<Project> {
    override fun apply(target: Project) = with(target) {
        apply(plugin = "org.jetbrains.kotlin.plugin.compose")

        pluginManager.withPlugin("com.android.application") {
            extensions.configure<ApplicationExtension> { buildFeatures.compose = true }
        }
        pluginManager.withPlugin("com.android.library") {
            extensions.configure<LibraryExtension> { buildFeatures.compose = true }
        }

        dependencies {
            val bom = platform(libs.lib("androidx-compose-bom"))
            "implementation"(bom)
            "androidTestImplementation"(bom)
            "implementation"(libs.lib("androidx-compose-ui-tooling-preview"))
            "debugImplementation"(libs.lib("androidx-compose-ui-tooling"))
        }

        extensions.configure<ComposeCompilerGradlePluginExtension> {
            // One shared stability file at the root: lists external types the compiler should treat as stable
            stabilityConfigurationFiles.add(isolated.rootProject.projectDirectory.file("compose-stability.conf"))

            // ./gradlew assembleRelease -PcomposeCompilerReports=true → build/compose-reports
            if (providers.gradleProperty("composeCompilerReports").isPresent) {
                reportsDestination.set(layout.buildDirectory.dir("compose-reports"))
                metricsDestination.set(layout.buildDirectory.dir("compose-metrics"))
            }
        }
    }
}
```

```
# compose-stability.conf (repo root)
java.time.*
kotlinx.datetime.*
kotlin.collections.*          # only if the team accepts the trade-off; prefer kotlinx.collections.immutable
```

## Feature plugin (composition of the others)

```kotlin
// AndroidFeatureConventionPlugin.kt
import com.example.buildlogic.lib
import com.example.buildlogic.libs
import org.gradle.api.Plugin
import org.gradle.api.Project
import org.gradle.kotlin.dsl.apply
import org.gradle.kotlin.dsl.dependencies

class AndroidFeatureConventionPlugin : Plugin<Project> {
    override fun apply(target: Project) = with(target) {
        apply(plugin = "convention.android.library")
        apply(plugin = "convention.android.compose")
        // apply(plugin = "convention.di")   // the project's DI convention, if any

        dependencies {
            "implementation"(project(":core:ui"))
            "implementation"(project(":core:domain"))
            "implementation"(libs.lib("androidx-lifecycle-viewmodel-compose"))
            "implementation"(libs.lib("androidx-lifecycle-runtime-compose"))
        }
    }
}
```

## Pure JVM modules (`:core:domain`, `:core:model`)

```kotlin
// JvmLibraryConventionPlugin.kt
import com.example.buildlogic.configureKotlin
import com.example.buildlogic.configureUnitTests
import org.gradle.api.Plugin
import org.gradle.api.Project
import org.gradle.kotlin.dsl.apply
import org.gradle.kotlin.dsl.configure
import org.jetbrains.kotlin.gradle.dsl.KotlinJvmProjectExtension

class JvmLibraryConventionPlugin : Plugin<Project> {
    override fun apply(target: Project) = with(target) {
        apply(plugin = "org.jetbrains.kotlin.jvm")
        extensions.configure<KotlinJvmProjectExtension> {
            jvmToolchain(17)
            explicitApi()   // public API must be declared explicitly in shared JVM libraries
        }
        configureKotlin()
        configureUnitTests()
    }
}
```

## Checklist

- [ ] `includeBuild("build-logic")` inside `pluginManagement` in `settings.gradle.kts`
- [ ] Every plugin used by a convention plugin is declared `apply false` in the root build file
- [ ] No `allprojects {}` or `subprojects {}`, and no reads of other projects' models
- [ ] `./gradlew help --configuration-cache` passes
- [ ] `./gradlew :build-logic:convention:validatePlugins` passes
- [ ] Feature module build files are ≤ 15 lines
