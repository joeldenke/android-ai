---
name: baseline-profile
description: Generates, verifies, and integrates Android Baseline Profiles for measurable startup and runtime performance gains — Macrobenchmark module setup, BaselineProfileGenerator authoring, ProfileInstaller wiring, R8 profile rewriting, and CI integration with the AVD emulator runner.
---

When the user runs `/baseline-profile [task]`, generate or audit the baseline profile pipeline for the project. Default to a full setup (`generate` + `verify` + `ci`) if no task is specified.

Reference: https://developer.android.com/topic/performance/baselineprofiles/overview

## Tasks

| Command | Action |
|---|---|
| `/baseline-profile` | Full setup — scaffold module, generator, profile installer wiring, CI job |
| `/baseline-profile generate` | Add or update the Macrobenchmark generator and run it locally |
| `/baseline-profile verify` | Run StartupBenchmark before/after and report the delta |
| `/baseline-profile ci` | Scaffold the GitHub Actions job that regenerates profiles on the AVD emulator runner |

---

## What Baseline Profiles Are

A **Baseline Profile** is a list of classes and methods (in HRF — Human Readable Format) that the Android runtime AOT-compiles **at install time** rather than JIT-compiling at first execution.

- **Startup wins**: cold start typically improves by 20-40% — measured in real apps (Compose-heavy startups often see ≥30%).
- **Jank reduction**: scroll and animation paths covered by the profile skip JIT warm-up, eliminating interpreter spikes.
- **Code size**: profiles are small (typically <200 KB) — they reference classes/methods already in the APK.
- **No runtime cost**: AOT compilation happens before the first launch; nothing extra runs in your app process.
- **Works on API 24+** via the `androidx.profileinstaller` library; native ART support kicks in from API 28+.

Baseline Profiles complement R8 — R8 shrinks and optimises, while the profile tells ART **which** of the kept code to pre-compile.

---

## Rule 1 — Macrobenchmark Module Setup

Create a separate Gradle module (`:macrobenchmark`) using the `com.android.test` plugin. This module never ships to users — it only runs locally and in CI to generate the profile.

### Version Catalog Entries

```toml
# gradle/libs.versions.toml
[versions]
benchmark           = "1.3.4"
profileinstaller    = "1.4.1"
uiautomator         = "2.3.0"

[libraries]
androidx-benchmark-macro-junit4    = { group = "androidx.benchmark",         name = "benchmark-macro-junit4",       version.ref = "benchmark" }
androidx-profileinstaller          = { group = "androidx.profileinstaller",  name = "profileinstaller",             version.ref = "profileinstaller" }
androidx-test-uiautomator          = { group = "androidx.test.uiautomator",  name = "uiautomator",                  version.ref = "uiautomator" }

[plugins]
android-test          = { id = "com.android.test",                version.ref = "agp" }
androidx-baselineprofile = { id = "androidx.baselineprofile",     version.ref = "benchmark" }
```

### `:macrobenchmark/build.gradle.kts`

```kotlin
plugins {
    alias(libs.plugins.android.test)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.androidx.baselineprofile)
}

android {
    namespace = "com.example.app.macrobenchmark"
    compileSdk = 35

    defaultConfig {
        minSdk = 28                                // Macrobenchmark requires API 28+
        targetSdk = 35
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    // Macrobenchmark must run against a non-debuggable, profileable build of the app.
    // The Baseline Profile Gradle plugin wires this up via `targetProjectPath` + `experimentalProperties`.
    targetProjectPath = ":app"

    // R8 must be on for the target app variant when generating profiles —
    // generated profiles must reflect the shrunk class names that will ship.
    experimentalProperties["android.experimental.self-instrumenting"] = true

    buildTypes {
        // Mirror the release build that users will actually run.
        create("benchmark") {
            isDebuggable = false
            signingConfig = signingConfigs.getByName("debug")  // local-only signing
            matchingFallbacks += listOf("release")
        }
    }
}

dependencies {
    implementation(libs.androidx.benchmark.macro.junit4)
    implementation(libs.androidx.test.uiautomator)
    implementation(libs.androidx.test.runner)
    implementation(libs.androidx.test.ext.junit)
}

baselineProfile {
    // Run generation on a managed device or connected device; AVD is preferred in CI.
    useConnectedDevices = true
    // Profiles must be regenerated when source changes; keep this `false` in CI.
    saveInSrc = true
}
```

