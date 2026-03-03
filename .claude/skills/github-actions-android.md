---
name: github-actions-android
description: GitHub Actions CI/CD for Android — Gradle caching with gradle/actions, PR validation, release signing and Play Store deployment, Firebase Test Lab, and Google-recommended GHA patterns.
---

When the user runs `/github-actions-android [task]`, generate or audit the requested GitHub Actions workflow for Android.

## Tasks

| Command | Action |
|---|---|
| `/github-actions-android` | Full CI audit — check all existing workflows |
| `/github-actions-android pr-check` | Scaffold PR validation workflow (lint, test, build) |
| `/github-actions-android release` | Scaffold release workflow (sign, bundle, Play Store) |
| `/github-actions-android firebase` | Add Firebase Test Lab device testing |
| `/github-actions-android build-scan` | Add Gradle Build Scan reporting |
| `/github-actions-android dependency-review` | Add dependency vulnerability review |

---

## Rule 1 — Always Pin Action Versions to Git SHA

```yaml
# Bad — mutable tag, can be hijacked
uses: actions/checkout@v4

# Good — pinned to immutable SHA, safe from tag updates
uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # v4.2.2
```

Every action reference must be pinned to a full SHA, not a branch or tag.

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
  cancel-in-progress: true  # cancel superseded PR runs

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
          cache: gradle

      - name: Setup Gradle
        uses: gradle/actions/setup-gradle@94baf225fe0a508e9a66a5d9bbcef7f4f923f369  # v4.3.0
        with:
          gradle-version: wrapper
          cache-read-only: ${{ github.ref != 'refs/heads/main' }}
          build-scan-publish: true
          build-scan-terms-of-use-url: "https://gradle.com/terms-of-service"
          build-scan-terms-of-use-agree: "yes"

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

## Gradle Caching Configuration

The `gradle/actions/setup-gradle` action handles all caching automatically. Key options:

```yaml
- name: Setup Gradle
  uses: gradle/actions/setup-gradle@94baf225fe0a508e9a66a5d9bbcef7f4f923f369  # v4.3.0
  with:
    gradle-version: wrapper

    # main branch populates the cache; PRs read-only (prevents cache pollution)
    cache-read-only: ${{ github.ref != 'refs/heads/main' }}

    # Configuration cache encryption (prevents secret leakage in cache)
    # Set GRADLE_ENCRYPTION_KEY in repo secrets
    cache-encryption-key: ${{ secrets.GRADLE_ENCRYPTION_KEY }}

    # Gradle Build Scan for every run
    build-scan-publish: true
    build-scan-terms-of-use-url: "https://gradle.com/terms-of-service"
    build-scan-terms-of-use-agree: "yes"
```

**`gradle.properties` for CI:**
```properties
org.gradle.caching=true
org.gradle.parallel=true
org.gradle.configuration-cache=true
org.gradle.configuration-cache.problems=warn
org.gradle.jvmargs=-Xmx4g -XX:+UseG1GC -Dfile.encoding=UTF-8
android.nonTransitiveRClass=true
android.enableJetifier=false
```

---

## Release Workflow (Sign + Play Store)

```yaml
# .github/workflows/release.yml
name: Release

on:
  push:
    tags:
      - 'v[0-9]+.[0-9]+.[0-9]+'   # trigger on version tags: v1.2.3

jobs:
  release:
    name: Build · Sign · Publish
    runs-on: ubuntu-latest
    timeout-minutes: 60
    environment: production  # requires manual approval in GitHub Environments

    steps:
      - name: Checkout
        uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # v4.2.2

      - name: Setup JDK 17
        uses: actions/setup-java@3a4f6e1af504cf6a31855fa899c6aa5355ba6c12  # v4.7.0
        with:
          java-version: 17
          distribution: temurin

      - name: Setup Gradle
        uses: gradle/actions/setup-gradle@94baf225fe0a508e9a66a5d9bbcef7f4f923f369  # v4.3.0
        with:
          gradle-version: wrapper
          cache-read-only: false
          cache-encryption-key: ${{ secrets.GRADLE_ENCRYPTION_KEY }}

      - name: Decode keystore
        run: |
          echo "${{ secrets.RELEASE_KEYSTORE_BASE64 }}" | base64 --decode > ${{ runner.temp }}/release.keystore

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
        if: always()
        run: shred -u ${{ runner.temp }}/release.keystore
```

