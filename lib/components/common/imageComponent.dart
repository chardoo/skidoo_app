import 'package:flutter/material.dart';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:skidoo_app/controller/cart_controller.dart';

// import 'package:photoapp_mobile/contollers/cart_controller.dart';

class imageComponents extends StatelessWidget {
  String imageURL = "";
  imageComponents({required this.imageURL});

  CartController cartController = Get.put(CartController());
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(
            imageURL,
            fit: BoxFit.cover,
          ),
        ),
        Container(
            alignment: Alignment.topRight,
            padding: const EdgeInsets.all(12),
            child: Container(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                  Container(
                      padding: const EdgeInsets.all(5),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color.fromARGB(255, 242, 239, 239),
                      ),
                      child: GetBuilder<CartController>(
                          init: CartController(),
                          builder: (value) => InkWell(
                                onTap: () async {
                                  value.downloadeImage(imageURL);
                                },
                                child: const Icon(Icons.download,
                                    color: Colors.black),
                              )))
                ]))),
      ],
    );
  }
}
