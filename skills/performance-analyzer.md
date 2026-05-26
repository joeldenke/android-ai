---
name: performance-analyzer
description: Trace-based profiling with Android Performance Analyzer (APA) and Perfetto — captures system traces, runs AI-assisted root-cause analysis, generates Perfetto SQL queries from natural language, diagnoses startup, jank, memory, and GPU regressions, and integrates bulk analysis into CI via the Profiling Manager API.
---

When the user runs `/performance-analyzer [task] [args]`, drive a trace-based profiling workflow using **Android Performance Analyzer (APA)** — Google's standalone desktop profiler announced at Google I/O 2026 that replaces the legacy Android Studio profilers — together with **Perfetto** as the underlying trace format and query engine.

This skill is the **trace-based** counterpart to [`debug-performance`](./debug-performance.md). Use `debug-performance` for code-level fixes (Compose recomposition, leaks, lambda stability). Use **this** skill when you need to:

- Capture a real device system trace and find out *why* something is slow.
- Translate a question ("why is cold start regressing on Pixel 8?") into a Perfetto SQL query.
- Compare traces across builds in CI to detect regressions before they ship.
- Read GPU counters (Qualcomm Snapdragon Profiler, Arm Mali, PowerVR, Samsung Xclipse) alongside CPU traces.

Reference: https://developer.android.com/studio/profile/performance-analyzer (Google I/O 2026)

## Tasks

| Command | Action |
|---|---|
| `/performance-analyzer` | Guided trace workflow — capture, open in APA, ask the AI assistant for hotspots, summarise findings |
| `/performance-analyzer startup` | Cold-start breakdown — Application.onCreate → Activity.onCreate → first frame, identifies slow ContentProviders, class loading, first composition |
| `/performance-analyzer jank` | Frame-by-frame analysis against the 120 Hz budget (8.33 ms) — finds long main-thread slices, RenderThread stalls, GPU waits |
| `/performance-analyzer memory` | Heap dump + native allocations + graphics memory (from GPU counters) — locates retained allocations and leak suspects |
| `/performance-analyzer perfetto-sql <question>` | Natural-language → Perfetto SQL via the `perfetto-sql` Android CLI skill |
| `/performance-analyzer ci` | Scaffold the Profiling Manager workflow for bulk trace comparison across builds |

---

## Rule 1 — Installing APA and the Perfetto Skills

APA ships in two surfaces — pick whichever fits your workflow. Both read the same `.perfetto-trace` format, so traces are portable.

### Option A — Standalone Desktop App (recommended)

The standalone APA decouples profiling from Android Studio's release train and works against any device/emulator regardless of which Studio version built the APK.

```bash
# macOS
brew install --cask android-performance-analyzer

# Linux
curl -fsSL https://dl.google.com/android/apa/apa-linux-x86_64.tar.gz \
  | tar -xz -C ~/Applications

# Windows (PowerShell)
winget install Google.AndroidPerformanceAnalyzer
```

### Option B — Inside Android Studio (Panda 4 canary+)

Android Studio **Panda 4 canary** ships APA as the replacement **System Trace** viewer. Older versions (Iguana / Jellyfish / Koala) still show the legacy CPU/Memory profilers — these are deprecated and will be removed in the Quokka release.

```
Android Studio Panda 4+
  → View → Tool Windows → Performance Analyzer
  → Replaces: Profiler (Run → Profile)
```

### Install the Perfetto AI Skills via Android CLI

The AI features (natural-language queries, root-cause analysis) live in the Android CLI as separate skills. Install both:

```bash
# Capture + AI analysis of .perfetto-trace files
android skills add --skill=perfetto-analysis

# Natural language → Perfetto SQL
android skills add --skill=perfetto-sql

# Verify
android skills list | grep perfetto
# perfetto-analysis  v1.2.0   AI-assisted analysis of system traces
# perfetto-sql       v1.0.4   Natural language to Perfetto SQL queries
```

Both skills auto-register with Claude Code, Cursor, and Codex CLI — once installed, calling `/performance-analyzer perfetto-sql <question>` will dispatch through them.

---

## Rule 2 — Capturing a Trace

Three capture surfaces, in order of preference:

### 2a. APA Built-In Capture (interactive)

Open APA → connect device over ADB → press **Record**. The default config captures CPU + scheduling + atrace + frame timing for 10 seconds. For startup, use **Record on Launch** which traces from process fork through first frame.

