allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Fix for older Flutter plugins (e.g. image_gallery_saver) that don't declare
// a namespace in their build.gradle, which is required by AGP 8+.
subprojects {
    afterEvaluate {
        (extensions.findByName("android") as? com.android.build.gradle.LibraryExtension)
            ?.apply {
                if (namespace == null) {
                    namespace = group.toString()
                }
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
