import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/common/widgets/app_button.dart';
import 'package:skidoo_app/core/common/widgets/app_text_field.dart';
import 'package:skidoo_app/core/di/service_locator.dart';
import 'package:skidoo_app/core/error/exceptions.dart';
import 'package:skidoo_app/core/theme/app_spacing.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/core/utils/web_wrap.dart';
import 'package:skidoo_app/core/validators/validators.dart';
import 'package:skidoo_app/features/auth/domain/usecases/request_password_reset_usecase.dart';
import 'package:skidoo_app/features/auth/presentation/pages/verify_reset_code_page.dart';

/// Step 1 of password reset — "Reset your password" (see
/// mobile/docs/FRONTEND_RESET_PASSWORD.md). Sends a 6-digit code to the
/// entered email; [VerifyResetCodePage] handles the rest of the flow.
class ForgetPasswordPage extends StatefulWidget {
  static const routeName = '/forgotPassword';
  const ForgetPasswordPage({super.key});

  @override
  State<ForgetPasswordPage> createState() => _ForgetPasswordPageState();
}

class _ForgetPasswordPageState extends State<ForgetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false) || _isLoading) return;
    final email = _emailController.text.trim();
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await sl<RequestPasswordResetUseCase>().call(email);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => VerifyResetCodePage(email: email),
        ),
      );
    } on NetworkException catch (e) {
      setState(() => _error = e.message);
    } on ServerException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Could not send a reset code. Please try again.');
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
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: kIsWeb ? 48.h : 12.h),
                    if (!kIsWeb)
                      IconButton(
                        padding: EdgeInsets.zero,
                        alignment: Alignment.centerLeft,
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(Icons.arrow_back_ios_new_rounded,
                            color: ext.greetingColor, size: 20.sp),
                      ),
                    SizedBox(height: AppSpacing.lg.h),
                    Text(
                      'Reset your password',
                      style: TextStyle(
                        color: ext.greetingColor,
                        fontSize: 26.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: AppSpacing.sm.h),
                    Text(
                      "Enter your account email and we'll send a code to reset it",
                      style: TextStyle(color: ext.searchHintColor, fontSize: 14.sp),
                    ),
                    SizedBox(height: AppSpacing.xxxl.h),
                    AppTextField(
                      controller: _emailController,
                      validator: Validators.emailValidator,
                      label: 'Email',
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    if (_error != null) ...[
                      SizedBox(height: 14.h),
                      Text(_error!,
                          style: TextStyle(color: ext.errorRed, fontSize: 12.5.sp)),
                    ],
                    SizedBox(height: AppSpacing.xxl.h),
                    AppButton(
                      fullWidth: true,
                      isLoading: _isLoading,
                      label: 'Send code',
                      onPressed: _submit,
                    ),
                    SizedBox(height: AppSpacing.xl.h),
                    Center(
                      child: Semantics(
                        button: true,
                        label: 'Back to sign in',
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(
                            'Back to sign in',
                            style: TextStyle(
                              color: ext.searchHintColor,
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
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