### 2b. `adb shell perfetto` (scripted, reproducible)

The reliable option for CI and regression bisection. Write a config file once and reuse it.

```protobuf
# perfetto-startup.pbtx — recommended startup config
buffers {
  size_kb: 65536
  fill_policy: DISCARD
}

# CPU frequency + scheduling — required to see core stalls and big.LITTLE migration
data_sources {
  config {
    name: "linux.ftrace"
    ftrace_config {
      ftrace_events: "sched/sched_switch"
      ftrace_events: "sched/sched_wakeup"
      ftrace_events: "sched/sched_wakeup_new"
      ftrace_events: "sched/sched_waking"
      ftrace_events: "power/cpu_frequency"
      ftrace_events: "power/cpu_idle"
      ftrace_events: "power/suspend_resume"
      atrace_categories: "am"      # ActivityManager — process start, activity lifecycle
      atrace_categories: "wm"      # WindowManager — surface creation, first frame
      atrace_categories: "view"    # View hierarchy — measure/layout/draw
      atrace_categories: "gfx"     # Graphics — RenderThread, Choreographer
      atrace_categories: "res"     # Resources — asset / drawable inflation
      atrace_categories: "dalvik"  # Class loading, GC
      atrace_apps: "com.example.app"
    }
  }
}

# Process metadata — required for joining slices to processes by name
data_sources {
  config { name: "linux.process_stats" }
}

# Trace duration — bump for jank investigations; keep tight for startup
duration_ms: 10000
```

Capture, pull, and open:

```bash
# Push the config to the device
adb push perfetto-startup.pbtx /data/local/tmp/

# Record (writes to a world-readable location)
adb shell perfetto \
  --config /data/local/tmp/perfetto-startup.pbtx \
  --txt \
  -o /data/misc/perfetto-traces/startup.perfetto-trace

# Pull and open in APA
adb pull /data/misc/perfetto-traces/startup.perfetto-trace
apa open startup.perfetto-trace
```

### 2c. In-App Capture via `androidx.tracing.perfetto`

For traces that need to start before the user clicks Record (e.g., process warm starts), enable the in-app tracer:

```kotlin
// :app/build.gradle.kts
dependencies {
    implementation("androidx.tracing:tracing-perfetto:1.0.0")
    implementation("androidx.tracing:tracing-perfetto-binary:1.0.0")
}

// Trigger from adb without restarting the app:
//   adb shell am broadcast \
//     -a androidx.tracing.perfetto.action.ENABLE_TRACING \
//     com.example.app
```

### GPU Counters

APA pulls GPU counters from whichever vendor stack is on the device:

| Vendor | Source | What you see |
|---|---|---|
| Qualcomm Snapdragon | Snapdragon Profiler agent (bundled in APA 1.2+) | GPU clock, ALU/TEX cycles, vertex/fragment shader load |
| Arm Mali | Streamline gator (built into AOSP) | Job slot occupancy, tiler throughput, memory bandwidth |
| Imagination PowerVR | PVRTune | USC load, TPU cache miss, primitive throughput |
| Samsung Xclipse (RDNA) | Samsung Performance HUD | CU occupancy, ROP fill rate, geometry stage timing |

GPU counter capture has no extra cost on supported devices — APA auto-detects the GPU and enables the right data source.

---

## Rule 3 — AI-Assisted Analysis

APA ships an LLM-backed assistant that reads the loaded trace and answers questions in natural language. The same backend is exposed to Claude Code, Cursor, and Codex CLI via the `perfetto-analysis` skill — so you can run analysis from the terminal without opening the desktop app.

### In APA (GUI)

Open a trace → click **Ask AI** in the top-right → type the question. The assistant grounds its answer in actual slice IDs from the trace and links back to the relevant timeline regions.

Useful prompts:

```
Why is cold start slow on this trace?
Which ContentProvider takes the longest in Application.onCreate?
List frames longer than 16ms and their causes.
Compare main-thread CPU time spent on layout vs draw.
Find every Binder transaction longer than 5ms and group by remote process.
What's holding the RenderThread between frame 142 and frame 158?
```

### Via Claude Code / Codex (CLI)

```bash
# Single trace
claude "Use the perfetto-analysis skill to analyse startup.perfetto-trace.
        Focus on Application.onCreate. List the top 5 slowest slices with their durations and parent threads."

# Or directly from the Android CLI skill
android skills run perfetto-analysis \
  --trace startup.perfetto-trace \
  --query "Why does the first frame take 1.2 seconds after Activity.onCreate returns?"
```

