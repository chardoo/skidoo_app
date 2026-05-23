import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/l10n/app_localizations.dart';
import 'package:skidoo_app/core/utils/snackbar_utils.dart';
import 'package:skidoo_app/core/common/customButtom.dart';
import 'package:skidoo_app/core/common/textfield.dart';
import 'package:skidoo_app/core/validators/validators.dart';

class ForgetPasswordPage extends StatefulWidget {
  static const routeName = '/forgotPassword';
  const ForgetPasswordPage({super.key});

  @override
  State<ForgetPasswordPage> createState() => _ForgetPasswordPageState();
}

class _ForgetPasswordPageState extends State<ForgetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.forgotPasswordTitle),
        leading: BackButton(
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.all(24.w),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                AppLocalizations.of(context)!.forgotPasswordResetTitle,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold, fontSize: 24.sp),
              ),
              SizedBox(height: 8.h),
              Text(
                AppLocalizations.of(context)!.forgotPasswordSubtitle,
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: Colors.grey),
              ),
              SizedBox(height: 30.h),
              MyTextField(
                controller: _emailController,
                validator: Validators.emailValidator,
                label: AppLocalizations.of(context)!.forgotPasswordEmail,
              ),
              SizedBox(height: 30.h),
              CustomButton(
                height: 50.h,
                width: double.infinity,
                ontap: () {
                  if (_formKey.currentState?.validate() ?? false) {
                    AppSnackBar.success(context, AppLocalizations.of(context)!.forgotPasswordLinkSent);
                  }
                },
                label: AppLocalizations.of(context)!.forgotPasswordSendLink,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
