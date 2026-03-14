import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/di/service_locator.dart';
import 'package:skidoo_app/core/theme/customThemeData.dart';
import 'package:skidoo_app/features/auth/presentation/pages/login_page.dart';
import 'package:skidoo_app/features/auth/presentation/pages/signup_page.dart';
import 'package:skidoo_app/features/cart/presentation/bloc/cart_bloc.dart';
import 'package:skidoo_app/features/home/presentation/pages/home_page.dart';

class MyApp extends StatelessWidget {
  final String token;
  final CameraDescription? firstCamera;

  const MyApp({super.key, required this.token, this.firstCamera});

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: sl<CartBloc>(),
      child: ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (context, child) => MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: Styles.themeData(true, context),
          initialRoute: token.isEmpty ? LoginPage.routeName : HomePage.routeName,
          routes: {
            LoginPage.routeName: (_) => const LoginPage(),
            SignUpPage.routeName: (_) =>
                SignUpPage(camera: firstCamera ?? const CameraDescription(name: '', lensDirection: CameraLensDirection.front, sensorOrientation: 0)),
            HomePage.routeName: (_) => const HomePage(),
          },
        ),
      ),
    );
  }
}