### What "Root Cause Analysis" Returns

The skill responds with structured findings, not prose:

```json
{
  "trace": "startup.perfetto-trace",
  "phase": "Application.onCreate",
  "total_duration_ms": 487,
  "hotspots": [
    {
      "slice": "FirebaseInitProvider.onCreate",
      "self_time_ms": 142,
      "thread": "main",
      "evidence_slice_id": 8421,
      "recommendation": "Defer Firebase init to a background WorkInitializer (see androidx.startup)."
    },
    {
      "slice": "Class loading: kotlin.reflect.full.*",
      "self_time_ms": 89,
      "thread": "main",
      "evidence_slice_id": 9013,
      "recommendation": "Remove kotlin-reflect dependency from startup path; consider kotlinx.serialization codegen instead."
    }
  ]
}
```

Pass the `evidence_slice_id` back to APA to jump straight to that slice on the timeline — every claim is verifiable.

---

## Rule 4 — Perfetto SQL (Natural Language → Query)

The Perfetto trace processor exposes a SQL surface over every captured event. The `perfetto-sql` skill turns plain-English questions into runnable queries.

### Invoking the skill

```bash
# Inline (no trace needed — generates a query you can run later)
/performance-analyzer perfetto-sql "frames longer than the 120Hz budget grouped by process"

# Against a specific trace
android skills run perfetto-sql \
  --trace jank.perfetto-trace \
  --query "frames longer than 8.33ms grouped by process" \
  --execute
```

### Common Query Recipes

#### Slow frames (jank)

```sql
-- Every frame longer than the 120 Hz budget (8.33 ms), with the process and reason
SELECT
  process.name                                          AS process,
  actual.ts                                             AS frame_ts,
  actual.dur / 1e6                                      AS frame_ms,
  actual.jank_type                                      AS jank_reason,
  actual.surface_frame_token                            AS surface_token
FROM actual_frame_timeline_slice AS actual
JOIN thread USING (utid)
JOIN process USING (upid)
WHERE actual.dur > 8.33 * 1e6                           -- nanoseconds
ORDER BY actual.dur DESC
LIMIT 50;
```

#### Cold start phases

```sql
-- Timing breakdown: process fork → Application.onCreate → Activity.onCreate → reportFullyDrawn
WITH startup AS (
  SELECT
    s.name           AS phase,
    s.ts             AS start_ts,
    s.dur            AS dur_ns
  FROM slice s
  JOIN thread USING (utid)
  JOIN process USING (upid)
  WHERE process.name = 'com.example.app'
    AND s.name IN (
      'Application.onCreate',
      'Activity.onCreate',
      'activityStart',
      'activityResume',
      'reportFullyDrawn',
      'Choreographer#doFrame'
    )
)
SELECT phase, dur_ns / 1e6 AS dur_ms
FROM startup
ORDER BY start_ts ASC;
```

#### Memory — top allocations by retained size

```sql
-- Retained bytes per class from the loaded heap graph
SELECT
  c.name                                                AS class_name,
  COUNT(*)                                              AS instances,
  SUM(o.self_size)                                      AS shallow_bytes,
  SUM(o.retained_size)                                  AS retained_bytes
FROM heap_graph_object o
JOIN heap_graph_class c ON o.type_id = c.id
WHERE o.reachable = 1
GROUP BY c.name
ORDER BY retained_bytes DESC
LIMIT 25;
```

```sql
-- Native allocations not yet freed at end of trace
SELECT
  callsite_id,
  SUM(size)                                             AS bytes_outstanding,
  COUNT(*)                                              AS allocations
FROM heap_profile_allocation
WHERE upid = (SELECT upid FROM process WHERE name = 'com.example.app')
GROUP BY callsite_id
ORDER BY bytes_outstanding DESC
LIMIT 25;
```

#### Thread contention

```sql
-- Time the main thread spent in S (sleeping), D (uninterruptible), or Runnable-waiting states
SELECT
  ts.state                                              AS state,
  SUM(ts.dur) / 1e6                                     AS total_ms,
  COUNT(*)                                              AS occurrences
FROM thread_state ts
JOIN thread t USING (utid)
JOIN process p USING (upid)
WHERE p.name = 'com.example.app'
  AND t.name = 'main'
  AND ts.state IN ('S', 'D', 'R')                       -- Sleeping, uninterruptible, runnable
GROUP BY ts.state
ORDER BY total_ms DESC;
```