### `:app/build.gradle.kts` — Wire the Plugin

```kotlin
plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.androidx.baselineprofile)
}

android {
    // ... existing config ...

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            // Required for the generator: the release variant must be profileable.
            // Without this, Macrobenchmark cannot read the profile data.
            // <profileable android:shell="true" /> is added automatically by the plugin.
        }
        create("benchmark") {
            initWith(getByName("release"))
            // Keep release optimizations but allow Macrobenchmark to read profiling data.
            isDebuggable = false
            matchingFallbacks += listOf("release")
        }
    }

    // Dex Layout Optimization — R8 rewrites the dex layout using the profile so that
    // startup-critical classes live in primary dex regions, improving cold start I/O.
    androidComponents {
        onVariants(selector().withBuildType("release")) { variant ->
            variant.experimentalProperties.put(
                "android.experimental.art-profile-r8-rewriting",
                true,
            )
            // Also enables R8 to use the profile during shrinking — keeps hot methods inlined.
            variant.experimentalProperties.put(
                "android.experimental.r8.dex-startup-optimization",
                true,
            )
        }
    }
}

dependencies {
    // REQUIRED: this is what actually installs the profile on devices < API 28
    // and on first launch for API 28+ devices that didn't get the profile from Play Store.
    implementation(libs.androidx.profileinstaller)

    // Allow the baseline profile module to feed profiles back into :app.
    "baselineProfile"(project(":macrobenchmark"))
}
```

---

## Rule 2 — Writing a BaselineProfileGenerator

The generator drives the app through its critical user paths (cold start, login, scroll). Whatever code runs during the journey gets compiled AOT.

```kotlin
// macrobenchmark/src/main/java/com/example/app/macrobenchmark/BaselineProfileGenerator.kt
package com.example.app.macrobenchmark

import androidx.benchmark.macro.junit4.BaselineProfileRule
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.uiautomator.By
import androidx.test.uiautomator.Until
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class BaselineProfileGenerator {

    @get:Rule
    val baselineProfileRule = BaselineProfileRule()

    @Test
    fun generate() = baselineProfileRule.collect(
        packageName = "com.example.app",
        // Limit profile to ~3 stable iterations — more iterations don't help.
        maxIterations = 3,
        stableIterations = 2,
    ) {
        // 1. Cold start — must always be the first journey.
        pressHome()
        startActivityAndWait()

        // 2. Critical post-startup work — anything users see in the first 3 seconds.
        device.wait(Until.hasObject(By.res("home_feed")), 5_000)

        // 3. First scroll — covers RecyclerView/LazyColumn warm-up paths.
        device.findObject(By.res("home_feed")).fling(androidx.test.uiautomator.Direction.DOWN)
        device.waitForIdle()

        // 4. Most-common navigation target — e.g., item detail.
        device.findObject(By.res("home_feed_item_0"))?.click()
        device.wait(Until.hasObject(By.res("detail_screen")), 5_000)

        // 5. Back to home — captures back-navigation paths.
        device.pressBack()
        device.wait(Until.hasObject(By.res("home_feed")), 5_000)
    }
}
```

### Coverage Guidance

Profile the **first 5 seconds** of the most common user flows. In order of priority:

1. **Cold start** (always required).
2. **First scroll** of any LazyList/LazyGrid on the landing screen.
3. **Highest-traffic navigation target** (e.g., detail screen from home).
4. **Auth flow** if users routinely re-authenticate.
5. **Search** if it's a primary entry point.

