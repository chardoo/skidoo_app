import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skidoo_app/app.dart';
import 'package:skidoo_app/controller/login_controller.dart';
import 'package:skidoo_app/controller/signUp_controller.dart';
import 'package:skidoo_app/controller/userProfile_controller.dart';
import 'package:skidoo_app/core/theme/customThemeData.dart';
import 'package:skidoo_app/firebase_options.dart';
import 'package:skidoo_app/pages/cartScreen.dart';
import 'package:skidoo_app/pages/forget_pasword.dart';
import 'package:skidoo_app/pages/home.dart';
import 'package:skidoo_app/pages/login.dart';
import 'package:skidoo_app/pages/serchview.dart';
import 'package:skidoo_app/pages/signUp.dart';
import 'package:skidoo_app/pages/splash.dart';
import 'package:skidoo_app/pages/verifyCode.dart';
import 'package:skidoo_app/screens/chat_page.dart';
import 'package:skidoo_app/services/auth_service.dart';
import 'package:camera/camera.dart';
import 'package:skidoo_app/services/auth_service.dart';

main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final cameras = await availableCameras();
  final firstCamera = cameras.first;
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  // Obtain a list of the available cameras on the device.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  var prefs = await SharedPreferences.getInstance();
  Get.put(prefs);
  String token = await AuthService.getToken();

  // Get.put(prefs);
  Get.lazyPut(() => UserController());
  Get.lazyPut<LoginController>(() => LoginController());
  Get.put(SignUpController());
   token = await AuthService.getToken();
  runApp(
    
    
   MyApp(token: token,)
  );
}
