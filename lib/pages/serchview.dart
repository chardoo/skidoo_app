import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:skidoo_app/components/common/imageComponentWithAddtoCart.dart';
import 'package:skidoo_app/controller/cart_controller.dart';
import 'package:skidoo_app/controller/home_controller.dart';

class SearchResultsView extends StatelessWidget {
  final HomeController searchController = Get.find();
  final CartController Cartcontroller = Get.put(CartController());
  SearchResultsView({Key? key}) : super(key: key);
  Color mycolor = const Color.fromARGB(255, 15, 19, 26);
  Color whitecolor = Colors.white;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () {
            Get.offNamed('/home');
          },
          color: const Color.fromARGB(255, 255, 255, 255), // <-- SEE HERE
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.shopping_bag,
              color: whitecolor,
            ),
            onPressed: () {
              Get.offNamed('/cart');
            },
          )
        ],
        backgroundColor: mycolor,
        title: Text(
          "search results",
          style: TextStyle(
            color: whitecolor,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
      ),
      body: Scaffold(
          body: Column(children: [
        const SizedBox(
          height: 10,
        ),
        Obx(() => Expanded(
              child: searchController.loading.value == true
                  ? Container(
                      alignment: Alignment.topCenter,
                      margin: const EdgeInsets.only(top: 20),
                      child: const CircularProgressIndicator(
                        backgroundColor: Colors.grey,
                        color: Colors.purple,
                        strokeWidth: 10,
                      ))
                  : Container(
                      child: Obx(
                        () => SizedBox(
                            child: searchController.searchImage.value.isEmpty
                                ? const Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.image, size: 100),
                                        Text("No image found",
                                            style: TextStyle(
                                                color: Color.fromARGB(
                                                    255, 221, 217, 217)))
                                      ],
                                    ),
                                  )
                                : Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: MasonryGridView.count(
                                        crossAxisCount: 2,
                                        mainAxisSpacing: 8,
                                        crossAxisSpacing: 8,
                                        itemCount:
                                            searchController.searchImage.length,
                                        itemBuilder: (context, index) {
                                          return Column(children: [
                                            SearchImageComponents(
                                              photo: searchController
                                                  .searchImage[index],
                                            )
                                          ]);
                                        }))),
                      ),
                    ),
            ))
      ])),
    );
  }
}