Do **not** profile rarely-visited screens — every extra method in the profile slightly increases install-time AOT cost.

---

## Rule 3 — ProfileInstaller Wiring & Verification

`androidx.profileinstaller` is what makes the profile work on devices that didn't receive it from Play Store (sideloads, internal distribution, API 24-27).

```kotlin
// :app/build.gradle.kts
dependencies {
    implementation(libs.androidx.profileinstaller)
}
```

### Verify the Profile is Bundled

After running generation, the file must exist at:

```
app/src/main/baseline-prof.txt          # Baseline Profile (HRF)
app/src/main/baseline-prof-startup.txt  # Startup Profile (subset, R8-aware)
```

Sanity check:

```bash
# Confirm the profile lives in the source tree (committed to git)
ls -la app/src/main/baseline-prof.txt

# Inspect the first few lines — should look like:
#   HSPLandroidx/compose/runtime/ComposerImpl;-><init>(...)V
#   HSPLcom/example/app/feature/home/HomeViewModel;->onStart()V
head app/src/main/baseline-prof.txt

# Verify the APK contains the compiled profile
unzip -l app/build/outputs/apk/release/app-release.apk | grep baseline.prof
# Should list:
#   assets/dexopt/baseline.prof
#   assets/dexopt/baseline.profm
```

---

## Rule 4 — Running Locally

Generation must run on a **rooted emulator (AOSP image)** or a **physical device with `userdebug` build** — not a Play Store image and not a debuggable build.

### Create the AVD

```bash
# AOSP image (no Google APIs) — supports root and disables verified boot.
sdkmanager "system-images;android-34;aosp_atd;x86_64"
avdmanager create avd -n baseline-profile-avd -k "system-images;android-34;aosp_atd;x86_64" -d pixel_6

# Boot with writable system and disabled verified boot
emulator -avd baseline-profile-avd -writable-system -no-snapshot -no-window &

adb wait-for-device
adb root
adb shell setenforce 0
```

### Generate

```bash
# This task is added by the androidx.baselineprofile plugin.
./gradlew :app:generateReleaseBaselineProfile

# What it does:
# 1. Builds :app with the `benchmark` build type (release + profileable).
# 2. Installs it on the connected device.
# 3. Runs the BaselineProfileGenerator from :macrobenchmark.
# 4. Pulls /data/misc/profiles/cur/0/com.example.app/primary.prof.
# 5. Converts it to HRF and writes app/src/main/baseline-prof.txt.
```

### Commit the Profile

```bash
git add app/src/main/baseline-prof.txt app/src/main/baseline-prof-startup.txt
git commit -m "perf: regenerate baseline profile after home screen redesign"
```

Treat baseline profiles like generated lock files — regenerate when startup-critical code changes (new dependencies, screen redesign, navigation refactor).

---

## Rule 5 — Startup Benchmarks (Verification)

Without a benchmark, you can't prove the profile is doing anything. Pair every profile with a `StartupBenchmark` that runs in CI and tracks the cold-start delta.

```kotlin
// macrobenchmark/src/main/java/com/example/app/macrobenchmark/StartupBenchmark.kt
package com.example.app.macrobenchmark

import androidx.benchmark.macro.CompilationMode
import androidx.benchmark.macro.StartupMode
import androidx.benchmark.macro.StartupTimingMetric
import androidx.benchmark.macro.junit4.MacrobenchmarkRule
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class StartupBenchmark {

    @get:Rule
    val benchmarkRule = MacrobenchmarkRule()

    // Baseline — no profile. Establishes the regression threshold.
    @Test
    fun startupNone() = startup(CompilationMode.None())

    // Partial AOT compilation — what users get after the profile is installed.
    @Test
    fun startupBaselineProfile() = startup(
        CompilationMode.Partial(baselineProfileMode = androidx.benchmark.macro.BaselineProfileMode.Require),
    )

    private fun startup(compilationMode: CompilationMode) = benchmarkRule.measureRepeated(
        packageName = "com.example.app",
        metrics = listOf(StartupTimingMetric()),
        iterations = 10,
        startupMode = StartupMode.COLD,
        compilationMode = compilationMode,
    ) {
        pressHome()
        startActivityAndWait()
    }
}
```

