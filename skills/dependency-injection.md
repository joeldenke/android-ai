---
name: dependency-injection
description: Sets up and audits dependency injection for Android projects. DI-framework agnostic — guides Hilt, Koin, Anvil, Metro, or manual injection setup, module organization, ViewModel binding, testability patterns, and common anti-patterns.
---

When the user runs `/dependency-injection [task]`, set up or audit dependency injection for the Android project. The skill is DI-framework agnostic — it guides Hilt, Koin, Anvil, Metro, or manual injection from first principles, covering project setup, module organisation, ViewModel binding, testability patterns, and common anti-patterns.

Supported tasks:

- `setup <framework>` — bootstrap DI for the project using the named framework
- `audit` — inspect the project for DI anti-patterns and suggest fixes
- `test` — show how to swap real bindings for fakes/mocks in tests
- `migrate <from> <to>` — guide a migration between DI frameworks

Default (no task): explain which framework best fits the project and scaffold the chosen one.

---

## Framework Selection Guide

| Framework | Best for | Key trait |
|---|---|---|
| **Hilt** | New Google-stack projects | Compile-time validation, integrates with Jetpack |
| **Koin** | Kotlin-first, rapid setup | Runtime DSL, minimal boilerplate |
| **Anvil** | Large teams, strict modularity | Scope merging, no generated code at compile time for contributions |
| **Metro** | Kotlin Multiplatform or strict KMP targets | Pure Kotlin, no annotation processor |
| **Manual** | Libraries, tiny apps, full control | Zero runtime overhead, explicit wiring |

Ask the user their preference before scaffolding. Default recommendation: **Hilt** for new Jetpack-based apps.

---

## 1 — Hilt Setup

### Dependency (version catalog)

```toml
# gradle/libs.versions.toml
[versions]
hilt = "2.51.1"

[libraries]
hilt-android         = { module = "com.google.dagger:hilt-android",          version.ref = "hilt" }
hilt-compiler        = { module = "com.google.dagger:hilt-android-compiler",  version.ref = "hilt" }
hilt-navigation      = { module = "androidx.hilt:hilt-navigation-compose",    version = "1.2.0"   }

[plugins]
hilt = { id = "com.google.dagger.hilt.android", version.ref = "hilt" }
ksp  = { id = "com.google.devtools.ksp",         version = "2.0.21-1.0.28"   }
```

### Root `build.gradle.kts`

```kotlin
plugins {
    alias(libs.plugins.hilt) apply false
    alias(libs.plugins.ksp)  apply false
}
```

### App `build.gradle.kts`

```kotlin
plugins {
    alias(libs.plugins.hilt)
    alias(libs.plugins.ksp)
}

dependencies {
    implementation(libs.hilt.android)
    ksp(libs.hilt.compiler)
    implementation(libs.hilt.navigation)
}
```

### Application class

```kotlin
@HiltAndroidApp
class App : Application()
```

`AndroidManifest.xml`:
```xml
<application android:name=".App" ...>
```

### Module organisation

Keep one Hilt module per feature/layer — never one giant `AppModule`.

```kotlin
// :core:data — binds repository implementations
@Module
@InstallIn(SingletonComponent::class)
abstract class DataModule {

    @Binds
    @Singleton
    abstract fun bindUserRepository(impl: UserRepositoryImpl): UserRepository
}

// :feature:profile — provides screen-scoped dependencies
@Module
@InstallIn(ViewModelComponent::class)
abstract class ProfileModule {

    @Binds
    abstract fun bindGetUserProfileUseCase(impl: GetUserProfileUseCaseImpl): GetUserProfileUseCase
}
```

### ViewModel injection

```kotlin
@HiltViewModel
class UserProfileViewModel @Inject constructor(
    private val getUserProfile: GetUserProfileUseCase,
    private val savedStateHandle: SavedStateHandle,
) : ViewModel() { ... }
```

Compose screen:

```kotlin
@Composable
fun UserProfileScreen(
    viewModel: UserProfileViewModel = hiltViewModel(),
    modifier: Modifier = Modifier,
) { ... }
```

---

## 2 — Koin Setup

### Dependency (version catalog)

```toml
[versions]
koin = "3.5.6"

[libraries]
koin-android  = { module = "io.insert-koin:koin-android",         version.ref = "koin" }
koin-compose  = { module = "io.insert-koin:koin-androidx-compose", version.ref = "koin" }
koin-test     = { module = "io.insert-koin:koin-test-junit5",      version.ref = "koin" }
```

### Module definition

```kotlin
val dataModule = module {
    single<UserRepository> { UserRepositoryImpl(get()) }
}

val profileModule = module {
    viewModel { UserProfileViewModel(get()) }
}
```

### Application class

```kotlin
class App : Application() {
    override fun onCreate() {
        super.onCreate()
        startKoin {
            androidContext(this@App)
            modules(dataModule, profileModule)
        }
    }
}
```

### Compose screen

```kotlin
@Composable
fun UserProfileScreen(
    viewModel: UserProfileViewModel = koinViewModel(),
    modifier: Modifier = Modifier,
) { ... }
```

---

## 3 — Anvil Setup

Anvil generates Dagger component contributions — no explicit `@Module` + `@InstallIn` boilerplate.

