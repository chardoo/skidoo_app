import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/theme/app_typography.dart';
import 'package:jperg_app/core/utils/snackbar_utils.dart';
import 'package:jperg_app/features/verification/presentation/verification_form.dart';
import 'package:jperg_app/features/photographers/presentation/pages/creator_ready_page.dart';
import 'package:jperg_app/features/photographers/presentation/widgets/creator_steps.dart';
import 'package:jperg_app/services/auth_service.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/common/widgets/app_back_button.dart';

/// "Verify and accept terms" — part of a photographer's portfolio setup,
/// done on demand from the Account page (see `portfolio_edit_page.dart`),
/// not automatically during onboarding. Ghana Card ID as a photo (not a
class VerifyTermsPage extends StatefulWidget {
  const VerifyTermsPage({super.key, this.isCreatorSetup = false});

  /// True when this is step two of becoming a creator. It adds the wizard
  /// chrome, and sends them to [CreatorReadyPage] afterwards rather than
  /// popping back to the account page with a snackbar.
  final bool isCreatorSetup;

  @override
  State<VerifyTermsPage> createState() => _VerifyTermsPageState();
}

class _VerifyTermsPageState extends State<VerifyTermsPage> {

  bool _acceptedTerms = false;
  bool _confirmedUploadRights = false;
  bool _acceptedPayoutPolicy = false;

  bool get _canContinue =>
      _acceptedTerms &&
      _confirmedUploadRights &&
      _acceptedPayoutPolicy;

  /// The wizard's own step-two behaviour, run once the form's submission was
  /// accepted. The details themselves are [VerificationForm]'s business — this
  /// is only what happens afterwards.
  Future<void> _afterSubmitted() async {
    if (!mounted) return;

    if (!widget.isCreatorSetup) {
      AppSnackBar.success(context, 'Verification submitted.');
      Navigator.of(context).pop(true);
      return;
    }

    // The role moved server-side when this was accepted, so the session's copy
    // is now stale. Setting it here is what tells the app: every screen that
    // shows or hides on role watches [AuthService.role], so the creator tools
    // appear on the screens already built underneath this wizard rather than
    // at the next sign-in — which is what the old "sign in again to see your
    // tools" message was apologising for.
    await sl<AuthService>().setRole('photographer');

    final name = await sl<AuthService>().getName();
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => CreatorReadyPage(
          name: CreatorReadyPage.firstNameOf(name),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final page = Scaffold(
      backgroundColor: ext.homeBackground,
      appBar: AppBar(
        backgroundColor: ext.homeBackground,
        elevation: 0,
        leading: const AppBackButton(),
        title: Text(
          widget.isCreatorSetup
              ? 'Become a Creator'
              : 'Verify and accept terms',
          style: TextStyle(
              color: ext.greetingColor,
              fontFamily: AppTypography.displayFontFamily,
              fontSize: 16.sp,
              fontWeight: FontWeight.w700),
        ),
        centerTitle: widget.isCreatorSetup,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(AppSpacing.xl.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.isCreatorSetup) ...[
                const Center(child: CreatorSteps(current: 1)),
                SizedBox(height: AppSpacing.lg.h),
                Text(
                  'Verify and accept terms',
                  style: TextStyle(
                    color: ext.greetingColor,
                    fontFamily: AppTypography.displayFontFamily,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: AppSpacing.xs.h),
              ],
              Text(
                'One last step before you start uploading events',
                style: TextStyle(color: ext.searchHintColor, fontSize: 14.sp),
              ),
              SizedBox(height: AppSpacing.xl.h),
              // Details, never a photograph of the card. Ghana's NIA and
              // Data Protection Commission both treat storing an image of a
              // Ghana Card as something a private company may not casually
              // ask for — and the image is the part of this that would have
              // to be secured and eventually deleted.
              //
              // The same form Account & Security shows, because it collects
              // exactly the same thing and a second copy is a second thing to
              // keep in step. The three agreements below are this step's own,
              // so they ride along as its `extra` rather than living in it.
              VerificationForm(
                submitLabel: 'Submit',
                canSubmit: _canContinue,
                agreements: (
                  terms: _acceptedTerms,
                  uploadRights: _confirmedUploadRights,
                  payoutPolicy: _acceptedPayoutPolicy,
                ),
                onSubmitted: _afterSubmitted,
                extra: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Divider(color: ext.searchHintColor.withValues(alpha: 0.2)),
                    SizedBox(height: AppSpacing.md.h),
                    _TermsCheckbox(
                      ext: ext,
                      value: _acceptedTerms,
                      onChanged: (v) => setState(() => _acceptedTerms = v),
                      label:
                          'I agree to the Photographer Terms of Service, '
                          'including image licensing and content standards.',
                    ),
                    _TermsCheckbox(
                      ext: ext,
                      value: _confirmedUploadRights,
                      onChanged: (v) =>
                          setState(() => _confirmedUploadRights = v),
                      label:
                          'I confirm I have the right to upload and distribute '
                          'all photos I post',
                    ),
                    _TermsCheckbox(
                      ext: ext,
                      value: _acceptedPayoutPolicy,
                      onChanged: (v) =>
                          setState(() => _acceptedPayoutPolicy = v),
                      label: "I agree to JPerg's Payout Policy",
                    ),
                  ],
                ),
              ),
              SizedBox(height: AppSpacing.md.h),
            ],
          ),
        ),
      ),
    );
    return page;
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
                  style: TextStyle(
                      color: ext.greetingColor, fontSize: 14.sp, height: 1.4),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
