import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Load signing credentials from android/key.properties (never commit this file).
val keystoreProps = Properties()
val keystoreFile = rootProject.file("key.properties")
if (keystoreFile.exists()) {
    keystoreFile.inputStream().use { keystoreProps.load(it) }
}

android {
    namespace = "com.skidoo.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.skidoo.app"
        // google_ml_kit requires minSdk 21; camera requires 21
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Required by google_ml_kit to bundle ML model files
    aaptOptions {
        noCompress("tflite")
        noCompress("lite")
    }

    signingConfigs {
        create("release") {
            keyAlias     = keystoreProps["keyAlias"]     as String?
            keyPassword  = keystoreProps["keyPassword"]  as String?
            storeFile    = keystoreProps["storeFile"]?.let { file(it as String) }
            storePassword = keystoreProps["storePassword"] as String?
        }
    }

    buildTypes {
        release {
            // Uses release signing if key.properties exists; falls back to debug
            // for local flutter run --release without a keystore set up.
            signingConfig = if (keystoreFile.exists())
                signingConfigs.getByName("release")
            else
                signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

// KGP 2.2+ removed kotlinOptions; use compilerOptions to lock jvmTarget so it
// matches the Java 17 compileOptions above (the Flutter Gradle plugin otherwise
// overrides it to 18, which AGP 8+ rejects as a mismatch).
tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}
