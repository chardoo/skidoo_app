import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:skidoo_app/controller/login_controller.dart';
import 'package:skidoo_app/core/common/customButtom.dart';
import 'package:skidoo_app/core/common/textfield.dart';
import 'package:skidoo_app/core/validators/validators.dart';

class ResetPasswordScreen extends StatelessWidget {
  final LoginController controller = Get.put(LoginController());

  Color mycolor = const Color.fromARGB(255, 15, 19, 26);
  static const colorizeTextStyle =
      TextStyle(fontSize: 25.0, fontFamily: 'SF', color: Colors.redAccent);
  bool secureTest = true;
  bool isError = false;

  ResetPasswordScreen({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: body(context));
  }

  Widget body(context) {
    return SafeArea(
        child: Scaffold(
            body: ListView(children: [
      Center(
        
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                      margin: const EdgeInsets.only(left: 30),
                      child: const Text(
                        "Type a new Password",
                        softWrap: true,
                        style: TextStyle(color: Colors.white, fontSize: 20),
                      )),
                ],
              ),
              Form(
                  key: controller.formKeyResetPassword,
                  child: Column(
                    children: [
                      Obx(() => Container(
                            child: (controller.isError.value == true)
                                ? const Text(
                                    "Invalid Credentials",
                                    style: TextStyle(
                                        color: Colors.red, fontSize: 20),
                                  )
                                : const Text(" "),
                          )),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 25),
                        child: Column(
                          children: [
                            MyTextField(
                              controller: controller.confirmemailController,
                              validator: (value) =>
                                  Validators.passwordValidator(value),
                              label: "Password",
                            ),
                            const SizedBox(
                              height: 60,
                            ),
                            MyTextField(
                              controller: controller.confirmemailController,
                              validator: (value) =>
                                  Validators.passwordValidator(value),
                              label: "Confirm Password",
                            ),
                            const SizedBox(
                              height: 100,
                            ),
                            SizedBox(
                                width: 343,
                                height: 50,
                                child: CustomButton(
                                  ontap: () async {
                                    if (controller.formKey.currentState!
                                        .validate()) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(const SnackBar(
                                              duration: Duration(hours: 2),
                                              backgroundColor:
                                                  Color.fromARGB(255, 8, 8, 8),
                                              content:
                                                  Text('loggin In .....')));
                                      dynamic login =
                                          await controller.confirmEmail();
                                      ScaffoldMessenger.of(context)
                                          .removeCurrentSnackBar();
                                      if (login == true) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(const SnackBar(
                                                backgroundColor: Color.fromARGB(
                                                    255, 8, 8, 8),
                                                content: Text('Success')));
                                        Get.offNamed('/home');
                                      } else {
                                        controller.isError.value = true;
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(const SnackBar(
                                                backgroundColor: Color.fromARGB(
                                                    255, 8, 8, 8),
                                                content: Text(
                                                    'Sorry Login Failed')));
                                      }
                                    }
                                  },
                                  label: "Reset Password",
                                )),
                            const SizedBox(
                              height: 20,
                            ),
                            const SizedBox(
                              height: 10,
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text("Have you remebered ?",
                                    style: TextStyle(
                                        fontSize: 15, color: Colors.white)),
                                TextButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                    },
                                    child: const Text(
                                      "Login",
                                      style: TextStyle(
                                          fontSize: 15, color: Colors.white),
                                    ))
                              ],
                            )
                          ],
                        ),
                      )
                    ],
                  ))
            ],
          ))
    ])));
  }
}
