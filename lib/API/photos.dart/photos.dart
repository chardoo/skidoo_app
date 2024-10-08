import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart';
import 'package:skidoo_app/API/DioClietService.dart';
import 'package:skidoo_app/models/event/Event.dart';
import 'package:skidoo_app/models/photos/Photo.dart';
import 'package:dio/dio.dart' as dio;

class PhotosHttpService {
  Future<List<Photo>> userDash(String clientId) async {
    try {
      print("client id is here man");
      print(clientId);
      var res = await Api().dio.post("/client/clientDashboard",
          data: jsonEncode({"clientId": clientId}));

      print("his is hte data");
      print(res.data);
      List<dynamic> body = res.data;
      List<Photo> photos = body
          .map(
            (dynamic item) => Photo.fromMap(item),
          )
          .toList();

      return photos;
    } on dio.DioException catch (err) {
      if (err.response == null) {
        return [];
      } else {
        print("hello error is here aman");
        return [];
      }
    }
  }

  Future<List<Event>> getEvent(String searchKey) async {
    try {
      print("event hello how aer");
      var res = await Api()
          .dio
          .post("/client/events", data: jsonEncode({"queryString": searchKey}));

      print("res");

      print(res);
      List<dynamic> body = res.data;
      List<Event> events = body
          .map(
            (dynamic item) => Event.fromMap(item),
          )
          .toList();

      return events;
    } on dio.DioException catch (err) {
      if (err.response == null) {
        return [];
      } else {
        print("hello error is here aman");
        return [];
      }
    }
  }

  Future<List<Photo>> searchEventImages(
      String eventId, String uniqueName) async {
    try {
      print("event hello how aer");
      var res = await Api().dio.post("/client/searchEventImages",
          data: jsonEncode(
              {"uiqueName": uniqueName, "eventId": eventId, "isTrue": true}));
      List<dynamic> body = res.data;
      List<Photo> events = body
          .map(
            (dynamic item) => Photo.fromMap2(item),
          )
          .toList();
      return events;
    } on dio.DioException catch (err) {
      if (err.response == null) {
        return [];
      } else {
        return [];
      }
    }
  }

  Future<dynamic> payForImages(payload) async {
    try {
      var res = await Api()
          .dio
          .post("/client/payForImages", data: jsonEncode(payload));
      return res.data;
    } on dio.DioException catch (err) {
      if (err.response == null) {
        return null;
      } else {
        print("hello error is here aman");
        return false;
      }
    }
  }

  Future<dynamic> completePayment(payload) async {
    try {
      var res = await Api()
          .dio
          .post("/client/completePayment", data: jsonEncode(payload));
      if (res.statusCode == 200) {
        return res.data;
      } else {
        return jsonDecode(res.data);
      }
    } on dio.DioException catch (err) {
      if (err.response == null) {
        return null;
      } else {
        print("complete payment is called");
        return false;
      }
    }
  }
}
