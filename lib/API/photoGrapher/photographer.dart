import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skidoo_app/API/DioClietService.dart';
import 'package:skidoo_app/models/photographer/photographerModel.dart';

class PhotoGraphersHttpService {
  // static const BASE_URL = "http://api.skiiddo.com";

  Future<List<PhotographerModel>> getPhotoGraphers(dynamic payload) async {
    print("get photographers");
    print(payload);
    var res = await Api().dio.post("/client/getphotographers", data: payload);
    print("found photographer ajrr");
    print(res.data);
    List<dynamic> body = res.data;
    List<PhotographerModel> photoGraphers = body
        .map(
          (dynamic item) => PhotographerModel.fromJson(item),
        )
        .toList();

    return photoGraphers;
  }

  Future<List<PhotographerModel>> searchPhotoGraphers(dynamic payload) async {
    print("search photographers");
    var res =
        await Api().dio.post("/client/searchPhotographers", data: payload);
    List<dynamic> body = res.data;
    List<PhotographerModel> photoGraphers = body
        .map(
          (dynamic item) => PhotographerModel.fromJson(item),
        )
        .toList();
    return photoGraphers;
  }
}
