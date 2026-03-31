import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:skidoo_app/app.dart';
import 'package:skidoo_app/core/di/service_locator.dart';
import 'package:skidoo_app/services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  await setupServiceLocator();

  final cameras = await availableCameras();
  final firstCamera = cameras.isNotEmpty ? cameras.first : null;
  final token = await sl<AuthService>().getToken();

  runApp(MyApp(token: token, firstCamera: firstCamera));
}
