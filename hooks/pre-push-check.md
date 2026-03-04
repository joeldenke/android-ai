---
name: pre-push-check
description: Runs before every git push. Executes full lint, Detekt, unit tests, and build validation. Blocks the push if any gate fails. Ensures no broken code reaches the remote branch.
event: PreToolUse
tools: [Bash]
matcher: "git push"
---

Before executing any `git push` command, run the full quality gate pipeline. **Block the push if any step fails.**

## Pipeline

### Step 1: Staged Changes Scan
```bash
echo "🔍 Scanning staged changes for critical issues..."

# Get list of staged Kotlin files
STAGED_KT=$(git diff --cached --name-only --diff-filter=ACM | grep "\.kt$")

if [ -z "$STAGED_KT" ]; then
    echo "ℹ️  No Kotlin files staged"
else
    echo "📝 Staged files:"
    echo "$STAGED_KT"

    # Critical checks on staged files
    BANG_BANG_COUNT=0
    GLOBAL_SCOPE_COUNT=0
    M2_COUNT=0

    for f in $STAGED_KT; do
        [ -f "$f" ] || continue
        BB=$(grep -c "!!" "$f" 2>/dev/null || true)
        GS=$(grep -c "GlobalScope" "$f" 2>/dev/null || true)
        M2=$(grep -c "androidx.compose.material[^3]" "$f" 2>/dev/null || true)
        BANG_BANG_COUNT=$((BANG_BANG_COUNT + BB))
        GLOBAL_SCOPE_COUNT=$((GLOBAL_SCOPE_COUNT + GS))
        M2_COUNT=$((M2_COUNT + M2))
    done

    if [ "$BANG_BANG_COUNT" -gt 0 ]; then
        echo "🔴 BLOCKED: $BANG_BANG_COUNT non-null assertion (!!) found in staged files"
        echo "   Fix all !! before pushing. Use ?., ?:, or requireNotNull() with message."
        exit 1
    fi

    if [ "$GLOBAL_SCOPE_COUNT" -gt 0 ]; then
        echo "🔴 BLOCKED: GlobalScope found in staged files"
        echo "   Replace with viewModelScope, lifecycleScope, or injected CoroutineScope."
        exit 1
    fi

    if [ "$M2_COUNT" -gt 0 ]; then
        echo "🔴 BLOCKED: Material2 (M2) imports found in staged files"
        echo "   Migrate all to androidx.compose.material3.*"
        exit 1
    fi

    echo "✅ Critical scan passed"
fi
```

### Step 2: ktlint Full Check
```bash
echo ""
echo "🎨 Running ktlint..."
ktlint --reporter=plain 2>&1
KTLINT_EXIT=$?

if [ $KTLINT_EXIT -ne 0 ]; then
    echo "🔴 BLOCKED: ktlint found style violations"
    echo "   Run: ktlint --format to auto-fix, then re-stage"
    exit 1
fi
echo "✅ ktlint passed"
```

### Step 3: Detekt
```bash
echo ""
echo "🔬 Running Detekt..."
./gradlew detekt --quiet 2>&1
DETEKT_EXIT=$?

if [ $DETEKT_EXIT -ne 0 ]; then
    echo "🔴 BLOCKED: Detekt found issues"
    echo "   Fix all Detekt violations before pushing"
    echo "   Run: ./gradlew detekt to see full report"
    exit 1
fi
echo "✅ Detekt passed"
```

### Step 4: Unit Tests
```bash
echo ""
echo "🧪 Running unit tests..."
./gradlew testDebugUnitTest --quiet 2>&1
TEST_EXIT=$?

if [ $TEST_EXIT -ne 0 ]; then
    echo "🔴 BLOCKED: Unit tests failing"
    echo "   Fix all failing tests before pushing"
    echo "   Run: ./gradlew testDebugUnitTest to see failures"
    exit 1
fi
echo "✅ Unit tests passed"
```

### Step 5: Debug Build
```bash
echo ""
echo "🔨 Validating debug build..."
./gradlew assembleDebug --quiet 2>&1
BUILD_EXIT=$?

if [ $BUILD_EXIT -ne 0 ]; then
    echo "🔴 BLOCKED: Debug build failed"
    echo "   Fix compilation errors before pushing"
    exit 1
fi
echo "✅ Build passed"
```

### Step 6: Architecture Violation Check
```bash
echo ""
echo "🏗️  Checking architecture violations..."

# Feature-to-feature dependencies
FEAT_TO_FEAT=$(grep -r 'implementation(project(":feature:' --include="*.kts" \
    $(find . -path "*/feature/*/build.gradle.kts") 2>/dev/null | wc -l)

if [ "$FEAT_TO_FEAT" -gt 0 ]; then
    echo "🟠 WARNING: Feature-to-feature dependencies detected ($FEAT_TO_FEAT)"
    grep -r 'implementation(project(":feature:' --include="*.kts" \
        $(find . -path "*/feature/*/build.gradle.kts") 2>/dev/null
    echo "   Features should not depend on other features. Use :core:* or navigation instead."
    # Warning only — don't block push, but log for review
fi

# Android imports in domain modules
DOMAIN_ANDROID=$(find . -path "*/domain/*" -name "*.kt" -not -path "*/build/*" \
    -exec grep -l "^import android\." {} \; 2>/dev/null | wc -l)

if [ "$DOMAIN_ANDROID" -gt 0 ]; then
    echo "🔴 BLOCKED: Android imports in domain layer ($DOMAIN_ANDROID files)"
    find . -path "*/domain/*" -name "*.kt" -not -path "*/build/*" \
        -exec grep -l "^import android\." {} \;
    exit 1
fi

echo "✅ Architecture check passed"
```

### Step 7: Summary & Push Authorization
```bash
echo ""
echo "═══════════════════════════════════════════════════════"
echo "  Pre-Push Gate: ALL CHECKS PASSED ✅"
echo "  Branch:  $(git rev-parse --abbrev-ref HEAD)"
echo "  Commits: $(git log origin/$(git rev-parse --abbrev-ref HEAD)..HEAD --oneline 2>/dev/null | wc -l) new commit(s)"
echo "  Files:   $(git diff origin/$(git rev-parse --abbrev-ref HEAD)..HEAD --name-only 2>/dev/null | wc -l) changed"
echo "═══════════════════════════════════════════════════════"
echo "  Authorized to push. Proceeding..."
echo ""
```

## Gate Summary

| Gate | Failure Action |
|---|---|
| Critical code scan (!!,  GlobalScope, M2) | 🔴 Block push |
| ktlint | 🔴 Block push |
| Detekt | 🔴 Block push |
| Unit tests | 🔴 Block push |
| Debug build | 🔴 Block push |
| Android in domain | 🔴 Block push |
| Feature-to-feature deps | 🟠 Warn, allow push |

## Bypassing (For Emergencies Only)
```bash
# Emergency bypass — MUST leave a comment explaining why
git push --no-verify  # bypasses git hooks (not this Claude hook)
# Add: # EMERGENCY: <reason> — fix in follow-up PR
```
