import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:skidoo_app/API/Auth/auth.dart';
import 'package:skidoo_app/models/Auth/LoginResponse.dart';
import 'package:skidoo_app/services/auth_service.dart';

class LoginController extends GetxController {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final GlobalKey<FormState> formKeyConfirmEmail = GlobalKey<FormState>();
  final GlobalKey<FormState> formKeyResetPassword = GlobalKey<FormState>();
  final passwordController = TextEditingController();
  final emailController = TextEditingController();
  final confirmemailController = TextEditingController();
  var ispasswordHidden = true.obs;
  var isError = false.obs;
  var isloading = false.obs;
  var error = '';
  var isDisabled = true.obs;
  final loginApi = AuthHttpService();
  AuthService service = AuthService();
  @override
  void onClose() {
    emailController.dispose();
    passwordController.dispose();
    super.onClose();
  }

  Future<dynamic> login() async {
    Map<String, dynamic> loginDetails = {
      "password": passwordController.text.trim().toString(),
      "email": emailController.text.trim().toString(),
    };
    isloading.value = true;
    var response = await loginApi.login(loginDetails);
    isloading.value = false;
    if (response.runtimeType == LoginResponseObject) {
      await AuthService.setToken(response.token);
      await AuthService.setUniqueName(response.uniqueName);
      await AuthService.setId(response.id);
      await AuthService.setEmail(response.email);
      await AuthService.setName(response.name);
      return true;
    } else {
      return false;
    }
  }

  Future<dynamic> confirmEmail() async {}

  // ignore: non_constant_identifier_names
  Future<bool> createUser() async {
    Map<String, dynamic> loginDetails = {
      "password": passwordController.text,
      "email": emailController.text,
    };
    return false;
  }
}
