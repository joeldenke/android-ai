#!/usr/bin/env bash
# install.sh — install Android AI skills/agents/rules into an Android project (run from the project root)
#
#   bash <(curl -fsSL https://raw.githubusercontent.com/joeldenke/android-ai/main/scripts/install.sh) <tool>
#
# Re-running is safe: skills are refreshed, and generated sections inside existing AGENTS.md / GEMINI.md /
# copilot-instructions.md / .windsurfrules are replaced between markers without touching the rest.

set -euo pipefail

REPO="https://github.com/joeldenke/android-ai"
TOOL="${1:-}"
MARK_START="<!-- android-ai:start -->"
MARK_END="<!-- android-ai:end -->"

print_help() {
  cat <<EOF
install.sh — Android AI installer

Usage:
  install.sh <tool>                    install skills + rules for one agent
  install.sh mcp <tool> [servers]      add MCP servers (comma list; default: google-developer-knowledge,firebase)
  install.sh google-skills             link Google's official Android skills into every agent's skill dir

Tools:
  claude    Claude Code — prefer the plugin:  /plugin marketplace add joeldenke/android-ai
                                              /plugin install android-ai@android-ai
            fallback: .claude/skills + .claude/agents (no hooks — hooks need the plugin)
  cursor    .agents/skills + .cursor/rules/
  copilot   .agents/skills (+ .github/skills link) + .github/copilot-instructions.md
  codex     .agents/skills + AGENTS.md section
  gemini    .agents/skills + GEMINI.md section
  windsurf  .agents/skills + .windsurf/rules/ + .windsurfrules section
  all       every tool above

MCP servers (from mcp/servers.json):
  google-developer-knowledge   official Google developer docs search (needs GOOGLE_DEVELOPER_KNOWLEDGE_API_KEY)
  firebase                     Firebase MCP (uses 'firebase login' credentials)
  gcloud                       Google Cloud CLI MCP (uses gcloud ADC)
  gcp-observability            Cloud Logging/Monitoring/Trace MCP (uses gcloud ADC)

Capability matrix:
                               claude  cursor  copilot  codex  gemini  windsurf
  Skills (Agent Skills format)   ✓       ✓       ✓        ✓      ✓       ✓ (rules → skills)
  Always-on standards            ✓       ✓       ✓        ✓      ✓       ✓
  Specialist sub-agents          ✓       -       -        -      -       -
  Lifecycle hooks                ✓       -       -        -      -       -
  MCP servers (install.sh mcp)   ✓       ✓       ✓        ✓*     ✓       ✓*     (* printed instructions)
EOF
}

if [[ -z "$TOOL" || "$TOOL" == "--help" || "$TOOL" == "-h" || "$TOOL" == "help" ]]; then
  print_help
  [[ -z "$TOOL" ]] && exit 1 || exit 0
fi

# Use a local checkout when run from one (ANDROID_AI_SRC or ../ of this script), otherwise clone.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || true)"
if [[ -n "${ANDROID_AI_SRC:-}" ]]; then
  SRC="$ANDROID_AI_SRC"
elif [[ -n "$SCRIPT_DIR" && -f "$SCRIPT_DIR/../skills/android-standards/SKILL.md" ]]; then
  SRC="$(cd "$SCRIPT_DIR/.." && pwd)"
else
  TMP=$(mktemp -d)
  trap 'rm -rf "$TMP"' EXIT
  echo "Cloning android-ai..."
  git clone --depth=1 --quiet "$REPO" "$TMP/android-ai"
  SRC="$TMP/android-ai"
fi

# --- helpers ----------------------------------------------------------------

install_skills() {   # real files in .agents/skills (read by Codex, Gemini, Cursor, Copilot)
  mkdir -p .agents/skills
  for dir in "$SRC"/skills/*/; do
    name="$(basename "$dir")"
    rm -rf ".agents/skills/$name"
    cp -R "$dir" ".agents/skills/$name"
  done
  echo "  ✓ .agents/skills/ ($(ls -d "$SRC"/skills/*/ | wc -l | tr -d ' ') skills)"
}

