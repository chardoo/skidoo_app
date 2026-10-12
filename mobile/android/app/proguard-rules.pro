# What R8 must not remove.
#
# Release builds shrink and obfuscate now (see `isMinifyEnabled` in
# build.gradle.kts). R8 decides what is unused by walking references from the
# entry points, which means anything reached only by *reflection* or only from
# native code looks unreachable and is deleted — and the failure shows up at
# runtime, in release, on a user's phone, as a ClassNotFoundException on a path
# that was never exercised in debug.
#
# Everything below is a class that is reached that way. Flutter's own plugin
# rules are contributed by the Flutter Gradle plugin; these are the ones our
# dependencies need on top.

# ── Flutter ──────────────────────────────────────────────────────────────────
# The embedding is instantiated by name from the generated manifest.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# ── ML Kit face detection (FaceCheckPlugin) ──────────────────────────────────
# Loaded through Play Services on demand, so the classes that bind to it are
# referenced from outside this APK.
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_** { *; }
-dontwarn com.google.mlkit.**

# ── OneSignal ────────────────────────────────────────────────────────────────
# Receivers and services are named in the manifest and constructed by the OS.
-keep class com.onesignal.** { *; }
-dontwarn com.onesignal.**

# ── Keep every plugin's registered entry point ───────────────────────────────
# Flutter plugins are registered by class name from GeneratedPluginRegistrant.
-keep class * implements io.flutter.plugin.common.PluginRegistry$Registrar { *; }
-keep class * implements io.flutter.embedding.engine.plugins.FlutterPlugin { *; }

# ── Kotlin coroutines ────────────────────────────────────────────────────────
# ServiceLoader-driven; the implementation is found by name at runtime.
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}
-dontwarn kotlinx.coroutines.**

# ── Annotations the above rules are written against ──────────────────────────
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# Line numbers, so a release stack trace from the Play Console is readable.
# Without this a crash report is a list of obfuscated frames with no lines.
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# ── Play Core, which this app does not use ───────────────────────────────────
# Flutter's embedding carries PlayStoreDeferredComponentManager and
# FlutterPlayStoreSplitApplication, which reference `com.google.android.play.core.*`
# for deferred components — a feature nothing here uses, so the library is not
# on the classpath and R8 stops dead on eleven missing classes.
#
# `-dontwarn` rather than adding the dependency: pulling in Play Core to
# satisfy references on a code path that never runs would add to the APK this
# change exists to shrink. The classes stay missing and the code that would
# have called them is unreachable.
-dontwarn com.google.android.play.core.**
-keep class io.flutter.embedding.engine.deferredcomponents.** { *; }
