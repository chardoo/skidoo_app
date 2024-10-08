import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:path_provider/path_provider.dart';
import 'package:skidoo_app/controller/signUp_controller.dart';
import 'package:skidoo_app/controller/train_controller.dart';
import 'package:skidoo_app/widgets/loader.dart';

// import 'package:get/get_core/src/get_main.dart';

class CropperScreen extends StatelessWidget {
  Uint8List file;
  CropperScreen({required this.file});

  TrainController controller = Get.put(TrainController());
  @override
  Widget build(BuildContext context) {
    final cropController = CropController();

    return Scaffold(
        appBar: AppBar(title: const Text('Take a picture')),
        body: Stack(
          children: [
            Crop(
                image: file,
                initialAreaBuilder: (rect) => Rect.fromLTRB(rect.left + 50,
                    rect.top + 150, rect.right - 50, rect.bottom - 150),
                controller: cropController,
                onCropped: (image) async {
                  Directory appDocumentsDirectory =
                      await getApplicationDocumentsDirectory(); // 1
                  String appDocumentsPath = appDocumentsDirectory.path; // 2
                  String filePath = '$appDocumentsPath/imagefedff.png';
                  var file = await File(filePath).writeAsBytes(image);
                  controller.myImages.add(file);
                   final results = await controller.trainModel();
                  Navigator.pop(context, true);
                }),
            const Text(
                "kindly crop image as we rely on these images to deliver your best experience "),
          ],
        ),
        floatingActionButton: FloatingActionButton(
            backgroundColor: Colors.black,
            child: const Icon(Icons.crop),
            // Provide an onPressed callback.
            onPressed: () async {
              cropController.crop();
              showLoadingDialog(context);
             
            }));
  }

  void showLoadingDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox.square(
                    dimension: 112,
                    child: CircularProgressIndicator(
                      color: Theme.of(context).focusColor,
                      strokeWidth: 15.0,
                    ),
                  ),
                  const Text(
                    'training model...',
                    style: TextStyle(
                      fontSize: 10.0,
                      fontWeight: FontWeight.bold,
                      color: Color.fromARGB(255, 244, 243, 243),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
