import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

// import 'package:open_file/open_file.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

// import 'package:file_picker/file_picker.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:url_launcher/url_launcher.dart';

class DocumentController extends GetxController {
  // final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  // DocumentsHttpService documentHttpService = DocumentsHttpService();
  // RxList documents = [].obs;
  // RxList mimeTypes = [].obs;
  // dynamic firstValue = null.obs;
  // @override
  // onInit() async {
  //   List<Documents> data = await documentHttpService.getDocuments();
  //   documents.value = data;

  //   List<MimeTypeModel> mimeTypesdata = await documentHttpService.getMime();
  //   mimeTypes.value = mimeTypesdata;
  //   mimeTypes.sort((a, b) => a.name.compareTo(b.name));
  //   firstValue = mimeTypes[0];
  //   super.onInit();
  // }

  // Future<void> searchWithMime(dynamic mimeType) async {
  //   SharedPreferences prefs = await SharedPreferences.getInstance();

  //   var payload = {"userId": prefs.getString('email'), "mimeType": mimeType};

  //   List<Documents> data =
  //       await documentHttpService.getDocumentsByMimeTypes(payload);
  //   documents.value.clear();
  //   documents.value = data;
  // }

  // Future<List<Documents>> serachdocuments(String searchKey) async {
  //   List<Documents> documents =
  //       await documentHttpService.searchDocuments(searchKey);
  //   print("after body");
  //   print(documents);
  //   return documents;
  // }

  
  
}
