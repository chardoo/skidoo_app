import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:skidoo_app/controller/cart_controller.dart';
import 'package:skidoo_app/models/photos/Photo.dart';

// ignore: must_be_immutable
class CartItem extends StatelessWidget {
  Photo photo = Photo("", "", "", "", "", 0, "", "", false);

  CartController cartController = Get.find();
  CartItem({Key? key, required this.photo}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    final int price = photo.price;
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(
            photo.url,
            fit: BoxFit.contain,
            height: 250,
          ),
        ),
        Align(
          alignment: Alignment.topRight,
          child: IconButton(
            onPressed: () {
              cartController.cartItems.remove(photo);
              cartController.total();
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('Image Removed')));
            },
            icon: const Icon(
              Icons.remove_circle,
              color: Color.fromARGB(255, 251, 250, 250),
              size: 40,
            ),
          ),
        )
      ],
    );
  }
}
