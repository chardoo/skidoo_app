package com.jperg.app

import android.content.pm.ActivityInfo
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // App-local channel rather than a pub package — see FaceCheckPlugin.
        FaceCheckPlugin.register(
            applicationContext,
            flutterEngine.dartExecutor.binaryMessenger,
        )
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Enable wide colour gamut (P3 / HDR) rendering on Android O+ devices.
        // Gives photos and videos their full captured colour range instead of
        // being clamped to sRGB.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            window.colorMode = ActivityInfo.COLOR_MODE_WIDE_COLOR_GAMUT
        }
    }
}
