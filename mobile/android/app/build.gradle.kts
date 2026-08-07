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
    namespace = "com.jperg.app"
    compileSdk = flutter.compileSdkVersion
    // Use the highest NDK any plugin requires (jni needs 28.2); backward compatible.
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.jperg.app"

        // The domain App Links are verified against. One place, because it
        // also has to match the iOS entitlement and the gateway's
        // /.well-known/assetlinks.json — three files that must agree or the
        // link silently opens a browser instead of the app.
        manifestPlaceholders["deepLinkHost"] = "jperg.com"
        // google_ml_kit requires minSdk 21; camera requires 21
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = 12 
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

dependencies {
    // Unbundled ML Kit face detection: the detector and its model live in
    // Play Services and are fetched on demand, so this adds a thin client to
    // the APK rather than the ~16 MB the bundled variant shipped. Used only by
    // FaceCheckPlugin — see the `com.google.mlkit.vision.DEPENDENCIES`
    // meta-data in AndroidManifest.xml, which asks Play Services to download
    // the model at install time instead of on first use.
    implementation("com.google.android.gms:play-services-mlkit-face-detection:17.1.0")
}

// KGP 2.2+ removed kotlinOptions; use compilerOptions to lock jvmTarget so it
// matches the Java 17 compileOptions above (the Flutter Gradle plugin otherwise
// overrides it to 18, which AGP 8+ rejects as a mismatch).
tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}
