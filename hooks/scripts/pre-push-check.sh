#!/usr/bin/env bash
# PreToolUse (Bash): before an agent-run `git push`, run the project's Gradle quality gate.
# Exit 2 + stderr blocks the push and tells the agent why. Skip with ANDROID_AI_SKIP_PREPUSH=1.
set -uo pipefail

command -v python3 >/dev/null 2>&1 || exit 0
cmd=$(python3 -c 'import sys,json; print(json.load(sys.stdin).get("tool_input",{}).get("command",""))' 2>/dev/null)
[[ "$cmd" =~ (^|[;&|[:space:]])git[[:space:]]+push([[:space:]]|$) ]] || exit 0
[[ "${ANDROID_AI_SKIP_PREPUSH:-0}" == "1" ]] && exit 0
[[ -x ./gradlew ]] || exit 0

configured() { grep -rqs -- "$1" gradle/libs.versions.toml build-logic build.gradle.kts 2>/dev/null; }

tasks=()
configured "org.jlleitschuh.gradle.ktlint" && tasks+=(ktlintCheck)
configured "detekt" && tasks+=(detekt)
tasks+=(testDebugUnitTest)

log=$(mktemp)
trap 'rm -f "$log"' EXIT
if ! ./gradlew "${tasks[@]}" --continue --quiet >"$log" 2>&1; then
  {
    echo "android-ai pre-push gate failed: ./gradlew ${tasks[*]}"
    tail -n 60 "$log"
    echo "Fix the failures and push again. (Humans can bypass with ANDROID_AI_SKIP_PREPUSH=1.)"
  } >&2
  exit 2
fi
exit 0
