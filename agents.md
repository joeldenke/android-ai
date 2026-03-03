# Android AI — Plugin Marketplace

> Expert-level Android development agents, skills, and hooks for Claude Code.
> Encodes best practices from Google, JetBrains, and Slack Compose rules.

---

## Agent Team Topology

```
                      ┌─────────────────────┐
                      │    @android-lead     │  ← Principal Engineer
                      │  model: opus         │    Coordinator & synthesizer
                      │  memory: project     │    Spawns all sub-agents
                      └──────────┬──────────┘
                                 │ delegates via Agent() tool
              ┌──────────────────┼──────────────────────┐
              │                  │                       │
   ┌──────────▼─────────┐  ┌─────▼──────────┐  ┌───────▼────────────┐
   │ @android-architect │  │ @kotlin-expert │  │  @compose-expert   │
   │ model: sonnet      │  │ model: sonnet  │  │  model: sonnet     │
   │ memory: project    │  │                │  │                    │
   └────────────────────┘  └────────────────┘  └────────────────────┘
              │                                          │
   ┌──────────▼─────────────────────────────────────────▼───────────┐
   │              @coroutine-flow-expert                             │
   │              model: sonnet                                      │
   └─────────────────────────────────────────────────────────────────┘
                                 │
   ┌─────────────────────────────▼───────────────────────────────────┐
   │                    @testing-engineer                            │
   │                    model: sonnet                                │
   └─────────────────────────────────────────────────────────────────┘
```

**Delegation flow:** `android-lead` coordinates work → spawns specialists in parallel or sequence → synthesizes their outputs into a unified response.

---

## Agents

Specialist sub-agents invoked with `@agent-name`. Each is a deep expert in its domain.

| Agent | Trigger | Role | Model | Memory |
|---|---|---|---|---|
| `@android-lead` | Complex multi-domain tasks, full feature delivery, PR planning | Principal Engineer — orchestrates all specialists | opus | project |
| `@android-architect` | Architecture decisions, module design, layering | Senior Android Architect — produces ADRs & module graphs | sonnet | project |
| `@kotlin-expert` | Kotlin idioms, coroutines, Flow, language features | Principal Kotlin Engineer | sonnet | — |
| `@compose-expert` | Composable design, state, theming, animations | Senior Compose Engineer — enforces all Slack rules | sonnet | — |
| `@coroutine-flow-expert` | Concurrency, structured concurrency, Flow operators | Concurrency Specialist | sonnet | — |
| `@testing-engineer` | Unit, integration, UI tests, TDD guidance | Senior QA/Test Engineer | sonnet | — |

---

## When to Use Which Agent

| Task | Agent |
|---|---|
| "Design the data layer for offline-first sync" | `@android-architect` |
| "Build the complete UserProfile feature" | `@android-lead` |
| "Is this idiomatic Kotlin?" | `@kotlin-expert` |
| "Fix this Compose recomposition issue" | `@compose-expert` |
| "Design a search Flow with debounce" | `@coroutine-flow-expert` |
| "Write tests for this ViewModel" | `@testing-engineer` |
| "Review this PR across all layers" | `@android-lead` |
| "Refactor this module from MVP to MVVM" | `@android-lead` |

---

## Skills

Reusable slash commands invoked with `/skill-name [args]`.

| Skill | Command | What it does |
|---|---|---|
| New Feature | `/new-feature <description>` | Scaffolds full MVVM feature (screen, VM, use case, repo, DI) |
| Compose Component | `/compose-component <name>` | Creates a production-ready Composable with preview, state hoist, a11y |
| Code Review | `/code-review [file or PR]` | Deep review against all Android best-practice rules |
| Refactor Kotlin | `/refactor-kotlin <target>` | Modernizes code to idiomatic Kotlin (coroutines, sealed, etc.) |
| Coroutine Flow | `/coroutine-flow <scenario>` | Designs the optimal Flow/coroutine pipeline for a problem |
| Architecture Audit | `/architecture-audit` | Audits current project for layer violations, coupling, anti-patterns |
| Debug Performance | `/debug-performance <screen or area>` | Identifies Compose recomposition, memory, startup, or jank issues |
| Write Tests | `/write-tests <target>` | Generates comprehensive test suite (unit + integration + UI) |

---

## Hooks

Automated quality gates that run during Claude Code lifecycle events.

| Hook | Event | Action |
|---|---|---|
| `session-start` | Session begins | Sets up ktlint, Detekt, validates module structure |
| `post-tool-lint` | After every file edit | Runs ktlint format + Detekt on changed file |
| `pre-push-check` | Before git push | Full lint, tests, build validation |

**Sub-agent lifecycle hooks** (configured in `.claude/settings.json`):
- Each specialist prints a status banner when it starts
- All agents print completion status on stop

---

## Best Practices Index

