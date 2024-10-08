import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:skidoo_app/controller/login_controller.dart';
import 'package:skidoo_app/core/common/customButtom.dart';
import 'package:skidoo_app/core/common/textfield.dart';
import 'package:skidoo_app/core/validators/validators.dart';
import 'package:skidoo_app/pages/reset_password.dart';

class ForgetPasswordScreen extends StatelessWidget {
  final LoginController controller = Get.put(LoginController());

  Color mycolor = const Color.fromARGB(255, 15, 19, 26);
  static const colorizeTextStyle =
      TextStyle(fontSize: 25.0, fontFamily: 'SF', color: Colors.redAccent);
  bool secureTest = true;
  bool isError = false;

  ForgetPasswordScreen({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Scaffold(
       
        backgroundColor: mycolor,
        body:Center(
          child: SingleChildScrollView(
            child: Padding(
                padding: const EdgeInsets.all(24),
                child: 
                   Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                              margin: const EdgeInsets.only(left: 30),
                              child:  Text(
                                "Confirm Email",
                                softWrap: true,
                                  style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 24),
                              )),
                        ],
                      ),
                      Form(
                          key: controller.formKeyConfirmEmail,
                          child: Column(
                            children: [
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
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 25),
                                child: Column(
                                  children: [
                                     MyTextField(
                                       
                                          controller:
                                              controller.confirmemailController,
                                          validator: (value) =>
                                              Validators.emailValidator(value),
                                          label: "email",
                                           
                                        ),
                                    const SizedBox(
                                      height: 30,
                                    ),
                                    SizedBox(
                                        width: 343,
                                        height: 50,
                                        child: CustomButton(
                                            
                                            ontap: () async {
                                              print(
                                                  "print hello how are you doing ");

                                              Get.offAll(ResetPasswordScreen());

                                            },
                                            label: 
                                              "Verify Email",
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
                                        const Text("Have you remebered ?",
                                            style: TextStyle(
                                                fontSize: 15,
                                                color: Colors.white)),
                                        TextButton(
                                            onPressed: () {
                                              Navigator.pop(context);
                                            },
                                            child: const Text(
                                              "Login",
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
                    ],
                  ))
            ))
        
        );
  }

 
}
