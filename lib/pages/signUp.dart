import 'dart:io';
//import 'package:face_camera/face_camera.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:skidoo_app/components/Screens/captureFace.dart';
import 'package:skidoo_app/controller/signUp_controller.dart';
import 'package:skidoo_app/core/common/customButtom.dart';
import 'package:skidoo_app/core/common/password_textfield.dart';
import 'package:skidoo_app/core/common/textfield.dart';
import 'package:skidoo_app/core/validators/validators.dart';
import 'package:skidoo_app/pages/login.dart';
import 'package:skidoo_app/widgets/loader.dart';

// import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
// import 'package:camera/camera.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({
    super.key,
    required this.camera,
  });

  final CameraDescription camera;
  @override
  _SignUpScreen createState() => _SignUpScreen();
}

class _SignUpScreen extends State<SignUpScreen>
    with SingleTickerProviderStateMixin {
  final SignUpController controller = Get.put(SignUpController());
  static const colorizeTextStyle =
      TextStyle(fontSize: 25.0, fontFamily: 'SF', color: Colors.redAccent);
  String imagepath = "";
  late List<File> facefiles = [];
  late File faces;
  Color mycolor = const Color.fromARGB(255, 15, 19, 26);
  Color whiteColor = Colors.white;
  // String _image =
  //     'https://ouch-cdn2.icons8.com/84zU-uvFboh65geJMR5XIHCaNkx-BZ2TahEpE9TpVJM/rs:fit:784:784/czM6Ly9pY29uczgu/b3VjaC1wcm9kLmFz/c2V0cy9wbmcvODU5/L2E1MDk1MmUyLTg1/ZTMtNGU3OC1hYzlh/LWU2NDVmMWRiMjY0/OS5wbmc.png';
  late AnimationController loadingController;
  //late Future<void> _initializeControllerFuture;

  @override
  void initState() {
    loadingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..addListener(() {
        setState(() {});
      });

    // _controller = CameraController(
    //   widget.camera,
    //   ResolutionPreset.medium,
    // );
    // _initializeControllerFuture = _controller.initialize();
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: body(context));
  }

  Widget body(context) {
    return Scaffold(
        body: Center(
            child: Padding(
                padding: const EdgeInsets.all(24),
                child: SingleChildScrollView(
                    child: Form(
                  key: controller.formKey,
                  child: Column(
                    children: [
                      Column(
                        children: [
                          Text(
                            "Let's get Started ",
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                    fontWeight: FontWeight.bold, fontSize: 24),
                          ),
                          Text(
                            "Create an account and get best \nfeatures",
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(color: Colors.grey),
                          ),
                        ],
                      ),
                      Obx(() => controller.Imagepath.value.isNotEmpty
                          ? CircleAvatar(
                              radius: 40,
                              child: ClipOval(
                                child: SizedBox(
                                  child: Image.file(
                                    File(controller.Imagepath.value),
                                    fit: BoxFit.cover,
                                    height: 150,
                                    width: 150,
                                  ),
                                ),
                              ))
                          : Container()),
                      Obx(() => Container(
                            child: (controller.isError.value == true)
                                ? const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                        Text(
                                          "Register Again,Something went Wrong",
                                          style: TextStyle(
                                              color: Colors.red, fontSize: 15),
                                        )
                                      ])
                                : const Text(" "),
                          )),
                      const SizedBox(
                        height: 20,
                      ),
                      Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 0),
                          child: Column(
                            children: [
                              const SizedBox(
                                height: 10,
                              ),
                              MyTextField(
                                controller: controller.emailController,
                                validator: (value) =>
                                    Validators.emailValidator(value),
                                label: 'Email',
                              ),
                              const SizedBox(
                                height: 20,
                              ),
                              MyTextField(
                                controller: controller.userNameController,
                                validator: (value) =>
                                    Validators.nameValidator(value),
                                label: "UserName",
                              ),
                              const SizedBox(
                                height: 20,
                              ),
                              MyTextField(
                                controller: controller.contactController,
                                validator: (value) =>
                                    Validators.phoneNumberValidator(value),
                                label: "Telephone",
                              ),
                              const SizedBox(
                                height: 20,
                              ),
                              PasswordField(
                                label: "Confirm Password",
                                pwdController: controller.passwordController,
                                validator: (value) =>
                                    Validators.passwordValidator(value),
                              ),
                              const SizedBox(
                                height: 20,
                              ),
                              PasswordField(
                                label: "Confirm Password",
                                pwdController: controller.passwordController,
                                validator: (value) =>
                                    Validators.passwordValidator(value),
                              ),
                              const SizedBox(
                                height: 20,
                              ),
                              MaterialButton(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 0),
                                onPressed: () async {
                                  final cameras = await availableCameras();
                                  final firstCamera = cameras;
                                  await Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => TakePictureScreen(
                                        camera: firstCamera[1],
                                      ),
                                    ),
                                  );
                                },
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.start,
                                      children: [
                                        Icon(
                                          Icons.camera,
                                          color: whiteColor,
                                        ),
                                        Text(
                                          "Register your face here",
                                          style: TextStyle(color: whiteColor),
                                        )
                                      ],
                                    ),
                                    Obx(
                                      () => controller.Imagepath.isEmpty &&
                                              controller.isRegisterClicked
                                                      .value ==
                                                  true
                                          ? const Text(
                                              'Face not captured',
                                              style:
                                                  TextStyle(color: Colors.red),
                                            )
                                          : const Text(" "),
                                    )
                                  ],
                                ),
                              ),
                              const SizedBox(
                                height: 20,
                              ),
                            ],
                          )),
                      const SizedBox(
                        height: 5,
                      ),
                      Obx(() => controller.isloading.value
                          ? const LoadingButton()
                          : CustomButton(
                              height: 50.h,
                              width: double.infinity,
                              ontap: () async {
                                await signIn();
                              },
                              label: "Sign Up",
                            )),
                      const SizedBox(
                        height: 20,
                      ),
                      const SizedBox(
                        height: 8,
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text("Already have account",
                              style:
                                  TextStyle(fontSize: 15, color: whiteColor)),
                          TextButton(
                              onPressed: () {
                                Get.offAll(LoginScreen());
                              },
                              child: Text(
                                "Sign In",
                                style:
                                    TextStyle(fontSize: 15, color: whiteColor),
                              ))
                        ],
                      )
                    ],
                  ),
                )))));
  }

  Future<void> signIn() async {
    controller.isRegisterClicked.value = true;
    File file = File(controller.Imagepath.value);
    controller.imageName.value = file.path.split('/').last;
    if (controller.formKey.currentState!.validate()) {
      Get.snackbar("SignUp", "Sign up please wait....");
      dynamic login = await controller.register(file);
      Get.closeAllSnackbars();
      if (login == true) {
        controller.isRegisterClicked.value = false;
        Get.offNamed('/login');
      } else {
        controller.isRegisterClicked.value = false;
        controller.isError.value = true;
        Get.snackbar("login", "Sorry sign up unsuccessful");
      }
    }
  }
}