### Interpreting Results

```
StartupBenchmark.startupNone
  timeToInitialDisplayMs   min 612.3,   median 645.8,   max 689.1
StartupBenchmark.startupBaselineProfile
  timeToInitialDisplayMs   min 384.2,   median 401.5,   max 432.7
```

- **Median delta** is the headline number — here, 645.8 → 401.5 = **37.8% improvement**.
- **Max** matters for jank tail latency.
- Anything <10% improvement signals the generator isn't covering the right paths — extend the journey.
- A *regression* between releases means startup-critical code grew or moved off the profile path — regenerate.

---

## Rule 6 — CI Integration (GitHub Actions)

Baseline profile generation needs a rooted emulator, which means using the `reactivecircus/android-emulator-runner` action with an AOSP system image.

```yaml
# .github/workflows/baseline-profile.yml
name: Baseline Profile

on:
  workflow_dispatch:
  schedule:
    - cron: '0 6 * * 1'  # Weekly Monday 06:00 UTC — regenerate before the release train
  pull_request:
    paths:
      - 'app/src/main/**'
      - 'feature/**/src/main/**'
      - 'macrobenchmark/**'

permissions:
  contents: write  # Required if the workflow auto-commits regenerated profiles

jobs:
  generate:
    name: Generate & Verify Baseline Profile
    runs-on: ubuntu-latest
    timeout-minutes: 60

    strategy:
      matrix:
        api-level: [34]

    steps:
      - name: Checkout
        uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # v4.2.2

      - name: Setup JDK 17
        uses: actions/setup-java@3a4f6e1af504cf6a31855fa899c6aa5355ba6c12  # v4.7.0
        with:
          java-version: 17
          distribution: temurin

      - name: Setup Gradle
        uses: gradle/actions/setup-gradle@0723195856401067f7a2779048b490ace7a47d7c  # v5.0.2
        with:
          cache-encryption-key: ${{ secrets.GRADLE_ENCRYPTION_KEY }}

      - name: Enable KVM (required for hardware acceleration)
        run: |
          echo 'KERNEL=="kvm", GROUP="kvm", MODE="0666", OPTIONS+="static_node=kvm"' | sudo tee /etc/udev/rules.d/99-kvm4all.rules
          sudo udevadm control --reload-rules
          sudo udevadm trigger --name-match=kvm

      - name: Cache AVD snapshot
        uses: actions/cache@d4323d4df104b026a6aa633fdb11d772146be0bf  # v4.2.2
        id: avd-cache
        with:
          path: |
            ~/.android/avd/*
            ~/.android/adb*
          key: avd-${{ matrix.api-level }}-aosp-atd

      - name: Create AVD and cache snapshot
        if: steps.avd-cache.outputs.cache-hit != 'true'
        uses: reactivecircus/android-emulator-runner@62dbb605bba737720e10b196cb4220d374026a6d  # v2.33.0
        with:
          api-level: ${{ matrix.api-level }}
          target: aosp_atd
          arch: x86_64
          profile: pixel_6
          force-avd-creation: false
          emulator-options: -no-window -gpu swiftshader_indirect -noaudio -no-boot-anim -camera-back none
          disable-animations: true
          script: echo "Generated AVD snapshot."

      - name: Generate baseline profile
        uses: reactivecircus/android-emulator-runner@62dbb605bba737720e10b196cb4220d374026a6d  # v2.33.0
        with:
          api-level: ${{ matrix.api-level }}
          target: aosp_atd
          arch: x86_64
          profile: pixel_6
          force-avd-creation: false
          emulator-options: -no-snapshot-save -no-window -gpu swiftshader_indirect -noaudio -no-boot-anim -camera-back none
          disable-animations: true
          # uiautomator2 driver is required to drive the app from the macrobenchmark module.
          script: |
            ./gradlew :app:generateReleaseBaselineProfile \
              -Pandroid.testInstrumentationRunnerArguments.androidx.benchmark.enabledRules=BaselineProfile

      - name: Run startup benchmark
        uses: reactivecircus/android-emulator-runner@62dbb605bba737720e10b196cb4220d374026a6d  # v2.33.0
        with:
          api-level: ${{ matrix.api-level }}
          target: aosp_atd
          arch: x86_64
          profile: pixel_6
          force-avd-creation: false
          emulator-options: -no-snapshot-save -no-window -gpu swiftshader_indirect -noaudio -no-boot-anim -camera-back none
          disable-animations: true
          script: |
            ./gradlew :macrobenchmark:connectedBenchmarkAndroidTest \
              -Pandroid.testInstrumentationRunnerArguments.androidx.benchmark.enabledRules=Macrobenchmark

      - name: Upload benchmark results
        if: always()
        uses: actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02  # v4.6.2
        with:
          name: baseline-profile-results-${{ github.run_id }}
          path: |
            macrobenchmark/build/outputs/connected_android_test_additional_output/
            app/src/main/baseline-prof.txt
            app/src/main/baseline-prof-startup.txt
          retention-days: 30

      - name: Commit updated profile
        if: github.event_name == 'schedule' || github.event_name == 'workflow_dispatch'
        run: |
          git config user.name  "baseline-profile-bot"
          git config user.email "baseline-profile-bot@users.noreply.github.com"
          if git diff --quiet app/src/main/baseline-prof.txt app/src/main/baseline-prof-startup.txt; then
            echo "Profile unchanged — nothing to commit."
          else
            git checkout -b "chore/baseline-profile-$(date +%Y%m%d)"
            git add app/src/main/baseline-prof.txt app/src/main/baseline-prof-startup.txt
            git commit -m "chore: regenerate baseline profile [skip ci]"
            git push --set-upstream origin "chore/baseline-profile-$(date +%Y%m%d)"
            gh pr create --fill --label "performance,baseline-profile"
          fi
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

---

## Rule 7 — Dex Layout Optimization (R8 Profile Rewriting)

When R8 minifies, class and method names change (`com.example.app.Foo` → `a.a.a`). The plugin rewrites the profile so its references match the shrunk names — without this, the profile silently does nothing in release builds.

```kotlin
// :app/build.gradle.kts
android {
    androidComponents {
        onVariants(selector().withBuildType("release")) { variant ->
            // Tell R8 to rewrite the baseline profile against the shrunk dex output.
            variant.experimentalProperties.put(
                "android.experimental.art-profile-r8-rewriting",
                true,
            )
            // Order dex files so profile-referenced classes live in the primary dex region.
            // This is what produces the measurable I/O win on cold start.
            variant.experimentalProperties.put(
                "android.experimental.r8.dex-startup-optimization",
                true,
            )
        }
    }
}
```

Verify the rewriting actually happened — the build log should include:

```
> Task :app:minifyReleaseWithR8
ART profile rewriting: 4823 methods, 1247 classes rewritten to shrunk names
```

---

## Common Pitfalls

| Pitfall | Symptom | Fix |
|---|---|---|
| Missing `profileinstaller` dependency | Profile in APK but no startup improvement on sideloaded builds | Add `implementation(libs.androidx.profileinstaller)` to `:app` |
| Running generation on debug build | `Cannot run with debuggable=true` error | Use the `benchmark` build type (release + profileable) |
| Generator only covers cold start | Startup improves but in-app jank persists | Extend the journey to include first scroll + top navigation paths |
| Profile committed but not loaded | `unzip` shows no `baseline.prof` in APK | The `androidx.baselineprofile` plugin isn't applied to `:app` |
| Play Store image used for AVD | `adb root` fails / profile capture returns empty | Use `aosp_atd` system image, not `google_apis` |
| Profile out of date | Benchmark shows <10% improvement after a release | Regenerate — schedule weekly CI job to keep it fresh |
| No StartupBenchmark | "We added a profile" claim with no data | Pair every profile with `CompilationMode.None` vs `Partial(Require)` comparison |
| R8 rewriting disabled | Profile present but startup unchanged in release | Enable `android.experimental.art-profile-r8-rewriting=true` |
| Stale profile on PR | Profile references methods that no longer exist | Add `baseline-profile.yml` to PRs that touch startup code |
| Generator runs on emulator without KVM | 30+ minute timeouts in CI | Enable KVM via udev rules in the workflow (see Rule 6) |

---

## Checklist

- [ ] `:macrobenchmark` module created with `com.android.test` plugin
- [ ] `androidx.baselineprofile` plugin applied to both `:macrobenchmark` and `:app`
- [ ] `androidx.profileinstaller` dependency added to `:app`
- [ ] `BaselineProfileGenerator` covers cold start + first scroll + top navigation target
- [ ] `StartupBenchmark` measures `CompilationMode.None` vs `Partial(Require)`
- [ ] `targetProjectPath = ":app"` set in macrobenchmark `build.gradle.kts`
- [ ] `benchmark` build type created (release + non-debuggable + profileable)
- [ ] `android.experimental.art-profile-r8-rewriting = true` set for release variant
- [ ] `app/src/main/baseline-prof.txt` and `baseline-prof-startup.txt` committed to git
- [ ] GitHub Actions workflow uses `aosp_atd` AVD image with KVM acceleration
- [ ] Weekly scheduled regeneration with auto-PR
- [ ] Measured median cold-start improvement ≥20% on representative device
- [ ] Profile regenerated whenever startup-critical code changes (dependencies, nav, home screen)

---

## Output Format

```markdown
## Baseline Profile Audit
**Date:** <today>
**Target:** <package name>

