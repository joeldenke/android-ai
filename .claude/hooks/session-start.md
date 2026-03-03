---
name: session-start
description: Runs at the start of every Claude Code session. Validates the development environment, checks tool versions, inspects module structure, and prints a status summary so Claude has full context before touching any code.
event: SessionStart
---

At the start of every session, run the following checks and print a concise status report.

## Actions

### 1. Validate Required Tools
```bash
# Check ktlint
ktlint --version 2>/dev/null || echo "⚠️  ktlint not found — install: brew install ktlint"

# Check Detekt
./gradlew detekt --dry-run -q 2>/dev/null && echo "✅ Detekt configured" || echo "⚠️  Detekt not configured"

# Check Android SDK
echo "Android SDK: ${ANDROID_HOME:-NOT SET}"
sdkmanager --list_installed 2>/dev/null | grep "build-tools\|platforms;android" | tail -5

# Check Java version (must be 17+ for AGP 8+)
java -version 2>&1 | head -1

# Check Gradle wrapper
cat gradle/wrapper/gradle-wrapper.properties | grep distributionUrl
```

### 2. Inspect Project Structure
```bash
# List all modules and their types
find . -name "build.gradle.kts" -not -path "*/build/*" \
    | sed 's|/build.gradle.kts||' \
    | sed 's|^\./||' \
    | sort

# Check for Java files in new code (should be zero in Kotlin-only projects)
JAVA_COUNT=$(find . -name "*.java" -not -path "*/build/*" -not -path "*/.git/*" | wc -l)
if [ "$JAVA_COUNT" -gt 0 ]; then
    echo "⚠️  $JAVA_COUNT .java files found — new code should be Kotlin only"
    find . -name "*.java" -not -path "*/build/*" | head -10
else
    echo "✅ No Java files in source tree"
fi

# Check for GlobalScope usage
GLOBAL_SCOPE=$(grep -r "GlobalScope" --include="*.kt" --exclude-dir=build -l 2>/dev/null | wc -l)
[ "$GLOBAL_SCOPE" -gt 0 ] && echo "🔴 GlobalScope found in $GLOBAL_SCOPE files" || echo "✅ No GlobalScope usage"

# Check for !! usage
BANG_BANG=$(grep -r "!!" --include="*.kt" --exclude-dir=build -l 2>/dev/null | wc -l)
[ "$BANG_BANG" -gt 0 ] && echo "🟠 !! (non-null assertion) found in $BANG_BANG files" || echo "✅ No !! assertions found"

# Check for M2 imports
M2_IMPORTS=$(grep -r "androidx.compose.material[^3]" --include="*.kt" --exclude-dir=build -l 2>/dev/null | wc -l)
[ "$M2_IMPORTS" -gt 0 ] && echo "🔴 Material2 imports in $M2_IMPORTS files — migrate to M3" || echo "✅ No Material2 imports"
```

### 3. Validate libs.versions.toml
```bash
if [ -f "gradle/libs.versions.toml" ]; then
    echo "✅ Version catalog found"
    # Count dependencies
    DEPS=$(grep -c "= {" gradle/libs.versions.toml 2>/dev/null || echo 0)
    echo "   Dependencies: $DEPS"
else
    echo "⚠️  No libs.versions.toml — consider adopting Version Catalog"
fi
```

### 4. Check Git State
```bash
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
UNCOMMITTED=$(git status --porcelain 2>/dev/null | wc -l)
echo "Git branch: $BRANCH"
echo "Uncommitted changes: $UNCOMMITTED file(s)"
git log --oneline -3 2>/dev/null
```

### 5. Print Session Context Summary

Print this summary for Claude to read at session start:

```
╔══════════════════════════════════════════════════════════════════╗
║           Android AI — Session Start Summary                     ║
╠══════════════════════════════════════════════════════════════════╣
║ Project:     <project name from settings.gradle.kts>            ║
║ Modules:     <count>                                             ║
║ Branch:      <current branch>                                    ║
║ Java:        <version>                                           ║
║ Gradle:      <version>                                           ║
╠══════════════════════════════════════════════════════════════════╣
║ Code Quality Gates:                                              ║
║   ktlint:        [installed/missing]                             ║
║   Detekt:        [configured/missing]                            ║
║   Version Cat:   [present/missing]                               ║
╠══════════════════════════════════════════════════════════════════╣
║ Quick Scan Results:                                              ║
║   Java files:    [count] (target: 0)                            ║
║   GlobalScope:   [count] (target: 0)                            ║
║   !! operators:  [count] (target: 0)                            ║
║   M2 imports:    [count] (target: 0)                            ║
╠══════════════════════════════════════════════════════════════════╣
║ Active Agents:   @android-architect @kotlin-expert              ║
║                  @compose-expert @coroutine-flow-expert         ║
║                  @testing-engineer                               ║
║ Skills:          /new-feature /compose-component /code-review   ║
║                  /refactor-kotlin /coroutine-flow /architecture-audit ║
║                  /debug-performance /write-tests                 ║
╚══════════════════════════════════════════════════════════════════╝
```

## Standards Reminder (Printed Every Session)

Enforce these standards in all code written this session:
- **Kotlin only** — no Java in new files
- **Min SDK 26+** — use modern APIs freely
- **MVVM + Clean Architecture** — UI / Domain / Data separation
- **Hilt** for DI — `@HiltViewModel`, `@Singleton`, injected dispatchers
- **Coroutines + Flow** — no RxJava, no callbacks, no `GlobalScope`
- **Compose + Material3** — no M2, no XML layouts in new code
- **Slack Compose rules** — all 16 rules enforced, zero warnings
- **JUnit5 + Turbine + Mockk** — for all new tests
- **ktlint + Detekt** — format before every commit
