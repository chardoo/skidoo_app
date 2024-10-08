// ignore_for_file: file_names

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';


import 'package:skidoo_app/components/common/photographerTale.dart';
import 'package:skidoo_app/controller/photographer.dart';
import 'package:skidoo_app/screens/chat_page.dart';
import 'package:url_launcher/url_launcher.dart';

class PhotographersScreen extends StatefulWidget {
  @override
  _PhotographersScreen createState() => _PhotographersScreen();
}

class _PhotographersScreen extends State<PhotographersScreen> {
  Color mycolor = const Color.fromARGB(255, 15, 19, 26);
  Color whitecolor = Colors.white;
  final PhotoGrapherController photoGrapherController =
      Get.put(PhotoGrapherController());

  @override
  Widget build(BuildContext context) {
    var screenSize = MediaQuery.of(context).size;
    return Scaffold(

        appBar: AppBar(
          elevation: 0,
          centerTitle: true,
          title: const Text("Photographers"),
        ),
        body: SingleChildScrollView(
            child: SizedBox(
                height: screenSize.height,
                width: double.infinity,
                child: Column(
                  children: [
                    Container(
                        margin: const EdgeInsets.only(
                            top: 10, left: 20, right: 20, bottom: 20),
                        height: 40,
                        // width: 343,
                        child: TextFormField(
                          // onTap: () => ,

                          onTap: () async {
                            // controller.issearching.value = true;
                          },
                          decoration: InputDecoration(
                            focusColor: const Color.fromARGB(255, 88, 88, 88),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.close),
                              color: const Color.fromARGB(255, 247, 245, 245),
                              onPressed: () async {
                                // await SystemChannels.textInput
                                //     .invokeMethod('TextInput.hide');
                                // controller.issearching.value = false;
                              },
                            ),
                            border: OutlineInputBorder(
                              borderSide: BorderSide.none,
                              borderRadius: BorderRadius.circular(5.0),
                            ),
                            fillColor: const Color.fromARGB(255, 74, 73, 73),
                            filled: true,
                            labelText: 'Search',
                            //lable style
                            labelStyle: const TextStyle(
                              color: Color.fromARGB(255, 200, 198, 198),
                              fontSize: 12,
                              fontFamily: "verdana_regular",
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          onChanged: (value) async {
                            photoGrapherController
                                .searhPhotographer({"queryString": value});
                          },
                        )),
                    Expanded(
                        child: Container(
                            margin: const EdgeInsets.only(left: 16, right: 16),
                            child: Obx(() => SizedBox(
                                    child: 
                                       ListView.builder(
                                          scrollDirection: Axis.vertical,
                                          itemCount: photoGrapherController
                                              .photoGraphers.length,
                                          itemBuilder:
                                              (BuildContext ctxt, int index) {
                                            return PhotographerTale(
                                                photographerModel:
                                                    photoGrapherController
                                                        .photoGraphers[index]);
                                          },
                                        ),
                                      ) 
                                      )))
                  ],
                )

                
                )));
  }
}