#### Binder transactions blocking the main thread

```sql
SELECT
  s.name                                                AS binder_call,
  s.dur / 1e6                                           AS dur_ms,
  remote.process_name                                   AS remote_process
FROM slice s
JOIN thread t   USING (utid)
JOIN process p  USING (upid)
LEFT JOIN android_binder_outgoing remote ON remote.binder_txn_id = s.id
WHERE p.name = 'com.example.app'
  AND t.name = 'main'
  AND s.name LIKE 'binder transaction%'
  AND s.dur > 1e6                                       -- > 1 ms
ORDER BY s.dur DESC;
```

Run any query directly via `trace_processor_shell` if you prefer not to use the skill:

```bash
trace_processor_shell startup.perfetto-trace -q query.sql
```

---

## Rule 5 — Startup Analysis

Cold start is a sequence of well-known phases. APA's startup view splits the timeline into them and highlights any phase that exceeds its budget on the target device class.

### Phase Budgets (Pixel-class device, API 34+)

| Phase | Budget | What APA shows |
|---|---|---|
| Process fork → `bindApplication` | 80 ms | `Zygote → fork` slice, dex file load count |
| `Application.onCreate` (incl. ContentProviders) | 120 ms | Per-provider slice; ranked by self-time |
| `Activity.onCreate` | 100 ms | Inflation, ViewModel init, first composition |
| First measure/layout/draw | 80 ms | `Choreographer#doFrame` slices on main thread |
| First frame rendered (Time-to-Initial-Display) | 500 ms total | Vertical line at `reportFullyDrawn` |

### What to Look For

1. **Slow ContentProviders** — every dependency that ships an `androidx.startup.Initializer` or its own `<provider>` declaration runs synchronously before `Application.onCreate` even returns. APA groups providers under the **Pre-Application** band; sort by self-time. Common offenders: WorkManager, Firebase, EmojiCompat, Sentry, Datadog.

2. **Slow class loading** — look for long `Class loading: <fqcn>` slices on the main thread. Heavy reflection libraries (`kotlin-reflect`, Moshi reflective adapters, Jackson) show up here.

3. **Slow first composition** — Compose's first frame includes the entire composition tree's first invocation. APA marks it with the `androidx.compose.runtime.SnapshotKt#sendApplyNotifications` slice. If this exceeds 60 ms, you likely need a baseline profile (see [`baseline-profile`](./baseline-profile.md)).

4. **Disk I/O on the main thread** — APA flags any `f2fs_readpage` / `block_rq_issue` ftrace events while the main thread is RUNNING. SharedPreferences `commit()` and `Room` synchronous queries are the usual culprits.

5. **Synchronous network on startup** — any `OkHttp ConnectInterceptor` slice on the main thread is a P0 bug.

Pair the trace with a benchmark — see [`baseline-profile.md`](./baseline-profile.md) Rule 5 for the `StartupBenchmark` template.

---

## Rule 6 — Jank Analysis

### Frame Budgets

| Refresh rate | Frame budget | APA threshold for "janky" |
|---|---|---|
| 60 Hz | 16.67 ms | > 16.67 ms |
| 90 Hz | 11.11 ms | > 11.11 ms |
| 120 Hz | 8.33 ms | > 8.33 ms |

APA reads the actual display refresh rate from `SurfaceFlinger` and applies the right budget per-frame. Modern devices with variable refresh rate (LTPO) report per-frame refresh — APA respects this.

### Reading `Choreographer#doFrame`

Each frame is a `Choreographer#doFrame` slice on the main thread, followed by an `RTtl#DrawFrame` (or `DrawFrames`) slice on the RenderThread. Three failure modes:

1. **Main-thread overrun** — `Choreographer#doFrame` itself exceeds the budget. Inspect its child slices for the long pole. Usually:
   - `inflate` → view inflation on scroll (use Compose or `RecyclerView` with view holders).
   - `measure` / `layout` → constraint thrash, deeply nested layouts.
   - `Composition` → unstable inputs causing wholesale recomposition (cross-reference [`debug-performance`](./debug-performance.md)).
   - `Trace.beginSection("MyExpensiveWork")` → your own slow code, instrumented.

