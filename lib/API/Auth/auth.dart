import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import 'package:dio/dio.dart' as dio;
import 'package:http/http.dart' as httpre;
import 'package:skidoo_app/API/DioClietService.dart';
import 'package:skidoo_app/models/Auth/LoginResponse.dart';
import 'package:skidoo_app/models/badrequest.dart';
// import 'package:docoradi/Models/Auth/LoginResponse.dart';

class AuthHttpService {
  // static const BASE_URL = "https://docoradi-app-phrl5joxbq-uc.a.run.app"
  Future<dynamic> login(Map<String, dynamic> resquestData) async {
    try {
      print("payload is her man");
      print(resquestData);
      var res =
          await Api().dio.post("/client/login", data: jsonEncode(resquestData));
      print("man is here man");
      print(res.data);
      switch (res.statusCode) {
        case 200:
          dynamic body = res.data;
          LoginResponseObject LoggedInuser = LoginResponseObject.fromJson(body);
          return LoggedInuser;
        default:
          dynamic body = jsonDecode(res.data);
          BadRequest badRequest = BadRequest.fromMap(body);
          return badRequest;
      }
    } on dio.DioException catch (err) {
      if (err.response == null) {
        return null;
      } else {
        print("hello error is here aman");
        return false;
      }
    }
  }

  Future<dynamic> register(Map<String, String> resquestData, File file) async {
    var request = httpre.MultipartRequest(
      "POST",
      Uri.parse(
          "https://photoapp-backend-b71j.onrender.com/client/createClient"),
    );

    List<httpre.MultipartFile> data = [];
    request.fields.addAll(resquestData);
    request.files.add(httpre.MultipartFile(
        'images', file.readAsBytes().asStream(), file.lengthSync(),
        filename: file.path));
    var res = await request.send();
    switch (res.statusCode) {
      case 201:
        return true;
      default:
        return false;
    }
  }

  Future<dynamic> confirmEmail(Map<String, dynamic> resquestData) async {
    try {
      var res = await Api()
          .dio
          .post("/client/confirmEmail", data: jsonEncode(resquestData));
      switch (res.statusCode) {
        case 200:
          dynamic body = jsonDecode(res.data);
          LoginResponseObject LoggedInuser = LoginResponseObject.fromJson(body);
          return LoggedInuser;
        default:
          dynamic body = res.data;
          BadRequest badRequest = BadRequest.fromMap(body);
          return badRequest;
      }
    } on dio.DioException catch (err) {
      if (err.response == null) {
        return null;
      } else {
        return false;
      }
    }
  }

  Future<dynamic> verifyCode(Map<String, dynamic> resquestData) async {
    try {
      var res = await Api()
          .dio
          .post("/client/confirmEmail", data: jsonEncode(resquestData));
      switch (res.statusCode) {
        case 200:
          dynamic body = jsonDecode(res.data);
          LoginResponseObject loggedInuser = LoginResponseObject.fromJson(body);
          return loggedInuser;
        default:
          dynamic body = jsonDecode(res.data);
          BadRequest badRequest = BadRequest.fromMap(body);
          return badRequest;
      }
    } on dio.DioException catch (err) {
      if (err.response == null) {
        return null;
      } else {
        return false;
      }
    }
  }
}
