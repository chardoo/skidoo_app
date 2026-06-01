import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:skidoo_app/l10n/app_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/common/widgets/selfie_capture_screen.dart';
import 'package:skidoo_app/core/di/service_locator.dart';
import 'package:skidoo_app/core/validators/validators.dart';
import 'package:skidoo_app/features/auth/presentation/bloc/signup/signup_bloc.dart';
import 'package:skidoo_app/core/utils/snackbar_utils.dart';
import 'package:skidoo_app/features/auth/presentation/pages/login_page.dart';
import 'package:skidoo_app/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:skidoo_app/core/utils/web_wrap.dart';

// ── Design tokens ──────────────────────────────────────────────────────────────
const _kOrange      = Color(0xFFFF8303);
const _kOrangeDark  = Color(0xFFE66E00);
const _kBg          = Color(0xFF0A0D11);
const _kBgDeep      = Color(0xFF0F1525);
const _kSubtext     = Color(0xFF9BA3B2);
const _kError       = Color(0xFFFF4757);

class SignUpPage extends StatelessWidget {
  static const routeName = '/signup';
  const SignUpPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<SignUpBloc>(),
      child: const _SignUpView(),
    );
  }
}

class _SignUpView extends StatefulWidget {
  const _SignUpView();

  @override
  State<_SignUpView> createState() => _SignUpViewState();
}

class _SignUpViewState extends State<_SignUpView>
    with SingleTickerProviderStateMixin {
  final _formKey                  = GlobalKey<FormState>();
  final _emailController          = TextEditingController();
  final _usernameController       = TextEditingController();
  final _contactController        = TextEditingController();
  final _passwordController       = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  late final AnimationController _fadeCtrl;
  late final Animation<double>   _fadeAnim;
  bool _submitAttempted = false;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _contactController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _submit(SignUpState state) {
    setState(() => _submitAttempted = true);
    if (_formKey.currentState?.validate() ?? false) {
      if (state.imagePath.isEmpty) return;
      context.read<SignUpBloc>().add(SignUpSubmitted(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
            contact: _contactController.text.trim(),
            userName: _usernameController.text.trim(),
            imagePath: state.imagePath,
          ));
    }
  }

  Future<void> _takeSelfie(BuildContext context) async {
    final xFile = await SelfieCaptureScreen.push(context);
    if (!context.mounted || xFile == null) return;
    context.read<SignUpBloc>().add(SignUpFaceImageCaptured(xFile.path, xFile));
  }

  @override
  Widget build(BuildContext context) {
    final page = Scaffold(
      backgroundColor: _kBg,
      body: BlocConsumer<SignUpBloc, SignUpState>(
        listener: (context, state) {
          if (state.isSuccess) {
            AppSnackBar.success(context, AppLocalizations.of(context)!.signupAccountCreated);
            Navigator.of(context).pushReplacementNamed(LoginPage.routeName);
          }
          if (state.errorMessage != null && !state.isLoading) {
            AppSnackBar.error(context, state.errorMessage!);
          }
        },
        builder: (context, state) {
          return Stack(
            children: [
              // ── Ambient gradient background ──────────────────────────────
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [_kBg, _kBgDeep],
                  ),
                ),
              ),
              // ── Radial orange glow ───────────────────────────────────────
              Positioned(
                top: -120,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    width: 320,
                    height: 320,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          _kOrange.withValues(alpha: 0.15),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // ── Content ──────────────────────────────────────────────────
              SafeArea(
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: SingleChildScrollView(
                        padding: EdgeInsets.symmetric(horizontal: 28.w),
                        child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 48.h),

                          // ── Logo mark ──────────────────────────────────
                          Container(
                            width: 52.w,
                            height: 52.w,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [_kOrange, _kOrangeDark],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(14.r),
                              boxShadow: [
                                BoxShadow(
                                  color: _kOrange.withValues(alpha: 0.35),
                                  blurRadius: 20,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.photo_camera_rounded,
                              color: Colors.white,
                              size: 26.sp,
                            ),
                          ),
                          SizedBox(height: 28.h),

                          // ── Heading ────────────────────────────────────
                          Text(
                            AppLocalizations.of(context)!.signupCreateAccount,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 30.sp,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.5,
                              height: 1.1,
                            ),
                          ),
                          SizedBox(height: 8.h),
                          Text(
                            AppLocalizations.of(context)!.signupSubtitle,
                            style: TextStyle(
                              color: _kSubtext,
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w400,
                              letterSpacing: 0.1,
                            ),
                          ),
                          SizedBox(height: 36.h),

                          // ── Face capture ───────────────────────────────
                          _FaceCaptureButton(
                            imagePath: state.imagePath,
                            showError: _submitAttempted && state.imagePath.isEmpty,
                            onTap: () => _takeSelfie(context),
                          ),
                          SizedBox(height: 24.h),

                          // ── Email ──────────────────────────────────────
                          AuthTextField(
                            controller: _emailController,
                            label: AppLocalizations.of(context)!.signupEmailAddress,
                            prefixIcon: Icons.mail_outline_rounded,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            validator: Validators.emailValidator,
                          ),
                          SizedBox(height: 14.h),

                          // ── Username ───────────────────────────────────
                          AuthTextField(
                            controller: _usernameController,
                            label: AppLocalizations.of(context)!.signupUsername,
                            prefixIcon: Icons.person_outline_rounded,
                            textInputAction: TextInputAction.next,
                            validator: Validators.nameValidator,
                          ),
                          SizedBox(height: 14.h),

                          // ── Contact ────────────────────────────────────
                          AuthTextField(
                            controller: _contactController,
                            label: AppLocalizations.of(context)!.signupPhoneNumber,
                            prefixIcon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.next,
                            validator: Validators.phoneNumberValidator,
                          ),
                          SizedBox(height: 14.h),

                          // ── Password ───────────────────────────────────
                          AuthPasswordField(
                            controller: _passwordController,
                            label: AppLocalizations.of(context)!.signupPassword,
                            textInputAction: TextInputAction.next,
                            validator: Validators.signupPasswordValidator,
                          ),
                          SizedBox(height: 14.h),

                          // ── Confirm password ───────────────────────────
                          AuthPasswordField(
                            controller: _confirmPasswordController,
                            label: AppLocalizations.of(context)!.signupConfirmPassword,
                            textInputAction: TextInputAction.done,
                            validator: (v) {
                              if (v != _passwordController.text) {
                                return AppLocalizations.of(context)!.signupPasswordsDoNotMatch;
                              }
                              return Validators.signupPasswordValidator(v);
                            },
                          ),
                          SizedBox(height: 32.h),

                          // ── Sign up button ─────────────────────────────
                          _GradientButton(
                            label: AppLocalizations.of(context)!.signupCreateAccountButton,
                            isLoading: state.isLoading,
                            onTap: () => _submit(state),
                          ),
                          SizedBox(height: 28.h),

                          // ── Sign in link ───────────────────────────────
                          Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  AppLocalizations.of(context)!.signupAlreadyHaveAccount,
                                  style: TextStyle(
                                    color: _kSubtext,
                                    fontSize: 14.sp,
                                  ),
                                ),
                                Semantics(button: true, child: GestureDetector(
                                  onTap: () => Navigator.of(context)
                                      .pushReplacementNamed(LoginPage.routeName),
                                  child: Text(
                                    AppLocalizations.of(context)!.signupSignIn,
                                    style: TextStyle(
                                      color: _kOrange,
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                )),
                              ],
                            ),
                          ),
                          SizedBox(height: 40.h),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
            ],
          );
        },
      ),
    );
    return webWrap(page, backgroundColor: _kBg);
  }

}