2. **RenderThread stall** — main thread finishes on time but `RTtl#DrawFrame` runs long. Cause: hardware canvas commands generated faster than the GPU can consume (overdraw, complex shaders, large bitmap uploads). Check GPU counters in APA — if GPU clock is at 100% during the stall, you're GPU-bound.

3. **Buffer queue starvation** — both main and RenderThread are idle but `SurfaceFlinger` reports a missed frame. Cause: triple-buffering exhausted because the GPU previously fell behind. Look at the **Display** track: gaps between `app: presented` slices indicate dropped frames.

### Diagnostic SQL

```sql
-- Janky frames + the top main-thread slice during each
WITH jank AS (
  SELECT actual.ts, actual.dur, actual.surface_frame_token
  FROM actual_frame_timeline_slice actual
  JOIN process USING (upid)
  WHERE process.name = 'com.example.app'
    AND actual.jank_type != 'None'
)
SELECT
  jank.surface_frame_token                              AS frame,
  jank.dur / 1e6                                        AS frame_ms,
  s.name                                                AS longest_main_slice,
  s.dur / 1e6                                           AS slice_ms
FROM jank
JOIN slice s ON s.ts BETWEEN jank.ts AND (jank.ts + jank.dur)
JOIN thread t USING (utid)
WHERE t.name = 'main'
ORDER BY jank.dur DESC, s.dur DESC
LIMIT 50;
```

---

## Rule 7 — Memory Profiling

APA replaces the old Memory Profiler with two integrated panels:

### Heap Dump Panel

Triggered from APA's **Capture Heap Dump** button or via:

```bash
adb shell am dumpheap com.example.app /data/local/tmp/heap.hprof
adb pull /data/local/tmp/heap.hprof
apa open heap.hprof
```

What to read:

- **Retained-size column** — sort descending. Anything > 1 MB held by a non-cache object is suspicious.
- **Dominator tree** — shows which single object would be GC'd if removed. Activities and Fragments listed here after navigation = leak.
- **GC roots** — every retained object traces back to a GC root path. Common leak paths: `Choreographer` callbacks, static `Handler`, registered `BroadcastReceiver`.

### Graphics Memory (GPU Counters)

The old profilers had no view into graphics memory — APA fixes this by joining GPU counter data to the process. The **Graphics Memory** track shows:

- **Texture memory** — large bitmaps not downsampled (cross-reference Coil `Size()` hint in [`debug-performance`](./debug-performance.md)).
- **Surface memory** — leaked `SurfaceView` / `TextureView` from Fragments not detaching properly.
- **Shader cache** — abnormal growth suggests dynamic shader generation (avoid).

### Useful Heap Queries

```sql
-- Activities retained after they should have been destroyed
SELECT c.name, COUNT(*) AS retained_instances
FROM heap_graph_object o
JOIN heap_graph_class c ON o.type_id = c.id
WHERE c.name LIKE '%Activity'
  AND o.reachable = 1
GROUP BY c.name
HAVING COUNT(*) > 1                                     -- more than one live = leak suspect
ORDER BY retained_instances DESC;
```

```sql
-- Static fields holding the largest retained subtrees
SELECT
  c.name                                                AS class_name,
  f.field_name,
  o.retained_size
FROM heap_graph_reference r
JOIN heap_graph_object o     ON r.owned_id = o.id
JOIN heap_graph_class c      ON o.type_id  = c.id
JOIN heap_graph_field f      ON r.field_id = f.id
WHERE r.owner_id IS NULL                                -- static reference
ORDER BY o.retained_size DESC
LIMIT 25;
```

Pair findings with LeakCanary in debug builds — see [`debug-performance`](./debug-performance.md) Memory section.

---

## Rule 8 — Bulk Trace Analysis in CI (Profiling Manager API)

The **Profiling Manager** is APA's headless backend — it captures, stores, and queries traces at scale. Use it to:

- Capture a trace on every PR that touches startup-critical code.
- Compare median startup time across the last 30 builds and fail the build on regression.
- Run the same Perfetto SQL against thousands of traces from production (via Firebase Performance integration).

### Setup

```kotlin
// :macrobenchmark/build.gradle.kts
dependencies {
    implementation("com.google.android.profiling:profiling-manager:1.0.0")
    implementation("com.google.android.profiling:profiling-manager-perfetto:1.0.0")
}
```

