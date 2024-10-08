import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

import 'dart:async';
import 'dart:io';

// import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:skidoo_app/API/Auth/auth.dart';
// import '../contollers/user_controller.dart';
// import '../services/auth/auth_service.dart';
// import "../apis/httpService.dart";
// import '../configuration/constants.dart';
//import '../services/http/constants.dart';

class SignUpController extends GetxController {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final emailController = TextEditingController();
  final contactController = TextEditingController();
  final userNameController = TextEditingController();
  var ispasswordHidden = true.obs;
  var isError = false.obs;
  var Imagepath = ''.obs;
  var imageName = ''.obs;
  var isRegisterClicked = false.obs;
  var isloading = false.obs;
  var error = '';
  var isDisabled = true.obs;
  late File filetry;
  AuthHttpService LoginApi = AuthHttpService();

  @override
  void onClose() {
    emailController.dispose();
    passwordController.dispose();
    super.onClose();
  }

  // void selectFile() async {
  //   final file = await FilePicker.platform.pickFiles(
  //       type: FileType.custom, allowedExtensions: ['png', 'jpg', 'jpeg']);
  //   if (file != null) {
  //     filetry = File(file.files.single.path!);
  //     // _file = File(file.files.single.path!);
  //     // fileName.value = file.files.single.name;
  //     // _platformFile = file.files.first;
  //     // filePath.value = _file.path;
  //   }
  //   // print("helloe r");
  //   // print(_file.path);
  // }

  Future<bool> register(File file) async {
    isloading.value = true;
    Map<String, String> loginDetails = {
      "password": passwordController.text.trim(),
      "email": emailController.text.trim(),
      "contact": contactController.text.trim(),
      "name": userNameController.text.isNotEmpty
          ? userNameController.text.trim()
          : "chardoo"
    };
    return await LoginApi.register(loginDetails, File(Imagepath.value));
  }
}
