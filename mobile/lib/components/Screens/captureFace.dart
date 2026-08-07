import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:jperg_app/components/Screens/croptimage.dart';
import 'package:jperg_app/core/utils/snackbar_utils.dart';

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
            final picture = await _controller.takePicture();
            if (!mounted) return;
            final file = File(picture.path);
            navigator.push(MaterialPageRoute(
              builder: (_) => CropImages(
                file: file.readAsBytesSync(),
                onImageCropped: widget.onImageCaptured,
              ),
            ));
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
