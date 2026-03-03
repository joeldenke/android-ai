---
name: new-feature
description: Scaffolds a complete, production-ready MVVM feature — Compose screen, ViewModel, UseCase, Repository interface, Repository implementation, Hilt DI module, and unit tests. Follows Clean Architecture layer separation.
---

When the user runs `/new-feature <FeatureName> [description]`, generate the full vertical slice for that feature.

## What to Generate

Given `/new-feature UserProfile "Display and edit user profile"`, produce:

### 1. Domain Layer — `:domain:user` module

**`UserProfile.kt`** — domain model
```kotlin
data class UserProfile(
    val id: String,
    val displayName: String,
    val bio: String,
    val avatarUrl: String?,
    val updatedAt: Instant,
)
```

**`UserRepository.kt`** — repository interface (NO Android imports)
```kotlin
interface UserRepository {
    fun observeUserProfile(userId: String): Flow<UserProfile>
    suspend fun updateProfile(profile: UserProfile): Result<Unit>
}
```

**`GetUserProfileUseCase.kt`** — single-responsibility use case
```kotlin
class GetUserProfileUseCase @Inject constructor(
    private val userRepository: UserRepository,
) {
    operator fun invoke(userId: String): Flow<Result<UserProfile>> =
        userRepository.observeUserProfile(userId)
            .map { Result.success(it) }
            .catch { emit(Result.failure(it)) }
}
```

**`UpdateUserProfileUseCase.kt`**
```kotlin
class UpdateUserProfileUseCase @Inject constructor(
    private val userRepository: UserRepository,
) {
    suspend operator fun invoke(profile: UserProfile): Result<Unit> =
        userRepository.updateProfile(profile)
}
```

### 2. Data Layer — `:data:user` module

**`UserRepositoryImpl.kt`**
```kotlin
class UserRepositoryImpl @Inject constructor(
    private val remoteSource: UserRemoteDataSource,
    private val localSource: UserLocalDataSource,
    @IoDispatcher private val ioDispatcher: CoroutineDispatcher,
) : UserRepository {

    override fun observeUserProfile(userId: String): Flow<UserProfile> =
        localSource.observeUser(userId)
            .map { it.toDomain() }
            .onStart { refreshProfile(userId) }
            .flowOn(ioDispatcher)

    override suspend fun updateProfile(profile: UserProfile): Result<Unit> =
        withContext(ioDispatcher) {
            runCatching {
                val dto = remoteSource.updateUser(profile.toDto())
                localSource.save(dto.toEntity())
            }
        }
}
```

**`UserDataModule.kt`** — Hilt bindings
```kotlin
@Module
@InstallIn(SingletonComponent::class)
abstract class UserDataModule {

    @Binds
    @Singleton
    abstract fun bindUserRepository(impl: UserRepositoryImpl): UserRepository
}
```

### 3. UI Layer — `:feature:userprofile` module

**`UserProfileUiState.kt`**
```kotlin
sealed interface UserProfileUiState {
    data object Loading : UserProfileUiState
    data class Success(val profile: UserProfile) : UserProfileUiState
    data class Error(val message: String) : UserProfileUiState
}

sealed interface UserProfileUiEvent {
    data class NavigateTo(val destination: String) : UserProfileUiEvent
    data class ShowSnackbar(val message: String) : UserProfileUiEvent
}
```

**`UserProfileViewModel.kt`**
```kotlin
@HiltViewModel
class UserProfileViewModel @Inject constructor(
    savedStateHandle: SavedStateHandle,
    private val getUserProfileUseCase: GetUserProfileUseCase,
    private val updateUserProfileUseCase: UpdateUserProfileUseCase,
) : ViewModel() {

    private val userId: String = checkNotNull(savedStateHandle["userId"])

    private val _uiState = MutableStateFlow<UserProfileUiState>(UserProfileUiState.Loading)
    val uiState: StateFlow<UserProfileUiState> = _uiState.asStateFlow()

    private val _events = MutableSharedFlow<UserProfileUiEvent>(extraBufferCapacity = 1)
    val events: SharedFlow<UserProfileUiEvent> = _events.asSharedFlow()

    init {
        loadProfile()
    }

    private fun loadProfile() {
        viewModelScope.launch {
            getUserProfileUseCase(userId).collect { result ->
                _uiState.value = result.fold(
                    onSuccess = { UserProfileUiState.Success(it) },
                    onFailure = { UserProfileUiState.Error(it.message ?: "Unknown error") },
                )
            }
        }
    }

    fun onSaveProfile(profile: UserProfile) {
        viewModelScope.launch {
            updateUserProfileUseCase(profile)
                .onSuccess { _events.emit(UserProfileUiEvent.ShowSnackbar("Profile saved")) }
                .onFailure { _events.emit(UserProfileUiEvent.ShowSnackbar("Save failed: ${it.message}")) }
        }
    }
}
```

**`UserProfileScreen.kt`**
```kotlin
@Composable
fun UserProfileScreen(
    onNavigateBack: () -> Unit,
    modifier: Modifier = Modifier,
    viewModel: UserProfileViewModel = hiltViewModel(),
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val snackbarHostState = remember { SnackbarHostState() }

    LaunchedEffect(Unit) {
        viewModel.events.collect { event ->
            when (event) {
                is UserProfileUiEvent.ShowSnackbar ->
                    snackbarHostState.showSnackbar(event.message)
                is UserProfileUiEvent.NavigateTo ->
                    onNavigateBack()
            }
        }
    }

    Scaffold(
        modifier = modifier,
        snackbarHost = { SnackbarHost(snackbarHostState) },
        topBar = {
            TopAppBar(
                title = { Text("Profile") },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
            )
        },
    ) { padding ->
        UserProfileContent(
            uiState = uiState,
            onSaveProfile = viewModel::onSaveProfile,
            modifier = Modifier.padding(padding),
        )
    }
}

@Composable
private fun UserProfileContent(
    uiState: UserProfileUiState,
    onSaveProfile: (UserProfile) -> Unit,
    modifier: Modifier = Modifier,
) {
    when (uiState) {
        UserProfileUiState.Loading -> LoadingContent(modifier = modifier)
        is UserProfileUiState.Error -> ErrorContent(message = uiState.message, modifier = modifier)
        is UserProfileUiState.Success -> ProfileForm(
            profile = uiState.profile,
            onSave = onSaveProfile,
            modifier = modifier,
        )
    }
}
```

### 4. Tests — `:feature:userprofile` test source set

Generate `UserProfileViewModelTest.kt` covering:
- Loading state on init
- Success state when use case emits
- Error state on failure
- Save triggers snackbar event

Generate `UserProfileScreenTest.kt` covering:
- Loading indicator displayed
- Profile fields rendered correctly
- Save button triggers ViewModel

## Checklist Before Finishing

- [ ] Domain model is a `data class` with only Kotlin/Java types (no Android)
- [ ] Repository interface lives in `:domain`, implementation in `:data`
- [ ] ViewModel uses `viewModelScope`, not custom scope
- [ ] All screens have `modifier: Modifier = Modifier`
- [ ] ViewModel never passed to child composables
- [ ] All state collected with `collectAsStateWithLifecycle()`
- [ ] Hilt module created for DI bindings
- [ ] Tests cover all three states: Loading, Success, Error
