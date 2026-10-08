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
import 'package:jperg_app/core/config/legal_links.dart';
import 'package:jperg_app/features/photographers/presentation/pages/creator_setup_entry.dart';
import 'package:jperg_app/features/auth/presentation/widgets/onboarding_step_scaffold.dart';
import 'package:jperg_app/features/auth/presentation/pages/onboarding_complete_page.dart';

/// "Verify and accept terms" — the last step of becoming a photographer.
///
/// The ID details and the three agreements, reached from the portfolio screen
/// before it (see `portfolio_edit_page.dart`). [CreatorSetupEntry] decides the
/// chrome and the ending: the signup wizard's four dots finishing on the
/// shared completion screen, the two-step row finishing on [CreatorReadyPage],
/// or no wizard at all and a pop with a snackbar.
///
/// This is also where the role actually moves. The server promotes the account
/// when it accepts this submission, and not before, so anybody who abandons
/// the wizard at the portfolio stays an ordinary user.
class VerifyTermsPage extends StatefulWidget {
  const VerifyTermsPage({
    super.key,
    this.entry = CreatorSetupEntry.editing,
  });

  /// Why this screen is open — see [CreatorSetupEntry].
  final CreatorSetupEntry entry;

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

    if (!widget.entry.isSetup) {
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
    if (!mounted) return;

    // Coming through signup, this is the last of four steps and ends where
    // every other branch ends — the face capture at step 1 was the same for
    // creators, so "we're scanning photos for your face" is as true here as
    // it is for somebody who came to find themselves.
    if (widget.entry.isOnboarding) {
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const OnboardingCompletePage()),
      );
      return;
    }

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

  /// The ID form and the three agreements — identical on every entry.
  Widget _body(AppThemeExtension ext) => VerificationForm(
        submitLabel: widget.entry.isSetup ? 'Continue' : 'Submit',
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
            // The documents are linked from inside the sentences that ask
            // somebody to agree to them, which is the only place a link to
            // them is any use. These three boxes shipped for months with no
            // way at all to read what was being agreed to.
            _TermsCheckbox(
              ext: ext,
              value: _acceptedTerms,
              onChanged: (v) => setState(() => _acceptedTerms = v),
              children: [
                const TextSpan(text: 'I agree to the '),
                _link(ext, 'Photographer Terms of Service',
                    LegalLinks.openTerms),
                const TextSpan(
                  text: ', including image licensing and content standards.',
                ),
              ],
            ),
            _TermsCheckbox(
              ext: ext,
              value: _confirmedUploadRights,
              onChanged: (v) => setState(() => _confirmedUploadRights = v),
              children: const [
                TextSpan(
                  text: 'I confirm I have the right to upload and distribute '
                      'all photos I post',
                ),
              ],
            ),
            _TermsCheckbox(
              ext: ext,
              value: _acceptedPayoutPolicy,
              onChanged: (v) => setState(() => _acceptedPayoutPolicy = v),
              children: [
                const TextSpan(text: "I agree to jperg's "),
                // There is no separate payout document to link: the payout
                // policy is section 6.3 of the Terms. Pointing at a URL that
                // does not exist would be worse than pointing at the section
                // that does.
                _link(ext, 'Payout Policy', LegalLinks.openTerms),
              ],
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    // Step 4 of 4 — the last screen of signup, so it wears the wizard's
    // chrome rather than an app bar.
    if (widget.entry.isOnboarding) {
      return OnboardingStepScaffold(
        currentStep: 4,
        totalSteps: 4,
        title: 'Verify and accept terms',
        subtitle: 'One last step before you start uploading events',
        child: _body(ext),
      );
    }

    final page = Scaffold(
      backgroundColor: ext.homeBackground,
      appBar: AppBar(
        backgroundColor: ext.homeBackground,
        elevation: 0,
        leading: const AppBackButton(),
        title: Text(
          widget.entry.isSetup
              ? 'Become a Creator'
              : 'Verify and accept terms',
          style: TextStyle(
              color: ext.greetingColor,
              fontFamily: AppTypography.displayFontFamily,
              fontSize: 16.sp,
              fontWeight: FontWeight.w700),
        ),
        centerTitle: widget.entry.isSetup,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(AppSpacing.xl.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.entry.isSetup) ...[
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
              _body(ext),
              SizedBox(height: AppSpacing.md.h),
            ],
          ),
        ),
      ),
    );
    return page;
  }
}

/// One document, linked from inside the sentence that agrees to it.
///
/// A [WidgetSpan] rather than a [TapGestureRecognizer] on a [TextSpan]:
/// recognizers have to be disposed by whoever built them, and these are built
/// in `build`. The gesture detector also wins the tap against the row's own
/// InkWell, which is what lets the link open the document while the rest of
/// the line still toggles the box.
InlineSpan _link(
  AppThemeExtension ext,
  String label,
  Future<void> Function(BuildContext) open,
) =>
    WidgetSpan(
      alignment: PlaceholderAlignment.baseline,
      baseline: TextBaseline.alphabetic,
      child: Builder(
        builder: (context) => Semantics(
          button: true,
          label: label,
          child: GestureDetector(
            onTap: () => open(context),
            child: Text(
              label,
              style: TextStyle(
                color: ext.accentGold,
                fontSize: 14.sp,
                height: 1.4,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.underline,
                decorationColor: ext.accentGold,
              ),
            ),
          ),
        ),
      ),
    );

class _TermsCheckbox extends StatelessWidget {
  const _TermsCheckbox({
    required this.ext,
    required this.value,
    required this.onChanged,
    required this.children,
  });

  final AppThemeExtension ext;
  final bool value;
  final ValueChanged<bool> onChanged;

  /// The sentence, as spans, so a document can be linked mid-sentence.
  final List<InlineSpan> children;

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
                child: Text.rich(
                  TextSpan(children: children),
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
