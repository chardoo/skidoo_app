import 'dart:io';
import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class CropImages extends StatelessWidget {
  final Uint8List file;
  final void Function(String imagePath)? onImageCropped;

  const CropImages({super.key, required this.file, this.onImageCropped});

  @override
  Widget build(BuildContext context) {
    final cropController = CropController();

    return Scaffold(
      appBar: AppBar(title: const Text('Take a selfie')),
      body: Stack(
        children: [
          Crop(
            image: file,
            initialAreaBuilder: (rect) => Rect.fromLTRB(
              rect.left + 50,
              rect.top + 150,
              rect.right - 50,
              rect.bottom - 150,
            ),
            controller: cropController,
            onCropped: (image) async {
              final dir = await getApplicationDocumentsDirectory();
              final filePath = '${dir.path}/imagefedff.png';
              final savedFile = await File(filePath).writeAsBytes(image);
              onImageCropped?.call(savedFile.path);
            },
          ),
          const Text(
              'Kindly crop your face for a better experience — this helps us find the best results for you.'),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.black,
        child: const Icon(Icons.crop),
        onPressed: () async {
          cropController.crop();
          Navigator.pop(context, true);
          Navigator.pop(context, true);
        },
      ),
    );
  }
}