```kotlin
// macrobenchmark/src/main/java/.../PerformanceRegressionTest.kt
@RunWith(AndroidJUnit4::class)
class PerformanceRegressionTest {

    @get:Rule
    val benchmarkRule = MacrobenchmarkRule()

    @get:Rule
    val profilingRule = ProfilingManagerRule(
        config = ProfilingConfig.perfetto {
            durationMs = 10_000
            ftraceCategories(Ftrace.SCHED, Ftrace.CPU_FREQ)
            atraceCategories(Atrace.AM, Atrace.WM, Atrace.GFX, Atrace.VIEW)
        },
        // Uploads the captured trace to the Profiling Manager service for diffing.
        uploadOnFailure = true,
        regressionThresholds = RegressionThresholds(
            startupP95Ms = 600,
            jankyFramePercent = 1.0,
        ),
    )

    @Test
    fun startupRegression() = benchmarkRule.measureRepeated(
        packageName = "com.example.app",
        metrics = listOf(StartupTimingMetric(), FrameTimingMetric()),
        iterations = 10,
        startupMode = StartupMode.COLD,
    ) {
        pressHome()
        startActivityAndWait()
    }
}
```

### CI Workflow

```yaml
# .github/workflows/perf-regression.yml
name: Perf Regression

on:
  pull_request:
    paths:
      - 'app/src/main/**'
      - 'feature/**/src/main/**'

jobs:
  trace-and-compare:
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
          cache-encryption-key: ${{ secrets.GRADLE_ENCRYPTION_KEY }}

      - name: Run perf regression test
        uses: reactivecircus/android-emulator-runner@62dbb605bba737720e10b196cb4220d374026a6d  # v2.33.0
        with:
          api-level: 34
          target: aosp_atd
          arch: x86_64
          profile: pixel_6
          disable-animations: true
          script: |
            ./gradlew :macrobenchmark:connectedBenchmarkAndroidTest \
              -Pandroid.testInstrumentationRunnerArguments.class=com.example.app.macrobenchmark.PerformanceRegressionTest

      - name: Compare against baseline build
        env:
          PROFILING_MANAGER_TOKEN: ${{ secrets.PROFILING_MANAGER_TOKEN }}
        run: |
          apa-cli compare \
            --baseline-build main@HEAD \
            --candidate-build ${{ github.sha }} \
            --metric timeToInitialDisplayMs \
            --metric jankyFramePercent \
            --fail-on-regression-percent 5

      - name: Upload traces for inspection
        if: always()
        uses: actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02  # v4.6.2
        with:
          name: perf-traces-${{ github.run_id }}
          path: macrobenchmark/build/outputs/connected_android_test_additional_output/*.perfetto-trace
          retention-days: 14
```

### Querying the Profiling Manager from Claude Code

```bash
# Compare two builds against each other
claude "Use the perfetto-analysis skill to compare the median startup time
        across the last 5 main-branch builds vs the last 5 builds on the
        compose-upgrade branch. Identify any slice whose median grew by >10%."
```

The skill calls the Profiling Manager's batch query API, runs the SQL against every matching trace, and returns a ranked regression report.

---

## Common Pitfalls

| Pitfall | Symptom | Fix |
|---|---|---|
| Capturing on a debuggable build | Traces show 2-3x slower than reality due to JNI checks | Use the `benchmark` build type (release + profileable) — see [`baseline-profile`](./baseline-profile.md) Rule 1 |
| Atrace categories missing | App-level slices (`Trace.beginSection`) absent from trace | Add `atrace_apps: "com.example.app"` to the perfetto config (Rule 2) |
| Short trace duration | Cold start visible but first scroll cut off | Bump `duration_ms` to at least 12000 for startup + first interaction |
| Wrong refresh rate budget | "No jank" but users report stutter on 120Hz device | Read budget from per-frame refresh in trace, not from a hardcoded 16.67 ms |
| GPU counters empty | Vendor track shows zero data | Counters require API 31+ on Qualcomm, API 33+ on Mali — check device support in APA's capture dialog |
| AI analysis hallucinates a slice | Recommendation references a slice not in the trace | Always click through to the `evidence_slice_id` in APA to verify before acting |
| Perfetto SQL `duration_ms` confusion | Query returns no rows | All durations in the trace are nanoseconds — multiply your threshold by `1e6` |
| Comparing across device classes | "Regression" between Pixel 8 and Pixel 4a | Profiling Manager comparisons must hold device, OS, and build type constant |
| Heap dump captured during GC | Retained sizes look inflated | Trigger `adb shell am force-gc` before `am dumpheap` |
| Profiling Manager regression flaky | Tests fail intermittently with no code change | Increase `iterations` to 20+, use median (not p95) for thresholds, hold one device per CI runner |

