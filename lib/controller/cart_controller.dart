// ignore_for_file: depend_on_referenced_packages

import 'dart:async';
import 'package:get/get.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

import 'package:lecle_downloads_path_provider/lecle_downloads_path_provider.dart';
// import 'package:open_file/open_file.dart';
import 'package:skidoo_app/API/photos.dart/photos.dart';
import 'package:skidoo_app/controller/Gallery_controller.dart';
import 'package:skidoo_app/controller/home_controller.dart';
import 'package:skidoo_app/models/photos/Photo.dart';
import 'package:skidoo_app/pages/home.dart';
import 'package:skidoo_app/services/auth_service.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'dart:typed_data';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

class CartController extends GetxController {
  // ignore: deprecated_member_use
  PhotosHttpService apis = new PhotosHttpService();
  HomeController homeController = Get.find();
  GalleryController galleryController = Get.put(GalleryController());
  List<Photo> cartItems = List<Photo>.empty().obs;

  var totalAmount = 0.obs;
  var referenceId = "".obs;

  void total() {
    totalAmount.value = 0;
    for (var i = 0; i < cartItems.length; i++) {
      totalAmount += cartItems[i].price;
    }
    update();
  }

  onInit() async {
    total();
  }

  Future<dynamic> payForImages(
    String amount,
  ) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    Map<String, dynamic> payload = {
      "email": prefs.getString('email'),
      "amount": amount
    };
    return await apis.payForImages(payload);
  }

  Future<dynamic> completePayment(
    dynamic payload,
  ) async {
    String clientIds = await AuthService.getUserId();
    var mylist = [];
    for (var element in cartItems) {
      mylist.add({
        "pictureId": element.id,
        "clientId": clientIds,
        "userId": element.userId,
      });
    }
    Map<String, dynamic> payload = {
      "amount": totalAmount.value.toString(),
      "referenceId": referenceId.value,
      "clientId": clientIds,
      "PaidImage": mylist
    };
    var me = await apis.completePayment(payload);
    if (me['paidImages']['count'] > 0) {
      Get.snackbar(
        "Successful Payment",
        "Check your Gallery to download Image",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Color.fromARGB(255, 238, 244, 238),
      );
      homeController.index.value = 1;
      galleryController.onInit();
      cartItems.clear();
      Get.to(HomeScreen());
    } else {
      Get.snackbar(
        "Sorry Payment Unsuccessful",
        "Make Payment  again",
        icon: Icon(Icons.person, color: Colors.white),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Color.fromARGB(255, 238, 244, 238),
      );
      cartItems.clear();
      Get.offAllNamed("/cart");
    }
    return me;
  }

  void downloadeImage(String url) async {
    try {
      Get.snackbar(
        "Images is been Downloaded",
        " ",
        snackPosition: SnackPosition.TOP,
        backgroundColor: Color.fromARGB(255, 238, 244, 238),
      );
     await requestPermissions();
    var response = await Dio().get(url,
    options: Options(responseType: ResponseType.bytes));
    final  bytes = Uint8List.fromList(response.data);
        await ImageGallerySaver.saveImage(bytes);
      if (response.statusCode == 200) {
        Get.snackbar(
          "Successful Downloads",
          "Check your downloads",
          snackPosition: SnackPosition.TOP,
          backgroundColor: Color.fromARGB(255, 238, 244, 238),
        );
      }
    } catch (e) {
      print(e);
    }
  }

  Future<void> requestPermissions() async {
  await [Permission.storage, Permission.photos].request();
}
}
