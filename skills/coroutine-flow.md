---
name: coroutine-flow
description: Designs the optimal coroutine/Flow pipeline for a given async problem — operator selection, error handling, cancellation, testing strategy. Use for any "how do I structure this async code?" question.
---

When the user runs `/coroutine-flow <scenario>`, design the complete coroutine/Flow solution.

## Design Process

For every scenario, answer these questions before writing code:
1. **Cold or Hot?** — Is this a one-shot operation or a stream?
2. **Who owns the lifecycle?** — ViewModel, Repository, Application?
3. **Which dispatcher?** — IO for blocking, Default for CPU, Main for UI
4. **How does cancellation propagate?** — What cleans up on cancel?
5. **How are errors surfaced?** — `Result<T>`, `catch {}`, or `CoroutineExceptionHandler`?
6. **How is it tested?** — `runTest`, `UnconfinedTestDispatcher`, `Turbine`

---

## Common Scenario Templates

### Scenario: Search with Debounce
```kotlin
// Problem: search query → debounced API call → display results, cancel previous on new input
class SearchViewModel @Inject constructor(
    private val searchUseCase: SearchUseCase,
) : ViewModel() {

    private val _query = MutableStateFlow("")
    private val _uiState = MutableStateFlow<SearchUiState>(SearchUiState.Idle)
    val uiState: StateFlow<SearchUiState> = _uiState.asStateFlow()

    init {
        viewModelScope.launch {
            _query
                .debounce(300)                          // wait for user to pause
                .distinctUntilChanged()                 // skip duplicate queries
                .filter { it.length >= 2 }             // minimum chars
                .flatMapLatest { query ->               // cancel previous search on new query
                    if (query.isBlank()) {
                        flowOf(SearchUiState.Idle)
                    } else {
                        searchUseCase(query)
                            .map { SearchUiState.Results(it) }
                            .onStart { emit(SearchUiState.Loading) }
                            .catch { e -> emit(SearchUiState.Error(e.message ?: "Search failed")) }
                    }
                }
                .collect { _uiState.value = it }
        }
    }

    fun onQueryChange(query: String) { _query.value = query }
}
```

### Scenario: Offline-First Data with Periodic Refresh
```kotlin
// Problem: show cached data immediately, refresh from network, retry on failure
class UserRepositoryImpl @Inject constructor(
    private val localSource: UserLocalDataSource,
    private val remoteSource: UserRemoteDataSource,
    @IoDispatcher private val ioDispatcher: CoroutineDispatcher,
) : UserRepository {

    override fun observeUser(userId: String): Flow<UserProfile> = flow {
        // 1. Emit cached data immediately
        emitAll(localSource.observeUser(userId).map { it.toDomain() })
    }.onStart {
        // 2. Trigger background refresh (doesn't block emission)
        refreshUser(userId)
    }.flowOn(ioDispatcher)

    override suspend fun refreshUser(userId: String): Result<Unit> =
        withContext(ioDispatcher) {
            runCatching {
                val dto = remoteSource.fetchUser(userId)
                localSource.save(dto.toEntity())
            }
        }
}

// In ViewModel: stateIn converts cold Flow to hot StateFlow
val userState: StateFlow<UserUiState> = userRepository.observeUser(userId)
    .map { UserUiState.Success(it) }
    .catch { emit(UserUiState.Error(it.message ?: "Unknown error")) }
    .stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(stopTimeoutMillis = 5_000),
        initialValue = UserUiState.Loading,
    )
```

### Scenario: Parallel Concurrent Requests
```kotlin
// Problem: fetch user + notifications + settings simultaneously, combine when all done
class DashboardViewModel @Inject constructor(
    private val userUseCase: GetUserUseCase,
    private val notificationsUseCase: GetNotificationsUseCase,
    private val settingsUseCase: GetSettingsUseCase,
) : ViewModel() {

    val dashboardState: StateFlow<DashboardUiState> = combine(
        userUseCase(),
        notificationsUseCase(),
        settingsUseCase(),
    ) { userResult, notificationsResult, settingsResult ->
        when {
            userResult.isFailure -> DashboardUiState.Error(userResult.exceptionOrNull()!!.message)
            else -> DashboardUiState.Success(
                user = userResult.getOrThrow(),
                notifications = notificationsResult.getOrDefault(emptyList()),
                settings = settingsResult.getOrDefault(Settings.default()),
            )
        }
    }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), DashboardUiState.Loading)

    // Alternative: async/await for one-shot parallel fetch
    suspend fun fetchDashboardOnce(): DashboardData = coroutineScope {
        val userDeferred = async { userRepository.fetchUser() }
        val notifDeferred = async { notificationRepository.fetchNotifications() }
        val settingsDeferred = async { settingsRepository.fetchSettings() }

        DashboardData(
            user = userDeferred.await(),
            notifications = notifDeferred.await(),
            settings = settingsDeferred.await(),
        )
    }
}
```

