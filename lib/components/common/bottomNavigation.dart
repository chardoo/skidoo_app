import 'package:cached_network_image/cached_network_image.dart';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:skidoo_app/controller/home_controller.dart';

// import 'packag
class BottomNavigation extends StatelessWidget {
  final HomeController controller = Get.put(HomeController());

  BottomNavigation({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return
     BottomAppBar(
      clipBehavior: Clip.hardEdge,
      // ignore: sort_child_properties_last
      child: IconTheme(
          data: const IconThemeData(),
          child: Padding(
            padding: const EdgeInsets.only(top: 11.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                GestureDetector(
                  onTap: () {
                    controller.index.value = 0;
                    // Get.to(HomeScreen());
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(width: 30, child: Icon(Icons.home)),
                      Padding(
                        padding: const EdgeInsets.only(top: 1.0),
                        child: Text(
                          "Home",
                          style: TextStyle(
                            color: controller.index.value == 0
                                ? const Color(0xFF42B546)
                                : const Color(0xff989899),
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(
                  width: 10,
                ),
                GestureDetector(
                  onTap: () {
                    controller.index.value = 1;
                    // Get.to(HomeScreen());
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(width: 30, child: Icon(Icons.home)),
                      Padding(
                        padding: const EdgeInsets.only(top: 1.0),
                        child: Text(
                          "Gallery",
                          style: TextStyle(
                            color: controller.index.value == 0
                                ? const Color(0xFF42B546)
                                : const Color(0xff989899),
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(
                  width: 10,
                ),
                GestureDetector(
                  onTap: () {
                    controller.index.value = 2;
                    // Get.to(HomeScreen());
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(width: 30, child: Icon(Icons.home)),
                      Padding(
                        padding: const EdgeInsets.only(top: 1.0),
                        child: Text(
                          "Account",
                          style: TextStyle(
                            color: controller.index.value == 0
                                ? const Color(0xFF42B546)
                                : const Color(0xff989899),
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )),
      color: Theme.of(context).bottomNavigationBarTheme.backgroundColor,
    );
  }
}
