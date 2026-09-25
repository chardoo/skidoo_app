import 'package:dio/dio.dart' as dio;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/api/dio_client_service.dart';
import 'package:jperg_app/core/common/widgets/app_widgets.dart';
import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/theme/app_typography.dart';
import 'package:jperg_app/core/validators/validators.dart';

/// Current password, new password, done — the shape the endpoint asks for.
///
/// A page rather than the [AlertDialog] this used to be. Three password fields
/// behind a keyboard is not dialog-shaped work: the keyboard covers most of a
/// phone, and a dialog gets what is left, so the fields, the error and the Save
/// button were competing for a few hundred pixels. It also wore bare Material —
/// default [TextField]s, a Material title, plain text buttons — which is the
/// only screen in the app that did, because a dialog does not inherit the
/// page-level styling everything else is built from.
///
/// It is also the sibling of [SetNewPasswordPage], which does the same job at
/// the end of a password reset and has always been a page. The two are now
/// built the same way, down to the validators.
///
/// Pops `true` when the password was changed, so the caller can say so.
class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();

  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  /// Deliberately the loose rule, not [Validators.signupPasswordValidator].
  ///
  /// The strict rule is about what a password may *become*. Applied to the
  /// current one it would lock out every account whose password predates that
  /// rule — they would be told their own working password is invalid, on the
  /// one screen that exists to let them replace it.
  String? _currentValidator(String? value) =>
      (value == null || value.isEmpty) ? '*Enter your current password' : null;

  String? _nextValidator(String? value) {
    final strength = Validators.signupPasswordValidator(value);
    if (strength != null) return strength;
    // Caught here rather than at the server, which rejects this with a message
    // about the new password being invalid — true, but not the reason.
    if (value == _current.text) return '*This is already your password';
    return null;
  }

  String? _confirmValidator(String? value) {
    if (value == null || value.isEmpty) return '*Please confirm your password';
    if (value != _next.text) return '*Passwords do not match';
    return null;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false) || _busy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await sl<Api>().dio.patch('/client/account/password', data: {
        'current_password': _current.text,
        'new_password': _next.text,
      });
      if (mounted) Navigator.of(context).pop(true);
    } on dio.DioException catch (err) {
      // The server says which of the two it objected to — the current password
      // being wrong reads very differently from the new one being too weak.
      final message = err.response?.data?['error']?['message'];
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error =
            message is String ? message : 'Could not change your password.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    final page = Scaffold(
      backgroundColor: ext.homeBackground,
      appBar: AppBar(
        backgroundColor: ext.homeBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: const AppBackButton(),
        title: Text(
          'Change Password',
          style: TextStyle(
            color: ext.greetingColor,
            fontFamily: AppTypography.displayFontFamily,
            fontSize: 16.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 28.w),
              child: Form(
                // Same reasoning as sign-up and the reset flow: the rules are
                // strict, so show which one is unmet while the user is still
                // typing rather than after they submit.
                autovalidateMode: AutovalidateMode.onUserInteraction,
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: AppSpacing.xl.h),
                    Text(
                      'Your password is how you get back in. Choose one you '
                      'have not used anywhere else.',
                      style: TextStyle(
                        color: ext.searchHintColor,
                        fontSize: 14.sp,
                        height: 1.4,
                      ),
                    ),
                    SizedBox(height: AppSpacing.xxl.h),
                    AppPasswordField(
                      controller: _current,
                      label: 'Current Password',
                      validator: _currentValidator,
                      textInputAction: TextInputAction.next,
                    ),
                    SizedBox(height: AppSpacing.lg.h),
                    AppPasswordField(
                      controller: _next,
                      label: 'New Password',
                      validator: _nextValidator,
                      textInputAction: TextInputAction.next,
                    ),
                    SizedBox(height: AppSpacing.lg.h),
                    // Not in the dialog, and the room to add it is half the
                    // point of the page: a typo in a password you cannot see,
                    // on the screen that replaces the one you know, is how
                    // somebody locks themselves out of their own account.
                    AppPasswordField(
                      controller: _confirm,
                      label: 'Confirm New Password',
                      validator: _confirmValidator,
                      textInputAction: TextInputAction.done,
                    ),
                    if (_error != null) ...[
                      SizedBox(height: AppSpacing.lg.h),
                      // The server's own words, and usually the whole reason
                      // the submit failed — "current password is incorrect" is
                      // not something to say in 12 px of red under a field.
                      AppInlineBanner(
                        message: _error!,
                        onDismiss: () => setState(() => _error = null),
                      ),
                    ],
                    SizedBox(height: AppSpacing.xxl.h),
                    AppButton(
                      fullWidth: true,
                      isLoading: _busy,
                      label: 'Update password',
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

    return page;
  }
}
