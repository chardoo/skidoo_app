import 'dart:io';
import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class CropImages extends StatefulWidget {
  final Uint8List file;
  final void Function(String imagePath)? onImageCropped;

  const CropImages({super.key, required this.file, this.onImageCropped});

  @override
  State<CropImages> createState() => _CropImagesState();
}

class _CropImagesState extends State<CropImages> {
  final _cropController = CropController();
  bool _isCropping = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Take a selfie')),
      body: Stack(
        children: [
          Crop(
            image: widget.file,
            initialAreaBuilder: (rect) => Rect.fromLTRB(
              rect.left + 50,
              rect.top + 150,
              rect.right - 50,
              rect.bottom - 150,
            ),
            controller: _cropController,
            onCropped: (image) async {
              // Capture navigator before async gaps to avoid using
              // a stale BuildContext after the widget may be unmounted.
              final navigator = Navigator.of(context);
              final dir = await getApplicationDocumentsDirectory();
              final filePath = '${dir.path}/imagefedff.png';
              final savedFile = await File(filePath).writeAsBytes(image);
              widget.onImageCropped?.call(savedFile.path);
              if (mounted) {
                navigator.pop();
                navigator.pop();
              }
            },
          ),
          const Positioned(
            left: 16,
            right: 16,
            bottom: 100,
            child: Text(
              'Kindly crop your face for a better experience — this helps us find the best results for you.',
              style: TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.black,
        onPressed: _isCropping
            ? null
            : () {
                setState(() => _isCropping = true);
                _cropController.crop();
              },
        child: _isCropping
            ? const CircularProgressIndicator(color: Colors.white)
            : const Icon(Icons.crop),
      ),
    );
  }
}