```toml
[versions]
anvil  = "2.4.9"
dagger = "2.51.1"

[plugins]
anvil = { id = "com.squareup.anvil", version.ref = "anvil" }
```

```kotlin
// Feature module contributes binding without touching AppComponent
@ContributesBinding(AppScope::class)
class UserRepositoryImpl @Inject constructor(
    private val api: UserApi,
) : UserRepository
```

---

## 4 — Metro Setup

Metro is annotation-processor-free and KMP-ready.

```toml
[versions]
metro = "0.1.0"

[plugins]
metro = { id = "dev.zacsweers.metro", version.ref = "metro" }
```

```kotlin
@DependencyGraph
abstract class AppGraph {
    abstract val userRepository: UserRepository
}

@Inject
class UserRepositoryImpl(private val api: UserApi) : UserRepository
```

---

## 5 — Manual / Constructor Injection

Use for libraries, shared modules, or when annotation processors are not acceptable.

```kotlin
// Explicit wiring in Application or top-level object
object AppDependencies {
    private val httpClient: HttpClient by lazy { HttpClient() }
    val userApi: UserApi by lazy { UserApiImpl(httpClient) }
    val userRepository: UserRepository by lazy { UserRepositoryImpl(userApi) }
}

// ViewModel receives dependencies via ViewModelProvider.Factory
class UserProfileViewModelFactory(
    private val getUserProfile: GetUserProfileUseCase,
) : ViewModelProvider.Factory {
    @Suppress("UNCHECKED_CAST")
    override fun <T : ViewModel> create(modelClass: Class<T>): T =
        UserProfileViewModel(getUserProfile) as T
}
```

---

## Testing — Swap Real Bindings for Fakes

### Hilt testing

```kotlin
// Fake module replaces the real one in tests
@TestInstallIn(components = [SingletonComponent::class], replaces = [DataModule::class])
@Module
abstract class FakeDataModule {

    @Binds
    @Singleton
    abstract fun bindUserRepository(fake: FakeUserRepository): UserRepository
}

// Fake implementation (shared across tests)
class FakeUserRepository : UserRepository {
    var profileToReturn: UserProfile? = null

    override fun observeUserProfile(userId: String): Flow<UserProfile> =
        flowOf(profileToReturn ?: error("No profile configured"))

    override suspend fun updateProfile(profile: UserProfile): Result<Unit> = Result.success(Unit)
}
```

### Koin testing

```kotlin
class UserProfileViewModelTest {

    @BeforeEach
    fun setUp() {
        startKoin {
            modules(
                module { single<UserRepository> { FakeUserRepository() } },
                profileModule,
            )
        }
    }

    @AfterEach
    fun tearDown() = stopKoin()
}
```

### Manual / factory testing

```kotlin
class UserProfileViewModelTest {
    private val fakeRepo = FakeUserRepository()
    private val useCase = GetUserProfileUseCaseImpl(fakeRepo)
    private val viewModel = UserProfileViewModel(useCase)
}
```

---

## Anti-Patterns to Avoid

| Anti-pattern | Why it's bad | Fix |
|---|---|---|
| **Service Locator** (`get()` / `inject()` called inside class body) | Hides dependencies, untestable | Constructor-inject everything |
| **God module** (one `AppModule` with 50+ bindings) | Impossible to navigate, slow incremental builds | One module per feature/layer |
| **Injecting `Context` into domain layer** | Breaks Clean Architecture | Keep `Context` in `:core:android` or data layer only |
| **`@Singleton` on everything** | Memory leaks, unexpected shared state | Scope narrowly — prefer `@ViewModelScoped` or unscoped |
| **Accessing `DaggerAppComponent` directly in production code** | Leaks graph, couples call sites to DI | Let Hilt/framework manage the graph; inject through constructors |
| **`lateinit var` injected fields** | Crashes if field accessed before injection | Prefer constructor injection; field injection only in `Activity`/`Fragment` |
| **Circular dependencies** | Compile error or runtime crash | Refactor — introduce an interface or event bus |

---

## Audit Checklist

Run `/dependency-injection audit` to verify:

- [ ] All `ViewModel`s use constructor injection — no manual `ViewModelProvider` boilerplate
- [ ] No `Context` in domain layer classes
- [ ] No `@Singleton` on `ViewModel`s (they are `@HiltViewModel` / `viewModel { }`)
- [ ] Each feature module has its own DI module, not one global `AppModule`
- [ ] Test modules replace production modules correctly (Hilt: `@TestInstallIn`)
- [ ] No static/companion object holding injected references
- [ ] No `inject()` calls inside `init {}` blocks
- [ ] Fake implementations live in `:test-fixtures` or `commonTest` — not in production source sets

---

## Output Format

When auditing, report findings as:

```
## DI Audit — <project/module>

### ✅ Passing
- Constructor injection used throughout domain layer
- Feature modules properly scoped

### ⚠️ Warnings
- `UserRepository` bound as `@Singleton` but holds user-scoped state — consider `@ActivityRetainedScoped`

### ❌ Issues
- `AuthService` references `Context` directly in domain layer
  → Move to `:core:android` and inject via interface abstraction

### 🔧 Recommendations
1. Extract `NetworkModule` from `AppModule` (~18 bindings)
2. Add `FakeUserRepository` to `:core:test-fixtures` for shared test reuse
```
