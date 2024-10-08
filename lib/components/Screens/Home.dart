import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'package:easy_autocomplete/easy_autocomplete.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/services.dart';
import 'package:skidoo_app/components/Screens/Account.dart';
import 'package:skidoo_app/components/common/SearchItem.dart';
import 'package:skidoo_app/components/common/photographersChat.dart';
import 'package:skidoo_app/controller/home_controller.dart';
import 'package:skidoo_app/pages/cartScreen.dart';
import 'package:skidoo_app/screens/chat_page.dart';

class HomeNavigationScreen extends StatelessWidget {
  final HomeController controller = Get.put(HomeController());
  Color mycolor = const Color.fromARGB(255, 15, 19, 26);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          automaticallyImplyLeading: true,
          actions: [
            IconButton(
              icon: const Icon(
                Icons.shopping_bag,
                size: 20,
                color: Color.fromARGB(255, 200, 199, 199),
              ),
              onPressed: () {
                Get.to(CartScreen(), transition: Transition.fadeIn);
              },
            )
          ],
          bottom: const PreferredSize(
            preferredSize: Size(double.infinity, 5),
            child: Divider(color: Color.fromARGB(255, 237, 233, 233)),
          ),
          leading: Obx(() => Container(
                margin: const EdgeInsets.only(top: 10),
                child: controller.issearching.value == true
                    ? BackButton(
                        onPressed: () async {
                          // await SystemChannels.textInput
                          //     .invokeMethod('TextInput.hide');
                          controller.issearching.value = false;
                        },
                      )
                    : GestureDetector(
                        onTap: () {
                          Get.to(AccountNavigationScreen());
                        },
                        child: CircleAvatar(
                          radius: 20.h,
                          backgroundColor: Colors.white,
                          child: Text(
                            controller.userName.value[0],
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        )),
              )),
          title: Container(
              margin: const EdgeInsets.only(top: 10),
              height: 40,
              child: TextFormField(
                onTap: () async {
                  controller.issearching.value = true;
                },
                decoration: InputDecoration(
                  focusColor: const Color.fromARGB(255, 88, 88, 88),
                  suffixIcon: Obx(() => controller.issearching.value == true
                      ? IconButton(
                          icon: const Icon(Icons.close),
                          color: const Color.fromARGB(255, 247, 245, 245),
                          onPressed: () async {
                            await SystemChannels.textInput
                                .invokeMethod('TextInput.hide');
                            controller.issearching.value = false;
                          },
                        )
                      : const Text('')),
                  border: OutlineInputBorder(
                    borderSide: BorderSide.none,
                    borderRadius: BorderRadius.circular(5.0),
                  ),
                  fillColor: const Color.fromARGB(255, 74, 73, 73),
                  filled: true,
                  labelText: 'Search event',
                  //lable style
                  labelStyle: const TextStyle(
                    color: Color.fromARGB(255, 200, 198, 198),
                    fontSize: 12,
                    fontFamily: "verdana_regular",
                    fontWeight: FontWeight.w400,
                  ),
                ),
                onChanged: (value) {
                  controller.searchEvents(value);
                },
              )),
        ),
        body: body());
  }

  Widget body() {
    return Obx(() => Scaffold(
        resizeToAvoidBottomInset: false,
        body: controller.issearching.value == true
            ? Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: controller.eventSearched.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.event_available_outlined, size: 100),
                            Text("No event found! ",
                                style: TextStyle(
                                    color: Color.fromARGB(255, 221, 217, 217)))
                          ],
                        ),
                      )
                    : controller.searchEvent.value == true
                        ? Container(
                            alignment: Alignment.topCenter,
                            margin: const EdgeInsets.only(top: 20),
                            child: const CircularProgressIndicator(
                              backgroundColor: Colors.grey,
                              color: Colors.purple,
                              strokeWidth: 10,
                            ))
                        : ListView.builder(
                            scrollDirection: Axis.vertical,
                            itemCount: controller.eventSearched.length,
                            itemBuilder: (BuildContext ctxt, int index) {
                              return ListTile(
                                  selected: false,
                                  title: SearchTale(
                                      event: controller.eventSearched[index]));
                            }))
            : Column(children: [
                SizedBox(
                  height: 500,
                  child: ListView(
                    children: [
                      CarouselSlider(
                        items: [
                          Container(
                            margin: const EdgeInsets.all(6.0),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8.0),
                              image: const DecorationImage(
                                image: NetworkImage(
                                    "https://res.cloudinary.com/dpakfvvhu/image/upload/v1641466489/sample.jpg"),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),

                          //3rd Image of Slider
                          Container(
                            margin: const EdgeInsets.all(6.0),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8.0),
                              image: const DecorationImage(
                                image: NetworkImage(
                                    "https://res.cloudinary.com/dpakfvvhu/image/upload/v1641466489/sample.jpg"),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),

                          //4th Image of Slider
                          Container(
                            margin: const EdgeInsets.all(6.0),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8.0),
                              image: const DecorationImage(
                                image: NetworkImage(
                                    "https://res.cloudinary.com/dpakfvvhu/image/upload/v1641466489/sample.jpg"),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),

                          //5th Image of Slider
                          Container(
                            margin: const EdgeInsets.all(6.0),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8.0),
                              image: const DecorationImage(
                                image: NetworkImage(
                                    "https://res.cloudinary.com/dpakfvvhu/image/upload/v1641466489/sample.jpg"),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ],

                        //Slider Container properties
                        options: CarouselOptions(
                          height: 180.0,
                          enlargeCenterPage: true,
                          autoPlay: true,
                          aspectRatio: 16 / 9,
                          autoPlayCurve: Curves.fastOutSlowIn,
                          enableInfiniteScroll: true,
                          autoPlayAnimationDuration:
                              const Duration(milliseconds: 800),
                          viewportFraction: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ])));
  }
}
