---
name: google-integrations
description: Connects the agent to Google's official tooling — Google's Android Skills catalog (android/skills, installed with the Android CLI), the Google Developer Knowledge MCP (searches developer.android.com, firebase.google.com and cloud docs), the Firebase MCP server, and the Google Cloud gcloud/observability MCP servers — and says when to prefer each over this plugin's own skills. Use when setting up these integrations, when a task needs up-to-date official docs, or when it touches Firebase or GCP resources.
---

When the user runs `/google-integrations [task]`, set up or use Google's official agent tooling. Default to `status`.

## Tasks

| Command | Action |
|---|---|
| `/google-integrations status` | Show which Google skills and MCP servers are installed and connected |
| `/google-integrations skills` | List, install or update official Android skills |
| `/google-integrations mcp <server>` | Configure an MCP server for the current agent |

## How this fits with this plugin

This plugin and Google's catalog use the same open [Agent Skills](https://agentskills.io) format: one folder per skill with a `SKILL.md`. They live side by side, and nothing in this repository needs to change to use both.

**Precedence:** when an official Google skill covers the exact task (an AGP 9 upgrade, XML→Compose, edge-to-edge, Navigation 3 migration, R8 audit…), **prefer it** for the mechanics. Then apply this plugin's house rules (`android-standards`, `static-analysis`, `code-review`) to the result. Our skills own project conventions (architecture, DI-agnosticism, design tokens, testing stack). Google's skills own platform migrations that Google keeps up to date.

**Name clashes:** if an official skill has the same `name` as one of ours, rename the local copy (for example `gradle` → `gradle-house`). Never edit an installed official skill in place, because `android skills add` overwrites it on update.

## 1 — Official Android skills (github.com/android/skills)

```bash
android skills list                 # what Google ships right now
android skills find <keyword>       # search
android skills add <skill-name>     # install, or update if already installed
android skills update               # update all installed skills
android skills remove <skill-name>
```

Requires the [Android CLI](../android-cli/SKILL.md). Without it, download the skill folder from `https://goo.gle/android-skills` and copy it into a skills directory.

**Where skills must live so every agent finds them:**

| Agent | Project skill directories it scans |
|---|---|
| Claude Code | `.claude/skills/` |
| Codex CLI | `.agents/skills/` |
| GitHub Copilot (CLI, VS Code, cloud agent) | `.github/skills/`, `.claude/skills/`, `.agents/skills/` |
| Cursor | `.cursor/skills/`, `.agents/skills/`, `.claude/skills/` |
| Gemini CLI | `.gemini/skills/`, `.agents/skills/` |
| Android Studio / Android CLI default | `.skills/`, `.agent/skills/` |

The portable setup is to keep real files in `.agents/skills/` and symlink the rest (`scripts/install.sh google-skills` does this):

```bash
mkdir -p .agents/skills .claude
ln -sfn ../.agents/skills .claude/skills      # Claude Code (Copilot and Cursor read either)
```

## 2 — Google Developer Knowledge MCP (official docs search)

One remote server, one tool: `search_documents`. It returns current Markdown from developer.android.com, firebase.google.com, docs.cloud.google.com, ai.google.dev and other Google developer sites.

**Use it before answering any question about API signatures, version compatibility, deprecations or release notes.** Model training data is older than the docs.

Setup (the service is in preview):

```bash
gcloud beta services mcp enable developerknowledge.googleapis.com --project=<project>
# Create an API key restricted to the Developer Knowledge API, then:
export GOOGLE_DEVELOPER_KNOWLEDGE_API_KEY=<key>      # never commit it
```

```json
{
  "mcpServers": {
    "google-developer-knowledge": {
      "type": "http",
      "url": "https://developerknowledge.googleapis.com/mcp",
      "headers": { "X-Goog-Api-Key": "${GOOGLE_DEVELOPER_KNOWLEDGE_API_KEY}" }
    }
  }
}
```

## 3 — Firebase MCP server

Crashlytics issues, Remote Config, App Distribution, Auth users, Firestore/RTDB data and rules, Cloud Messaging, and project/app management, all through the Firebase CLI's credentials (`firebase login`).

| Agent | Recommended install |
|---|---|
| Claude Code | `claude plugin marketplace add firebase/firebase-tools` then `claude plugin install firebase@firebase` (bundles the MCP server plus Firebase skills) |
| Gemini CLI | `gemini extensions install https://github.com/gemini-cli-extensions/firebase/` |
| Any MCP client | `npx -y firebase-tools@latest mcp` (see `mcp/servers.json`) |

Android-specific uses:
- **Crash triage:** pull the top Crashlytics issues for the release, map stack frames to code, then reproduce with [`adb`](../adb/SKILL.md) or [`auto-mobile`](../auto-mobile/SKILL.md).
- **Release gating:** compare crash-free users between the previous and current version before promoting a Play track ([`release`](../release/SKILL.md)).
- **Remote Config:** read flags before changing code paths that depend on them, and never hard-code a default that differs from the server value.

## 4 — Google Cloud MCP servers

| Server | Run | Use for |
|---|---|---|
| gcloud | `npx -y @google-cloud/gcloud-mcp` | Run `gcloud` commands through the agent (Firebase Test Lab, Artifact Registry, IAM, Play Integrity backend project) |
| Observability | `npx -y @google-cloud/observability-mcp` | Logs, metrics, traces and error reporting for the app's backend |
| Product remote servers | `https://<service>.googleapis.com/mcp` (BigQuery, Firestore, Pub/Sub…) | Enable per project. See docs.cloud.google.com/mcp/supported-products |

Both local servers use Application Default Credentials (`gcloud auth application-default login`). Use a project and account with **least privilege**, and never point an agent at production with an owner role.

## 5 — Installing MCP servers per agent

`mcp/servers.json` in this repository is the canonical list. `scripts/install.sh mcp <tool>` merges it into the right file:

| Agent | File | Notes |
|---|---|---|
| Claude Code | `.mcp.json` (project) | `claude mcp list` to verify |
| Cursor | `.cursor/mcp.json` | Same `mcpServers` shape |
| GitHub Copilot / VS Code | `.vscode/mcp.json` | Top-level key is `servers`, not `mcpServers` |
| Gemini CLI | `.gemini/settings.json` → `mcpServers` | HTTP servers use `httpUrl` |
| Codex CLI | `~/.codex/config.toml` → `[mcp_servers.<name>]` | Or `codex mcp add <name> -- npx -y firebase-tools@latest mcp` |
| Windsurf | `~/.codeium/windsurf/mcp_config.json` | User-level only |

These servers are **opt-in**. The plugin does not start them automatically, because each needs credentials and most projects use only some of them.

## Safety rules

- API keys and service-account JSON come from environment variables or the OS keychain. Never write them into committed config files.
- Read operations are fine to run freely. Writes (Remote Config publish, Firestore writes, rules deploys, IAM changes) need explicit user confirmation each time.
- Prefer a dev/staging Firebase project. Say which project ID you're about to touch before any write.
