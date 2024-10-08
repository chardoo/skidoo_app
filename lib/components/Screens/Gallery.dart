import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:skidoo_app/components/common/imageComponent.dart';
import 'package:skidoo_app/controller/Gallery_controller.dart';

class GalleryNavigationScreen extends StatelessWidget {
  GalleryNavigationScreen({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    final GalleryController controller = Get.put(GalleryController());

    return RefreshIndicator(
      onRefresh: () async {
        print("refresh now ");
        controller.onInit();
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          elevation: 0,
   
          title: const Text(
            "Gallery",
            style: TextStyle(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        body: SafeArea(
            child: Scaffold(

                body: Column(children: [
                  Obx(() => Expanded(
                        child: controller.loading.value == true
                            ? Container(
                                alignment: Alignment.topCenter,
                                margin: const EdgeInsets.only(top: 20),
                                child: const CircularProgressIndicator(
                                  backgroundColor: Colors.grey,
                                  color: Colors.purple,
                                  strokeWidth: 10,
                                ))
                            : Container(
                                margin: const EdgeInsets.only(
                                    left: 16, right: 16, top: 10),
                                child: SizedBox(
                                    child: controller.gallery.value.isEmpty
                                        ? const Center(
                                            child: 
                                            Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [Icon(Icons.folder, size: 100),
                                            Text(
                                                "Empty Gallery ",
                                                style: TextStyle(
                                                    color: Color.fromARGB(
                                                        255, 221, 217, 217)))
                                            ],)
                                            
                                                        
                                                        ,
                                          )
                                        : Obx(() => Padding(
                                            padding: const EdgeInsets.only(
                                                top: 12.0),
                                            child:
                                               
                                                MasonryGridView.count(
                                                    crossAxisCount: 2,
                                                    mainAxisSpacing: 8,
                                                    crossAxisSpacing: 8,
                                                    itemCount: controller
                                                        .gallery.length,
                                                    itemBuilder:
                                                        (context, index) {
                                                      return imageComponents(
                                                        imageURL: controller
                                                            .gallery[index].url,
                                                      );
                                                    })
                                        
                                            ))),
                              ),
                      ))
                ]))),
      ),
    );
  }
}