### Setup
- Macrobenchmark module: ✅ present | ❌ missing
- ProfileInstaller dependency: ✅ wired | ❌ missing
- R8 profile rewriting: ✅ enabled | ❌ disabled
- Committed profile: ✅ app/src/main/baseline-prof.txt | ❌ not in source tree
- StartupBenchmark: ✅ present | ❌ no verification

### Measurements
| Compilation Mode | Median (ms) | Max (ms) | Δ vs None |
|---|---|---|---|
| None             | 645.8       | 689.1    | —         |
| BaselineProfile  | 401.5       | 432.7    | -37.8%    |

### Findings

#### 🔴 Critical — [BP-001] R8 profile rewriting disabled
**Impact:** Release builds ship with a baseline profile that references unminified class names, so AOT compilation matches nothing.
**Fix:** Set `android.experimental.art-profile-r8-rewriting = true` in `:app/build.gradle.kts` (Rule 7).

#### 🟠 Major — [BP-002] Generator only covers cold start
**Impact:** First-scroll jank unaddressed; profile leaves 15-20% of potential win on the table.
**Fix:** Extend `BaselineProfileGenerator.generate()` to scroll the home feed and navigate to detail screen (Rule 2).

#### 🟡 Minor — [BP-003] No scheduled regeneration in CI
**Impact:** Profile drifts as startup code evolves; eventually contributes nothing.
**Fix:** Add weekly cron trigger to `baseline-profile.yml` with auto-PR (Rule 6).

### Recommended Next Step
Run `./gradlew :app:generateReleaseBaselineProfile` on a rooted AOSP emulator, commit the updated profile, then verify with `./gradlew :macrobenchmark:connectedBenchmarkAndroidTest`.
```