### Scenario: Retry with Exponential Backoff
```kotlin
// Problem: network call that should retry with backoff on transient failures
fun <T> Flow<T>.retryWithBackoff(
    maxAttempts: Int = 3,
    initialDelay: Duration = 1.seconds,
    maxDelay: Duration = 30.seconds,
    factor: Double = 2.0,
    retryOn: (Throwable) -> Boolean = { it is IOException },
): Flow<T> = retryWhen { cause, attempt ->
    if (attempt < maxAttempts && retryOn(cause)) {
        val delay = minOf(initialDelay * factor.pow(attempt.toDouble()), maxDelay)
        delay(delay)
        true
    } else {
        false
    }
}

// Usage
fun observeItems(): Flow<List<Item>> = remoteSource.streamItems()
    .retryWithBackoff(maxAttempts = 3, retryOn = { it is IOException || it is TimeoutException })
    .catch { e -> emit(emptyList()) }  // final fallback
```

### Scenario: Progress Tracking for Long Operations
```kotlin
// Problem: file upload / large data sync with progress updates
sealed interface UploadState {
    data object Idle : UploadState
    data class Uploading(val progress: Float) : UploadState
    data class Success(val url: String) : UploadState
    data class Error(val message: String) : UploadState
}

class UploadViewModel @Inject constructor(
    private val fileRepository: FileRepository,
) : ViewModel() {

    private val _uploadState = MutableStateFlow<UploadState>(UploadState.Idle)
    val uploadState: StateFlow<UploadState> = _uploadState.asStateFlow()

    fun uploadFile(uri: Uri) {
        viewModelScope.launch {
            fileRepository.uploadFile(uri)
                .collect { progress ->
                    _uploadState.value = when (progress) {
                        is UploadProgress.InProgress -> UploadState.Uploading(progress.fraction)
                        is UploadProgress.Complete -> UploadState.Success(progress.url)
                    }
                }
        }
    }
}

// In Repository
fun uploadFile(uri: Uri): Flow<UploadProgress> = channelFlow {
    val request = buildUploadRequest(uri) { bytesWritten, contentLength ->
        trySend(UploadProgress.InProgress(bytesWritten.toFloat() / contentLength))
    }
    val response = api.upload(request)
    send(UploadProgress.Complete(response.url))
}
    .catch { e -> throw UploadException("Upload failed: ${e.message}", e) }
    .flowOn(ioDispatcher)
```

### Scenario: Event Bus / Cross-Component Communication
```kotlin
// Problem: events that need to survive configuration changes and reach multiple consumers
@Singleton
class AppEventBus @Inject constructor() {
    private val _events = MutableSharedFlow<AppEvent>(
        replay = 0,
        extraBufferCapacity = 8,
        onBufferOverflow = BufferOverflow.DROP_OLDEST,
    )
    val events: SharedFlow<AppEvent> = _events.asSharedFlow()

    fun publish(event: AppEvent) {
        _events.tryEmit(event)
    }
}

// Consuming in ViewModel
class HomeViewModel @Inject constructor(
    private val eventBus: AppEventBus,
) : ViewModel() {
    init {
        viewModelScope.launch {
            eventBus.events
                .filterIsInstance<AppEvent.UserLoggedOut>()
                .collect { handleLogout() }
        }
    }
}
```

### Scenario: Pagination with Paging 3
```kotlin
// Problem: infinite scroll list
class ItemPagingSource @Inject constructor(
    private val api: ItemApi,
) : PagingSource<Int, Item>() {

    override suspend fun load(params: LoadParams<Int>): LoadResult<Int, Item> {
        val page = params.key ?: 1
        return try {
            val response = api.getItems(page = page, pageSize = params.loadSize)
            LoadResult.Page(
                data = response.items,
                prevKey = if (page == 1) null else page - 1,
                nextKey = if (response.items.isEmpty()) null else page + 1,
            )
        } catch (e: Exception) {
            LoadResult.Error(e)
        }
    }

    override fun getRefreshKey(state: PagingState<Int, Item>): Int? =
        state.anchorPosition?.let { state.closestPageToPosition(it)?.prevKey?.plus(1) }
}

// In ViewModel
val items: Flow<PagingData<Item>> = Pager(
    config = PagingConfig(pageSize = 20, enablePlaceholders = false),
    pagingSourceFactory = { itemPagingSource },
).flow.cachedIn(viewModelScope)
```

## Testing Template for Any Flow Scenario
```kotlin
@Test
fun `scenario under test`() = runTest {
    // Given
    val testDispatcher = UnconfinedTestDispatcher(testScheduler)

    // When / Then — Turbine for Flow assertions
    viewModel.uiState.test {
        assertEquals(Expected.Loading, awaitItem())

        // Trigger action
        viewModel.loadData()

        assertEquals(Expected.Success(data), awaitItem())
        expectNoEvents()
        cancelAndIgnoreRemainingEvents()
    }
}
```