### Architecture
- Clean Architecture: `UI → Domain → Data` — domain layer has **no** Android dependencies
- MVVM with `ViewModel` + `StateFlow`/`UiState` sealed class
- Single source of truth — all state lives in `ViewModel` or `Repository`
- `Repository` abstracts data sources; `UseCase` encapsulates business logic
- One `Activity`, multiple screens via Compose Navigation
- Multi-module by feature: `:feature:home`, `:feature:profile`, `:core:ui`, `:core:data`

### Kotlin
- `val` over `var` always; `var` requires justification
- `data class` for models, `sealed class`/`sealed interface` for state/events
- Prefer expression bodies for single-expression functions
- Use scope functions (`let`, `apply`, `run`, `also`, `with`) correctly — no misuse
- Never use `!!` — handle nullability with `?:`, `?.`, `let`, or contracts
- Extension functions for domain-specific utilities, not as a dumping ground
- Avoid platform types from Java interop — annotate Java with `@Nullable`/`@NonNull`

### Coroutines & Flow
- Inject `CoroutineDispatcher` — never hardcode `Dispatchers.IO` inside classes
- Use `viewModelScope` in ViewModel, `lifecycleScope` in Activity/Fragment
- Prefer `StateFlow` for state, `SharedFlow(replay=0)` for one-shot events
- Use `callbackFlow` to bridge callback APIs to Flow
- `withContext` for dispatcher switching, not `launch(Dispatchers.IO)`
- Structured concurrency — every coroutine has a defined scope and lifecycle
- Never use `GlobalScope` in production code
- Handle errors with `catch` operator on Flow, or `CoroutineExceptionHandler`
- Use `SupervisorJob` when child failures must not cancel siblings
- Prefer `flow {}` builder over `channelFlow` unless you need concurrent emissions

### Jetpack Compose
- State hoisting — stateless leaf composables, stateful wrappers at screen level
- `remember` all state; `rememberSaveable` for survives-process-death state
- Use `derivedStateOf` when derived state depends on other observed state — prevents over-recomposition
- Stability: annotate classes with `@Stable`/`@Immutable` when the compiler can't infer it
- Replace `List<T>` params with `ImmutableList<T>` (Kotlinx Immutable) for stable lambdas
- Never pass `ViewModel` or `NavController` into child composables — use callbacks and state
- Side effects only in `LaunchedEffect`, `DisposableEffect`, `SideEffect`, `rememberCoroutineScope`
- `key` every item in `LazyColumn`/`LazyRow` lists
- Prefer `Modifier` parameter named exactly `modifier: Modifier = Modifier` in every content-emitting composable
- Use `semantics {}` for accessibility; test with TalkBack and accessibility scanner
- Avoid `Modifier.composed {}` — prefer `Modifier.Node` API for custom modifiers
- Material3 only — no `androidx.compose.material` (M2) imports

### Slack Compose Rules (full list)
- **compose:content-emitter-returning-values-check** — emitters must return `Unit`
- **compose:modifier-not-used-at-root** — `modifier` must be applied to root element
- **compose:modifier-missing-check** — every content-emitting composable needs `modifier` param
- **compose:modifier-reused-check** — never reuse the same `Modifier` instance across nodes
- **compose:modifier-without-default-check** — `modifier` param must default to `Modifier`
- **compose:multiple-emitters-check** — one root emitter per composable
- **compose:mutable-params-check** — no mutable (`var`) parameters in composables
- **compose:naming-check** — composable functions must be PascalCase
- **compose:parameter-ordering** — order: required params → optional params → trailing lambda
- **compose:preview-naming** — preview functions must end with `Preview`
- **compose:preview-public** — preview functions must be `private` or `internal`
- **compose:remember-missing-check** — stateful objects inside composables must be `remember`ed
- **compose:unstable-collections** — avoid `List`, `Map`, `Set` as params; use Kotlinx Immutable
- **compose:vm-forwarding-check** — never pass `ViewModel` as a composable parameter
- **compose:compositionlocal-allowlist** — `CompositionLocal` only for cross-cutting concerns (theme, locale); document every use
- **compose:m2-api-check** — no Material2 APIs; migrate all to Material3

### Testing
- Test naming: `given_when_then` or descriptive sentence style
- `@Test fun `displays error state when network call fails`()`
- Use `Turbine` for Flow/StateFlow testing
- Use `Mockk` (not Mockito) for mocking
- `InstantTaskExecutorRule` + `TestDispatcher` for ViewModel tests
- Compose UI tests: `createComposeRule()`, semantic matchers over hardcoded IDs
- Avoid testing implementation details — test observable behavior
- Aim for test pyramid: many unit, some integration, few E2E

### Build & Tooling
- Kotlin DSL (`build.gradle.kts`) for all build files
- Version Catalog (`libs.versions.toml`) for all dependency versions
- `buildSrc` or convention plugins for shared build logic
- Enable `explicitApi()` for library modules
- R8 full mode for release builds
- Baseline profiles for startup performance
- Use `lint { abortOnError = true }` in CI
