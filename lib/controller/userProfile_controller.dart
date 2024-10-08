import 'dart:async';
import 'dart:io';
import 'package:get/get.dart';
import 'package:skidoo_app/services/auth_service.dart';

class UserController extends GetxController {
  AuthService service = AuthService();
  late String email;
  late String Mobile;
  late String name;

  @override
  onInit() async {
    print("yeah is been called");
    email = await AuthService.getEmail();
    name = await AuthService.getName();
    print(email);
    // Mobile = await AuthService.getmobile();
    super.onInit();
  }

  logOut() async {
    AuthService.removeToken();
    
    Get.offAllNamed('/login');
  }
}
