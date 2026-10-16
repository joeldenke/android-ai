# App badging guard (AGP 9, configuration-cache safe)

`aapt2 dump badging` prints the permissions, `uses-feature` requirements, SDK levels and supported screens of the final APK. A committed golden file diffed in CI catches dependency updates that silently add `<uses-feature android:required="true">`, which removes the app from tablets, TVs, Chromebooks or cars.

This version uses only AGP 9 public APIs (`androidComponents`, `sdkComponents`, `SingleArtifact.APK_FROM_BUNDLE`) and Gradle 9 services (`ExecOperations`). It never uses `BaseExtension`/`AppExtension` (removed in AGP 9) or `project.exec` (removed in Gradle 9).

```kotlin
// build-logic/convention/src/main/kotlin/AndroidApplicationBadgingConventionPlugin.kt
import com.android.build.api.artifact.SingleArtifact
import com.android.build.api.dsl.ApplicationExtension
import com.android.build.api.variant.ApplicationAndroidComponentsExtension
import org.gradle.api.DefaultTask
import org.gradle.api.GradleException
import org.gradle.api.Plugin
import org.gradle.api.Project
import org.gradle.api.file.RegularFileProperty
import org.gradle.api.provider.Property
import org.gradle.api.tasks.CacheableTask
import org.gradle.api.tasks.Copy
import org.gradle.api.tasks.Input
import org.gradle.api.tasks.InputFile
import org.gradle.api.tasks.OutputFile
import org.gradle.api.tasks.PathSensitive
import org.gradle.api.tasks.PathSensitivity
import org.gradle.api.tasks.TaskAction
import org.gradle.kotlin.dsl.getByType
import org.gradle.kotlin.dsl.register
import org.gradle.process.ExecOperations
import javax.inject.Inject

class AndroidApplicationBadgingConventionPlugin : Plugin<Project> {
    override fun apply(target: Project) = with(target) {
        pluginManager.withPlugin("com.android.application") {
            val android = extensions.getByType<ApplicationExtension>()
            val androidComponents = extensions.getByType<ApplicationAndroidComponentsExtension>()
            val aapt2Name = if (System.getProperty("os.name").startsWith("Windows")) "aapt2.exe" else "aapt2"

            androidComponents.onVariants { variant ->
                val name = variant.name.replaceFirstChar(Char::uppercaseChar)
                val golden = layout.projectDirectory.file("badging/${variant.name}-badging.txt")

                val generate = tasks.register<GenerateBadgingTask>("generate${name}Badging") {
                    apk.set(variant.artifacts.get(SingleArtifact.APK_FROM_BUNDLE))
                    aapt2Executable.set(
                        androidComponents.sdkComponents.sdkDirectory.map {
                            it.file("build-tools/${android.buildToolsVersion}/$aapt2Name")
                        },
                    )
                    badging.set(layout.buildDirectory.file("outputs/badging/${variant.name}-badging.txt"))
                }

                tasks.register<Copy>("update${name}Badging") {
                    group = "badging"
                    description = "Copies the generated ${variant.name} badging to badging/ — commit the result"
                    from(generate.flatMap { it.badging })
                    into(golden.asFile.parentFile)
                }

                tasks.register<CheckBadgingTask>("check${name}Badging") {
                    group = "verification"
                    description = "Fails if the ${variant.name} APK's badging differs from the committed golden file"
                    generatedBadging.set(generate.flatMap { it.badging })
                    goldenBadging.set(golden)
                    updateTaskName.set("update${name}Badging")
                    result.set(layout.buildDirectory.file("intermediates/badging-check/${variant.name}.txt"))
                }
            }
        }
    }
}

@CacheableTask
abstract class GenerateBadgingTask : DefaultTask() {
    @get:InputFile
    @get:PathSensitive(PathSensitivity.NONE)
    abstract val apk: RegularFileProperty

    @get:InputFile
    @get:PathSensitive(PathSensitivity.NONE)
    abstract val aapt2Executable: RegularFileProperty

    @get:OutputFile
    abstract val badging: RegularFileProperty

    @get:Inject
    abstract val execOperations: ExecOperations

    @TaskAction
    fun generate() {
        badging.get().asFile.outputStream().use { out ->
            execOperations.exec {
                commandLine(aapt2Executable.get().asFile.absolutePath, "dump", "badging", apk.get().asFile.absolutePath)
                standardOutput = out
            }
        }
    }
}

@CacheableTask
abstract class CheckBadgingTask : DefaultTask() {
    @get:InputFile
    @get:PathSensitive(PathSensitivity.NONE)
    abstract val generatedBadging: RegularFileProperty

    @get:InputFile
    @get:PathSensitive(PathSensitivity.NONE)
    abstract val goldenBadging: RegularFileProperty

    @get:Input
    abstract val updateTaskName: Property<String>

    @get:OutputFile   // marker output so the task is up-to-date / cacheable when nothing changed
    abstract val result: RegularFileProperty

    @TaskAction
    fun check() {
        val generated = generatedBadging.get().asFile
        val golden = goldenBadging.get().asFile
        if (generated.readText() != golden.readText()) {
            throw GradleException(
                """
                |Badging changed: ${golden.name}
                |A dependency update or manifest change altered the APK's permissions or required features.
                |Review:  diff ${golden.path} ${generated.path}
                |If intended: ./gradlew ${updateTaskName.get()} and commit the golden file.
                |Common culprits: android.hardware.camera / telephony / location.gps with required='true'.
                |Fix in AndroidManifest.xml: <uses-feature android:name="…" android:required="false" />
                """.trimMargin(),
            )
        }
        result.get().asFile.writeText("OK")
    }
}
```

Register it in `build-logic/convention/build.gradle.kts`:

```kotlin
register("androidApplicationBadging") {
    id = "convention.android.application.badging"
    implementationClass = "AndroidApplicationBadgingConventionPlugin"
}
```

Apply it in `app/build.gradle.kts`:

```kotlin
plugins {
    alias(libs.plugins.convention.android.application)
    id("convention.android.application.badging")
}
```

Bootstrap and CI:

```bash
./gradlew updateReleaseBadging && git add app/badging/ && git commit -m "chore: add badging golden file"
./gradlew checkReleaseBadging        # in the PR workflow, see /github-actions-android
```
