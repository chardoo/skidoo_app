package com.example.skidoo_app

import android.content.pm.ActivityInfo
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
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
