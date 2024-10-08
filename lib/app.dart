import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:skidoo_app/core/theme/DarkThemeProvider.dart';
import 'package:skidoo_app/core/theme/customThemeData.dart';
import 'package:skidoo_app/pages/cartScreen.dart';
import 'package:skidoo_app/pages/forget_pasword.dart';
import 'package:skidoo_app/pages/home.dart';
import 'package:skidoo_app/pages/login.dart';
import 'package:skidoo_app/pages/serchview.dart';
import 'package:skidoo_app/pages/signUp.dart';
import 'package:skidoo_app/pages/splash.dart';
import 'package:skidoo_app/pages/verifyCode.dart';
import 'package:provider/provider.dart';
import 'package:skidoo_app/services/auth_service.dart';

class MyApp extends StatefulWidget {
  String token;
  MyApp({super.key, required this.token});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  DarkThemeProvider themeChangeProvider = DarkThemeProvider();
  late CameraDescription firstCamera;
  var token = "";
  @override
  void initState() {
    initCameras();
    super.initState();
  }

  initCameras() async {
    final cameras = await availableCameras();
    firstCamera = cameras.first;
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) {
        return themeChangeProvider;
      },
      child: Consumer<DarkThemeProvider>(
        builder: (BuildContext context, value, child) {
          return ScreenUtilInit(
            builder: (context, child) => GetMaterialApp(
              defaultTransition: Transition.fadeIn,
              theme: Styles.themeData(true, context),
              // home: LoginScreen(),
              home: widget.token.isEmpty ? LoginScreen() : HomeScreen(),
              getPages: [
                GetPage(
                  name: '/splash',
                  page: () => const SplashScreen(),
                ),
                GetPage(
                  name: '/home', page: () => HomeScreen(),
                  //middlewares: [AuthMiddleWare()]
                ),
                GetPage(
                  name: '/signUp',
                  page: () => SignUpScreen(
                    camera: firstCamera,
                  ),
                ),
                GetPage(name: '/login', page: () => LoginScreen()),
                GetPage(
                    name: '/searchresults', page: () => SearchResultsView()),
                GetPage(name: '/cart', page: () => CartScreen()),
                GetPage(
                    name: '/forgotPassword',
                    page: () => ForgetPasswordScreen()),
                GetPage(name: '/verifyCode', page: () => VerifyEmailScreen()),
              ],
            ),
            designSize: const Size(390, 844),
          );
        },
      ),
    );
  }
}
