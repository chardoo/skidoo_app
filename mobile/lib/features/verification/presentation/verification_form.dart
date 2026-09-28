import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/common/widgets/app_button.dart';
import 'package:jperg_app/core/common/widgets/app_inline_banner.dart';
import 'package:jperg_app/core/common/widgets/app_text_field.dart';
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/verification/data/verification_api.dart';

/// The identity details a creator verifies with.
///
/// **Details, never a photograph of the card.** Ghana's NIA and Data
/// Protection Commission both treat storing an image of a Ghana Card as
/// something a private company may not casually do, and an image is the part
/// of this that would have to be secured and eventually deleted. So this asks
/// for the number the way a bank does.
///
/// The same form serves two places — Account & Security, and the last step of
/// the creator wizard — because they collect exactly the same thing and a
/// second copy is a second thing to keep in step. The wizard supplies
/// [onSubmitted] to move itself along; Settings leaves it null and the form
/// shows the resulting status in place.
///
/// Nothing here verifies anything. Every submission lands as *pending* and
/// waits for a person — the intention is an NIA or KYC API behind it later,
/// which is why the fields are the ones such an API asks for.
class VerificationForm extends StatefulWidget {
  const VerificationForm({
    super.key,
    this.api,
    this.countryCode,
    this.onSubmitted,
    this.submitLabel = 'Submit for verification',
    this.extra,
    this.canSubmit = true,
    this.agreements = const (terms: true, uploadRights: true, payoutPolicy: true),
  });

  final VerificationApi? api;

  /// Which country's documents to offer. Null lets the server answer from the
  /// account, which is the usual case.
  final String? countryCode;

  /// Called after a submission the server accepted. The wizard uses it to move
  /// on; Settings does not pass one.
  final VoidCallback? onSubmitted;

  final String submitLabel;

  /// Drawn between the fields and the button. The creator wizard puts its
  /// three consent checkboxes here, because they belong to that step rather
  /// than to identity — Settings, where somebody agreed long ago, shows none.
  final Widget? extra;

  /// Whether the button is live. The wizard holds it closed until all three
  /// boxes are ticked.
  final bool canSubmit;

  /// What was actually agreed to.
  ///
  /// Sent rather than assumed, because these are a legal record of consent and
  /// the server stores them separately for the same reason. Settings defaults
  /// to all three: somebody resubmitting details agreed at onboarding and the
  /// record already says so.
  final ({bool terms, bool uploadRights, bool payoutPolicy}) agreements;

  @override
  State<VerificationForm> createState() => _VerificationFormState();
}

class _VerificationFormState extends State<VerificationForm> {
  late final VerificationApi _api = widget.api ?? VerificationApi();

  final _name = TextEditingController();
  final _number = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  List<IdDocumentType> _types = const [];
  IdDocumentType? _type;
  DateTime? _dob;
  VerificationStatus? _existing;

  bool _loading = true;
  bool _submitting = false;
  String? _error;

