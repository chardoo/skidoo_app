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
// AGP 8+ rejects mismatched targets as a hard error. Kotlin 2.1.0 defaults to
// jvmTarget=17 but many plugins leave Java at sourceCompatibility=1.8
// (e.g. flutter_jailbreak_detection). Forcing Java up to 17 is the reliable
// fix — the plugin's own afterEvaluate may run after ours and set Kotlin to 17
// anyway, so pulling Kotlin down is fragile. D8/R8 desugar Java 17 bytecode
// to any minSdk, so this is safe regardless of Android API level.
subprojects {
    afterEvaluate {
        val android = extensions.findByName("android")
            as? com.android.build.gradle.LibraryExtension ?: return@afterEvaluate
        try {
            android.compileOptions {
                sourceCompatibility = JavaVersion.VERSION_17
                targetCompatibility = JavaVersion.VERSION_17
            }
        } catch (_: Exception) { }
        tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
            kotlinOptions { jvmTarget = "17" }
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
