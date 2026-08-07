import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/common/widgets/app_button.dart';
import 'package:jperg_app/core/common/widgets/app_text_field.dart';
import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/validators/validators.dart';
import 'package:jperg_app/features/auth/presentation/bloc/login/login_bloc.dart';
import 'package:jperg_app/features/auth/presentation/pages/email_verification_page.dart';
import 'package:jperg_app/features/auth/presentation/pages/forget_password_page.dart';
import 'package:jperg_app/features/auth/presentation/pages/signup_page.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/common/widgets/jperg_logo.dart';
import 'package:jperg_app/core/common/widgets/app_drag_handle.dart';

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
      listenWhen: (p, c) =>
          p.isSuccess != c.isSuccess ||
          p.needsEmailVerification != c.needsEmailVerification,
      listener: (context, state) {
        if (state.isSuccess) {
          Navigator.of(context).pop();
          widget.onLoginSuccess();
          return;
        }
        if (state.needsEmailVerification) {
          context.read<LoginBloc>().add(const LoginEmailVerificationHandled());
          final email = _emailCtrl.text.trim();
          Navigator.of(context).pop();
          EmailVerificationPage.push(context, email: email);
          return;
        }
        // Other errors are shown inline below (a SnackBar would render
        // behind this modal sheet and never be seen).
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
                  const AppDragHandle(),
                  SizedBox(height: AppSpacing.xxl.h),

                  // ── Logo ────────────────────────────────────────────────
                  Center(child: JpergLogo(height: 30.h)),
                  SizedBox(height: AppSpacing.xl.h),

                  // ── Title ───────────────────────────────────────────────
                  Text(
                    'Welcome back',
                    style: TextStyle(
                      color: ext.greetingColor,
                      fontSize: 22.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: AppSpacing.xs.h),
                  Text(
                    'Log in to view event photos',
                    style: TextStyle(
                      color: ext.searchHintColor,
                      fontSize: 13.sp,
                    ),
                  ),
                  SizedBox(height: AppSpacing.xl.h),

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
                        margin: EdgeInsets.only(bottom: AppSpacing.lg.h),
                        padding: EdgeInsets.symmetric(
                            horizontal: 14.w, vertical: 10.h),
                        decoration: BoxDecoration(
                          color: ext.errorRed.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10.r),
                          border: Border.all(
                              color: ext.errorRed
                                  .withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline_rounded,
                                color: ext.errorRed, size: 18.sp),
                            SizedBox(width: AppSpacing.sm.w),
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
                  AppTextField(
                    controller: _emailCtrl,
                    validator: (v) => Validators.emailValidator(v),
                    label: 'Email',
                  ),
                  SizedBox(height: AppSpacing.lg.h),
                  AppPasswordField(
                    label: 'Password',
                    validator: (v) => Validators.passwordValidator(v),
                    controller: _passwordCtrl,
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
                  SizedBox(height: AppSpacing.md.h),

                  // ── Login button ────────────────────────────────────────
                  BlocBuilder<LoginBloc, LoginState>(
                    builder: (context, state) {
                      return AppButton(
                        fullWidth: true,
                        isLoading: state.isLoading,
                        onPressed: _filled ? _submit : null,
                        label: 'Log in',
                      );
                    },
                  ),
                  SizedBox(height: AppSpacing.xl.h),

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
