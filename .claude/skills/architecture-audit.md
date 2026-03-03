---
name: architecture-audit
description: Audits the current project for Clean Architecture violations, layer coupling, module dependency issues, anti-patterns, and scalability problems. Produces a prioritized remediation plan.
---

When the user runs `/architecture-audit`, scan the current project and produce a structured audit report.

## Audit Process

### Step 1: Discover Project Structure
```bash
# Map all modules and their types
find . -name "build.gradle.kts" | sort
# Map import relationships
grep -r "^import" --include="*.kt" | grep "\.feature\.\|\.data\.\|\.domain\.\|\.core\."
# Find Android imports in domain layer
grep -r "android\." --include="*.kt" src/domain/
```

### Step 2: Check Each Layer

#### Domain Layer Checks
```
Rule: ZERO Android framework imports
Scan for: android.*, androidx.*, Context, LiveData, Room annotations
Allowed: kotlin.*, java.*, kotlinx.coroutines.*

Rule: No data layer imports
Scan for: imports from :data:* modules

Rule: Repository interfaces only (no impl classes)
Scan for: class *RepositoryImpl in domain module

Rule: Use cases have single public method
Check: each use case class exposes only operator fun invoke()
```

#### Data Layer Checks
```
Rule: Implements domain interfaces
Check: every *RepositoryImpl implements an interface from :domain

Rule: DTOs vs Domain models separated
Scan for: domain model classes used directly in API/DB responses

Rule: No UI layer imports
Scan for: imports from :feature:* or compose.*

Rule: mappers defined for DTO → Domain
Check: .toDomain() / .toEntity() extension functions present
```

#### UI/Feature Layer Checks
```
Rule: No direct domain or data imports bypassing use cases
Scan for: feature importing from :data:* directly

Rule: Business logic NOT in Composables
Scan for: complex logic inside @Composable functions (network calls, transformations)

Rule: ViewModels only use use cases (not repositories directly)
Scan for: *Repository injected into *ViewModel

Rule: Feature modules independent of each other
Build dependency graph; flag :feature:x → :feature:y edges
```

### Step 3: Cross-Cutting Checks
```
Rule: No circular dependencies
Build full dependency graph; detect cycles

Rule: Hilt scopes correct
@Singleton: repositories, network clients, database
@ActivityScoped: navigation state
@ViewModelScoped: use cases (if stateful)

Rule: No GlobalScope usage
grep -r "GlobalScope" --include="*.kt"

Rule: No LiveData in new code
grep -r "MutableLiveData\|LiveData" --include="*.kt"

Rule: No RxJava imports
grep -r "io.reactivex" --include="*.kt"
```

---

## Audit Report Format

```markdown
# Architecture Audit Report
**Project:** <name>
**Date:** <today>
**Modules scanned:** <count>
**Files scanned:** <count>

## Executive Summary
<2-3 sentences on overall health>

## Health Score: XX/100

| Category | Score | Status |
|---|---|---|
| Layer separation | XX/25 | 🔴/🟠/🟡/✅ |
| Module boundaries | XX/25 | ... |
| Async patterns | XX/25 | ... |
| Testability | XX/25 | ... |

---

## Critical Issues 🔴
*Must fix — these are architectural violations that will cause bugs or prevent scaling*

### [ARCH-001] Android imports in Domain layer
**Files:** `domain/user/UserRepository.kt:3`
**Rule:** Domain layer must have zero Android framework dependencies
**Impact:** Domain module cannot be reused in non-Android targets; breaks testability
**Fix:**
- Remove `android.content.Context` import
- Replace with abstracted interface: `interface FileReader { fun readBytes(path: String): ByteArray }`
- Implement in `:data` module with Android-specific logic

---

## Major Issues 🟠
*Should fix — creates coupling, reduces testability, accumulates tech debt*

### [ARCH-010] ViewModel injecting Repository directly
**Files:** `feature/home/HomeViewModel.kt:8`
**Rule:** ViewModels should depend on Use Cases, not Repositories directly
**Impact:** Business logic leaks into ViewModel; harder to test and reuse
**Fix:**
```kotlin
// Before
class HomeViewModel @Inject constructor(
    private val userRepository: UserRepository, // ← wrong
)

// After
class HomeViewModel @Inject constructor(
    private val getUsersUseCase: GetUsersUseCase, // ← correct
)
```

---

## Minor Issues 🟡
*Improve when convenient — style, consistency, future-proofing*

### [ARCH-020] Missing mapper between DTO and domain model
**Files:** `data/user/UserDto.kt`
**Rule:** DTOs must not be passed to domain or UI layers
**Fix:** Add `fun UserDto.toDomain(): UserProfile = UserProfile(id = id, ...)`

---

## Module Dependency Graph

```
:app ──────────────────────────────────────┐
  └── :feature:home ────────────────────┐  │
  └── :feature:profile ─────────────┐  │  │
  └── :feature:settings ──────────┐ │  │  │
                                   ▼ ▼  ▼  ▼
                             :domain:user  :domain:content
                                   │           │
                             :data:user    :data:content
                                   └─────┬─────┘
                                   :core:network
                                   :core:database
                                   :core:ui
                                   :core:testing
```

**Issues detected:**
- `:feature:home` → `:feature:profile` (direct feature dependency — use navigation instead)

---

## Remediation Plan

### Phase 1 — Critical (Sprint 1)
1. Remove Android imports from domain layer (3 files)
2. Break circular dependency between :feature:home and :feature:profile

### Phase 2 — Major (Sprint 2)
3. Add Use Case layer between ViewModels and Repositories (8 ViewModels)
4. Add DTO mappers for all data layer models

### Phase 3 — Minor (Sprint 3+)
5. Standardize module structure with convention plugins
6. Add `:core:testing` module with shared fakes
```

---

## Anti-Pattern Detection Library

| Anti-pattern | Detection | Severity |
|---|---|---|
| God ViewModel (> 300 lines) | `wc -l *ViewModel.kt \| sort -rn` | 🟠 |
| Business logic in Composable | `@Composable fun.*{[\s\S]*\.launch\|\.collect` | 🔴 |
| Passing Activity to ViewModel | `Activity\|Fragment` injected via Hilt | 🔴 |
| Static singleton state | `companion object.*var\|object.*var` | 🟠 |
| Feature-to-feature dependency | `implementation(project(":feature:` in another feature | 🔴 |
| Domain importing Android | `import android` in `:domain` module | 🔴 |
| ViewModel using Repository directly | `*Repository` in `@Inject constructor` of `*ViewModel` | 🟠 |
| Missing offline-first | Repository not emitting local data before network | 🟡 |
| LiveData in new code | `MutableLiveData\|LiveData<` | 🟠 |
| GlobalScope | `GlobalScope` | 🔴 |