link_skills_dir() {  # link_skills_dir <dir>: point another agent's skill dir at .agents/skills
  local target="$1" parent
  parent="$(dirname "$target")"
  mkdir -p "$parent"
  if [[ -L "$target" || ! -e "$target" ]]; then
    ln -sfn "$(realpath --relative-to="$parent" .agents/skills 2>/dev/null || echo ../.agents/skills)" "$target"
    echo "  ✓ $target -> .agents/skills"
  else
    # Real directory already exists (other skills live there): copy ours in alongside
    for dir in .agents/skills/*/; do
      name="$(basename "$dir")"; rm -rf "${target:?}/$name"; cp -R "$dir" "$target/$name"
    done
    echo "  ✓ $target/ (copied alongside existing skills)"
  fi
}

upsert_block() {     # upsert_block <file> <generated file>: replace our marked section, keep the rest
  local file="$1" content="$2"
  mkdir -p "$(dirname "$file")"
  touch "$file"
  python3 - "$file" "$content" "$MARK_START" "$MARK_END" <<'PY'
import sys, re
path, content_path, start, end = sys.argv[1:]
text = open(path, encoding="utf-8").read()
block = start + "\n" + open(content_path, encoding="utf-8").read().rstrip() + "\n" + end + "\n"
pattern = re.compile(re.escape(start) + r".*?" + re.escape(end) + r"\n?", re.S)
text = pattern.sub(lambda _: block, text) if pattern.search(text) else (text.rstrip() + "\n\n" + block if text.strip() else block)
open(path, "w", encoding="utf-8").write(text)
PY
  echo "  ✓ $file (android-ai section)"
}

require_python() { command -v python3 >/dev/null 2>&1 || { echo "error: python3 is required for this step" >&2; exit 1; }; }

# --- per-tool installers --------------------------------------------------------

install_claude() {
  echo "Installing for Claude Code (fallback — the plugin also installs hooks):"
  install_skills
  link_skills_dir .claude/skills
  mkdir -p .claude/agents
  cp "$SRC"/agents/*.md .claude/agents/
  echo "  ✓ .claude/agents/ ($(ls "$SRC"/agents/*.md | wc -l | tr -d ' ') agents)"
}

install_cursor() {
  echo "Installing for Cursor:"
  install_skills
  mkdir -p .cursor/rules
  cp "$SRC"/.cursor/rules/*.mdc .cursor/rules/
  echo "  ✓ .cursor/rules/ ($(ls "$SRC"/.cursor/rules/*.mdc | wc -l | tr -d ' ') rules)"
}

install_copilot() {
  require_python
  echo "Installing for GitHub Copilot:"
  install_skills
  link_skills_dir .github/skills
  upsert_block .github/copilot-instructions.md "$SRC/.github/copilot-instructions.md"
}

install_codex() {
  require_python
  echo "Installing for Codex CLI:"
  install_skills
  upsert_block AGENTS.md "$SRC/GEMINI.md"   # same generated standards + skill index
}

install_gemini() {
  require_python
  echo "Installing for Gemini CLI:"
  install_skills
  upsert_block GEMINI.md "$SRC/GEMINI.md"
}

install_windsurf() {
  require_python
  echo "Installing for Windsurf:"
  install_skills
  mkdir -p .windsurf/rules
  cp "$SRC"/.windsurf/rules/*.md .windsurf/rules/
  echo "  ✓ .windsurf/rules/ ($(ls "$SRC"/.windsurf/rules/*.md | wc -l | tr -d ' ') rules)"
  upsert_block .windsurfrules "$SRC/.windsurfrules"
}

# --- MCP ----------------------------------------------------------------------

install_mcp() {
  require_python
  local tool="${1:-}" servers="${2:-google-developer-knowledge,firebase}"
  [[ -n "$tool" ]] || { echo "usage: install.sh mcp <claude|cursor|copilot|gemini|codex|windsurf> [servers]" >&2; exit 1; }
  python3 - "$SRC/mcp/servers.json" "$tool" "$servers" <<'PY'
import json, os, re, sys
catalog_path, tool, wanted = sys.argv[1], sys.argv[2], sys.argv[3].split(",")
catalog = json.load(open(catalog_path))["mcpServers"]
unknown = [w for w in wanted if w not in catalog]
if unknown:
    sys.exit(f"unknown MCP server(s): {', '.join(unknown)} (known: {', '.join(catalog)})")
selected = {name: catalog[name] for name in wanted}

def env_syntax(obj, fmt):
    s = json.dumps(obj)
    return json.loads(re.sub(r"\$\{([A-Z0-9_]+)\}", lambda m: fmt.format(m.group(1)), s))

def merge(path, key, servers):
    data = json.load(open(path)) if os.path.exists(path) and os.path.getsize(path) else {}
    data.setdefault(key, {}).update(servers)
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    with open(path, "w") as f:
        json.dump(data, f, indent=2); f.write("\n")
    print(f"  ✓ {path}: {', '.join(servers)}")

if tool == "claude":
    merge(".mcp.json", "mcpServers", selected)
elif tool == "cursor":
    merge(".cursor/mcp.json", "mcpServers", env_syntax(selected, "${{env:{}}}"))
elif tool == "copilot":
    servers = {}
    for name, cfg in env_syntax(selected, "${{env:{}}}").items():
        cfg = dict(cfg)
        cfg.setdefault("type", "http" if "url" in cfg else "stdio")
        servers[name] = cfg
    merge(".vscode/mcp.json", "servers", servers)
elif tool == "gemini":
    servers = {}
    for name, cfg in selected.items():
        cfg = dict(cfg)
        if cfg.pop("type", None) == "http":
            cfg["httpUrl"] = cfg.pop("url")
        servers[name] = cfg
    merge(".gemini/settings.json", "mcpServers", servers)
elif tool in ("codex", "windsurf"):
    if tool == "codex":
        print("  Add to ~/.codex/config.toml:")
        for name, cfg in selected.items():
            print(f"\n  [mcp_servers.{name}]")
            if "url" in cfg:
                print(f'  url = "{cfg["url"]}"')
                for header, value in cfg.get("headers", {}).items():
                    var = re.sub(r"[${}]", "", value)
                    print(f'  env_http_headers = {{ "{header}" = "{var}" }}')
            else:
                print(f'  command = "{cfg["command"]}"')
                print(f"  args = {json.dumps(cfg['args'])}")
    else:
        print("  Windsurf reads MCP servers from ~/.codeium/windsurf/mcp_config.json (user level). Add:")
        print(json.dumps({"mcpServers": env_syntax(selected, "${{env:{}}}")}, indent=2))
else:
    sys.exit(f"unknown tool for mcp: {tool}")
PY
  if [[ ",$servers," == *",google-developer-knowledge,"* ]]; then
    echo "  → export GOOGLE_DEVELOPER_KNOWLEDGE_API_KEY=… (API key restricted to the Developer Knowledge API; never commit it)"
  fi
  if [[ ",$servers," == *",firebase,"* ]]; then
    echo "  → run 'firebase login' once. Claude Code users can instead: claude plugin marketplace add firebase/firebase-tools"
  fi
}

# --- Google official Android skills ---------------------------------------------

install_google_skills() {
  echo "Google official Android skills:"
  if command -v android >/dev/null 2>&1; then
    echo "  Available skills ('android skills list'):"
    android skills list || true
    echo "  Install with: android skills add <skill-name>   then re-run: install.sh google-skills"
  else
    echo "  Android CLI not found. Install it (see skills/android-cli) or download skills from https://goo.gle/android-skills"
  fi
  # Android CLI installs into .skills/ or .agent/skills/; expose them where every agent looks
  mkdir -p .agents/skills
  local linked=0
  for dir in .skills/*/ .agent/skills/*/; do
    [[ -f "$dir/SKILL.md" ]] || continue
    name="$(basename "$dir")"
    if [[ -e ".agents/skills/$name" && ! -L ".agents/skills/$name" ]]; then
      echo "  ! .agents/skills/$name already exists (name clash) — skipped; rename one of them"
      continue
    fi
    ln -sfn "../../${dir%/}" ".agents/skills/$name"
    linked=$((linked + 1))
  done
  echo "  ✓ linked $linked official skill(s) into .agents/skills/"
  [[ -e .claude/skills ]] || link_skills_dir .claude/skills
}

case "$TOOL" in
  claude)   install_claude ;;
  cursor)   install_cursor ;;
  copilot)  install_copilot ;;
  codex)    install_codex ;;
  gemini)   install_gemini ;;
  windsurf) install_windsurf ;;
  mcp)      install_mcp "${2:-}" "${3:-google-developer-knowledge,firebase}" ;;
  google-skills) install_google_skills ;;
  all)
    install_claude
    install_cursor
    install_copilot
    install_codex
    install_gemini
    install_windsurf
    ;;
  *)
    echo "error: unknown tool '$TOOL'"
    echo ""
    print_help
    exit 1
    ;;
esac

echo ""
echo "Done: android-ai → $TOOL"
