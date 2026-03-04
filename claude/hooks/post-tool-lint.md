---
name: post-tool-lint
description: Runs after every file edit tool use (Write, Edit, MultiEdit). Automatically formats with ktlint, runs Detekt on the changed file, and checks for common Kotlin/Compose anti-patterns. Blocks commit if critical issues remain.
event: PostToolUse
tools: [Write, Edit, MultiEdit]
---

After every file write or edit, run the following checks on the modified file(s).

## Trigger Condition
Run when the tool used is `Write`, `Edit`, or `MultiEdit` and the affected file ends in `.kt` or `.kts`.

## Actions

### 1. ktlint Format (Auto-fix)
```bash
FILE="$TOOL_OUTPUT_PATH"  # path of the modified file

# Auto-format with ktlint (fixes most style issues in-place)
ktlint --format "$FILE" 2>&1

# Report remaining issues that couldn't be auto-fixed
ktlint "$FILE" 2>&1 | grep -v "^$" | while read line; do
    echo "🔴 ktlint: $line"
done
```

### 2. Detekt Static Analysis
```bash
# Run Detekt on the modified file only (fast — not full project)
./gradlew detekt --input "$FILE" -q 2>&1 | grep -E "warning|error|issue" | while read line; do
    echo "🟠 Detekt: $line"
done
```

### 3. Quick Anti-Pattern Scan
Run these grep checks on the modified `.kt` file and report findings:

```bash
FILE="$TOOL_OUTPUT_PATH"

# 🔴 Critical: non-null assertion
grep -n "!!" "$FILE" | grep -v "//.*!!" | while read match; do
    echo "🔴 [CRITICAL] Non-null assertion (!!) at: $match"
    echo "   Fix: use ?., ?: operator, or requireNotNull() with message"
done

# 🔴 Critical: GlobalScope
grep -n "GlobalScope" "$FILE" | while read match; do
    echo "🔴 [CRITICAL] GlobalScope at: $match"
    echo "   Fix: use viewModelScope, lifecycleScope, or injected CoroutineScope"
done

# 🔴 Critical: Material2 imports
grep -n "androidx.compose.material[^3.]" "$FILE" | while read match; do
    echo "🔴 [CRITICAL] Material2 import at: $match"
    echo "   Fix: replace with androidx.compose.material3.*"
done

# 🔴 Critical: Android imports in domain layer
if echo "$FILE" | grep -q "/domain/"; then
    grep -n "^import android\." "$FILE" | while read match; do
        echo "🔴 [CRITICAL] Android import in domain layer at: $match"
        echo "   Fix: domain layer must have zero Android dependencies"
    done
fi

# 🟠 Major: hardcoded Dispatchers without injection
grep -n "Dispatchers\.IO\|Dispatchers\.Default\|Dispatchers\.Main" "$FILE" \
    | grep -v "//.*Dispatchers\|@.*Dispatcher\|fun provide\|test\|Test" \
    | while read match; do
        echo "🟠 [MAJOR] Hardcoded Dispatcher at: $match"
        echo "   Fix: inject CoroutineDispatcher via @IoDispatcher / @DefaultDispatcher"
    done

# 🟠 Major: ViewModel injected into Composable
grep -n "@Composable" "$FILE" | while read composable; do
    NEXT=$(grep -n "ViewModel" "$FILE" | awk -F: '{print $1}')
    echo "$NEXT" | while read vmline; do
        echo "🟠 [MAJOR] ViewModel may be passed to Composable — check line $vmline"
        echo "   Fix: pass state and callbacks, not the ViewModel itself"
    done
done

# 🟠 Major: missing modifier in content-emitting composable
if grep -q "@Composable" "$FILE"; then
    # Check for @Composable functions that emit UI but lack modifier param
    python3 - << 'PYEOF'
import re, sys

with open(sys.argv[1]) as f:
    content = f.read()

# Find @Composable functions
pattern = r'@Composable\s+(?:private\s+|internal\s+)?fun\s+(\w+)\s*\([^)]*\)'
for m in re.finditer(pattern, content):
    fn_name = m.group(1)
    fn_body_start = m.end()
    params = m.group(0)
    # Skip previews
    if fn_name.endswith('Preview'): continue
    # Check if modifier param present
    if 'modifier' not in params and fn_name[0].isupper():
        line_no = content[:m.start()].count('\n') + 1
        print(f"🟡 [MINOR] compose:modifier-missing-check — {fn_name}() at line {line_no} has no modifier param")
PYEOF
    fi

# 🟡 Minor: collectAsState instead of collectAsStateWithLifecycle
grep -n "\.collectAsState()" "$FILE" | while read match; do
    echo "🟡 [MINOR] Use collectAsStateWithLifecycle() instead of collectAsState() at: $match"
    echo "   Fix: import androidx.lifecycle.compose.collectAsStateWithLifecycle"
done

# 🟡 Minor: Kotlin anti-patterns
grep -n "!list\.isEmpty()\|list\.size > 0\|list\.size == 0" "$FILE" | while read match; do
    echo "🟡 [MINOR] Use isNotEmpty()/isEmpty() at: $match"
done
```

### 4. Summary Report

After all checks, print:
```
─────────────────────────────────────────────────────────
Post-Edit Lint: <filename>
  🔴 Critical: <count>  (block until fixed)
  🟠 Major:    <count>  (fix before PR)
  🟡 Minor:    <count>  (fix when convenient)
  ✅ ktlint:   formatted
─────────────────────────────────────────────────────────
```

If any 🔴 Critical issues are found:
- **Notify Claude immediately** — do not proceed with additional edits until resolved
- Print the specific issue and the recommended fix
- Claude should fix the issue in the same file before moving on

## Skipping Lint

To skip for generated code or intentional overrides:
- Add `// lint:skip-file` at the top of the file for blanket suppression
- Add `@Suppress("ktlint:xxx")` for specific ktlint rules
- Add `@Suppress("detekt:xxx")` for specific Detekt rules

## Kotlin/Compose Rules Summary (enforced by this hook)

| Rule | Severity | Source |
|---|---|---|
| No `!!` non-null assertion | 🔴 | Kotlin conventions |
| No `GlobalScope` | 🔴 | Android coroutines best practices |
| No Material2 imports | 🔴 | Slack compose:m2-api-check |
| No Android imports in domain | 🔴 | Clean Architecture |
| Inject dispatchers, don't hardcode | 🟠 | Android coroutines best practices |
| No ViewModel in composables | 🟠 | Slack compose:vm-forwarding-check |
| `modifier` param in composables | 🟡 | Slack compose:modifier-missing-check |
| `collectAsStateWithLifecycle` | 🟡 | Android lifecycle best practices |
| `isNotEmpty()` over `!isEmpty()` | 🟡 | Kotlin idioms |
