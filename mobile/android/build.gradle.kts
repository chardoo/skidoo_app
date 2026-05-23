allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Fix for older Flutter plugins that don't declare a namespace in their
// build.gradle (required by AGP 8+), AND for plugins whose source
// AndroidManifest.xml still has a package= attribute (rejected by AGP 8.3+
// even when namespace is already declared in build.gradle).
subprojects {
    afterEvaluate {
        (extensions.findByName("android") as? com.android.build.gradle.LibraryExtension)
            ?.apply {
                if (namespace == null) {
                    namespace = group.toString()
                }
            }

        // Strip legacy package= from source AndroidManifest.xml files.
        // AGP 8.3+ rejects package= as a namespace source even when namespace
        // is already declared in build.gradle (e.g. google_mlkit_smart_reply).
        val manifestFile = project.file("src/main/AndroidManifest.xml")
        if (manifestFile.exists()) {
            val original = manifestFile.readText()
            val patched = original.replace(Regex("""\s*package="[^"]*""""), "")
            if (patched != original) {
                manifestFile.writeText(patched)
            }
        }
    }
}

// Fix JVM-target mismatches between Java and Kotlin compile tasks.
// AGP 8+ rejects mismatched targets as a hard error (e.g. flutter_jailbreak_detection
// has Java=1.8 / Kotlin=18; share_plus has Java=17 / Kotlin=1.8).
// Rather than forcing a single version on all plugins (which breaks ones with a
// low compileSdkVersion like google_mlkit_commons at sdk=29), we read each
// project's declared Java targetCompatibility and set Kotlin's jvmTarget to match.
subprojects {
    afterEvaluate {
        val android = extensions.findByName("android")
            as? com.android.build.gradle.LibraryExtension ?: return@afterEvaluate
        // Some plugins (e.g. camera_android) set targetCompatibility inside their
        // own afterEvaluate, which runs after ours — the Property is not yet
        // finalized at this point and throws IllegalStateException.  Skip those
        // projects; their Kotlin/Java targets will already be aligned by the
        // plugin itself.
        val javaTarget = try {
            android.compileOptions.targetCompatibility?.toString()
        } catch (_: IllegalStateException) {
            null
        } ?: return@afterEvaluate
        tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
            kotlinOptions { jvmTarget = javaTarget }
        }
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
