import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/common/widgets/app_button.dart';
import 'package:jperg_app/core/common/widgets/app_inline_banner.dart';
import 'package:jperg_app/core/common/widgets/app_text_field.dart';
import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/core/error/exceptions.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/utils/snackbar_utils.dart';
import 'package:jperg_app/core/utils/web_wrap.dart';
import 'package:jperg_app/core/validators/validators.dart';
import 'package:jperg_app/features/auth/domain/usecases/reset_password_usecase.dart';
import 'package:jperg_app/features/auth/presentation/pages/login_page.dart';

/// Step 3 of password reset — "Set a new password" (see
/// mobile/docs/FRONTEND_RESET_PASSWORD.md). On success the code is consumed
/// server-side (one-time use), so the user logs in fresh with the new
/// password rather than being signed in automatically here.
class SetNewPasswordPage extends StatefulWidget {
  const SetNewPasswordPage({super.key, required this.email, required this.code});

  final String email;
  final String code;

  @override
  State<SetNewPasswordPage> createState() => _SetNewPasswordPageState();
}

class _SetNewPasswordPageState extends State<SetNewPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String? _confirmValidator(String? value) {
    if (value == null || value.isEmpty) return '*Please confirm your password';
    if (value != _passwordController.text) return '*Passwords do not match';
    return null;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false) || _isLoading) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await sl<ResetPasswordUseCase>().call(ResetPasswordParams(
        email: widget.email,
        code: widget.code,
        password: _passwordController.text,
      ));
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(
        LoginPage.routeName,
        (route) => false,
      );
      AppSnackBar.success(context, 'Your password has been reset. Please sign in.');
    } on NetworkException catch (e) {
      setState(() => _error = e.message);
    } on ServerException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Could not reset your password. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final page = Scaffold(
      backgroundColor: ext.homeBackground,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 28.w),
              child: Form(
                // Same reasoning as sign-up: the rules are strict, so show
                // which one is unmet while the user is still typing.
                autovalidateMode: AutovalidateMode.onUserInteraction,
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 48.h),
                    Text(
                      'Set a new password',
                      style: TextStyle(
                        color: ext.greetingColor,
                        fontSize: 26.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: AppSpacing.sm.h),
                    Text(
                      'Choose a strong new password for ${widget.email}',
                      style: TextStyle(color: ext.searchHintColor, fontSize: 14.sp),
                    ),
                    SizedBox(height: AppSpacing.xxxl.h),
                    AppPasswordField(
                      controller: _passwordController,
                      label: 'New Password',
                      validator: Validators.signupPasswordValidator,
                      textInputAction: TextInputAction.next,
                    ),
                    SizedBox(height: AppSpacing.lg.h),
                    AppPasswordField(
                      controller: _confirmController,
                      label: 'Confirm New Password',
                      validator: _confirmValidator,
                      textInputAction: TextInputAction.done,
                    ),
                    if (_error != null) ...[
                      SizedBox(height: AppSpacing.lg.h),
                      // The server rejects a reset back onto the current
                      // password, and that rejection is the whole reason this
                      // submit failed — a 12.5-px line of red under the fields
                      // is not enough to carry it.
                      AppInlineBanner(
                        message: _error!,
                        onDismiss: () => setState(() => _error = null),
                      ),
                    ],
                    SizedBox(height: AppSpacing.xxl.h),
                    AppButton(
                      fullWidth: true,
                      isLoading: _isLoading,
                      label: 'Reset password',
                      onPressed: _submit,
                    ),
                    SizedBox(height: AppSpacing.huge.h),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return webWrap(page, backgroundColor: ext.homeBackground);
  }
}
