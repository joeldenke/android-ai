#!/usr/bin/env bash
# SessionStart: print a compact build summary (stdout is added to the agent's context).
# Fast and read-only: never invokes Gradle.
set -uo pipefail

[[ -f settings.gradle.kts || -f settings.gradle ]] || exit 0

catalog="gradle/libs.versions.toml"
version_of() {
  [[ -f "$catalog" ]] || return 0
  sed -nE "s/^[[:space:]]*$1[[:space:]]*=[[:space:]]*\"([^\"]+)\".*/\1/p" "$catalog" | head -n1
}

gradle_version=""
if [[ -f gradle/wrapper/gradle-wrapper.properties ]]; then
  gradle_version=$(sed -nE 's/.*gradle-([0-9][^-]*)-(bin|all)\.zip.*/\1/p' gradle/wrapper/gradle-wrapper.properties)
fi

has() { grep -rqs -- "$1" "$catalog" build-logic build.gradle.kts 2>/dev/null; }

echo "Android project detected (android-ai plugin)"
echo "  Gradle wrapper: ${gradle_version:-unknown}   AGP: $(version_of agp)   Kotlin: $(version_of kotlin)   KSP: $(version_of ksp)"
echo "  Version catalog: $([[ -f $catalog ]] && echo yes || echo NO)   build-logic: $([[ -d build-logic ]] && echo yes || echo no)   buildSrc: $([[ -d buildSrc ]] && echo yes || echo no)"
echo "  ktlint: $(has ktlint && echo yes || echo no)   detekt: $(has detekt && echo yes || echo no)   compose rules: $(has io.nlopez.compose.rules && echo yes || echo no)"
if grep -rqs "org.jetbrains.kotlin.android\|kotlin-android" "$catalog" build.gradle.kts */build.gradle.kts 2>/dev/null; then
  echo "  Note: kotlin-android plugin found. Under AGP 9 built-in Kotlin it must be removed (see the gradle skill)."
fi
groovy=$(find . -name build.gradle -not -path "*/build/*" -not -path "*/.gradle/*" 2>/dev/null | head -n3)
[[ -n "$groovy" ]] && echo "  Groovy build files present: $(echo $groovy | tr '\n' ' ') (convert to .kts)"
exit 0
