#!/usr/bin/env bash
# PostToolUse (Write|Edit|MultiEdit): fast single-file checks for Kotlin sources.
# Exit 2 + stderr = critical issue fed back to the agent. Warnings go out as additionalContext.
set -uo pipefail

command -v python3 >/dev/null 2>&1 || exit 0
input=$(cat)
file=$(printf '%s' "$input" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("tool_input",{}).get("file_path",""))' 2>/dev/null)

[[ -n "$file" && -f "$file" ]] || exit 0
[[ "$file" == *.kt || "$file" == *.kts ]] || exit 0
grep -q "lint:skip-file" "$file" && exit 0
[[ "$file" == */build/* ]] && exit 0

# Auto-format when ktlint is on PATH (respects .editorconfig). Never fails the hook.
if command -v ktlint >/dev/null 2>&1; then
  ktlint --format --log-level=error "$file" >/dev/null 2>&1 || true
fi

critical=()
warnings=()
code_lines() { grep -nE "$1" "$file" | grep -vE '^[0-9]+:[[:space:]]*(//|\*|/\*)' ; }

while IFS= read -r m; do [[ -n "$m" ]] && critical+=("Non-null assertion (!!) at line ${m%%:*}: use ?., ?:, requireNotNull(x) { \"why\" }"); done \
  < <(code_lines '[]A-Za-z0-9_)>]!!')
while IFS= read -r m; do [[ -n "$m" ]] && critical+=("GlobalScope at line ${m%%:*}: use viewModelScope or an injected CoroutineScope"); done \
  < <(code_lines 'GlobalScope\.')
if [[ "$file" == */domain/* ]]; then
  while IFS= read -r m; do [[ -n "$m" ]] && critical+=("Android import in domain layer at line ${m%%:*}: domain must be pure Kotlin"); done \
    < <(grep -nE '^import android(x)?\.' "$file" | grep -v 'androidx.annotation')
fi

if [[ "$file" != */test/* && "$file" != */androidTest/* && "$file" != *Test.kt ]]; then
  while IFS= read -r m; do [[ -n "$m" ]] && warnings+=("Hardcoded dispatcher at line ${m%%:*}: inject a CoroutineDispatcher"); done \
    < <(code_lines 'Dispatchers\.(IO|Default)' | grep -vE 'CoroutineDispatcher[[:space:]]*=[[:space:]]*Dispatchers\.')
fi
while IFS= read -r m; do [[ -n "$m" ]] && warnings+=("Material2 import at line ${m%%:*}: use the project design system or material3"); done \
  < <(grep -nE '^import androidx\.compose\.material\.' "$file" | grep -vE 'material\.(icons|ripple)')
while IFS= read -r m; do [[ -n "$m" ]] && warnings+=("collectAsState() at line ${m%%:*}: use collectAsStateWithLifecycle()"); done \
  < <(code_lines '\.collectAsState\(')
while IFS= read -r m; do [[ -n "$m" ]] && warnings+=("ViewModel parameter without a default at line ${m%%:*}: only route-level composables obtain a ViewModel (default arg); children get state and callbacks"); done \
  < <(grep -nE '^\s*(private |internal )?fun [A-Z][A-Za-z0-9]*\(.*:\s*[A-Za-z]*ViewModel\b' "$file" | grep -vE 'ViewModel[[:space:]]*=')
if [[ "$file" == *.kts ]]; then
  while IFS= read -r m; do [[ -n "$m" ]] && warnings+=("kotlinOptions at line ${m%%:*}: removed in AGP 9, use kotlin { compilerOptions { } }"); done \
    < <(code_lines 'kotlinOptions')
  while IFS= read -r m; do [[ -n "$m" ]] && warnings+=("Hardcoded dependency version at line ${m%%:*}: move it to gradle/libs.versions.toml"); done \
    < <(code_lines '"[a-zA-Z0-9_.-]+:[a-zA-Z0-9_.-]+:[0-9][^"]*"')
fi

if ((${#critical[@]})); then
  {
    echo "android-ai post-edit check: ${#critical[@]} critical issue(s) in $file"
    printf '  - %s\n' "${critical[@]}"
    ((${#warnings[@]})) && printf '  - (warning) %s\n' "${warnings[@]}"
    echo "Fix these before continuing, or add a justified @Suppress / '// lint:skip-file' for generated code."
  } >&2
  exit 2
fi

if ((${#warnings[@]})); then
  printf '%s\n' "${warnings[@]}" | python3 -c '
import sys, json
items = [l.strip() for l in sys.stdin if l.strip()]
msg = "android-ai post-edit warnings for " + sys.argv[1] + ":\n" + "\n".join("- " + i for i in items)
print(json.dumps({"hookSpecificOutput": {"hookEventName": "PostToolUse", "additionalContext": msg}}))
' "$file"
fi
exit 0