---

## Checklist

- [ ] APA installed (standalone or via Android Studio Panda 4+)
- [ ] `perfetto-analysis` and `perfetto-sql` Android CLI skills installed
- [ ] Reusable `perfetto-*.pbtx` config files committed to `tools/perfetto/`
- [ ] Traces captured on `benchmark` (release + profileable) build, never `debug`
- [ ] App-level atrace section (`atrace_apps: "com.example.app"`) enabled in config
- [ ] `androidx.tracing:tracing-perfetto` added for in-app trace start
- [ ] Phase budgets defined for startup, jank, and memory tracks
- [ ] AI analysis verified by clicking through `evidence_slice_id` before acting on each recommendation
- [ ] Perfetto SQL queries version-controlled under `tools/perfetto/queries/`
- [ ] Profiling Manager wired into `:macrobenchmark` with `RegressionThresholds`
- [ ] CI workflow runs perf regression on every PR that touches startup-critical code
- [ ] Traces uploaded as artifacts on regression for offline inspection
- [ ] GPU counter capture verified on the project's target device set (Qualcomm + Mali at minimum)
- [ ] Heap dumps captured after `am force-gc` to avoid GC-window noise

---

## Output Format

```markdown
## Performance Trace Audit
**Trace:** <filename>.perfetto-trace
**Device:** <model> (<chipset>, <gpu>) — Android <api-level>, <refresh-rate> Hz
**Build:** <variant> (R8: on/off, Baseline Profile: present/absent)
**Captured:** <ISO timestamp> — duration <ms>

### Headline Metrics
| Metric | Value | Budget | Status |
|---|---|---|---|
| Time to Initial Display | 612 ms | 500 ms | FAIL |
| Time to Fully Drawn      | 1,140 ms | 1,000 ms | FAIL |
| Janky frame % (120 Hz)   | 4.2%  | <1%    | FAIL |
| GPU clock peak           | 845 MHz | —    | OK   |
| Peak heap                | 184 MB | 256 MB | OK   |

### Findings

#### Critical — [PERF-101] FirebaseInitProvider blocks Application.onCreate for 142 ms
**Phase:** Application.onCreate (Pre-Application providers)
**Evidence:** slice_id=8421 on thread `main`, dur=142.3 ms
**Root cause:** Firebase SDK initialises synchronously via its bundled ContentProvider before `Application.onCreate` runs.
**Fix:** Replace the auto-init provider with a deferred `androidx.startup.Initializer` that runs after the first frame; remove `com.google.firebase.provider.FirebaseInitProvider` from the merged manifest.
**File:** `app/src/main/AndroidManifest.xml`
**Expected win:** -140 ms cold start (verified with `CompilationMode.None` baseline).

#### Major — [PERF-102] Main-thread Binder transaction during first scroll
**Phase:** Jank (frame 47)
**Evidence:** slice_id=14210, `binder transaction to system_server` on thread `main`, dur=6.8 ms inside an 11.2 ms frame at 120 Hz.
**Root cause:** Synchronous `PackageManager.getApplicationInfo()` call from `AppIconLoader.load()`.
**Fix:** Move the lookup to a `Dispatchers.IO` coroutine; cache the result in the ViewModel.
**File:** `feature/home/AppIconLoader.kt:34`
**Expected win:** Removes 1.4% of janky frames.

#### Minor — [PERF-103] kotlin-reflect on startup path
**Phase:** Application.onCreate
**Evidence:** 89 ms cumulative class-loading time for `kotlin.reflect.*`.
**Fix:** Remove `kotlin-reflect` from `:app`'s runtime classpath; replace Moshi reflective adapter with `moshi-kotlin-codegen`.
**Expected win:** -80 ms cold start.

### Suggested Next Trace
Re-capture with the same config after fixes 101 and 103 are merged. Validate that `timeToInitialDisplayMs` median is below the 500 ms budget and that `actual_frame_timeline_slice.jank_type` returns zero rows for the first 5 seconds of the trace.

### Perfetto SQL Used
- `tools/perfetto/queries/startup_phases.sql`
- `tools/perfetto/queries/jank_top_slices.sql`
- `tools/perfetto/queries/static_field_retention.sql`
```
