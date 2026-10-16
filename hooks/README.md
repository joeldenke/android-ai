# Hooks

Real, executable Claude Code hooks, loaded automatically from `hooks/hooks.json` when the plugin is installed. Each script is plain Bash plus `python3` for JSON parsing, and exits silently when it doesn't apply (not an Android project, not a Kotlin file, no `python3`).

| Hook | Event | Script | Behaviour |
|---|---|---|---|
| Session context | `SessionStart` | `scripts/session-start.sh` | Prints Gradle/AGP/Kotlin/KSP versions, build-logic and lint setup, and AGP 9 red flags into the agent's context. Never runs Gradle. |
| Post-edit check | `PostToolUse` on `Write\|Edit\|MultiEdit` | `scripts/post-edit-lint.sh` | `.kt`/`.kts` only. Runs `ktlint --format` if installed. **Blocks** (exit 2) on `!!`, `GlobalScope` and Android imports in `/domain/`. **Warns** on hardcoded dispatchers, Material2 imports, `collectAsState()`, ViewModel parameters on child composables, `kotlinOptions`, and hardcoded dependency versions in `.kts`. Skip a file with `// lint:skip-file`. |
| Pre-push gate | `PreToolUse` on `Bash` | `scripts/pre-push-check.sh` | Only when the command is `git push`. Runs `./gradlew [ktlintCheck] [detekt] testDebugUnitTest` (lint tasks only if configured) and **blocks** the push on failure. Bypass with `ANDROID_AI_SKIP_PREPUSH=1`. |

Other agents have no equivalent lifecycle hooks. Use the same checks through `static-analysis` (Gradle tasks) and CI (`github-actions-android`), which enforce them for every tool.

Test a hook locally:

```bash
echo '{"tool_input":{"file_path":"app/src/main/kotlin/Foo.kt"}}' | bash hooks/scripts/post-edit-lint.sh; echo "exit=$?"
```
