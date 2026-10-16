# Upgrading to AGP 9 (and keeping up within 9.x)

Prefer Google's official upgrade skill when it is installed (`android skills list` will show it; see [`/google-integrations`](../../google-integrations/SKILL.md)). This checklist is the agent-agnostic fallback and the review guide.

## 0. Prepare

```bash
git switch -c build/agp-9
./gradlew --version
./gradlew help --configuration-cache --warning-mode=all   # fix deprecations first, they become errors
```

Upgrade one variable at a time, building after each step: **Gradle → AGP → Kotlin/KSP → built-in Kotlin → new DSL cleanup**.

## 1. Gradle wrapper

AGP 9.0 needs Gradle ≥ 9.1, AGP 9.2 needs ≥ 9.4.1, and AGP 9.4 needs ≥ 9.6.0.

```bash
./gradlew wrapper --gradle-version <version> --gradle-distribution-sha256-sum <sha256>
./gradlew wrapper    # second run updates gradle-wrapper.jar and scripts
```

Gradle 9 breakages you will hit:
- `Project.exec` / `Project.javaexec` removed → inject `ExecOperations`.
- JUnit Platform launcher no longer provided → add `testRuntimeOnly("org.junit.platform:junit-platform-launcher")`.
- Kotlin DSL scripts compile with Kotlin 2.x language rules; fix old `buildSrc` code.
- Running Gradle itself needs JDK 17+.

## 2. AGP version and SDK tooling

- Bump `agp` in `libs.versions.toml`. Build tools ≥ 36.0.0 are pulled in automatically.
- Set `targetSdk` explicitly in every app and test module. AGP 9 defaults it to `compileSdk` when unset.
- Libraries now require consumers to use the same or a higher `compileSdk` (`aarMetadata.minCompileSdk`).

## 3. Built-in Kotlin

1. Remove `org.jetbrains.kotlin.android` / `kotlin-android` from module plugins, the root `apply false` list and the catalog.
2. Replace `android { kotlinOptions { … } }` with `kotlin { compilerOptions { … } }`. `jvmTarget` now defaults to `compileOptions.targetCompatibility`, so you can usually delete it.
3. Move extra source directories to `android.sourceSets.named("main") { kotlin.directories += "…" }`.
4. Replace `kotlin-kapt` with KSP. If a processor has no KSP support yet, apply `com.android.legacy-kapt` (same version as AGP) as a bridge and track removing it.
5. Bump KSP to ≥ 2.2.10-2.0.2 (2.3.x recommended).
6. Modules without Kotlin sources: `android { enableKotlin = false }`.
7. Kotlin Multiplatform modules must use `com.android.kotlin.multiplatform.library` instead of `com.android.library`.

Large project? Migrate module by module: set `android.builtInKotlin=false`, apply `com.android.built-in-kotlin` to each migrated module, then remove both when done.

## 4. New DSL (`android.newDsl=true` is the default)

| Removed | Replacement |
|---|---|
| `applicationVariants`, `libraryVariants`, `testVariants`, `unitTestVariants` | `androidComponents.onVariants { }` |
| `variantFilter { }` | `androidComponents.beforeVariants { it.enable = … }` |
| `BaseExtension`, `AppExtension`, `LibraryExtension` (old `com.android.build.gradle.*`) | `com.android.build.api.dsl.ApplicationExtension` / `LibraryExtension` |
| `android.sdkDirectory`, `adbExecutable`, `bootClasspath` | `androidComponents.sdkComponents.*` |
| `dexOptions`, `generatePureSplits`, density splits | none — delete |
| `CommonExtension<…>` generics | Configure `ApplicationExtension` / `LibraryExtension` separately |

Third-party Gradle plugins that still use the old types fail with `ClassCastException … BaseExtension`. Upgrade them first. If one is not ready, `android.newDsl=false` is a temporary escape hatch (removed in AGP 10).

## 5. Changed defaults to review

| Property (new default) | What to check |
|---|---|
| `android.uniquePackageNames=true` | Two modules with the same `namespace` now fail |
| `android.enableAppCompileTimeRClass=true` | App `R` class is generated at compile time. Check build logic or tools that post-process `R.jar` |
| `android.defaults.buildfeatures.resvalues=false` | Enable `buildFeatures.resValues` where `resValue()` is used |
| `android.onlyEnableUnitTestForTheTestedBuildType=true` | CI should run `testDebugUnitTest`; release unit tests are gone |
| `android.r8.strictFullModeForKeepRules=true` | `-keep class A` no longer keeps `<init>()` |
| `android.r8.proguardAndroidTxt.disallowed=true` | Switch to `proguard-android-optimize.txt` |
| `android.r8.globalOptionsInConsumerRules.disallowed=true` | Remove `-dontoptimize` etc. from library consumer rules |
| `android.proguard.failOnMissingFiles=true` | Delete references to non-existent rule files |
| `android.dependency.useConstraints=false` | Verify test/main classpaths still align (`dependencyInsight`) |

## 6. Verify

```bash
./gradlew help --configuration-cache
./gradlew assembleDebug testDebugUnitTest lintDebug
./gradlew assembleRelease && ./gradlew checkReleaseBadging   # R8 + badging
./gradlew :app:connectedDebugAndroidTest                     # or Gradle Managed Devices
```

Then remove every temporary opt-out (`android.builtInKotlin=false`, `android.newDsl=false`, `com.android.legacy-kapt`) or open a tracked issue for each.
