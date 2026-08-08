package com.jperg.app

import android.content.Context
import android.net.Uri
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.face.FaceDetection
import com.google.mlkit.vision.face.FaceDetectorOptions
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Answers the Dart side's `jperg/face_check` channel: "does this photo
 * contain a face?"
 *
 * Uses the *unbundled* ML Kit face detector — the model lives in Play Services
 * and is downloaded on demand rather than shipped in the APK. The bundled
 * `google_mlkit_face_detection` plugin this replaced carried the same detector
 * and its models inside the app, for ~16 MB.
 *
 * Replies `null` for "couldn't tell" — no model yet, an unreadable file, a
 * detector error. The Dart side treats that as a pass rather than blocking the
 * user (see `FaceCheck.hasFace`).
 */
class FaceCheckPlugin(private val context: Context) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "jperg/face_check"

        fun register(context: Context, messenger: BinaryMessenger) {
            MethodChannel(messenger, CHANNEL).setMethodCallHandler(FaceCheckPlugin(context))
        }
    }

    private val options = FaceDetectorOptions.Builder()
        .setPerformanceMode(FaceDetectorOptions.PERFORMANCE_MODE_FAST)
        .setMinFaceSize(0.15f)
        .build()

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "hasFace") {
            result.notImplemented()
            return
        }

        val path = call.argument<String>("path")
        if (path.isNullOrEmpty() || !File(path).exists()) {
            result.success(null)
            return
        }

        val image = try {
            InputImage.fromFilePath(context, Uri.fromFile(File(path)))
        } catch (e: Exception) {
            result.success(null)
            return
        }

        val detector = FaceDetection.getClient(options)
        detector.process(image)
            .addOnSuccessListener { faces ->
                result.success(faces.isNotEmpty())
                detector.close()
            }
            .addOnFailureListener {
                // Most often the model is still downloading on a fresh install.
                result.success(null)
                detector.close()
            }
    }
}