  /// Whether somebody with a submission already in has asked to replace it.
  ///
  /// The form is behind this rather than under the status card. Waiting on a
  /// review is a state, not a task: a screen that reports it and then opens a
  /// blank form underneath reads as though the submission did not land, and
  /// it puts a live Resubmit button one stray tap from replacing details that
  /// are being looked at. Asking first is also the only way the page can
  /// answer the question people actually arrive with, which is whether the
  /// documents got there.
  bool _resending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _number.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      _api.documentTypes(country: widget.countryCode),
      _api.status(),
    ]);
    if (!mounted) return;
    final types = results[0] as List<IdDocumentType>;
    final status = results[1] as VerificationStatus?;
    setState(() {
      _types = types;
      _type = types.isNotEmpty ? types.first : null;
      _existing = status;
      // Prefilled from the last attempt, so somebody who was rejected fixes
      // one field rather than typing all four again.
      if (status?.legalName != null) _name.text = status!.legalName!;
      _loading = false;
    });
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_type == null) return;
    if (_dob == null) {
      setState(() => _error = 'Please give your date of birth');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final problem = await _api.submit(
      legalName: _name.text,
      idType: _type!.value,
      idNumber: _number.text,
      dateOfBirth: _dob!,
      countryCode: widget.countryCode,
      agreements: widget.agreements,
    );

    if (!mounted) return;
    if (problem != null) {
      setState(() {
        _submitting = false;
        _error = problem;
      });
      return;
    }

    final refreshed = await _api.status();
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _existing = refreshed;
      _number.clear();
      // Back to the status, which now describes the submission just made.
      _resending = false;
    });
    widget.onSubmitted?.call();
  }

  /// `14 Sep 2026`. The date they sent it, so "shortly" has something to be
  /// measured against — a review that has been pending a week reads very
  /// differently from one sent this morning, and only the person waiting can
  /// tell which they are looking at.
  static String _on(DateTime when) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final d = when.toLocal();
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      // Opens at a plausible birth year rather than today, which is thirty
      // years of scrolling away from any answer.
      initialDate: _dob ?? DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(now.year - 100),
      // Nobody verifying a creator account is under 18, so the picker does not
      // offer dates that the server is only going to refuse.
      lastDate: DateTime(now.year - 18, now.month, now.day),
      helpText: 'Date of birth',
    );
    if (picked != null && mounted) {
      setState(() {
        _dob = picked;
        _error = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    if (_loading) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xxxl.h),
        child: Center(
          child: CircularProgressIndicator(color: ext.accentGold),
        ),
      );
    }

    final existing = _existing;
    // Approved is the end of the road: re-submitting cannot un-verify anybody,
    // and offering the form again only invites somebody to try.
    if (existing != null && existing.isApproved) {
      return _StatusCard(
        ext: ext,
        icon: Icons.verified_rounded,
        tone: ext.accentGold,
        title: 'Verified',
        body: 'Your identity has been confirmed.',
      );
    }

    // Already sent, and not yet asked to replace it. The answer to "did my
    // documents arrive", and an offer rather than a form.
    if (existing != null && existing.isPending && !_resending) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _StatusCard(
            ext: ext,
            icon: Icons.hourglass_top_rounded,
            tone: ext.infoBlue,
            title: 'Pending verification',
            body: existing.submittedAt == null
                ? 'You have sent your documents. Someone will check them '
                    'shortly.'
                : 'You sent your documents on ${_on(existing.submittedAt!)}. '
                    'Someone will check them shortly.',
          ),
          if (existing.idNumberMasked != null) ...[
            SizedBox(height: AppSpacing.sm.h),
            Text(
              // What was sent, so "do you want to send it again" is a question
              // somebody can actually answer. The last four only — they typed
              // it, so it is not a secret from them, but a screen printing a
              // whole ID number is one that can be photographed over a
              // shoulder.
              'On file: ${existing.legalName ?? ''} · '
              '${existing.idNumberMasked}',
              style: TextStyle(color: ext.searchHintColor, fontSize: 12.sp),
            ),
          ],
          SizedBox(height: AppSpacing.lg.h),
          Text(
            'Sent the wrong details?',
            textAlign: TextAlign.center,
            style: TextStyle(color: ext.searchHintColor, fontSize: 12.sp),
          ),
          SizedBox(height: AppSpacing.sm.h),
          AppButton(
            fullWidth: true,
            variant: AppButtonVariant.secondary,
            label: 'Resend documents',
            onPressed: () => setState(() => _resending = true),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (existing != null && existing.isPending) ...[
          _StatusCard(
            ext: ext,
            icon: Icons.hourglass_top_rounded,
            tone: ext.infoBlue,
            title: 'Replacing what you sent',
            body: 'Your previous details are still being reviewed until this '
                'one arrives.',
          ),
          SizedBox(height: AppSpacing.md.h),
        ],
        if (existing != null && existing.isRejected) ...[
          AppInlineBanner(
            // The reason is the whole message: a rejection without one leaves
            // somebody guessing which of four fields was wrong.
            message: existing.rejectionReason ??
                'Your last submission was not accepted. Please check your '
                    'details and try again.',
          ),
          SizedBox(height: AppSpacing.md.h),
        ],

        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Full name, exactly as it appears on your document.',
                style:
                    TextStyle(color: ext.searchHintColor, fontSize: 12.sp),
              ),
              SizedBox(height: AppSpacing.sm.h),
              AppTextField(
                controller: _name,
                hint: 'Full name',
                textCapitalization: TextCapitalization.words,
                validator: (v) => (v ?? '').trim().length < 2
                    ? 'Please give your full name'
                    : null,
              ),
              SizedBox(height: AppSpacing.md.h),

              _DocumentPicker(
                ext: ext,
                types: _types,
                selected: _type,
                onChanged: (t) => setState(() {
                  _type = t;
                  // The number belongs to the document — keeping it across a
                  // change would submit a passport number as a Ghana Card.
                  _number.clear();
                }),
              ),
              SizedBox(height: AppSpacing.md.h),

              AppTextField(
                controller: _number,
                hint: _type?.hint ?? 'Document number',
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [UpperCaseFormatter()],
                validator: (v) => (v ?? '').trim().length < 4
                    ? 'Please give your document number'
                    : null,
              ),
              SizedBox(height: AppSpacing.md.h),

              _DateField(ext: ext, value: _dob, onTap: _pickDate),
            ],
          ),
        ),

        if (widget.extra != null) ...[
          SizedBox(height: AppSpacing.lg.h),
          widget.extra!,
        ],

        if (_error != null) ...[
          SizedBox(height: AppSpacing.md.h),
          AppInlineBanner(message: _error!),
        ],

        SizedBox(height: AppSpacing.lg.h),
        Text(
          // Said out loud because it is the thing people expect to be asked
          // for and are relieved not to be.
          'We never ask for a photo of your card.',
          textAlign: TextAlign.center,
          style: TextStyle(color: ext.searchHintColor, fontSize: 12.sp),
        ),
        SizedBox(height: AppSpacing.sm.h),
        AppButton(
          fullWidth: true,
          label: existing != null && existing.isPending
              ? 'Resubmit'
              : widget.submitLabel,
          isLoading: _submitting,
          onPressed: widget.canSubmit ? _submit : null,
        ),
      ],
    );
  }
}

