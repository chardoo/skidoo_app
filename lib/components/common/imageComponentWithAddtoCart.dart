import 'package:flutter/material.dart';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get_connect/http/src/utils/utils.dart';

import 'package:get/get.dart';
import 'package:skidoo_app/controller/cart_controller.dart';
import 'package:skidoo_app/models/photos/Photo.dart';

// ignore: must_be_immutable
class SearchImageComponents extends StatelessWidget {
  Photo photo = new Photo("", "", "", "", "", 0, "", "", false);
  SearchImageComponents({Key? key, required this.photo}) : super(key: key);
  CartController cartController = Get.find();
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(
            photo.url,
            fit: BoxFit.cover,
          ),
        ),
       Align(
        alignment: Alignment.topRight,
        child: 
        Column(
          children: [
       Container(
              padding: EdgeInsets.all(5),
              color: Colors.black,
              height: 40.h,
              width: 40.h,
              child: Text('GhC ${photo.price}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 10.h,
                      color: Theme.of(context).primaryColor)),
            ),
            SizedBox(height: 155.h,),
        Container(
                padding: EdgeInsets.all(5),
              color: Colors.black,
              height: 40.h,
              width: 40.h,
                child: photo.price == 0
                    //|| photo.isPublic == true
                    ? GetBuilder<CartController>(
                        init: CartController(),
                        builder: (value) => InkWell(
                              onTap: () async {
                                value.downloadeImage(photo.url);
                              },
                              child: const Icon(Icons.download,
                                  size: 20,),
                            ))
                    : GetBuilder<CartController>(
                        init: CartController(),
                        builder: (value) => InkWell(
                              onTap: () {
                                if (!value.cartItems.contains(photo)) {
                                  value.cartItems.add(photo);
                                  value.total();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text('Image added')));
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text('Already added')));
                                }
                              },
                              child: const Icon(Icons.shopping_cart,
                                  size: 20, ),
                            )))]))
        // ]))
      ],
    );

  
  }
}
