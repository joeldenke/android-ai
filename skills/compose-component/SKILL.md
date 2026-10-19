---
name: compose-component
description: Creates a production-ready Composable component with full Slack Compose rule compliance — correct modifier usage, state hoisting, previews, accessibility semantics, and Material3. Use for any new UI component.
---

When the user runs `/compose-component <ComponentName> [description]`, generate a complete, production-ready composable.

## What to Generate

Given `/compose-component UserAvatar "Circular avatar with fallback initials"`, produce:

### Full Component Template

```kotlin
// UserAvatar.kt — in :core:ui or appropriate :feature module

/**
 * Displays a user avatar as a circular image.
 * Falls back to initials on a colored background when [avatarUrl] is null or fails to load.
 *
 * @param displayName Used to generate fallback initials and accessibility description
 * @param avatarUrl Optional remote image URL; null shows initials fallback
 * @param size Diameter of the avatar circle
 * @param onClick Optional click handler; if null, the avatar is not clickable
 * @param modifier Modifier to apply to the root element
 */
@Composable
fun UserAvatar(
    displayName: String,
    avatarUrl: String?,
    size: Dp = 48.dp,
    onClick: (() -> Unit)? = null,
    modifier: Modifier = Modifier,            // Slack: compose:modifier-missing-check
) {
    val initials = remember(displayName) {    // Slack: compose:remember-missing-check
        displayName
            .trim()
            .split(" ")
            .take(2)
            .mapNotNull { it.firstOrNull()?.uppercaseChar() }
            .joinToString("")
    }

    val avatarColor = remember(displayName) {
        AvatarColors.forName(displayName)
    }

    val baseModifier = modifier               // Slack: compose:modifier-reused-check
        .size(size)
        .clip(CircleShape)
        .semantics {                          // Accessibility
            contentDescription = "$displayName's avatar"
            if (onClick != null) role = Role.Button
        }

    val clickableModifier = if (onClick != null) {
        baseModifier.clickable(onClick = onClick)
    } else {
        baseModifier
    }

    Box(
        modifier = clickableModifier,         // Slack: compose:modifier-not-used-at-root
        contentAlignment = Alignment.Center,
    ) {
        if (avatarUrl != null) {
            AsyncImage(
                model = ImageRequest.Builder(LocalContext.current)
                    .data(avatarUrl)
                    .crossfade(true)
                    .build(),
                contentDescription = null,    // parent Box has contentDescription
                contentScale = ContentScale.Crop,
                modifier = Modifier.fillMaxSize(),
                fallback = painterResource(R.drawable.ic_person_placeholder),
            )
        } else {
            // Initials fallback
            Surface(
                color = avatarColor,
                modifier = Modifier.fillMaxSize(),
            ) {
                Text(
                    text = initials,
                    style = MaterialTheme.typography.labelLarge,
                    color = MaterialTheme.colorScheme.onPrimary,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.wrapContentHeight(),
                )
            }
        }
    }
}

// Utility object for deterministic color assignment
private object AvatarColors {
    private val palette = listOf(
        Color(0xFF1565C0), Color(0xFF2E7D32), Color(0xFFC62828),
        Color(0xFF6A1B9A), Color(0xFF00695C), Color(0xFFE65100),
    )

    fun forName(name: String): Color =
        palette[name.hashCode().absoluteValue % palette.size]
}
```

### Previews (Slack rules: compose:preview-naming, compose:preview-public)