/// Upper-cases as it is typed, because every document number here is
/// upper-case and the server normalises to it anyway — so the field shows what
/// will actually be stored.
class UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) =>
      newValue.copyWith(text: newValue.text.toUpperCase());
}

class _DocumentPicker extends StatelessWidget {
  const _DocumentPicker({
    required this.ext,
    required this.types,
    required this.selected,
    required this.onChanged,
  });

  final AppThemeExtension ext;
  final List<IdDocumentType> types;
  final IdDocumentType? selected;
  final ValueChanged<IdDocumentType> onChanged;

  @override
  Widget build(BuildContext context) {
    if (types.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.md.w),
      decoration: BoxDecoration(
        color: ext.searchFieldFill,
        borderRadius: BorderRadius.circular(AppRadius.md.r),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selected?.value,
          isExpanded: true,
          dropdownColor: ext.cardSurface,
          icon: Icon(Icons.keyboard_arrow_down_rounded,
              color: ext.searchHintColor),
          style: TextStyle(color: ext.greetingColor, fontSize: 14.sp),
          items: [
            for (final t in types)
              DropdownMenuItem(value: t.value, child: Text(t.label)),
          ],
          onChanged: (value) {
            final next = types.firstWhere((t) => t.value == value);
            onChanged(next);
          },
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.ext, required this.value, required this.onTap});

  final AppThemeExtension ext;
  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = value == null
        ? 'Date of birth'
        : '${value!.day} ${_months[value!.month - 1]} ${value!.year}';

    return Semantics(
      button: true,
      label: 'Date of birth',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.md.w, vertical: AppSpacing.md.h),
          decoration: BoxDecoration(
            color: ext.searchFieldFill,
            borderRadius: BorderRadius.circular(AppRadius.md.r),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: value == null
                        ? ext.searchHintColor
                        : ext.greetingColor,
                    fontSize: 14.sp,
                  ),
                ),
              ),
              Icon(Icons.calendar_today_rounded,
                  size: 16.sp, color: ext.searchHintColor),
            ],
          ),
        ),
      ),
    );
  }
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.ext,
    required this.icon,
    required this.tone,
    required this.title,
    required this.body,
  });

  final AppThemeExtension ext;
  final IconData icon;
  final Color tone;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.md.w),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.md.r),
        border: Border.all(color: tone.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: tone, size: 18.sp),
          SizedBox(width: AppSpacing.sm.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: ext.greetingColor,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  body,
                  style:
                      TextStyle(color: ext.searchHintColor, fontSize: 12.sp),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