// ── Face capture section ───────────────────────────────────────────────────────
class _FaceCaptureButton extends StatelessWidget {
  const _FaceCaptureButton({
    required this.imagePath,
    required this.showError,
    required this.onTap,
  });

  final String imagePath;
  final bool showError;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final captured = imagePath.isNotEmpty;
    return Semantics(button: true, child: GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 20.h, horizontal: 16.w),
            decoration: BoxDecoration(
              color: const Color(0xFF151821),
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(
                color: showError
                    ? _kError
                    : captured
                        ? _kOrange
                        : const Color(0xFF252836),
                width: captured || showError ? 1.5 : 1,
              ),
              boxShadow: captured
                  ? [
                      BoxShadow(
                        color: _kOrange.withValues(alpha: 0.18),
                        blurRadius: 16,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : [],
            ),
            child: Row(
              children: [
                // Avatar / placeholder
                Container(
                  width: 56.w,
                  height: 56.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF0F1525),
                    border: Border.all(
                      color: captured ? _kOrange : const Color(0xFF3A3F52),
                      width: 2,
                    ),
                    boxShadow: captured
                        ? [
                            BoxShadow(
                              color: _kOrange.withValues(alpha: 0.25),
                              blurRadius: 12,
                            ),
                          ]
                        : [],
                  ),
                  child: captured
                      ? ClipOval(
                          child: kIsWeb
                              ? Image.network(imagePath, fit: BoxFit.cover)
                              : Image.file(File(imagePath), fit: BoxFit.cover),
                        )
                      : Icon(
                          Icons.face_retouching_natural,
                          color: const Color(0xFF9BA3B2),
                          size: 28.sp,
                        ),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        captured ? AppLocalizations.of(context)!.signupFaceCaptured : AppLocalizations.of(context)!.signupRegisterFace,
                        style: TextStyle(
                          color: captured ? Colors.white : const Color(0xFF9BA3B2),
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 3.h),
                      Text(
                        captured
                            ? AppLocalizations.of(context)!.signupTapToRetake
                            : AppLocalizations.of(context)!.signupTapToOpenCamera,
                        style: TextStyle(
                          color: const Color(0xFF4A5568),
                          fontSize: 12.sp,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  captured
                      ? Icons.check_circle_rounded
                      : Icons.chevron_right_rounded,
                  color: captured ? _kOrange : const Color(0xFF4A5568),
                  size: 22.sp,
                ),
              ],
            ),
          ),
          if (showError) ...[
            SizedBox(height: 6.h),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                AppLocalizations.of(context)!.signupFaceRequired,
                style: TextStyle(
                  color: _kError,
                  fontSize: 11.5.sp,
                ),
              ),
            ),
          ],
        ],
      ),
    ));
  }
}

// ── Gradient CTA button ────────────────────────────────────────────────────────
class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.label,
    required this.isLoading,
    required this.onTap,
  });

  final String label;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(button: true, child: GestureDetector(
      onTap: isLoading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 56.h,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isLoading
                ? [_kOrange.withValues(alpha: 0.5), _kOrangeDark.withValues(alpha: 0.5)]
                : [_kOrange, _kOrangeDark],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(14.r),
          boxShadow: isLoading
              ? []
              : [
                  BoxShadow(
                    color: _kOrange.withValues(alpha: 0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: Center(
          child: isLoading
              ? SizedBox(
                  width: 24.w,
                  height: 24.w,
                  child: const CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : Text(
                  label,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
        ),
      ),
    ));
  }
}