```kotlin
// UserAvatarPreviews.kt — same package, separate file keeps previews out of production

@Preview(name = "With image", showBackground = true)
@Preview(name = "Dark mode", uiMode = Configuration.UI_MODE_NIGHT_YES, showBackground = true)
@Composable
private fun UserAvatarWithImagePreview() {
    AppTheme {
        UserAvatar(
            displayName = "Jane Doe",
            avatarUrl = "https://picsum.photos/100",
        )
    }
}

@Preview(name = "Initials fallback")
@Composable
private fun UserAvatarInitialsPreview() {
    AppTheme {
        UserAvatar(
            displayName = "Jane Doe",
            avatarUrl = null,
        )
    }
}

@Preview(name = "Clickable")
@Composable
private fun UserAvatarClickablePreview() {
    AppTheme {
        UserAvatar(
            displayName = "Bob Smith",
            avatarUrl = null,
            onClick = {},
        )
    }
}

@Preview(name = "Size variants")
@Composable
private fun UserAvatarSizesPreview() {
    AppTheme {
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            UserAvatar(displayName = "A", avatarUrl = null, size = 32.dp)
            UserAvatar(displayName = "B", avatarUrl = null, size = 48.dp)
            UserAvatar(displayName = "C", avatarUrl = null, size = 64.dp)
        }
    }
}
```

### Tests

```kotlin
class UserAvatarTest {
    @get:Rule val composeRule = createComposeRule()

    @Test
    fun `shows initials when avatarUrl is null`() {
        composeRule.setContent {
            AppTheme { UserAvatar(displayName = "Jane Doe", avatarUrl = null) }
        }

        composeRule.onNodeWithText("JD").assertIsDisplayed()
    }

    @Test
    fun `has correct content description for accessibility`() {
        composeRule.setContent {
            AppTheme { UserAvatar(displayName = "Jane Doe", avatarUrl = null) }
        }

        composeRule.onNodeWithContentDescription("Jane Doe's avatar").assertExists()
    }

    @Test
    fun `is clickable when onClick provided`() {
        var clicked = false
        composeRule.setContent {
            AppTheme {
                UserAvatar(
                    displayName = "Jane Doe",
                    avatarUrl = null,
                    onClick = { clicked = true },
                )
            }
        }

        composeRule.onNodeWithContentDescription("Jane Doe's avatar").performClick()
        assertTrue(clicked)
    }

    @Test
    fun `is not clickable when onClick is null`() {
        composeRule.setContent {
            AppTheme { UserAvatar(displayName = "Jane Doe", avatarUrl = null) }
        }

        composeRule
            .onNodeWithContentDescription("Jane Doe's avatar")
            .assertHasNoClickAction()
    }
}
```

## Checklist You Enforce for Every Component

### Slack Compose Rules
- [ ] **compose:modifier-missing-check** — `modifier: Modifier = Modifier` present
- [ ] **compose:modifier-not-used-at-root** — modifier applied to root element only
- [ ] **compose:modifier-without-default-check** — defaults to `Modifier`
- [ ] **compose:modifier-reused-check** — modifier not passed to multiple children
- [ ] **compose:naming-check** — function is PascalCase
- [ ] **compose:parameter-ordering** — required → optional → modifier → trailing lambda
- [ ] **compose:preview-naming** — preview functions end with `Preview`
- [ ] **compose:preview-public** — preview functions are `private`
- [ ] **compose:remember-missing-check** — all stateful objects are `remember`ed
- [ ] **compose:mutable-params-check** — no `var` parameters
- [ ] **compose:vm-forwarding-check** — no ViewModel parameter
- [ ] **compose:m2-api-check** — Material3 only
- [ ] **compose:content-emitter-returning-values-check** — returns `Unit`

### Accessibility
- [ ] Meaningful `contentDescription` on all images and icons
- [ ] `Role` set correctly for interactive elements (Button, Checkbox, etc.)
- [ ] Touch targets at least 48dp × 48dp
- [ ] Color is not the only conveyor of information

### Performance
- [ ] All computed values inside `remember(key) {}`
- [ ] Parameters are stable types or annotated `@Stable`/`@Immutable`
- [ ] `List<T>` replaced with `ImmutableList<T>` if passed as param
- [ ] No side effects outside `LaunchedEffect`/`SideEffect`/`DisposableEffect`
