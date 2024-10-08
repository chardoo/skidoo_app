import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:skidoo_app/controller/login_controller.dart';
import 'package:skidoo_app/core/validators/validators.dart';

class VerifyEmailScreen extends StatelessWidget {
  final LoginController controller = Get.put(LoginController());

  Color mycolor = const Color.fromARGB(255, 15, 19, 26);
  static const colorizeTextStyle =
      TextStyle(fontSize: 25.0, fontFamily: 'SF', color: Colors.redAccent);
  bool secureTest = true;
  bool isError = false;

  VerifyEmailScreen({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          elevation: 5,
          centerTitle: true,
          title: const Text(
            "skiddo",
            style: TextStyle(
                color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700),
          ),
        ),
        body: body(context));
  }

  Widget body(context) {
    return SafeArea(
        child: Scaffold(
            body: ListView(children: [
      Container(
          child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Container(
                  margin: const EdgeInsets.only(left: 30),
                  child: const Text(
                    "Verify the Code",
                    softWrap: true,
                    style: TextStyle(color: Colors.white),
                  )),
            ],
          ),
          const SizedBox(
            height: 74,
          ),
          Form(
              key: controller.formKey,
              child: Column(
                children: [
                  Obx(() => Container(
                        child: (controller.isError.value == true)
                            ? const Text(
                                "Invalid Credentials",
                                style:
                                    TextStyle(color: Colors.red, fontSize: 20),
                              )
                            : const Text(" "),
                      )),
                  const SizedBox(
                    height: 30,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 25),
                    child: Column(
                      children: [
                        Container(
                            width: 343,
                            child: TextFormField(
                              controller: controller.emailController,
                              validator: (value) =>
                                  Validators.emailValidator(value),
                              decoration: InputDecoration(
                                focusColor: Colors.white,
                                prefixIcon: const Icon(
                                  Icons.person,
                                  color: Colors.grey,
                                ),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10.0),
                                    borderSide: BorderSide.none),
                                fillColor:
                                    const Color.fromARGB(255, 255, 254, 254),
                                filled: true,
                                labelText: 'Code',
                                //lable style
                                labelStyle: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 16,
                                  fontFamily: "verdana_regular",
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            )),
                        const SizedBox(
                          height: 20,
                        ),
                        const SizedBox(
                          height: 10,
                        ),
                        const SizedBox(
                          height: 60,
                        ),
                        SizedBox(
                            width: 343,
                            height: 50,
                            child: TextButton(
                                style: TextButton.styleFrom(
                                  backgroundColor: Colors.white,
                                ),
                                onPressed: () async {
                                  if (controller.formKey.currentState!
                                      .validate()) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                            duration: Duration(hours: 2),
                                            backgroundColor:
                                                Color.fromARGB(255, 8, 8, 8),
                                            content: Text('loggin In .....')));
                                    dynamic login = await controller.login();
                                    ScaffoldMessenger.of(context)
                                        .removeCurrentSnackBar();
                                    if (login == true) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(const SnackBar(
                                              backgroundColor:
                                                  Color.fromARGB(255, 8, 8, 8),
                                              content: Text('Success')));
                                      Get.offNamed('/home');
                                    } else {
                                      controller.isError.value = true;
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(const SnackBar(
                                              backgroundColor:
                                                  Color.fromARGB(255, 8, 8, 8),
                                              content:
                                                  Text('Sorry Login Failed')));
                                    }
                                  }
                                },
                                child: Text(
                                  "Verify Code",
                                  textAlign: TextAlign.center,
                                  style:
                                      TextStyle(color: mycolor, fontSize: 15),
                                ))),
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
                                  Get.offNamed('/verifyCode');
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
