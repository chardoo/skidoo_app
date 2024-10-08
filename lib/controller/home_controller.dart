import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:skidoo_app/API/photos.dart/photos.dart';
import 'package:skidoo_app/models/event/Event.dart';
import 'package:skidoo_app/services/auth_service.dart';

class HomeController extends GetxController {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  late Rx<List<Event>> events = Rx([]);
  var searchImage = [].obs;
  var loading = false.obs;
  var index = 0.obs;
  var eventSearched = [].obs;
  var issearching = false.obs;
  var searchEvent = false.obs;
   var userName = ''.obs;
  PhotosHttpService photoApi = new PhotosHttpService();

  onInit() async {
     userName.value = await AuthService.getName();
  }

  Future<void> searchimages(String eventName) async {
  
    loading.value = true;
    searchImage.clear();
    String clientUniqueName = await AuthService.getUniqueName();
    var foundImages =
        await photoApi.searchEventImages(eventName, clientUniqueName);
    if (foundImages.isNotEmpty) {
      loading.value = false;
      searchImage.clear();

      searchImage.value = foundImages;
    } else {
      loading.value = false;
      searchImage.value = [];
    }
  }

  Future<List<Event>> searchEvents(String searchKey) async {
    searchEvent.value = true;
    List<Event> events = await photoApi.getEvent(searchKey);
    searchEvent.value = false;
    eventSearched.value = events;
    return events;
  }
}
