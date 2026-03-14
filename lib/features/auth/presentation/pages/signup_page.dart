import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/components/Screens/captureFace.dart';
import 'package:skidoo_app/core/common/customButtom.dart';
import 'package:skidoo_app/core/common/password_textfield.dart';
import 'package:skidoo_app/core/common/textfield.dart';
import 'package:skidoo_app/core/di/service_locator.dart';
import 'package:skidoo_app/core/validators/validators.dart';
import 'package:skidoo_app/features/auth/presentation/bloc/signup/signup_bloc.dart';
import 'package:skidoo_app/features/auth/presentation/pages/login_page.dart';
import 'package:skidoo_app/widgets/loader.dart';

class SignUpPage extends StatelessWidget {
  static const routeName = '/signup';
  final CameraDescription camera;
  const SignUpPage({super.key, required this.camera});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<SignUpBloc>(),
      child: _SignUpView(camera: camera),
    );
  }
}

class _SignUpView extends StatefulWidget {
  final CameraDescription camera;
  const _SignUpView({required this.camera});

  @override
  State<_SignUpView> createState() => _SignUpViewState();
}

class _SignUpViewState extends State<_SignUpView> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _contactController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _registerClicked = false;

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _contactController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit(SignUpState state) {
    setState(() => _registerClicked = true);
    if (_formKey.currentState?.validate() ?? false) {
      context.read<SignUpBloc>().add(SignUpSubmitted(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
            contact: _contactController.text.trim(),
            userName: _usernameController.text.trim(),
            imagePath: state.imagePath,
          ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocConsumer<SignUpBloc, SignUpState>(
        listener: (context, state) {
          if (state.isSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Registration successful!')),
            );
            Navigator.of(context).pushReplacementNamed(LoginPage.routeName);
          }
          if (state.errorMessage != null && !state.isLoading) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(
                content: Text(state.errorMessage!),
                backgroundColor: Colors.red,
              ));
          }
        },
        builder: (context, state) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      Text(
                        "Let's get Started",
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(
                                fontWeight: FontWeight.bold, fontSize: 24),
                      ),
                      Text(
                        'Create an account to get the best features',
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                      if (state.imagePath.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        CircleAvatar(
                          radius: 40,
                          child: ClipOval(
                            child: Image.file(
                              File(state.imagePath),
                              fit: BoxFit.cover,
                              height: 150,
                              width: 150,
                            ),
                          ),
                        ),
                      ],
                      if (state.errorMessage != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          state.errorMessage!,
                          style: const TextStyle(
                              color: Colors.red, fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: 20),
                      MyTextField(
                        controller: _emailController,
                        validator: (v) => Validators.emailValidator(v),
                        label: 'Email',
                      ),
                      const SizedBox(height: 20),
                      MyTextField(
                        controller: _usernameController,
                        validator: (v) => Validators.nameValidator(v),
                        label: 'Username',
                      ),
                      const SizedBox(height: 20),
                      MyTextField(
                        controller: _contactController,
                        validator: (v) =>
                            Validators.phoneNumberValidator(v),
                        label: 'Phone Number',
                      ),
                      const SizedBox(height: 20),
                      PasswordField(
                        label: 'Password',
                        pwdController: _passwordController,
                        validator: (v) =>
                            Validators.passwordValidator(v as String?),
                      ),
                      const SizedBox(height: 20),
                      PasswordField(
                        label: 'Confirm Password',
                        pwdController: _passwordController,
                        validator: (v) {
                          if (v != _passwordController.text) {
                            return 'Passwords do not match';
                          }
                          return Validators.passwordValidator(v as String?);
                        },
                      ),
                      const SizedBox(height: 20),
                      MaterialButton(
                        padding: EdgeInsets.zero,
                        onPressed: () async {
                          final cameras = await availableCameras();
                          if (!context.mounted) return;
                          if (cameras.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('No camera available.')),
                            );
                            return;
                          }
                          final camera =
                              cameras.length > 1 ? cameras[1] : cameras[0];
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => TakePictureScreen(
                                camera: camera,
                                onImageCaptured: (path) {
                                  context.read<SignUpBloc>().add(
                                      SignUpFaceImageCaptured(path));
                                },
                              ),
                            ),
                          );
                        },
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                const Icon(Icons.camera,
                                    color: Colors.white),
                                const SizedBox(width: 8),
                                const Text(
                                  'Register your face here',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ],
                            ),
                            if (_registerClicked && state.imagePath.isEmpty)
                              const Text(
                                'Face not captured',
                                style: TextStyle(color: Colors.red),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      state.isLoading
                          ? const LoadingButton()
                          : CustomButton(
                              height: 50.h,
                              width: double.infinity,
                              ontap: () => _submit(state),
                              label: 'Sign Up',
                            ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Already have an account?',
                            style: TextStyle(
                                fontSize: 15, color: Colors.white),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context)
                                .pushReplacementNamed(LoginPage.routeName),
                            child: const Text(
                              'Sign In',
                              style: TextStyle(
                                  fontSize: 15, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
