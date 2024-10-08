import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:skidoo_app/components/Screens/Account.dart';
import 'package:skidoo_app/components/Screens/Gallery.dart';
import 'package:skidoo_app/components/Screens/Home.dart';
import 'package:skidoo_app/components/common/navbar.dart';
import 'package:skidoo_app/controller/Gallery_controller.dart';
import 'package:skidoo_app/controller/cart_controller.dart';
import 'package:skidoo_app/controller/home_controller.dart';
import 'package:skidoo_app/controller/userProfile_controller.dart';
import 'package:skidoo_app/pages/photographers.dart';
import 'package:skidoo_app/screens/chat_page.dart';
// import 'package:skiddoapp/components/Screens/Account.dart';
// import 'package:skiddoapp/components/Screens/Gallery.dart';
// import 'package:skiddoapp/components/Screens/Home.dart';
// import 'package:skiddoapp/controller/Gallery_controller.dart';
// import 'package:skiddoapp/controller/cart_controller.dart';
// import 'package:skiddoapp/controller/home_controller.dart';
// import 'package:skiddoapp/controller/userProfile_controller.dart';

class HomeScreen extends StatefulWidget {
  static const colorizeTextStyle =
      TextStyle(fontSize: 25.0, fontFamily: 'SF', color: Colors.redAccent);

  HomeScreen({Key? key}) : super(key: key);

  static const TextStyle optionStyle =
      TextStyle(fontSize: 30, fontWeight: FontWeight.bold);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final HomeController controller = Get.put(HomeController());

  final CartController Cartcontroller = Get.put(CartController());

  final GalleryController controllerr = Get.put(GalleryController());

  final UserController rerer = Get.put(UserController());

  bool secureTest = true;

  Color mycolor = const Color.fromARGB(255, 15, 19, 26);

  Color whitecolor = Colors.white;

  // ignore: prefer_final_fields
  int _selectedTab = 0;

  final List _pages = [
    HomeNavigationScreen(),
    GalleryNavigationScreen(),
    // const ChatPage(),
    PhotographersScreen()
   
  ];

  _changeTab(int index) {
    setState(() {
      _selectedTab = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: body(context));
  }

  Widget body(context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: _pages[_selectedTab],
      bottomNavigationBar: AppNavbar(selectedIndex: _selectedTab,
       onchange: _changeTab,) 
        );
  }
}
