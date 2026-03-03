---
name: auto-mobile
description: QA review and UX verification using the AutoMobile MCP server (https://kaeawc.github.io/auto-mobile/). Reproduces bugs from crash reports, verifies UX flows, checks accessibility, and captures performance data — all through AI-driven device control.
---

When the user runs `/auto-mobile [task]`, use the AutoMobile MCP tools to control the connected Android device and perform the requested verification. AutoMobile provides AI-driven device control without requiring SDK changes in most cases.

## Setup

```bash
# Install AutoMobile
curl -fsSL https://raw.githubusercontent.com/kaeawc/auto-mobile/main/scripts/install.sh | bash

# Add MCP server to Claude Code (project scope)
claude mcp add auto-mobile auto-mobile

# Verify device is connected
adb devices -l
```

For the Android MCP SDK (in-app observability), add to your debug dependencies only:
```kotlin
// build.gradle.kts — NEVER use implementation(), always debugImplementation()
dependencies {
    debugImplementation(libs.android.mcp.sdk)
}
```

```toml
# libs.versions.toml
[versions]
android-mcp-sdk = "0.1.0"
[libraries]
android-mcp-sdk = { group = "io.github.kaeawc", name = "android-mcp-sdk", version.ref = "android-mcp-sdk" }
```

---

## Tasks

| Command | Action |
|---|---|
| `/auto-mobile` | Full UX audit of current screen |
| `/auto-mobile reproduce <crash report or description>` | Reproduce bug from crash log or description |
| `/auto-mobile ux-flow <flow name>` | Verify a complete user flow end-to-end |
| `/auto-mobile accessibility` | Accessibility audit of current screen |
| `/auto-mobile performance <screen>` | Performance profiling with frame data |
| `/auto-mobile record <scenario>` | Record and annotate a scenario as video |

---

## Bug Reproduction

Paste a crash report or bug description. AutoMobile will navigate the app to reproduce it and capture evidence.

**Prompt pattern:**
```
/auto-mobile reproduce
Crash: NullPointerException in CheckoutViewModel.kt:87
Steps from Crashlytics:
1. User tapped "Proceed to checkout" with empty cart
2. App navigated to CheckoutScreen
3. Crash on cartItems.first() call

Reproduce this crash, capture a screen recording, and collect logcat output
correlated with each navigation step.
```

**What AutoMobile captures:**
- Video recording of reproduction steps
- Logcat output correlated with each action taken
- Device snapshots at point of crash
- Time-series performance data (CPU, memory, frame rate) leading up to crash
- Screenshot of crash state

---

## UX Flow Verification

Verify that a full user flow works correctly and matches expected UX behaviour.

**Prompt pattern:**
```
/auto-mobile ux-flow onboarding
Verify the complete onboarding flow:
1. Cold launch the app
2. Complete email registration with test@example.com / Password123!
3. Verify welcome screen appears with correct user name
4. Tap "Get Started" and verify home screen loads
5. Check that bottom navigation shows correct tabs

Report any deviations from expected flow, unexpected loading states,
or accessibility issues encountered.
```

**AutoMobile navigates, observes, and reports:**
- Each step outcome (pass / fail / unexpected state)
- Visual evidence (screenshots at key points)
- Timing data (how long each transition took)
- Any accessibility warnings encountered during navigation

---

## Accessibility Audit

```
/auto-mobile accessibility

Audit the current screen for:
- Missing content descriptions on interactive elements
- Touch targets smaller than 48dp
- Insufficient colour contrast (WCAG AA: 4.5:1 for text)
- Focus order issues for keyboard/switch navigation
- Missing role semantics on custom interactive components
- TalkBack readability — does the screen make sense when read aloud?
```

AutoMobile uses real device accessibility services to detect issues that static analysis misses.

---

## Performance Profiling

```
/auto-mobile performance ProfileScreen

Navigate to the ProfileScreen and:
1. Scroll through the full content list (slow scroll, then fast fling)
2. Open and close the Edit Profile sheet 3 times
3. Trigger an image load by scrolling past 10 avatar images

Capture:
- Frame render time histogram (identify frames > 16ms)
- Memory delta during session
- CPU spikes correlated with each user interaction
- Any janky frames with what was rendered at that moment
```

**Performance thresholds to flag:**
- Frame render time > 16ms (60fps budget) → warning
- Frame render time > 32ms (30fps) → critical
- Memory increase > 50MB during a simple flow → investigate
- CPU sustained > 80% → investigate

---

## UX Verification Report Format

```
## AutoMobile UX Verification Report
**Flow:** <flow name>
**Device:** <model, Android version>
**Date:** <today>
**Package:** <package.name>

### Summary
<pass/fail overall, 1-2 sentences>

### Step Results
| Step | Result | Duration | Notes |
|---|---|---|---|
| Cold launch | ✅ Pass | 1.2s | Splash visible for 400ms |
| Login form | ✅ Pass | — | |
| Dashboard load | ⚠️ Slow | 3.1s | Expected < 1.5s |
| Navigation | ✅ Pass | 180ms | |

### Issues Found

#### Critical 🔴
- Checkout button has no content description — TalkBack announces "Button" with no context
  Screenshot: [checkout_button.png]

#### Major 🟠
- Dashboard first load takes 3.1s on cold start — Baseline Profile may be missing for this flow

#### Minor 🟡
- Back gesture conflicts with swipe-to-dismiss on BottomSheet on Android 14

### Performance Data
- P95 frame time: 14ms ✅
- Peak memory: 187MB (baseline 134MB, +53MB — investigate image caching)
- Startup TotalTime: 1.2s ✅

### Evidence
- Recording: demo_20260303_143022.mp4
- Screenshots: attached inline above
- Logcat: logcat_20260303_143022.txt
```

---

## Integration with Android MCP SDK

When you need in-app observability (not just ADB-level), use the Android MCP SDK:

```kotlin
// Application.kt — initialise in debug builds only
class MyApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        if (BuildConfig.DEBUG) {
            // SDK auto-detects MCP client via ADB port forwarding
            // No explicit init needed — SDK registers itself
        }
    }
}
```

```bash
# Set up ADB port forwarding so MCP client on workstation
# can talk to the SDK running inside the app on device
adb forward tcp:8080 tcp:8080

# Verify MCP endpoint is reachable
curl http://localhost:8080/health
```

The SDK then exposes internal app state (navigation stack, ViewModel state, database contents) directly to AutoMobile — enabling richer verification than ADB alone.

---

## Safety Notes

- AutoMobile only controls **debug builds** — never use against production APKs on real user accounts
- MCP SDK must use `debugImplementation` — the SDK crashes intentionally if included in release builds
- Screen recordings may contain PII — store them securely and delete after bug is resolved
- Port forwarding (tcp:8080) is only active while `adb forward` is running; it closes when ADB session ends
