// ignore_for_file: file_names

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:get/get.dart';
import 'package:skidoo_app/components/common/cartItems.dart';
import 'package:skidoo_app/components/paymentCheckout.dart';
import 'package:skidoo_app/controller/cart_controller.dart';
import 'package:skidoo_app/core/common/customButtom.dart';

// import 'package:flutter_paystack/flutter_paystack.dart';
// import 'package:skiddoapp/models/photos/Photo.dart';
// import 'package:skiddoapp/components/common/cartItems.dart';
// import 'package:skiddoapp/components/paymentCheckout.dart';
// import 'package:skiddoapp/controller/cart_controller.dart';
// import 'package:skiddoapp/services/auth_service.dart';
//import 'package:flutter_paystack/flutter_paystack.dart';
import 'package:skidoo_app/models/photos/Photo.dart';
import 'package:skidoo_app/services/auth_service.dart';
import 'package:url_launcher/url_launcher.dart';

class CartScreen extends StatefulWidget {
  @override
  _CartScreen createState() => _CartScreen();
}

class _CartScreen extends State<CartScreen> {
  CartController cartController = Get.find();
  Color mycolor = const Color.fromARGB(255, 15, 19, 26);
  Color whitecolor = Colors.white;
  //final plugin = PaystackPlugin();

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    var screenSize = MediaQuery.of(context).size;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "My Cart",
          style: TextStyle(
            color: whitecolor,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
      ),
      body: SafeArea(
        child: SizedBox(
          height: screenSize.height,
          width: double.infinity,
          child: cartController.cartItems.length == 0
              ? const Center(
                  child:   Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [Icon(Icons.image, size: 100),
                                            Text(
                                                "Cart Empty ",
                                                style: TextStyle(
                                                    color: Color.fromARGB(
                                                        255, 221, 217, 217)))
                                            ],))
              : Obx(() => Padding(
                  padding: const EdgeInsets.all(10),
                  child: MasonryGridView.count(
                      crossAxisCount: 2,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      itemCount: cartController.cartItems.length,
                      itemBuilder: (context, index) {
                        return Column(children: [
                          CartItem(
                            photo: cartController.cartItems[index],
                          )
                        ]);
                      }))),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Obx(() =>  CustomButton(
             width: 343,
          height: 50,
            label: " Pay ${cartController.totalAmount}",
            ontap: () async {
              if (cartController.totalAmount.value > 1) {
                var me = await cartController
                    .payForImages(cartController.totalAmount.value.toString());
                cartController.referenceId.value = me["reference"];

                Get.to(CheckoutComponent(
                  url: me['authorization_url'],
                ));
              }
            },
          )),
    );
  }

  launchPayment(String url) async {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.inAppWebView);
    } else {
      throw 'Could not launch $url';
    }
  }

  Future<dynamic> processPayload(List<Photo> ImageInCart, reference) async {
    List<dynamic> paidItems = [];
    String clientId = await AuthService.getUserId();
    for (Photo item in ImageInCart) {
      paidItems.add(
          {"pictureId": item.id, "userId": item.userId, "clientId": clientId});
    }
    var payload = {
      "referenceId": reference,
      "clientId": clientId,
      "amount": cartController.totalAmount,
      "PaidImage": paidItems
    };
    return payload;
  }

  //async method to charge users card and return a response
  void _showMessage(String message) {
    final snackBar = SnackBar(content: Text(message));
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  //used to generate a unique reference for payment
  String _getReference() {
    var platform = (Platform.isIOS) ? 'iOS' : 'Android';
    final thisDate = DateTime.now().millisecondsSinceEpoch;
    return 'ChargedFrom${platform}_$thisDate';
  }
}
