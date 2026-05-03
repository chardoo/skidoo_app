import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:skidoo_app/components/Screens/croptimage.dart';
import 'package:skidoo_app/core/utils/snackbar_utils.dart';

class TakePictureScreen extends StatefulWidget {
  final CameraDescription camera;
  final void Function(String imagePath)? onImageCaptured;

  const TakePictureScreen({
    super.key,
    required this.camera,
    this.onImageCaptured,
  });

  @override
  TakePictureScreenState createState() => TakePictureScreenState();
}

class TakePictureScreenState extends State<TakePictureScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  // Prevents the stream callback firing multiple times before stopImageStream
  // takes effect, which would push CropImages onto the stack twice and cause
  // the crop_your_image package to crash when the first instance gets unmounted.
  bool _captureInProgress = false;

  @override
  void initState() {
    super.initState();
    _controller = CameraController(
      widget.camera,
      ResolutionPreset.max,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );
    _initializeControllerFuture = _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Take a selfie')),
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return CameraPreview(_controller);
          }
          return const Center(child: CircularProgressIndicator());
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.black,
        onPressed: () async {
          if (_captureInProgress) return;
          final navigator = Navigator.of(context);
          final messenger = ScaffoldMessenger.of(context);
          try {
            await _initializeControllerFuture;
            setState(() => _captureInProgress = true);
            await _controller.startImageStream((cameraImage) async {
              // Guard: only process the very first frame delivered by the stream.
              // Without this, the callback fires multiple times before
              // stopImageStream resolves, pushing CropImages onto the stack
              // more than once and causing an unmounted-context crash.
              if (!_captureInProgress) return;
              _captureInProgress = false;
              await _controller.stopImageStream();

              final allBytes = WriteBuffer();
              for (final plane in cameraImage.planes) {
                allBytes.putUint8List(plane.bytes);
              }
              final bytes = allBytes.done().buffer.asUint8List();

              final imageSize = Size(
                cameraImage.width.toDouble(),
                cameraImage.height.toDouble(),
              );
              final imageRotation = InputImageRotationValue.fromRawValue(
                  widget.camera.sensorOrientation);
              final inputImageFormat =
                  InputImageFormatValue.fromRawValue(cameraImage.format.raw)!;

              final inputImage = InputImage.fromBytes(
                bytes: bytes,
                metadata: InputImageMetadata(
                  size: imageSize,
                  rotation: imageRotation!,
                  format: inputImageFormat,
                  bytesPerRow: cameraImage.planes[0].bytesPerRow,
                ),
              );

              final faceDetector = GoogleMlKit.vision.faceDetector();
              final faces = await faceDetector.processImage(inputImage);

              if (faces.isNotEmpty) {
                final picture = await _controller.takePicture();
                final file = File(picture.path);
                navigator.push(MaterialPageRoute(
                  builder: (_) => CropImages(
                    file: file.readAsBytesSync(),
                    onImageCropped: widget.onImageCaptured,
                  ),
                ));
              } else {
                navigator.push(MaterialPageRoute(
                  builder: (_) => AlertDialog(
                    title: const Center(
                      child: Text(
                        'Sorry, no face detected',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => navigator.pop(),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                ));
              }
            });
          } catch (e) {
            if (mounted) setState(() => _captureInProgress = false);
            AppSnackBar.errorOnMessenger(messenger, 'Camera error: $e');
          }
        },
        child: const Icon(Icons.camera_alt),
      ),
    );
  }
}
