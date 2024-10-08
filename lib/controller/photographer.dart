import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:skidoo_app/API/photoGrapher/photographer.dart';

class PhotoGrapherController extends GetxController {
  var photoGraphers = [].obs;
  var foundPhotoGraphers = [].obs;

  PhotoGraphersHttpService photoGraphersHttpService =
      new PhotoGraphersHttpService();

  @override
  onInit() async {
    var results = await photoGraphersHttpService.getPhotoGraphers("eventName");
    photoGraphers.value = results;
  }

  void searhPhotographer(dynamic payload) async {
    var searchResults =
        await photoGraphersHttpService.searchPhotoGraphers(payload);
    photoGraphers.value = searchResults;
  }
}
