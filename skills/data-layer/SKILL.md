---
name: data-layer
description: Designs and scaffolds the Android data layer — offline-first repositories with Room as the single source of truth, DataStore for preferences, Retrofit/Ktor + kotlinx.serialization networking, WorkManager sync, Room migrations and schema tests, error mapping, and fakes for tests. Use for repositories, caching, persistence, sync, or "make this work offline" tasks.
---

When the user runs `/data-layer <scenario>`, design or scaffold the data layer for that scenario. Follow the [Android data layer guide](https://developer.android.com/topic/architecture/data-layer) and the [offline-first guide](https://developer.android.com/topic/architecture/data-layer/offline-first). Match the project's existing DI framework, network client and module layout. Never add a second one.

## Tasks

| Command | Action |
|---|---|
| `/data-layer repository <Entity>` | Repository interface (domain) + offline-first implementation (data) + fake |
| `/data-layer room <Entity>` | Entity, DAO, database wiring, exported schema, migration test |
| `/data-layer datastore <Name>` | Typed preferences repository on DataStore |
| `/data-layer sync` | WorkManager-based sync with constraints, backoff and unique work |
| `/data-layer network <Api>` | API interface, DTOs, serialization, error mapping |
| `/data-layer audit` | Review an existing data layer against these rules |

## Rule 1 — Layering and module placement

```
:core:model      pure Kotlin domain models (no annotations from Room/serialization)
:core:domain     repository interfaces + use cases (pure Kotlin)
:core:database   Room entities, DAOs, database, migrations
:core:network    API, DTOs, client configuration
:core:datastore  DataStore-backed preferences
:core:data       repository implementations, mappers, sync workers
```

- Entities, DTOs and domain models are **three different types**. Map them at the repository boundary with `toDomain()` / `toEntity()` extension functions. Never let `@Entity` or `@Serializable` types reach the UI.
- Repository interfaces live in domain. Implementations are `internal` in `:core:data` and bound through DI.

## Rule 2 — Offline-first repository: the database is the source of truth

```kotlin
// :core:domain
interface TopicRepository {
    fun observeTopics(): Flow<List<Topic>>
    suspend fun refresh(): Result<Unit>
    suspend fun setFollowed(id: String, followed: Boolean)
}

// :core:data
internal class OfflineFirstTopicRepository(
    private val dao: TopicDao,
    private val api: TopicApi,
    private val ioDispatcher: CoroutineDispatcher,
) : TopicRepository {

    // Reads always come from Room, so the UI works offline and updates when the database changes
    override fun observeTopics(): Flow<List<Topic>> =
        dao.observeAll().map { entities -> entities.map(TopicEntity::toDomain) }

    override suspend fun refresh(): Result<Unit> = withContext(ioDispatcher) {
        runSuspendCatching {
            val remote = api.getTopics()
            dao.upsertAll(remote.map(TopicDto::toEntity))   // network → DB, never network → UI
        }
    }

    // Local write first (optimistic), sync pushes it later
    override suspend fun setFollowed(id: String, followed: Boolean) = withContext(ioDispatcher) {
        dao.setFollowed(id, followed, pendingSync = true)
    }
}

/** runCatching that rethrows CancellationException, so structured concurrency still works. */
suspend inline fun <T> runSuspendCatching(block: () -> T): Result<T> =
    try { Result.success(block()) } catch (e: CancellationException) { throw e } catch (e: Exception) { Result.failure(e) }
```

Rules:
- Expose `Flow` for observable data and `suspend` for one-shot operations. Never expose `MutableStateFlow` or a callback.
- Repositories own the dispatcher switch (`withContext(ioDispatcher)`). Callers never pick dispatchers.
- Never swallow `CancellationException`. Plain `runCatching` around suspend calls breaks cancellation.
- Map errors to a domain error type (`sealed interface DataError`) or `Result`. Don't leak `HttpException` or `SQLiteException` to the UI.

## Rule 3 — Room

```kotlin
@Entity(tableName = "topics", indices = [Index("name")])
data class TopicEntity(
    @PrimaryKey val id: String,
    val name: String,
    val followed: Boolean,
    @ColumnInfo(defaultValue = "0") val pendingSync: Boolean,
)

@Dao
interface TopicDao {
    @Query("SELECT * FROM topics ORDER BY name")
    fun observeAll(): Flow<List<TopicEntity>>

    @Upsert
    suspend fun upsertAll(items: List<TopicEntity>)

    @Query("UPDATE topics SET followed = :followed, pendingSync = :pendingSync WHERE id = :id")
    suspend fun setFollowed(id: String, followed: Boolean, pendingSync: Boolean)

    @Query("SELECT * FROM topics WHERE pendingSync = 1")
    suspend fun pending(): List<TopicEntity>
}

@Database(
    entities = [TopicEntity::class],
    version = 2,
    autoMigrations = [AutoMigration(from = 1, to = 2)],
)
abstract class AppDatabase : RoomDatabase() {
    abstract fun topicDao(): TopicDao
}
```

Build setup (in the database convention plugin or module):

```kotlin
plugins {
    alias(libs.plugins.ksp)
    alias(libs.plugins.room)
}
room { schemaDirectory("$projectDir/schemas") }   // commit schemas/: they are the migration contract
dependencies {
    implementation(libs.androidx.room.runtime)
    ksp(libs.androidx.room.compiler)
    androidTestImplementation(libs.androidx.room.testing)
}
```

- **Every** schema change bumps `version` and comes with an auto-migration or a manual `Migration`. **Never** use `fallbackToDestructiveMigration()` in release builds, because it deletes user data.
- Test migrations with `MigrationTestHelper` against the exported schemas.
- Use `@Transaction` for multi-statement writes and `@Relation` reads.
- DAO functions are `suspend` or return `Flow`. Never block the main thread (`allowMainThreadQueries()` is banned).

## Rule 4 — DataStore for preferences, never SharedPreferences

```kotlin
class UserPreferencesRepository(private val dataStore: DataStore<Preferences>) {
    private object Keys {
        val DARK_THEME = booleanPreferencesKey("dark_theme")
    }

    val preferences: Flow<UserPreferences> = dataStore.data
        .catch { e -> if (e is IOException) emit(emptyPreferences()) else throw e }
        .map { prefs -> UserPreferences(darkTheme = prefs[Keys.DARK_THEME] ?: false) }

    suspend fun setDarkTheme(enabled: Boolean) {
        dataStore.edit { it[Keys.DARK_THEME] = enabled }
    }
}

// Exactly ONE DataStore instance per file per process: create it as a DI singleton
val Context.userPreferences: DataStore<Preferences> by preferencesDataStore(name = "user_preferences")
```

- Use a typed DataStore (kotlinx.serialization or Proto) for structured settings.
- Migrate from SharedPreferences with `SharedPreferencesMigration`.
- Secrets don't belong in DataStore in plain text. See [`security`](../security/SKILL.md).

## Rule 5 — Networking

```kotlin
@Serializable
data class TopicDto(val id: String, val name: String)

interface TopicApi {
    @GET("topics")
    suspend fun getTopics(): List<TopicDto>
}

val json = Json { ignoreUnknownKeys = true; explicitNulls = false }

fun provideRetrofit(okHttp: OkHttpClient, baseUrl: String): Retrofit = Retrofit.Builder()
    .baseUrl(baseUrl)
    .client(okHttp)
    .addConverterFactory(json.asConverterFactory("application/json".toMediaType()))
    .build()
```

- One `OkHttpClient` per app (shared connection pool). Derive variants with `newBuilder()`.
- Timeouts set explicitly. Logging interceptor in debug builds only, with `redactHeader("Authorization")`.
- Ktor client is equally valid (and required for KMP). Use whichever the project already uses.
- `ignoreUnknownKeys = true` so additive backend changes don't crash old app versions.

## Rule 6 — Sync with WorkManager

```kotlin
class SyncWorker(
    context: Context,
    params: WorkerParameters,
    private val repository: TopicRepository,
) : CoroutineWorker(context, params) {
    override suspend fun doWork(): Result =
        repository.refresh().fold(
            onSuccess = { Result.success() },
            onFailure = { if (runAttemptCount < 5) Result.retry() else Result.failure() },
        )
}

fun WorkManager.enqueueSync() = enqueueUniqueWork(
    "sync",
    ExistingWorkPolicy.KEEP,
    OneTimeWorkRequestBuilder<SyncWorker>()
        .setConstraints(Constraints(requiredNetworkType = NetworkType.CONNECTED))
        .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 10, TimeUnit.SECONDS)
        .setExpedited(OutOfQuotaPolicy.RUN_AS_NON_EXPEDITED_WORK_REQUEST)
        .build(),
)
```

- Workers get dependencies through a custom `WorkerFactory` (Hilt: `@HiltWorker`; Koin: `workManagerFactory()`; manual: your own `WorkerFactory`), so remove the default initializer from the manifest.
- Use unique work names so sync is never enqueued twice.
- Push local `pendingSync` rows first, then pull. Resolve conflicts with an explicit policy (last-write-wins by server timestamp, or merge), and document which one.

## Rule 7 — Testing

- **Fakes over mocks** for repositories and DAOs: `FakeTopicRepository` backed by `MutableStateFlow` lives in a `:core:testing` module and is reused by ViewModel tests.
- DAO tests: `Room.inMemoryDatabaseBuilder(...)` (instrumented, or Robolectric on the JVM).
- Repository tests: fake API + in-memory DB, assert with Turbine that `observeTopics()` emits after `refresh()`.
- Migration tests: `MigrationTestHelper` for every version step.
- Network tests: `MockWebServer` with recorded JSON fixtures, including malformed and error responses.

## Audit checklist

- [ ] UI reads only from repositories, and repositories read from the DB (single source of truth)
- [ ] No `@Entity` / DTO types in `:core:domain` or UI
- [ ] `CancellationException` is never swallowed
- [ ] Room schemas exported and committed, each version has a migration and a test
- [ ] No `fallbackToDestructiveMigration()` in release, no `allowMainThreadQueries()`
- [ ] One DataStore instance per file, no SharedPreferences in new code
- [ ] One `OkHttpClient`, logging only in debug, auth headers redacted
- [ ] Sync uses unique WorkManager work with constraints and backoff
- [ ] Fakes exist for every repository interface
