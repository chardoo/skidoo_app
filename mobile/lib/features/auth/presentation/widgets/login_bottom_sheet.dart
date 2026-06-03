import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/common/password_textfield.dart';
import 'package:skidoo_app/core/common/textfield.dart';
import 'package:skidoo_app/core/di/service_locator.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/core/validators/validators.dart';
import 'package:skidoo_app/features/auth/presentation/bloc/login/login_bloc.dart';
import 'package:skidoo_app/features/auth/presentation/pages/forget_password_page.dart';
import 'package:skidoo_app/features/auth/presentation/pages/signup_page.dart';
import 'package:skidoo_app/widgets/loader.dart';

/// Shows the login bottom sheet. [onLoginSuccess] is called after successful
/// login so the caller can navigate appropriately.
Future<void> showLoginSheet(
  BuildContext context, {
  required VoidCallback onLoginSuccess,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => LoginBottomSheet(onLoginSuccess: onLoginSuccess),
  );
}

class LoginBottomSheet extends StatelessWidget {
  const LoginBottomSheet({super.key, required this.onLoginSuccess});
  final VoidCallback onLoginSuccess;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<LoginBloc>(),
      child: _LoginSheetContent(onLoginSuccess: onLoginSuccess),
    );
  }
}

class _LoginSheetContent extends StatefulWidget {
  const _LoginSheetContent({required this.onLoginSuccess});
  final VoidCallback onLoginSuccess;

  @override
  State<_LoginSheetContent> createState() => _LoginSheetContentState();
}

class _LoginSheetContentState extends State<_LoginSheetContent> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _emailCtrl.addListener(_onChanged);
    _passwordCtrl.addListener(_onChanged);
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  bool get _filled =>
      _emailCtrl.text.trim().isNotEmpty && _passwordCtrl.text.isNotEmpty;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      context.read<LoginBloc>().add(LoginSubmitted(
            email: _emailCtrl.text.trim(),
            password: _passwordCtrl.text.trim(),
          ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return BlocListener<LoginBloc, LoginState>(
      listenWhen: (p, c) => p.isSuccess != c.isSuccess,
      listener: (context, state) {
        if (state.isSuccess) {
          Navigator.of(context).pop();
          widget.onLoginSuccess();
        }
        // Errors are shown inline below (a SnackBar would render behind this
        // modal sheet and never be seen).
      },
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.only(bottom: bottom),
        child: Container(
          decoration: BoxDecoration(
            color: ext.homeBackground,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(24.w, 12.h, 24.w, 32.h),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Drag handle ─────────────────────────────────────────
                  Center(
                    child: Container(
                      width: 40.w,
                      height: 4.h,
                      decoration: BoxDecoration(
                        color: ext.searchHintColor,
                        borderRadius: BorderRadius.circular(2.r),
                      ),
                    ),
                  ),
                  SizedBox(height: 24.h),

                  // ── Logo ────────────────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 28.w,
                        height: 28.h,
                        decoration: BoxDecoration(
                          color: ext.logoBadgeBackground,
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'S',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16.sp,
                          ),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        'SKIDDO',
                        style: TextStyle(
                          color: ext.logoTextColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 18.sp,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20.h),

                  // ── Title ───────────────────────────────────────────────
                  Text(
                    'Welcome back',
                    style: TextStyle(
                      color: ext.greetingColor,
                      fontSize: 22.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'Log in to view event photos',
                    style: TextStyle(
                      color: ext.searchHintColor,
                      fontSize: 13.sp,
                    ),
                  ),
                  SizedBox(height: 20.h),

                  // ── Inline error (shown here so it isn't hidden behind the
                  //    bottom sheet like a SnackBar would be) ────────────────
                  BlocBuilder<LoginBloc, LoginState>(
                    buildWhen: (p, c) => p.errorMessage != c.errorMessage,
                    builder: (context, state) {
                      if (state.errorMessage == null) {
                        return const SizedBox.shrink();
                      }
                      return Container(
                        width: double.infinity,
                        margin: EdgeInsets.only(bottom: 16.h),
                        padding: EdgeInsets.symmetric(
                            horizontal: 14.w, vertical: 10.h),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF4757).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10.r),
                          border: Border.all(
                              color: const Color(0xFFFF4757)
                                  .withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline_rounded,
                                color: const Color(0xFFFF4757), size: 18.sp),
                            SizedBox(width: 8.w),
                            Expanded(
                              child: Text(
                                state.errorMessage!,
                                style: TextStyle(
                                    color: const Color(0xFFFF6B7A),
                                    fontSize: 13.sp),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  // ── Fields ──────────────────────────────────────────────
                  MyTextField(
                    controller: _emailCtrl,
                    validator: (v) => Validators.emailValidator(v),
                    label: 'Email',
                  ),
                  SizedBox(height: 16.h),
                  PasswordField(
                    label: 'Password',
                    validator: (v) =>
                        Validators.passwordValidator(v as String?),
                    pwdController: _passwordCtrl,
                  ),

                  // ── Forgot password ─────────────────────────────────────
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const ForgetPasswordPage()),
                        );
                      },
                      child: Text(
                        'Forgot Password?',
                        style:
                            TextStyle(color: ext.accentGold, fontSize: 13.sp),
                      ),
                    ),
                  ),
                  SizedBox(height: 12.h),

                  // ── Login button ────────────────────────────────────────
                  BlocBuilder<LoginBloc, LoginState>(
                    builder: (context, state) {
                      return SizedBox(
                        width: double.infinity,
                        height: 50.h,
                        child: state.isLoading
                            ? const LoadingButton()
                            : FilledButton(
                                onPressed: _filled ? _submit : null,
                                style: FilledButton.styleFrom(
                                  backgroundColor: ext.accentGold,
                                  disabledBackgroundColor:
                                      ext.accentGold.withValues(alpha: 0.4),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12.r),
                                  ),
                                ),
                                child: Text(
                                  'Log in',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                      );
                    },
                  ),
                  SizedBox(height: 20.h),

                  // ── Sign up link ─────────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Don't have an account?",
                        style: TextStyle(
                            color: ext.searchHintColor, fontSize: 13.sp),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).pushNamed(
                            SignUpPage.routeName,
                          );
                        },
                        child: Text(
                          'Sign up',
                          style: TextStyle(
                              color: ext.accentGold,
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
