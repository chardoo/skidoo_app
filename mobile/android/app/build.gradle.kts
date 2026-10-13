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
    // Use the highest NDK any plugin requires (jni needs 28.2); backward compatible.
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.skidoo.app"

        // The domain App Links are verified against. One place, because it
        // also has to match the iOS entitlement and the gateway's
        // /.well-known/assetlinks.json — three files that must agree or the
        // link silently opens a browser instead of the app.
        manifestPlaceholders["deepLinkHost"] = "jperg.com"
        // google_ml_kit requires minSdk 21; camera requires 21
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = 36 
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

            // R8 was never switched on, so every release shipped the whole of
            // every Java/Kotlin dependency plus all of their resources —
            // classes.dex alone was 5.8 MB of code most of which nothing calls.
            //
            // What it is allowed to delete is bounded by proguard-rules.pro:
            // anything reached only by reflection or only from native code
            // looks unreachable to R8, and the failure arrives at runtime, in
            // release, on somebody's phone.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }

    // No `splits { abi { … } }` here, deliberately.
    //
    // It conflicts with the `ndk.abiFilters` the Flutter Gradle plugin injects
    // — "Conflicting configuration ... cannot be present when splits abi
    // filters are set" — and it fails the *bundle* build, which is the one the
    // store takes.
    //
    // It is also unnecessary. An app bundle already splits by ABI: Play builds
    // a per-device APK and sends one architecture, which is how a 96 MB fat
    // APK became a ~17 MB download. For a plain APK, Flutter's own
    // `--split-per-abi` does the same thing without touching Gradle, and
    // `--target-platform android-arm,android-arm64` leaves out the x86_64
    // slice that only emulators run.
    //
    // See the build commands in README / the release checklist.
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
