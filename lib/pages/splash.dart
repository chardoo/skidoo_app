import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:skidoo_app/controller/login_controller.dart';
import 'package:skidoo_app/controller/userProfile_controller.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    // TODO: implement createState
    return _SplashScreenState();
  }
}

class _SplashScreenState extends State<SplashScreen> {
  final loginController = Get.find<LoginController>();
  final userController = Get.find<UserController>();
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    startTimer();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(color: Colors.black),
        child: const Center(
            child: Text(
          'Skiddo',
          style: TextStyle(color: Colors.red, fontSize: 45),
        )),
      ),
    );
  }

  void startTimer() {
    Timer(const Duration(seconds: 3), () async {
      navigateUser(); //It will redirect  after 3 seconds
    });
  }

  void navigateUser() async {
    Get.offNamed('/home');
  }
}
