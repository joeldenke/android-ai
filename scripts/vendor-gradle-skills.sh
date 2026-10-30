#!/usr/bin/env bash
# vendor-gradle-skills.sh — copy Gradle's official skills (github.com/gradle/gradle-skills) into skills/
#
# Gradle, Inc. maintains gradle-best-practices (audit a build against the Gradle best practices, and
# apply the fixes) and gradle-wrapper-upgrade (upgrade the wrapper with a pinned checksum and roll back
# when the build no longer configures). They use the same Agent Skills format as this repository, so
# vendoring them into skills/ hands them to every agent this repository supports: the Claude Code plugin,
# install.sh (.agents/skills for Codex, Gemini, Cursor and Copilot) and the generated rules.
#
# The copies are never edited by hand. To update, change REF to a newer commit and re-run:
#
#   bash scripts/vendor-gradle-skills.sh
#   bash scripts/sync-rules.sh
#
# Apache-2.0: each skill folder keeps Gradle's LICENSE, and UPSTREAM records where it came from.

set -euo pipefail

REPO="https://github.com/gradle/gradle-skills"
REF="b26b14955e3a3ada5d1e90a4e08e2f10b2b54b5d"   # gradle-skills 1.1.0 (2026-10-21)
SKILLS=(gradle-best-practices gradle-wrapper-upgrade)

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

git -C "$TMP" init --quiet
git -C "$TMP" fetch --quiet --depth=1 "$REPO" "$REF"
git -C "$TMP" checkout --quiet FETCH_HEAD

for skill in "${SKILLS[@]}"; do
  src="$TMP/skills/$skill"
  [[ -f "$src/SKILL.md" ]] || { echo "error: $REPO@$REF has no skills/$skill" >&2; exit 1; }
  dest="$ROOT/skills/$skill"
  rm -rf "$dest"
  cp -R "$src" "$dest"
  cp "$TMP/LICENSE" "$dest/LICENSE"
  printf 'Vendored from %s/tree/%s/skills/%s\nby scripts/vendor-gradle-skills.sh. Do not edit; update REF there and re-run.\n' \
    "$REPO" "$REF" "$skill" > "$dest/UPSTREAM"
  echo "  ✓ skills/$skill"
done
