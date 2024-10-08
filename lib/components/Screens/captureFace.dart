import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:path_provider/path_provider.dart';
import 'package:skidoo_app/components/Screens/croptimage.dart';
import 'package:skidoo_app/controller/signUp_controller.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';

class TakePictureScreen extends StatefulWidget {
  const TakePictureScreen({
    super.key,
    required this.camera,
  });

  final CameraDescription camera;

  @override
  TakePictureScreenState createState() => TakePictureScreenState();
}

class TakePictureScreenState extends State<TakePictureScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  SignUpController controller = Get.find();
  @override
  void initState() {
    super.initState();
    // To display the current output from the Camera,
    // create a CameraController.
    _controller = CameraController(
        // Get a specific camera from the list of available cameras.
        widget.camera,
        // Define the resolution to use.
        ResolutionPreset.max,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21 // for Android
            : ImageFormatGroup.bgra8888);

    // Next, initialize the controller. This returns a Future.
    _initializeControllerFuture = _controller.initialize();
  }

  @override
  void dispose() {
    // Dispose of the controller when the widget is disposed.
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Take a selfie')),
      // You must wait until the controller is initialized before displaying the
      // camera preview. Use a FutureBuilder to display a loading spinner until the
      // controller has finished initializing.
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            // If the Future is complete, display the preview.
            return CameraPreview(_controller);
          } else {
            // Otherwise, display a loading indicator.
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.black,
        // Provide an onPressed callback.
        onPressed: () async {
          // Take the Picture in a try / catch block. If anything goes wrong,
          // catch the error.
          try {
            // Ensure that the camera is initialized.
            await _initializeControllerFuture;

            // Attempt to take a picture and get the file `image`
            // where it was saved.

            await _controller.startImageStream((image) async {
              await _controller.stopImageStream();
              CameraImage cameraImage = image;

              final WriteBuffer allBytes = WriteBuffer();
              for (final Plane plane in cameraImage.planes) {
                allBytes.putUint8List(plane.bytes);
              }

              final bytes = allBytes.done().buffer.asUint8List();

              final Size imageSize = Size(
                  cameraImage.width.toDouble(), cameraImage.height.toDouble());

              final InputImageRotation? imageRotation =
                  InputImageRotationValue.fromRawValue(
                      widget.camera.sensorOrientation);

              final InputImageFormat inputImageFormat =
                  InputImageFormatValue.fromRawValue(cameraImage!.format!.raw)!;

              final inputImageData = InputImageMetadata(
                size: imageSize,
                rotation: imageRotation!,
                format: inputImageFormat,
                bytesPerRow: cameraImage.planes[0].bytesPerRow,
              );

              final inputImage = InputImage.fromBytes(
                bytes: bytes,
                metadata: inputImageData,
              );
              final faceDetector = GoogleMlKit.vision.faceDetector();
              final List<Face> faces =
                  await faceDetector.processImage(inputImage);
              if (faces.isNotEmpty) {
                print("please print  side for me please");
                print(faces.length);
                  // print(faces[0].);
                print(faces[0].contours);
                print(faces[0].landmarks);
                print(faces[0].rightEyeOpenProbability);
                print(faces[0].leftEyeOpenProbability);
                print(faces[0].headEulerAngleX);
                print(faces[0].headEulerAngleY);
                print(faces[0].headEulerAngleZ);
                final image = await _controller.takePicture();

                File file = File(image.path);
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) =>
                      CropImages(file: file.readAsBytesSync()),
                ));
                //  Navigator.pop(context, true);
              } else {
                showDialog(
                    context: context,
                    builder: (context) {
                      return const AlertDialog(
                        title: Center(
                            child: Text(
                          'Sorry No face Detected',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold),
                        )),
                      );
                    });
                Future.delayed(
                  Duration(seconds: 2),
                  () {
                    Navigator.pop(context, true);
                  },
                );
              }
            });
          } catch (e) {
            // If an error occurs, log the error to the console.
            print(e);
          }
        },
        child: const Icon(Icons.camera_alt),
      ),
    );
  }
}
