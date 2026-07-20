import 'dart:io' show File;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:skidoo_app/core/common/widgets/app_button.dart';
import 'package:skidoo_app/core/di/service_locator.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/core/utils/snackbar_utils.dart';
import 'package:skidoo_app/core/utils/web_wrap.dart';
import 'package:skidoo_app/features/photographers/domain/usecases/photographer_profile_usecases.dart';
import 'package:skidoo_app/services/auth_service.dart';
import 'package:skidoo_app/core/theme/app_radius.dart';
import 'package:skidoo_app/core/theme/app_spacing.dart';

/// "Verify and accept terms" — part of a photographer's portfolio setup,
/// done on demand from the Account page (see `portfolio_edit_page.dart`),
/// not automatically during onboarding. Ghana Card ID as a photo (not a
/// PDF/file picker — `file_picker` isn't a dependency yet, scoped down
/// deliberately) plus three acceptance checkboxes. **Assumed**
/// `POST /photographer/verification` endpoint — no backend contract exists
/// for this yet (see `PhotographerRepository.submitVerification`).
class VerifyTermsPage extends StatefulWidget {
  const VerifyTermsPage({super.key});

  @override
  State<VerifyTermsPage> createState() => _VerifyTermsPageState();
}

class _VerifyTermsPageState extends State<VerifyTermsPage> {
  XFile? _idDocument;
  bool _acceptedTerms = false;
  bool _confirmedUploadRights = false;
  bool _acceptedPayoutPolicy = false;
  bool _submitting = false;

  bool get _canContinue =>
      _idDocument != null &&
      _acceptedTerms &&
      _confirmedUploadRights &&
      _acceptedPayoutPolicy;

  Future<void> _pickDocument() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (picked == null) return;
    setState(() => _idDocument = picked);
  }

  Future<void> _submit() async {
    if (!_canContinue || _submitting) return;
    setState(() => _submitting = true);
    try {
      final userId = await sl<AuthService>().getUserId();
      await sl<SubmitVerificationUseCase>().call(
        photographerId: userId,
        idDocument: _idDocument!,
        acceptedTerms: _acceptedTerms,
        confirmedUploadRights: _confirmedUploadRights,
        acceptedPayoutPolicy: _acceptedPayoutPolicy,
      );
      if (!mounted) return;
      AppSnackBar.success(context, 'Verification submitted.');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) AppSnackBar.error(context, 'Could not submit verification: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final page = Scaffold(
      backgroundColor: ext.homeBackground,
      appBar: AppBar(
        backgroundColor: ext.homeBackground,
        elevation: 0,
        leading: kIsWeb
            ? null
            : IconButton(
                tooltip: 'Back',
                icon: Icon(Icons.arrow_back_ios_rounded,
                    color: ext.greetingColor, size: 18.sp),
                onPressed: () => Navigator.of(context).pop(),
              ),
        title: Text(
          'Verify and accept terms',
          style: TextStyle(
              color: ext.greetingColor, fontSize: 17.sp, fontWeight: FontWeight.w700),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(AppSpacing.xl.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'One last step before you start uploading events',
                style: TextStyle(color: ext.searchHintColor, fontSize: 13.sp),
              ),
              SizedBox(height: AppSpacing.xl.h),
              Semantics(
                button: true,
                label: _idDocument != null ? 'Change Ghana Card photo' : 'Upload Ghana Card photo',
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.md.r),
                  onTap: _pickDocument,
                  child: Container(
                    padding: EdgeInsets.all(14.w),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.md.r),
                      border: Border.all(color: ext.searchHintColor.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36.w,
                          height: 36.w,
                          decoration: BoxDecoration(
                            color: ext.accentGold.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(AppRadius.sm.r),
                          ),
                          child: Icon(Icons.badge_outlined, color: ext.accentGold, size: 20.sp),
                        ),
                        SizedBox(width: AppSpacing.md.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _idDocument != null ? 'Ghana Card selected' : 'Upload Ghana Card',
                                style: TextStyle(
                                    color: ext.greetingColor,
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w600),
                              ),
                              SizedBox(height: 2.h),
                              Text(
                                'Required to accept payouts',
                                style: TextStyle(color: ext.searchHintColor, fontSize: 12.sp),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          _idDocument != null ? 'Change' : 'Upload',
                          style: TextStyle(
                              color: ext.accentGold, fontSize: 13.sp, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (_idDocument != null) ...[
                SizedBox(height: 10.h),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10.r),
                  child: kIsWeb
                      ? Image.network(_idDocument!.path, height: 120.h, fit: BoxFit.cover)
                      : Image.file(File(_idDocument!.path), height: 120.h, fit: BoxFit.cover),
                ),
              ],
              SizedBox(height: AppSpacing.xxl.h),
              Divider(color: ext.searchHintColor.withValues(alpha: 0.2)),
              SizedBox(height: AppSpacing.md.h),
              _TermsCheckbox(
                ext: ext,
                value: _acceptedTerms,
                onChanged: (v) => setState(() => _acceptedTerms = v),
                label: 'I agree to the Photographer Terms of Service, including '
                    'image licensing and content standards.',
              ),
              _TermsCheckbox(
                ext: ext,
                value: _confirmedUploadRights,
                onChanged: (v) => setState(() => _confirmedUploadRights = v),
                label: 'I confirm I have the right to upload and distribute all '
                    'photos I post',
              ),
              _TermsCheckbox(
                ext: ext,
                value: _acceptedPayoutPolicy,
                onChanged: (v) => setState(() => _acceptedPayoutPolicy = v),
                label: "I agree to Jperg's Payout Policy",
              ),
              SizedBox(height: AppSpacing.xxl.h),
              AppButton(
                fullWidth: true,
                isLoading: _submitting,
                onPressed: _canContinue ? _submit : null,
                label: 'Submit',
              ),
              SizedBox(height: AppSpacing.md.h),
            ],
          ),
        ),
      ),
    );
    return webWrap(page, backgroundColor: ext.homeBackground);
  }
}

class _TermsCheckbox extends StatelessWidget {
  const _TermsCheckbox({
    required this.ext,
    required this.value,
    required this.onChanged,
    required this.label,
  });

  final AppThemeExtension ext;
  final bool value;
  final ValueChanged<bool> onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10.r),
      onTap: () => onChanged(!value),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.sm.h),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 22.w,
              height: 22.w,
              child: Checkbox(
                value: value,
                activeColor: ext.accentGold,
                onChanged: (v) => onChanged(v ?? false),
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(top: AppSpacing.xs.h),
                child: Text(
                  label,
                  style: TextStyle(color: ext.greetingColor, fontSize: 13.sp, height: 1.4),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