**Required GitHub Secrets:**
```
RELEASE_KEYSTORE_BASE64     # base64-encoded .jks file
KEYSTORE_PASSWORD           # keystore password
KEY_ALIAS                   # signing key alias
KEY_PASSWORD                # key password
PLAY_SERVICE_ACCOUNT_JSON   # GCP service account JSON with Play API access
GRADLE_ENCRYPTION_KEY       # 32-byte random key for config cache encryption
```

```kotlin
// build.gradle.kts — read signing config from environment (never commit keys)
android {
    signingConfigs {
        create("release") {
            storeFile    = file(System.getenv("STORE_FILE") ?: "missing.jks")
            storePassword = System.getenv("STORE_PASSWORD")
            keyAlias     = System.getenv("KEY_ALIAS")
            keyPassword  = System.getenv("KEY_PASSWORD")
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
    branches: [main]   # run on merge to main only (expensive)

jobs:
  instrumented-tests:
    name: Instrumented Tests (Firebase Test Lab)
    runs-on: ubuntu-latest
    timeout-minutes: 60

    steps:
      - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # v4.2.2

      - uses: actions/setup-java@3a4f6e1af504cf6a31855fa899c6aa5355ba6c12  # v4.7.0
        with:
          java-version: 17
          distribution: temurin

      - uses: gradle/actions/setup-gradle@94baf225fe0a508e9a66a5d9bbcef7f4f923f369  # v4.3.0
        with:
          gradle-version: wrapper
          cache-encryption-key: ${{ secrets.GRADLE_ENCRYPTION_KEY }}

      - name: Build test APKs
        run: |
          ./gradlew assembleDebug
          ./gradlew assembleDebugAndroidTest

      - name: Authenticate to GCP
        uses: google-github-actions/auth@71f986410dfbc7added4569d411d040a91e1c890  # v2.1.8
        with:
          credentials_json: ${{ secrets.GCP_SERVICE_ACCOUNT_JSON }}

      - name: Setup gcloud
        uses: google-github-actions/setup-gcloud@77e7a554d41f0250fb29b9c9628e11174f23aba0  # v2.1.4

      - name: Run on Firebase Test Lab
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

      - name: Upload results
        if: always()
        uses: actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02  # v4.6.2
        with:
          name: firebase-test-results-${{ github.run_id }}
          path: test-results/
          retention-days: 14
```

---

## Dependency Review (Supply Chain Security)

```yaml
# .github/workflows/dependency-review.yml
name: Dependency Review

on:
  pull_request:
    branches: [main]

jobs:
  dependency-review:
    name: Dependency Vulnerability Scan
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: write

    steps:
      - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # v4.2.2

      - name: Dependency Review
        uses: actions/dependency-review-action@ce3cf9537a52e8119d91fd484ab5e8a0d7d7c8e8  # v4.5.0
        with:
          fail-on-severity: high
          comment-summary-in-pr: always
          # Allow specific advisories if needed
          # allow-ghsas: GHSA-xxxx-xxxx-xxxx
```

---

## Workflow Summary

| Workflow | Trigger | Duration | Cost |
|---|---|---|---|
| `pr-check.yml` | Every PR | ~10-15 min | Low |
| `release.yml` | Version tags (`v*.*.*`) | ~20-30 min | Low |
| `firebase-test-lab.yml` | Push to `main` | ~20-40 min | Medium (Firebase billing) |
| `dependency-review.yml` | Every PR | ~2 min | Free |

---

## Workflow Audit Output

```
## GitHub Actions Audit
**Date:** <today>

### Critical 🔴
- release.yml: keystore decoded to working directory — use ${{ runner.temp }} instead
- pr-check.yml: actions pinned to mutable tags (v4), not SHAs — supply chain risk

### Major 🟠
- No concurrency group on PR workflow — parallel PR runs waste minutes and cache
- Configuration cache not enabled in Gradle — adds 30-60s to every run
- No timeout-minutes set — stuck jobs can run for 6 hours and exhaust quota

### Minor 🟡
- No dependency-review workflow — add for supply chain visibility
- Firebase Test Lab runs on every PR — move to main-only to reduce cost
- Build Scan not enabled — missing build performance visibility

### Good ✅
- gradle/actions/setup-gradle used (not manual actions/cache for Gradle)
- Separate production environment with manual approval on release workflow
- Secrets not echoed to logs anywhere
```
