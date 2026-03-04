---
name: github-actions-android
description: GitHub Actions CI/CD for Android — gradle/actions v5 with built-in wrapper validation and caching, PR validation, release signing and Play Store deployment, Firebase Test Lab, dependency graph submission, and supply chain security.
---

When the user runs `/github-actions-android [task]`, generate or audit the requested GitHub Actions workflow for Android.

Reference: https://github.com/gradle/actions

## Tasks

| Command | Action |
|---|---|
| `/github-actions-android` | Full CI audit — check all existing workflows |
| `/github-actions-android pr-check` | Scaffold PR validation workflow (lint, test, build) |
| `/github-actions-android release` | Scaffold release workflow (sign, bundle, Play Store) |
| `/github-actions-android firebase` | Add Firebase Test Lab device testing |
| `/github-actions-android dependency-graph` | Add Gradle dependency graph submission for GitHub security alerts |
| `/github-actions-android dependency-review` | Add dependency vulnerability review on PRs |

---

## Rule 1 — Always Pin Action Versions to Git SHA

```yaml
# Bad — mutable tag, susceptible to tag-override attacks
uses: gradle/actions/setup-gradle@v5

# Good — pinned to immutable commit SHA
uses: gradle/actions/setup-gradle@0723195856401067f7a2779048b490ace7a47d7c  # v5.0.2
```

Every action reference must use a full 40-character SHA, never a branch or tag.

---

## gradle/actions/setup-gradle — v5 Overview

