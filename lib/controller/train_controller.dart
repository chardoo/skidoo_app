import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

import 'dart:async';
import 'dart:io';

// import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:get/get_connect/http/src/multipart/multipart_file.dart';
import 'package:get/get_connect/http/src/multipart/multipart_file.dart';
import 'package:http/http.dart' as httpre;
import 'package:skidoo_app/API/Auth/auth.dart';
import 'package:skidoo_app/services/auth_service.dart';
// import '../contollers/user_controller.dart';
// import '../services/auth/auth_service.dart';
// import "../apis/httpService.dart";
// import '../configuration/constants.dart';
//import '../services/http/constants.dart';

class TrainController extends GetxController {
  var myImages = [].obs;
  AuthHttpService LoginApi = AuthHttpService();

  @override
  void onClose() {
    myImages.clear();
    super.onClose();
  }

  dynamic trainModel() async {
    Map<String, String> resquestData = {"email": await AuthService.getEmail()};
    var request = httpre.MultipartRequest(
      "POST",
      Uri.parse("https://photoapp-backend-b71j.onrender.com/client/trainModel"),
    );

    final images = myImages.map((element) => httpre.MultipartFile(
        'images', element.readAsBytes().asStream(), element.lengthSync(),
        filename: element.path));
    List<httpre.MultipartFile> data = [];
    request.fields.addAll(resquestData);
    request.files.addAll(images);
    var res = await request.send();
    switch (res.statusCode) {
      case 201:
        return true;
      default:
        return false;
    }
  }
}
