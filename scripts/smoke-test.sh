#!/usr/bin/env bash
# smoke-test.sh — behavioural tests for the hooks and the installer (run by CI and locally).
# Syntax checks alone (bash -n) don't prove the scripts do the right thing; this does.
#
# Usage: bash scripts/smoke-test.sh
# shellcheck disable=SC2015  # `cond && ok || bad` is safe here: ok/bad always exit 0
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
command -v python3 >/dev/null 2>&1 || { echo "error: python3 is required" >&2; exit 1; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

pass=0
fail=0
ok()  { pass=$((pass + 1)); echo "  ok   $1"; }
bad() { fail=$((fail + 1)); echo "  FAIL $1" >&2; }

check_exit() {  # check_exit <want> <label> <got>
  if [[ "$3" == "$1" ]]; then ok "$2"; else bad "$2 (exit $3, want $1)"; sed 's/^/       /' "$tmp/err" | tail -n 5 >&2; fi
}

# --- hooks/scripts/session-start.sh ------------------------------------------------

echo "session-start.sh"
mkdir -p "$tmp/empty"
got=0
(cd "$tmp/empty" && bash "$ROOT/hooks/scripts/session-start.sh") >"$tmp/out" 2>"$tmp/err" || got=$?
check_exit 0 "non-Android directory exits 0 silently" "$got"
[[ ! -s "$tmp/out" ]] && ok "non-Android directory prints nothing" || bad "non-Android directory printed: $(cat "$tmp/out")"

proj="$tmp/fake-project"
mkdir -p "$proj/gradle/wrapper"
cat >"$proj/settings.gradle.kts" <<'EOF'
rootProject.name = "demo"
EOF
cat >"$proj/gradle/wrapper/gradle-wrapper.properties" <<'EOF'
distributionUrl=https\://services.gradle.org/distributions/gradle-9.0-bin.zip
EOF
cat >"$proj/gradle/libs.versions.toml" <<'EOF'
[versions]
agp = "9.0.0"
kotlin = "2.2.0"
ktlint-plugin = "12.1.0"
EOF
cat >"$proj/build.gradle.kts" <<'EOF'
plugins { alias(libs.plugins.ktlint.plugin) }
EOF
got=0
(cd "$proj" && bash "$ROOT/hooks/scripts/session-start.sh") >"$tmp/out" 2>"$tmp/err" || got=$?
check_exit 0 "Android project exits 0" "$got"
grep -q "Android project detected" "$tmp/out" && ok "Android project prints summary" || bad "Android project summary missing"
grep -q "Gradle wrapper: 9.0" "$tmp/out" && ok "detects Gradle wrapper version" || bad "Gradle version not detected: $(cat "$tmp/out")"

# --- hooks/scripts/post-edit-lint.sh -----------------------------------------------

echo "post-edit-lint.sh"
hook_json() { printf '{"tool_input":{"file_path":"%s"}}' "$1"; }

got=0
hook_json "$proj/Main.kt" | bash "$ROOT/hooks/scripts/post-edit-lint.sh" >"$tmp/out" 2>"$tmp/err" || got=$?
check_exit 0 "non-existent file exits 0" "$got"

echo 'val x = 1' >"$tmp/Clean.kt"
got=0
hook_json "$tmp/Clean.kt" | bash "$ROOT/hooks/scripts/post-edit-lint.sh" >"$tmp/out" 2>"$tmp/err" || got=$?
check_exit 0 "clean .kt exits 0" "$got"

echo 'val x = foo!!' >"$tmp/Bad.kt"
got=0
hook_json "$tmp/Bad.kt" | bash "$ROOT/hooks/scripts/post-edit-lint.sh" >"$tmp/out" 2>"$tmp/err" || got=$?
check_exit 2 "!! blocks with exit 2" "$got"
grep -q "Non-null assertion" "$tmp/err" && ok "!! message names the issue" || bad "!! stderr missing: $(cat "$tmp/err")"

echo '// lint:skip-file
val x = foo!!' >"$tmp/Skip.kt"
got=0
hook_json "$tmp/Skip.kt" | bash "$ROOT/hooks/scripts/post-edit-lint.sh" >"$tmp/out" 2>"$tmp/err" || got=$?
check_exit 0 "lint:skip-file bypasses checks" "$got"

mkdir -p "$tmp/domain"
echo 'import android.os.Bundle' >"$tmp/domain/UseCase.kt"
got=0
hook_json "$tmp/domain/UseCase.kt" | bash "$ROOT/hooks/scripts/post-edit-lint.sh" >"$tmp/out" 2>"$tmp/err" || got=$?
check_exit 2 "Android import in /domain/ blocks" "$got"

echo 'val dep = "androidx.core:core-ktx:1.13.1"' >"$tmp/Hardcoded.kts"
got=0
hook_json "$tmp/Hardcoded.kts" | bash "$ROOT/hooks/scripts/post-edit-lint.sh" >"$tmp/out" 2>"$tmp/err" || got=$?
check_exit 0 "hardcoded version in .kts warns (exit 0), not blocks" "$got"
grep -q "additionalContext" "$tmp/out" && ok "warnings emitted as additionalContext JSON" || bad "no additionalContext in: $(cat "$tmp/out")"

# --- hooks/scripts/pre-push-check.sh ------------------------------------------------

echo "pre-push-check.sh"
mkdir -p "$tmp/no-gradle"
got=0
(cd "$tmp/no-gradle" && printf '{"tool_input":{"command":"echo done"}}' | bash "$ROOT/hooks/scripts/pre-push-check.sh") >"$tmp/out" 2>"$tmp/err" || got=$?
check_exit 0 "non-push command exits 0" "$got"

got=0
(cd "$tmp/no-gradle" && printf '{"tool_input":{"command":"git push origin main"}}' | bash "$ROOT/hooks/scripts/pre-push-check.sh") >"$tmp/out" 2>"$tmp/err" || got=$?
check_exit 0 "git push without ./gradlew exits 0 (nothing to gate)" "$got"

# --- scripts/install.sh ---------------------------------------------------------------

echo "install.sh"
proj2="$tmp/install-target"
mkdir -p "$proj2"
got=0
(cd "$proj2" && ANDROID_AI_SRC="$ROOT" bash "$ROOT/scripts/install.sh" all) >"$tmp/out" 2>"$tmp/err" || got=$?
check_exit 0 "install.sh all exits 0" "$got"

assert_file() { [[ -f "$proj2/$1" ]] && ok "$1 installed" || bad "$1 missing"; }
assert_link() { [[ -L "$proj2/$1" ]] && ok "$1 is a symlink" || bad "$1 not a symlink"; }
assert_dir()  { [[ -d "$proj2/$1" && ! -L "$proj2/$1" ]] && ok "$1 is a real directory" || bad "$1 is not a real directory"; }

assert_file .agents/skills/android-standards/SKILL.md
assert_file .agents/skills/gradle/SKILL.md
assert_dir .agents/skills
assert_link .claude/skills
assert_file .claude/agents/android-lead.md
assert_file .cursor/rules/000-android-standards.mdc
assert_file .cursor/rules/gradle.mdc
assert_file .windsurf/rules/000-android-standards.md
assert_file .github/copilot-instructions.md
grep -q '<!-- android-ai:start -->' "$proj2/.github/copilot-instructions.md" && ok "copilot instructions carry markers" || bad "copilot markers missing"
(cd "$proj2" && ANDROID_AI_SRC="$ROOT" bash "$ROOT/scripts/install.sh" codex) >/dev/null 2>&1
grep -q '<!-- android-ai:start -->' "$proj2/AGENTS.md" && ok "AGENTS.md section upserted" || bad "AGENTS.md section missing"
(cd "$proj2" && ANDROID_AI_SRC="$ROOT" bash "$ROOT/scripts/install.sh" gemini) >/dev/null 2>&1
grep -q '<!-- android-ai:start -->' "$proj2/GEMINI.md" && ok "GEMINI.md section upserted" || bad "GEMINI.md section missing"
(cd "$proj2" && ANDROID_AI_SRC="$ROOT" bash "$ROOT/scripts/install.sh" windsurf) >/dev/null 2>&1
grep -q '<!-- android-ai:start -->' "$proj2/.windsurfrules" && ok ".windsurfrules section upserted" || bad ".windsurfrules section missing"

skill_count=$(find "$proj2/.agents/skills" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')
repo_count=$(find "$ROOT/skills" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')
[[ "$skill_count" == "$repo_count" ]] && ok "all $repo_count skills installed" || bad "installed $skill_count of $repo_count skills"

# Re-run is safe and keeps user content around the markers
echo '# my notes' >>"$proj2/GEMINI.md"
(cd "$proj2" && ANDROID_AI_SRC="$ROOT" bash "$ROOT/scripts/install.sh" gemini) >/dev/null 2>&1
grep -q '# my notes' "$proj2/GEMINI.md" && ok "re-install preserves surrounding user content" || bad "re-install clobbered user content"

got=0
(cd "$proj2" && ANDROID_AI_SRC="$ROOT" bash "$ROOT/scripts/install.sh" mcp claude google-developer-knowledge,firebase) >"$tmp/out" 2>"$tmp/err" || got=$?
check_exit 0 "install.sh mcp exits 0" "$got"
python3 -c 'import json; d=json.load(open("'"$proj2"'/.mcp.json")); assert "google-developer-knowledge" in d["mcpServers"] and "firebase" in d["mcpServers"]' \
  && ok ".mcp.json written with selected servers" || bad ".mcp.json invalid: $(cat "$proj2/.mcp.json" 2>/dev/null)"

got=0
(cd "$proj2" && ANDROID_AI_SRC="$ROOT" bash "$ROOT/scripts/install.sh" mcp claude bogus-server) >"$tmp/out" 2>"$tmp/err" || got=$?
[[ "$got" != 0 ]] && ok "unknown MCP server rejected" || bad "unknown MCP server accepted"

# --- summary ------------------------------------------------------------------------

echo
echo "smoke-test: $pass passed, $fail failed"
((fail == 0))