`setup-gradle` (https://github.com/gradle/actions) is the official Gradle action replacing the old `gradle/gradle-build-action`.

**Current version:** v5.0.2 — SHA `0723195856401067f7a2779048b490ace7a47d7c`

Key features in v5:
- **Wrapper validation built-in** — `validate-wrappers: true` by default; no separate `wrapper-validation` step needed
- **Automatic caching** — Gradle User Home (caches, notifications) cached and restored per job; handles cache key collisions automatically
- **Config cache encryption** — provide `cache-encryption-key` to encrypt configuration cache entries (prevents secret leakage)
- **Build Scan publishing** — opt-in; posts scan link to job summary
- **Dependency graph** — generate and submit to GitHub's dependency graph API (enables Dependabot alerts)
- **Job summary** — posts Gradle task results and Build Scan links to the Actions job summary automatically

**Do not use `cache: gradle` in `actions/setup-java` alongside `setup-gradle`** — they would conflict. Let `setup-gradle` own all Gradle caching.

---

## PR Validation Workflow

```yaml
# .github/workflows/pr-check.yml
name: PR Check

on:
  pull_request:
    branches: [main, develop]

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true  # cancel superseded PR runs immediately

permissions:
  contents: read

jobs:
  validate:
    name: Lint · Test · Build
    runs-on: ubuntu-latest
    timeout-minutes: 45

    steps:
      - name: Checkout
        uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # v4.2.2

      - name: Setup JDK 17
        uses: actions/setup-java@3a4f6e1af504cf6a31855fa899c6aa5355ba6c12  # v4.7.0
        with:
          java-version: 17
          distribution: temurin
          # No cache: gradle here — setup-gradle owns all Gradle caching

      - name: Setup Gradle
        uses: gradle/actions/setup-gradle@0723195856401067f7a2779048b490ace7a47d7c  # v5.0.2
        with:
          # validate-wrappers: true is the default — wrapper JAR checksum verified automatically
          # PRs read from cache but don't write (prevents polluting the cache from feature branches)
          cache-read-only: true
          # Encrypt config cache to prevent accidental secret serialisation
          cache-encryption-key: ${{ secrets.GRADLE_ENCRYPTION_KEY }}
          # Post build summary as a PR comment (failures only — keeps PRs clean)
          add-job-summary-as-pr-comment: on-failure

      - name: Run ktlint
        run: ./gradlew ktlintCheck --continue

      - name: Run Detekt
        run: ./gradlew detekt --continue

      - name: Upload lint reports
        if: always()
        uses: actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02  # v4.6.2
        with:
          name: lint-reports-${{ github.run_id }}
          path: |
            **/build/reports/ktlint/
            **/build/reports/detekt/
          retention-days: 7

      - name: Run unit tests
        run: ./gradlew testDebugUnitTest --continue

      - name: Upload test results
        if: always()
        uses: actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02  # v4.6.2
        with:
          name: test-results-${{ github.run_id }}
          path: "**/build/test-results/"
          retention-days: 7

      - name: Build debug APK
        run: ./gradlew assembleDebug

      - name: Upload APK
        uses: actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02  # v4.6.2
        with:
          name: debug-apk-${{ github.run_id }}
          path: app/build/outputs/apk/debug/*.apk
          retention-days: 7
```

---

## Main Branch Build (Cache Population + Dependency Graph)

The main branch job writes to the cache (so PRs can read from it) and submits the dependency graph to GitHub for Dependabot alerts.

```yaml
# .github/workflows/main-build.yml
name: Main Branch Build

on:
  push:
    branches: [main]

permissions:
  contents: write   # required for dependency-graph submission

jobs:
  build:
    name: Build · Test · Submit Dependency Graph
    runs-on: ubuntu-latest
    timeout-minutes: 45

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
          cache-read-only: false   # main branch populates the cache for all other jobs
          cache-encryption-key: ${{ secrets.GRADLE_ENCRYPTION_KEY }}
          # Submit dependency graph — enables Dependabot vulnerability alerts
          dependency-graph: generate-and-submit
          build-scan-publish: true
          build-scan-terms-of-use-url: "https://gradle.com/terms-of-service"
          build-scan-terms-of-use-agree: "yes"

      - name: Run all tests
        run: ./gradlew testDebugUnitTest --continue

      - name: Build debug APK
        run: ./gradlew assembleDebug
```

---

## Gradle Configuration (`gradle.properties`)

```properties
# Checked into the repo — safe defaults for local and CI

org.gradle.caching=true
org.gradle.parallel=true
org.gradle.configuration-cache=true
org.gradle.configuration-cache.problems=warn
org.gradle.jvmargs=-Xmx4g -XX:+UseG1GC -XX:MaxMetaspaceSize=1g -Dfile.encoding=UTF-8

android.nonTransitiveRClass=true
android.enableJetifier=false

kotlin.incremental=true
```

**`GRADLE_ENCRYPTION_KEY` generation** (run once, store as repository secret):
```bash
openssl rand -base64 32
# → paste the output into Settings → Secrets → GRADLE_ENCRYPTION_KEY
```

---

## Release Workflow (Sign + Play Store)

```yaml
# .github/workflows/release.yml
name: Release

on:
  push:
    tags:
      - 'v[0-9]+.[0-9]+.[0-9]+'   # triggers on: v1.2.3

permissions:
  contents: read

jobs:
  release:
    name: Build · Sign · Publish
    runs-on: ubuntu-latest
    timeout-minutes: 60
    environment: production   # GitHub Environment — requires manual approval

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
          cache-read-only: false
          cache-encryption-key: ${{ secrets.GRADLE_ENCRYPTION_KEY }}

      - name: Decode keystore
        # Decode into runner.temp — not the workspace (never lands in git)
        run: echo "${{ secrets.RELEASE_KEYSTORE_BASE64 }}" | base64 --decode > ${{ runner.temp }}/release.keystore

      - name: Build release bundle
        run: ./gradlew bundleProductionRelease
        env:
          STORE_FILE: ${{ runner.temp }}/release.keystore
          STORE_PASSWORD: ${{ secrets.KEYSTORE_PASSWORD }}
          KEY_ALIAS: ${{ secrets.KEY_ALIAS }}
          KEY_PASSWORD: ${{ secrets.KEY_PASSWORD }}

      - name: Upload to Play Store (internal track)
        uses: r0adkll/upload-google-play@935ef9c68bb393a8e6116b1575626a7f5be3a7fb  # v1.1.3
        with:
          serviceAccountJsonPlainText: ${{ secrets.PLAY_SERVICE_ACCOUNT_JSON }}
          packageName: com.example.app
          releaseFiles: app/build/outputs/bundle/productionRelease/*.aab
          track: internal
          status: completed
          changesNotSentForReview: false

      - name: Shred keystore
        if: always()   # runs even if previous steps fail
        run: shred -u ${{ runner.temp }}/release.keystore
```

**Required GitHub Secrets:**
```
RELEASE_KEYSTORE_BASE64     # base64 -i release.jks | pbcopy
KEYSTORE_PASSWORD
KEY_ALIAS
KEY_PASSWORD
PLAY_SERVICE_ACCOUNT_JSON   # GCP service account with releasemanager role
GRADLE_ENCRYPTION_KEY       # openssl rand -base64 32
GCP_SERVICE_ACCOUNT_JSON    # (Firebase Test Lab only)
GCS_BUCKET                  # (Firebase Test Lab only)
```

```kotlin
// build.gradle.kts — read signing from env; never commit key material
android {
    signingConfigs {
        create("release") {
            storeFile     = file(System.getenv("STORE_FILE") ?: "missing.jks")
            storePassword = System.getenv("STORE_PASSWORD")
            keyAlias      = System.getenv("KEY_ALIAS")
            keyPassword   = System.getenv("KEY_PASSWORD")
        }
    }
    buildTypes {
        release { signingConfig = signingConfigs.getByName("release") }
    }
}
```

---

## Firebase Test Lab

```yaml
# .github/workflows/firebase-test-lab.yml
name: Firebase Test Lab

on:
  push:
    branches: [main]   # expensive — run post-merge only, not on every PR

permissions:
  contents: read

jobs:
  instrumented-tests:
    name: Instrumented Tests — Firebase Test Lab
    runs-on: ubuntu-latest
    timeout-minutes: 60

    steps:
      - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # v4.2.2

      - uses: actions/setup-java@3a4f6e1af504cf6a31855fa899c6aa5355ba6c12  # v4.7.0
        with:
          java-version: 17
          distribution: temurin

      - uses: gradle/actions/setup-gradle@0723195856401067f7a2779048b490ace7a47d7c  # v5.0.2
        with:
          cache-encryption-key: ${{ secrets.GRADLE_ENCRYPTION_KEY }}

      - name: Build APKs for testing
        run: |
          ./gradlew assembleDebug assembleDebugAndroidTest

      - name: Authenticate to GCP
        uses: google-github-actions/auth@71f986410dfbc7added4569d411d040a91e1c890  # v2.1.8
        with:
          credentials_json: ${{ secrets.GCP_SERVICE_ACCOUNT_JSON }}

      - name: Setup gcloud CLI
        uses: google-github-actions/setup-gcloud@77e7a554d41f0250fb29b9c9628e11174f23aba0  # v2.1.4

      - name: Run tests on Firebase Test Lab
        run: |
          gcloud firebase test android run \
            --type instrumentation \
            --app app/build/outputs/apk/debug/app-debug.apk \
            --test app/build/outputs/apk/androidTest/debug/app-debug-androidTest.apk \
            --device model=Pixel8,version=34,locale=en,orientation=portrait \
            --device model=Pixel6,version=33,locale=en,orientation=portrait \
            --timeout 10m \
            --results-bucket gs://${{ secrets.GCS_BUCKET }}/test-results/${{ github.run_id }} \
            --environment-variables clearPackageData=true

      - name: Pull test results
        if: always()
        run: gsutil -m cp -r gs://${{ secrets.GCS_BUCKET }}/test-results/${{ github.run_id }} ./test-results

      - name: Upload results artifact
        if: always()
        uses: actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02  # v4.6.2
        with:
          name: firebase-test-results-${{ github.run_id }}
          path: test-results/
          retention-days: 14
```

---

## Dependency Graph Submission

Submits the full Gradle dependency graph to GitHub, enabling Dependabot vulnerability alerts for all transitive dependencies. Already included in `main-build.yml` via `dependency-graph: generate-and-submit`. Use this standalone workflow only if you need a dedicated schedule:

```yaml
# .github/workflows/dependency-graph.yml
name: Dependency Graph

on:
  schedule:
    - cron: '0 8 * * 1'   # every Monday at 08:00 UTC
  workflow_dispatch:

permissions:
  contents: write   # required to submit dependency graph

jobs:
  submit:
    runs-on: ubuntu-latest
    timeout-minutes: 30

    steps:
      - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # v4.2.2

      - uses: actions/setup-java@3a4f6e1af504cf6a31855fa899c6aa5355ba6c12  # v4.7.0
        with:
          java-version: 17
          distribution: temurin

      - uses: gradle/actions/setup-gradle@0723195856401067f7a2779048b490ace7a47d7c  # v5.0.2
        with:
          dependency-graph: generate-and-submit
          cache-encryption-key: ${{ secrets.GRADLE_ENCRYPTION_KEY }}

      - name: Resolve all dependencies
        run: ./gradlew dependencies
```

---

## App Badging — Device Availability Regression Guard

`aapt2 dump badging` outputs every declared permission and required hardware feature from your final APK — including features pulled in by transitive dependencies. A new dependency that silently requires `android.hardware.camera` or `android.hardware.telephony` will block your app from appearing on tablets, TVs, Wear OS, and other device types that don't have those features.

**Strategy:** commit a golden badging file to source control; CI fails if the current APK's badges differ from the golden file. Intentional changes require running `updateReleaseBadging` locally and committing the updated golden file, which surfaces in code review.

### Gradle Tasks to Add

```kotlin
// build.gradle.kts (:app)

val universalApkDir = layout.buildDirectory.dir("outputs/apk/release/universal")
val goldenBadgingFile = rootDir.resolve("app/badging/release.txt")

// Task 1: Generate badging from the universal release APK
val generateReleaseBadging by tasks.registering(Exec::class) {
    dependsOn("packageReleaseUniversalApk")
    description = "Generates aapt2 badging output for the release universal APK"

    val apkFile = universalApkDir.map { dir ->
        dir.asFileTree.matching { include("*.apk") }.singleFile
    }
    inputs.files(apkFile)
    outputs.file(layout.buildDirectory.file("badging/release.txt"))

    doFirst {
        val aapt2 = android.sdkDirectory.resolve(
            "build-tools/${android.buildToolsVersion}/aapt2"
        )
        commandLine(aapt2, "dump", "badging", apkFile.get().absolutePath)
        standardOutput = outputs.files.singleFile.outputStream()
    }
}

// Task 2: Update the golden file (run locally after intentional changes)
val updateReleaseBadging by tasks.registering(Copy::class) {
    dependsOn(generateReleaseBadging)
    description = "Updates the committed golden badging file — run locally and commit the result"

    from(layout.buildDirectory.file("badging/release.txt"))
    into(goldenBadgingFile.parentFile)
    rename { goldenBadgingFile.name }
}

// Task 3: Validate current APK against the golden file — CI runs this
val checkReleaseBadging by tasks.registering {
    dependsOn(generateReleaseBadging)
    description = "Fails if the release APK's badging has changed from the committed golden file"

    inputs.files(layout.buildDirectory.file("badging/release.txt"), goldenBadgingFile)

    doLast {
        val generated = layout.buildDirectory.file("badging/release.txt").get().asFile.readText()
        val golden    = goldenBadgingFile.readText()

        if (generated != golden) {
            error(
                """
                Badging mismatch — the release APK's required features have changed.

                This could be caused by a new dependency adding an implicit hardware feature requirement
                (e.g., android.hardware.camera, android.hardware.telephony) that reduces device availability
                across phones, tablets, foldables, TVs, Wear OS, and cars.

                To review the diff:
                  diff app/badging/release.txt build/badging/release.txt

                If the change is intentional:
                  ./gradlew updateReleaseBadging
                  # commit app/badging/release.txt and include it in your PR for review
                """.trimIndent()
            )
        }
    }
}
```

Commit the initial golden file once setup is done:
```bash
./gradlew updateReleaseBadging
git add app/badging/release.txt
git commit -m "chore: add initial aapt2 badging golden file"
```

### GitHub Actions Integration

Add `checkReleaseBadging` to the PR validation workflow as a dedicated job so it fails fast before the full build:

```yaml
  badging-check:
    name: App Badging Check
    runs-on: ubuntu-latest
    timeout-minutes: 20

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
          cache-read-only: true
          cache-encryption-key: ${{ secrets.GRADLE_ENCRYPTION_KEY }}

      - name: Check release badging
        run: ./gradlew checkReleaseBadging

      - name: Upload badging diff on failure
        if: failure()
        uses: actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02  # v4.6.2
        with:
          name: badging-diff-${{ github.run_id }}
          path: |
            app/badging/release.txt
            app/build/badging/release.txt
          retention-days: 7
```

### What the Badging File Looks Like

```
# app/badging/release.txt — committed to source control
package: name='com.example.app' versionCode='10' versionName='1.0.0'
sdkVersion:'26'
targetSdkVersion:'35'
uses-permission: name='android.permission.INTERNET'
uses-permission: name='android.permission.ACCESS_NETWORK_STATE'
uses-feature: name='android.hardware.touchscreen' required='false'
application-label:'My App'
...
```

**Danger signals to watch for in diffs:**
- `uses-feature: name='android.hardware.camera' required='true'` — blocks tablets, TVs, Wear OS
- `uses-feature: name='android.hardware.telephony' required='true'` — blocks Wi-Fi-only tablets
- `uses-feature: name='android.hardware.location.gps' required='true'` — blocks many TVs and PCs
- Any `required='true'` feature that wasn't there before a dependency update

**Fix:** if a library adds a feature requirement you don't actually need, override it in your manifest:
```xml
<!-- AndroidManifest.xml — override implicit requirement from library -->
<uses-feature android:name="android.hardware.camera" android:required="false" />
```

---

## Dependency Review (PR Supply Chain Check)

```yaml
# .github/workflows/dependency-review.yml
name: Dependency Review

on:
  pull_request:
    branches: [main]

permissions:
  contents: read
  pull-requests: write

jobs:
  dependency-review:
    name: Dependency Vulnerability Scan
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # v4.2.2

      - name: Dependency Review
        uses: actions/dependency-review-action@ce3cf9537a52e8119d91fd484ab5e8a0d7d7c8e8  # v4.5.0
        with:
          fail-on-severity: high
          comment-summary-in-pr: always
```

---

## Workflow Map

| Workflow | Trigger | Cache | Notes |
|---|---|---|---|
| `pr-check.yml` (+ `badging-check` job) | Every PR | Read-only | Fast; cancels stale runs; badging guards device availability |
| `main-build.yml` | Push to `main` | Read+Write | Populates cache; submits dep graph |
| `release.yml` | Tag `v*.*.*` | Read+Write | Requires `production` env approval |
| `firebase-test-lab.yml` | Push to `main` | Read-only | Firebase billing applies |
| `dependency-graph.yml` | Weekly schedule | Read-only | Optional if using main-build |
| `dependency-review.yml` | Every PR | None | Free; ~2 min |

---

## Workflow Audit Output

```
## GitHub Actions Audit
**Date:** <today>

### Critical 🔴
- pr-check.yml line 12: uses gradle/actions/setup-gradle@v5 — must pin to SHA
  Fix: gradle/actions/setup-gradle@0723195856401067f7a2779048b490ace7a47d7c  # v5.0.2
- release.yml line 31: keystore decoded to $GITHUB_WORKSPACE — use ${{ runner.temp }}
- No GRADLE_ENCRYPTION_KEY — configuration cache may serialise secrets

### Major 🟠
- No concurrency group on pr-check workflow — wastes minutes on superseded runs
- cache: gradle set in setup-java AND setup-gradle — remove from setup-java
- firebase-test-lab triggers on every PR — expensive; move to push:main only
- No timeout-minutes on any job — stuck jobs run for 6h and exhaust quota

### Minor 🟡
- No dependency-graph submission — Dependabot blind to transitive vulnerabilities
- Build Scan not enabled on main build — missing build performance visibility
- No dependency-review workflow — PRs adding vulnerable deps go undetected
- No app/badging/release.txt golden file — add checkReleaseBadging to guard device availability (tablets, TVs, Wear OS, foldables) against implicit feature regressions from dependency updates

### Good ✅
- gradle/actions/setup-gradle used (not manual actions/cache)
- Production environment with required reviewers on release workflow
- Secrets not echoed to logs
- Concurrency cancel-in-progress on PR workflow
```
