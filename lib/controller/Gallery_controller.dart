import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:skidoo_app/API/photos.dart/photos.dart';
import 'package:skidoo_app/services/auth_service.dart';

class GalleryController extends GetxController {
  var gallery = [].obs;
  var loading = false.obs;
  PhotosHttpService photoApi = new PhotosHttpService();

  @override
  onInit() async {
    loading.value = true;

    getGallery();
    loading.value = false;
  }

  void getGallery() async {
    String clientId = await AuthService.getUserId();
    gallery.value = await photoApi.userDash(clientId);
  }
}
