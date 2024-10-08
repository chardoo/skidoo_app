import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:skidoo_app/controller/login_controller.dart';
import 'package:skidoo_app/core/common/customButtom.dart';
import 'package:skidoo_app/core/common/password_textfield.dart';
import 'package:skidoo_app/core/common/textfield.dart';
import 'package:skidoo_app/core/validators/validators.dart';
import 'package:skidoo_app/pages/forget_pasword.dart';
import 'package:skidoo_app/widgets/loader.dart';

class LoginScreen extends StatelessWidget {
  final  controller = Get.put(LoginController());

  Color mycolor = const Color.fromARGB(255, 15, 19, 26);
  static const colorizeTextStyle =
      TextStyle(fontSize: 25.0, fontFamily: 'SF', color: Colors.redAccent);
  bool secureTest = true;
  bool isError = false;

  LoginScreen({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Center(
            child: SingleChildScrollView(
                child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(children: [
                      Form(
                          key: controller.formKey,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Column(
                                children: [
                                  Text(
                                    "Welcome back ",
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 24),
                                  ),
                                  Text(
                                    "Enter your credentials ",
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(color: Colors.grey),
                                  ),
                                ],
                              ),
                              Obx(() => Container(
                                    child: (controller.isError.value == true)
                                        ? const Text(
                                            "Invalid Credentials",
                                            style: TextStyle(
                                                color: Colors.red,
                                                fontSize: 20),
                                          )
                                        : const Text(" "),
                                  )),
                              const SizedBox(
                                height: 30,
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 25),
                                child: Column(
                                  children: [
                                    MyTextField(
                                      controller: controller.emailController,
                                      validator: (value) =>
                                          Validators.emailValidator(value),
                                      label: 'Email',
                                    ),
                                    const SizedBox(
                                      height: 20,
                                    ),
                                    PasswordField(
                                      onSubmited: (p0) {
                                        login();
                                      },
                                      label: 'Password',
                                      validator: (value) =>
                                          Validators.passwordValidator(value),
                                      pwdController:
                                          controller.passwordController,
                                    ),
                                    const SizedBox(
                                      height: 10,
                                    ),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        TextButton(
                                          onPressed: () {
                                            //  Get.offNamed('/forgotPassword');
                                            Get.to(ForgetPasswordScreen(),
                                                transition: Transition.fadeIn);
                                            //  Get.(page)
                                          },
                                          child: const Text(
                                            "Forget Password",
                                            style:
                                                TextStyle(color: Colors.white),
                                          ),
                                        )
                                      ],
                                    ),
                                    const SizedBox(
                                      height: 60,
                                    ),
                                    Obx(
                          () => controller.isloading.value
                              ? const LoadingButton()
                              
                              :CustomButton(
                                            height: 50.h,
                                             width: double.infinity,
                                          ontap: () async {
                                            await login();
                                          },
                                          label: "Login",
                                        )),
                                    const SizedBox(
                                      height: 20,
                                    ),
                                    const SizedBox(
                                      height: 10,
                                    ),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Text("Don't have account?",
                                            style: TextStyle(
                                                fontSize: 15,
                                                color: Colors.white)),
                                        TextButton(
                                            onPressed: () {
                                              Get.offNamed('/signUp');
                                            },
                                            child: const Text(
                                              "Sign Up",
                                              style: TextStyle(
                                                  fontSize: 15,
                                                  color: Colors.white),
                                            ))
                                      ],
                                    )
                                  ],
                                ),
                              )
                            ],
                          ))
                    ])))));
  }

  Future<void> login() async {
    if (controller.formKey.currentState!.validate()) {
      Get.snackbar("login", "Sloggin In .....");
      dynamic login = await controller.login();
      Get.closeAllSnackbars();
      if (login == true) {
        Get.offNamed('/home');
      } else {
        controller.isError.value = true;

        Get.snackbar("login", "Sorry Login Failed");
      }
    }
  }
}
