import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:jperg_app/core/common/widgets/xfile_image.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:jperg_app/core/common/widgets/app_widgets.dart';
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/utils/image_pick.dart';
import 'package:jperg_app/core/utils/number_format.dart';
import 'package:jperg_app/core/utils/snackbar_utils.dart';
import 'package:jperg_app/core/utils/web_wrap.dart';
import 'package:jperg_app/features/ads/data/repositories/ads_repository.dart';
import 'package:jperg_app/features/location/data/models/place.dart';
import 'package:jperg_app/features/location/presentation/widgets/location_picker_sheet.dart';
import 'package:jperg_app/features/admin/data/models/app_config.dart';
import 'package:jperg_app/features/admin/data/repositories/app_config_repository.dart';
import 'package:jperg_app/features/ads/models/ad_campaign.dart';

/// Everything the five steps collect, in one place.
///
/// Held here rather than posted step by step: the old wizard created the
/// campaign at step one and the ad set at step two, so backing out at step four
/// left something behind that existed and could never run.
class CampaignDraft {
  CampaignObjective objective = CampaignObjective.awareness;
  CampaignFormat format = CampaignFormat.image;

  final headline = TextEditingController();
  final copy = TextEditingController();
  final ctaText = TextEditingController(text: 'Book Now');
  final ctaUrl = TextEditingController();
  final photos = <XFile>[];

  /// Where the thing being advertised happens — "Labadi Beach Hotel, Accra".
  ///
  /// Optional and free text: plenty of campaigns sell a service rather than an
  /// event and have no venue at all, and a venue that does exist is an address
  /// rather than a city a picker could offer.
  ///
  /// Part of the creative, not the targeting. [targetLocations] below decides
  /// who is shown the campaign; this only says what it is about.
  final location = TextEditingController();

  /// Where the campaign is aimed, as resolved places. `locations` below is
  /// derived from these for the review card and older reads; the server
  /// re-derives it too, so the two cannot disagree about one campaign.
  ///
  /// Not the same question as [location] above, and the wizard asks both:
  /// a concert at one venue is routinely advertised to a whole country.
  final targetLocations = <Place>[];
  final interests = <String>{};

  /// The "#wedding #photography" line on the card. Copy, not targeting —
  /// [interests] above is the targeting, and they are two fields on purpose.
  final contentTags = <String>{};

  /// The card gives the tag line one row.
  static const maxContentTags = 5;
  String audience = 'all';
  /// Who to show it to, by age. Defaults to the widest the picker offers
  /// rather than a guess — narrowing is a decision, and it should be one the
  /// advertiser makes rather than one they inherit.
  RangeValues ages = const RangeValues(18, 65);
  final placements = <String>{'event_feed', 'explore'};

  BudgetMode budgetMode = BudgetMode.daily;
  final budget = TextEditingController();
  final duration = TextEditingController(text: '14');
  DateTime? startDate;
  DateTime? endDate;

  bool agreedToTerms = false;

  double get budgetValue => double.tryParse(budget.text.trim()) ?? 0;
  int get durationValue => int.tryParse(duration.text.trim()) ?? 0;

  /// The other number, shown live under the field they are typing in.
  double get derived => durationValue <= 0
      ? 0
      : budgetMode == BudgetMode.daily
          ? budgetValue * durationValue
          : budgetValue / durationValue;

  bool get typeDone => true; // objective and format both have defaults

  bool get creativeDone {
    final (low, high) = format.mediaRange;
    return headline.text.trim().isNotEmpty &&
        copy.text.trim().isNotEmpty &&
        ctaText.text.trim().isNotEmpty &&
        ctaUrl.text.trim().isNotEmpty &&
        photos.length >= low &&
        photos.length <= high;
  }

  bool get audienceDone =>
      targetLocations.isNotEmpty && placements.isNotEmpty;

  bool get budgetDone =>
      budgetValue > 0 &&
      durationValue > 0 &&
      startDate != null &&
      endDate != null &&
      endDate!.isAfter(startDate!);

  void dispose() {
    headline.dispose();
    copy.dispose();
    ctaText.dispose();
    ctaUrl.dispose();
    location.dispose();
    budget.dispose();
    duration.dispose();
  }
}

/// Shared with the edit form, so the two cannot offer different sets.
const kCampaignInterests = [
  'Weddings', 'Portraits', 'Events', 'Fashion', 'Real Estate', 'Food',
  'Corporate', 'Nature', 'Product',
];

/// The seven cities this used to offer, kept only for reading campaigns that
/// were built from them. Targeting is picked from the location search now — see
/// [LocationPickerSheet] — because a name cannot be gated on or measured from,
/// and seven cities is not a country.
const kLegacyCampaignLocations = [
  'Accra', 'Kumasi', 'Takoradi', 'Tamale', 'Cape Coast', 'Ho', 'Sunyani',
];

/// Create Campaign — Type, Creative, Audience, Budget, Review.
class CampaignWizardPage extends StatefulWidget {
  const CampaignWizardPage({super.key});

  @override
  State<CampaignWizardPage> createState() => _CampaignWizardPageState();
}

class _CampaignWizardPageState extends State<CampaignWizardPage> {
  final _repo = AdsRepository();
  final _draft = CampaignDraft();

  int _step = 0;
  bool _saving = false;

  static const _labels = ['Type', 'Creative', 'Audience', 'Budget', 'Review'];

  @override
  void initState() {
    super.initState();
    // Both dates move together with the duration, so the review card cannot
    // show "14 days" over a fortnight that is actually nine.
    _draft.startDate = DateTime.now().add(const Duration(days: 1));
    _syncEndDate();
    _draft.duration.addListener(_syncEndDate);
  }

  @override
  void dispose() {
    _draft.duration.removeListener(_syncEndDate);
    _draft.dispose();
    super.dispose();
  }

  void _syncEndDate() {
    final start = _draft.startDate;
    final days = _draft.durationValue;
    if (start == null || days <= 0) return;
    setState(() => _draft.endDate = start.add(Duration(days: days)));
  }

  bool get _canAdvance => switch (_step) {
        0 => _draft.typeDone,
        1 => _draft.creativeDone,
        2 => _draft.audienceDone,
        3 => _draft.budgetDone,
        _ => _draft.agreedToTerms,
      };

  Future<void> _next() async {
    if (!_canAdvance || _saving) return;
    if (_step < 4) {
      setState(() => _step++);
      return;
    }
    await _submit();
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    try {
      final campaign = await _repo.createCampaignDraft(
        name: _draft.headline.text.trim(),
        objective: _draft.objective.value,
        format: _draft.format.value,
        headline: _draft.headline.text.trim(),
        body: _draft.copy.text.trim(),
        ctaText: _draft.ctaText.text.trim(),
        ctaUrl: _draft.ctaUrl.text.trim(),
        location: _draft.location.text.trim(),
        targetLocations:
            _draft.targetLocations.map((p) => p.toJson()).toList(),
        interests: _draft.interests.toList(),
        contentTags: _draft.contentTags.toList(),
        audience: _draft.audience,
        placements: _draft.placements.toList(),
        ageMin: _draft.ages.start.round(),
        ageMax: _draft.ages.end.round(),
        budgetMode: _draft.budgetMode.value,
        budgetAmount: _draft.budgetValue,
        durationDays: _draft.durationValue,
        startAt: _draft.startDate?.toIso8601String(),
        endAt: _draft.endDate?.toIso8601String(),
      );

      // Uploaded after the draft exists, because media hangs off a campaign id.
      // Any failure here has to stop the submission: a campaign submitted with
      // no creative reaches a reviewer as something unrenderable.
      for (final photo in _draft.photos) {
        await _repo.uploadCampaignMedia(campaign.id, photo);
      }

      await _repo.submitCampaign(campaign.id);
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const CampaignSubmittedPage()),
      );
    } catch (e) {
      debugPrint('[CampaignWizard] submit ERROR: $e');
      if (!mounted) return;
      setState(() => _saving = false);
      AppSnackBar.error(context, 'Could not submit your campaign. Try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    final page = Scaffold(
      backgroundColor: ext.homeBackground,
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        leading: kIsWeb
            ? null
            : AppBackButton(
                onPressed: () => _step == 0
                    ? Navigator.of(context).pop()
                    : setState(() => _step--),
              ),
        title: Text(
          'Create Campaign',
          style: TextStyle(
            color: ext.greetingColor,
            fontWeight: FontWeight.w700,
            fontSize: 16.sp,
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.lg.w, vertical: AppSpacing.md.h,
            ),
            child: _StepBar(step: _step, labels: _labels, ext: ext),
          ),
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg.w, AppSpacing.sm.h, AppSpacing.lg.w,
                AppSpacing.xxl.h,
              ),
              children: [_body(ext)],
            ),
          ),
          _Footer(
            ext: ext,
            step: _step,
            saving: _saving,
            enabled: _canAdvance,
            onBack: _step > 0 ? () => setState(() => _step--) : null,
            onNext: _next,
          ),
        ],
      ),
    );
    return webWrap(page, backgroundColor: ext.homeBackground);
  }

  Widget _body(AppThemeExtension ext) => switch (_step) {
        0 => _TypeStep(draft: _draft, ext: ext, onChanged: () => setState(() {})),
        1 => _CreativeStep(
            draft: _draft,
            ext: ext,
            onChanged: () => setState(() {}),
            onPick: _pickPhotos,
          ),
        2 => _AudienceStep(
            draft: _draft, ext: ext, onChanged: () => setState(() {})),
        3 => _BudgetStep(
            draft: _draft,
            ext: ext,
            repo: _repo,
            onChanged: () => setState(() {}),
            onPickStart: _pickStartDate,
          ),
        _ => _ReviewStep(
            draft: _draft,
            ext: ext,
            onEdit: (i) => setState(() => _step = i),
            onTermsChanged: (v) => setState(() => _draft.agreedToTerms = v),
          ),
      };

  Future<void> _pickPhotos() async {
    final (_, high) = _draft.format.mediaRange;
    if (_draft.photos.length >= high) {
      AppSnackBar.error(
        context,
        '${_draft.format.label} campaigns take at most $high '
        '${high == 1 ? 'file' : 'files'}.',
      );
      return;
    }
    // pickImagesUpTo, not pickMultiImage: its `limit` throws below 2, which is
    // exactly the pick that fills the last slot.
    final picked = await pickImagesUpTo(
      ImagePicker(),
      limit: high - _draft.photos.length,
    );
    if (picked.isEmpty) return;
    setState(() => _draft.photos.addAll(picked.take(high - _draft.photos.length)));
  }

  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _draft.startDate ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() => _draft.startDate = picked);
    _syncEndDate();
  }
}

// ── Chrome ───────────────────────────────────────────────────────────────────

class _StepBar extends StatelessWidget {
  const _StepBar({required this.step, required this.labels, required this.ext});

  final int step;
  final List<String> labels;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0)
            Expanded(
              child: Container(
                height: 1.5.h,
                margin: EdgeInsets.symmetric(horizontal: 4.w),
                color: i <= step
                    ? ext.accentGold
                    : ext.searchHintColor.withValues(alpha: 0.25),
              ),
            ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 26.r,
                height: 26.r,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i <= step ? ext.accentGold : Colors.transparent,
                  border: Border.all(
                    color: i <= step
                        ? ext.accentGold
                        : ext.searchHintColor.withValues(alpha: 0.35),
                  ),
                ),
                child: i < step
                    ? Icon(Icons.check_rounded, size: 15.r, color: Colors.white)
                    : Text(
                        '${i + 1}',
                        style: TextStyle(
                          color: i == step ? Colors.white : ext.searchHintColor,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
              SizedBox(height: 4.h),
              Text(
                labels[i],
                style: TextStyle(
                  color: i == step ? ext.accentGold : ext.searchHintColor,
                  fontSize: 10.sp,
                  fontWeight: i == step ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.ext,
    required this.step,
    required this.saving,
    required this.enabled,
    required this.onBack,
    required this.onNext,
  });

  final AppThemeExtension ext;
  final int step;
  final bool saving;
  final bool enabled;
  final VoidCallback? onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: EdgeInsets.fromLTRB(
        AppSpacing.lg.w, AppSpacing.sm.h, AppSpacing.lg.w, AppSpacing.md.h,
      ),
      child: Row(
        children: [
          if (onBack != null) ...[
            Expanded(
              child: SizedBox(
                height: 48.h,
                child: OutlinedButton(
                  onPressed: saving ? null : onBack,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: ext.searchHintColor.withValues(alpha: 0.4),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999.r),
                    ),
                  ),
                  child: Text(
                    'Back',
                    style: TextStyle(color: ext.greetingColor, fontSize: 15.sp),
                  ),
                ),
              ),
            ),
            SizedBox(width: AppSpacing.md.w),
          ],
          Expanded(
            flex: onBack == null ? 1 : 1,
            child: SizedBox(
              height: 48.h,
              child: ElevatedButton(
                onPressed: (enabled && !saving) ? onNext : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ext.accentGold,
                  disabledBackgroundColor:
                      ext.searchHintColor.withValues(alpha: 0.25),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999.r),
                  ),
                ),
                child: saving
                    ? SizedBox(
                        width: 18.r,
                        height: 18.r,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        step == 4 ? 'Submit for review' : 'Next',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text, {required this.ext});

  final String text;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(bottom: AppSpacing.md.h),
        child: Text(
          text,
          style: TextStyle(
            color: ext.greetingColor,
            fontSize: 19.sp,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
      );
}

class _Label extends StatelessWidget {
  const _Label(this.text, {required this.ext, this.required = false, this.hint});

  final String text;
  final AppThemeExtension ext;
  final bool required;
  final String? hint;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(top: AppSpacing.md.h, bottom: AppSpacing.xs.h),
        child: Text.rich(
          TextSpan(children: [
            TextSpan(text: text),
            if (hint != null)
              TextSpan(
                text: ' $hint',
                style: TextStyle(
                  color: ext.searchHintColor,
                  fontStyle: FontStyle.italic,
                  fontSize: 12.sp,
                ),
              ),
            if (required)
              TextSpan(
                text: ' *',
                style: TextStyle(color: ext.accentGold),
              ),
          ]),
          style: TextStyle(
            color: ext.greetingColor,
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
}

class _Input extends StatelessWidget {
  const _Input({
    required this.controller,
    required this.ext,
    this.hint,
    this.maxLines = 1,
    this.maxLength,
    this.keyboardType,
    this.prefix,
    this.onChanged,
  });

  final TextEditingController controller;
  final AppThemeExtension ext;
  final String? hint;
  final int maxLines;
  final int? maxLength;
  final TextInputType? keyboardType;
  final Widget? prefix;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        maxLines: maxLines,
        maxLength: maxLength,
        keyboardType: keyboardType,
        onChanged: onChanged,
        style: TextStyle(color: ext.greetingColor, fontSize: 14.sp),
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: prefix,
          prefixIconConstraints: BoxConstraints(minWidth: 52.w),
          hintStyle: TextStyle(color: ext.searchHintColor, fontSize: 14.sp),
          counterText: '',
          filled: true,
          fillColor: ext.cardSurface,
          contentPadding: EdgeInsets.symmetric(
            horizontal: AppSpacing.md.w, vertical: AppSpacing.md.h,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md.r),
            borderSide: BorderSide(
              color: ext.searchHintColor.withValues(alpha: 0.2),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md.r),
            borderSide: BorderSide(
              color: ext.searchHintColor.withValues(alpha: 0.2),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md.r),
            borderSide: BorderSide(color: ext.accentGold),
          ),
        ),
      );
}

/// A segmented control — Image/Carousel/Video, Daily/Total.
class _Segmented extends StatelessWidget {
  const _Segmented({
    required this.labels,
    required this.index,
    required this.ext,
    required this.onChanged,
  });

  final List<String> labels;
  final int index;
  final AppThemeExtension ext;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(3.r),
      decoration: BoxDecoration(
        color: ext.accentGold.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.md.r),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(i),
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 10.h),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == index ? ext.accentGold : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.sm.r),
                  ),
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      color: i == index ? Colors.white : ext.greetingColor,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── 1. Type ──────────────────────────────────────────────────────────────────

class _TypeStep extends StatelessWidget {
  const _TypeStep({
    required this.draft,
    required this.ext,
    required this.onChanged,
  });

  final CampaignDraft draft;
  final AppThemeExtension ext;
  final VoidCallback onChanged;

  static const _icons = {
    CampaignObjective.awareness: Icons.visibility_outlined,
    CampaignObjective.traffic: Icons.north_east_rounded,
    CampaignObjective.leads: Icons.groups_outlined,
    CampaignObjective.services: Icons.photo_camera_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Heading('Campaign Objective', ext: ext),
        for (final objective in CampaignObjective.values)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              draft.objective = objective;
              onChanged();
            },
            child: Container(
              margin: EdgeInsets.only(bottom: AppSpacing.sm.h),
              padding: EdgeInsets.all(AppSpacing.md.w),
              decoration: BoxDecoration(
                color: draft.objective == objective
                    ? ext.accentGold.withValues(alpha: 0.08)
                    : ext.cardSurface,
                borderRadius: BorderRadius.circular(AppRadius.md.r),
                border: Border.all(
                  color: draft.objective == objective
                      ? ext.accentGold
                      : ext.searchHintColor.withValues(alpha: 0.18),
                  width: draft.objective == objective ? 1.4 : 0.8,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40.r,
                    height: 40.r,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: draft.objective == objective
                          ? ext.accentGold
                          : ext.accentGold.withValues(alpha: 0.12),
                    ),
                    child: Icon(
                      _icons[objective],
                      size: 19.r,
                      color: draft.objective == objective
                          ? Colors.white
                          : ext.accentGold,
                    ),
                  ),
                  SizedBox(width: AppSpacing.md.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          objective.label,
                          style: TextStyle(
                            color: ext.greetingColor,
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          objective.blurb,
                          style: TextStyle(
                            color: ext.searchHintColor, fontSize: 12.sp,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        _Label('Campaign format', ext: ext),
        _Segmented(
          labels: [for (final f in CampaignFormat.values) f.label],
          index: CampaignFormat.values.indexOf(draft.format),
          ext: ext,
          onChanged: (i) {
            draft.format = CampaignFormat.values[i];
            // Changing format changes how many files are allowed, so anything
            // already over the new ceiling goes rather than blocking Next with
            // no way to see why.
            final (_, high) = draft.format.mediaRange;
            if (draft.photos.length > high) {
              draft.photos.removeRange(high, draft.photos.length);
            }
            onChanged();
          },
        ),
      ],
    );
  }
}

// ── 2. Creative ──────────────────────────────────────────────────────────────

class _CreativeStep extends StatelessWidget {
  const _CreativeStep({
    required this.draft,
    required this.ext,
    required this.onChanged,
    required this.onPick,
  });

  final CampaignDraft draft;
  final AppThemeExtension ext;
  final VoidCallback onChanged;
  final Future<void> Function() onPick;

  @override
  Widget build(BuildContext context) {
    final (low, high) = draft.format.mediaRange;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Heading('Campaign Creative', ext: ext),
        _Label('Campaign headline', ext: ext, required: true),
        _Input(
          controller: draft.headline,
          ext: ext,
          hint: 'Book Your Perfect Photoshoot Today',
          maxLength: 60,
          onChanged: (_) => onChanged(),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '${draft.headline.text.characters.length} / 60 characters',
            style: TextStyle(color: ext.searchHintColor, fontSize: 11.sp),
          ),
        ),
        _Label('Campaign copy', ext: ext, required: true),
        _Input(
          controller: draft.copy,
          ext: ext,
          hint: 'What are you offering?',
          maxLines: 4,
          onChanged: (_) => onChanged(),
        ),
        _Label(
          high == 1 ? 'Cover image / flyer upload' : 'Images ($low–$high)',
          ext: ext,
          required: true,
        ),
        _PhotoStrip(
          draft: draft,
          ext: ext,
          onPick: onPick,
          onRemove: (f) {
            draft.photos.remove(f);
            onChanged();
          },
        ),
        _Label(
          'Call to action',
          ext: ext,
          required: true,
          hint: '(Select action for your campaign button)',
        ),
        _Input(
          controller: draft.ctaText,
          ext: ext,
          hint: 'Book Now',
          maxLength: 50,
          onChanged: (_) => onChanged(),
        ),
        _Label('Destination URL', ext: ext, required: true),
        _Input(
          controller: draft.ctaUrl,
          ext: ext,
          hint: 'https://mystudio.com/booking',
          keyboardType: TextInputType.url,
          onChanged: (_) => onChanged(),
        ),
        // The venue, on the creative step because it is copy: it tells a reader
        // where to turn up. It is not the target areas in the Audience step,
        // which decide who ever reads it — a concert at one hotel is regularly
        // advertised to a whole country.
        _Label(
          'Location',
          ext: ext,
          hint: '(Where the event happens — optional)',
        ),
        _Input(
          controller: draft.location,
          ext: ext,
          hint: 'e.g. Labadi Beach Hotel, Accra',
          maxLength: 255,
          onChanged: (_) => onChanged(),
        ),
        // Copy, and so part of the creative — not the interest tags in the
        // Audience step, which decide who is shown this. The two look alike
        // and mean opposite ends of the same sentence.
        _Label(
          'Tags',
          ext: ext,
          hint: '(Shown on the card as #hashtags, up to '
              '${CampaignDraft.maxContentTags})',
        ),
        _TagPicker(draft: draft, ext: ext, onChanged: onChanged),
      ],
    );
  }
}

/// The words from the app's own vocabulary, the same ones photographers tag
/// albums with, so a campaign and an album about the same thing say it the
/// same way. Served from /config; the built-in list is the offline fallback.
class _TagPicker extends StatelessWidget {
  const _TagPicker({
    required this.draft,
    required this.ext,
    required this.onChanged,
  });

  final CampaignDraft draft;
  final AppThemeExtension ext;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppConfig>(
      valueListenable: AppConfigRepository.notifier,
      builder: (context, config, _) {
        final vocabulary = config.contentTags;
        return Wrap(
          spacing: AppSpacing.sm.w,
          runSpacing: AppSpacing.xs.h,
          children: [
            for (final tag in vocabulary)
              _Choice(
                label: tag,
                selected: draft.contentTags.contains(tag),
                ext: ext,
                onTap: () {
                  if (draft.contentTags.contains(tag)) {
                    draft.contentTags.remove(tag);
                  } else if (draft.contentTags.length <
                      CampaignDraft.maxContentTags) {
                    // Silently at the cap rather than an error: the card gives
                    // this line one row, and five is what fits.
                    draft.contentTags.add(tag);
                  }
                  onChanged();
                },
              ),
          ],
        );
      },
    );
  }
}

class _PhotoStrip extends StatelessWidget {
  const _PhotoStrip({
    required this.draft,
    required this.ext,
    required this.onPick,
    required this.onRemove,
  });

  final CampaignDraft draft;
  final AppThemeExtension ext;
  final Future<void> Function() onPick;
  final ValueChanged<XFile> onRemove;

  @override
  Widget build(BuildContext context) {
    final (_, high) = draft.format.mediaRange;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (draft.photos.isEmpty)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onPick,
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: AppSpacing.xl.h),
              decoration: BoxDecoration(
                color: ext.accentGold.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(AppRadius.md.r),
                border: Border.all(
                  color: ext.accentGold.withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  Icon(Icons.add_photo_alternate_outlined,
                      color: ext.accentGold, size: 26.r),
                  SizedBox(height: 6.h),
                  Text(
                    'Upload image',
                    style: TextStyle(
                      color: ext.accentGold,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    'PNG, JPG up to 5MB',
                    style: TextStyle(
                      color: ext.searchHintColor, fontSize: 11.sp,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          SizedBox(
            height: 96.h,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final photo in draft.photos)
                  Padding(
                    padding: EdgeInsets.only(right: AppSpacing.sm.w),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.md.r),
                          // XFileImage, not Image.file: it decodes to the size
                          // of the thumbnail. A camera frame decoded whole is
                          // ~50 MB, and ten of them is an out-of-memory kill.
                          child: XFileImage(photo,
                              width: 96.w, height: 96.h, fit: BoxFit.cover),
                        ),
                        Positioned(
                          top: 2, right: 2,
                          child: GestureDetector(
                            onTap: () => onRemove(photo),
                            child: Container(
                              padding: EdgeInsets.all(3.r),
                              decoration: const BoxDecoration(
                                color: Colors.black54, shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.close_rounded,
                                  size: 13.r, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (draft.photos.length < high)
                  GestureDetector(
                    onTap: onPick,
                    child: Container(
                      width: 96.w,
                      height: 96.h,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: ext.accentGold.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(AppRadius.md.r),
                        border: Border.all(
                          color: ext.accentGold.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Icon(Icons.add_rounded,
                          color: ext.accentGold, size: 24.r),
                    ),
                  ),
              ],
            ),
          ),
        if (draft.photos.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: 6.h),
            child: Text(
              '${draft.photos.length} of $high',
              style: TextStyle(color: ext.searchHintColor, fontSize: 11.sp),
            ),
          ),
      ],
    );
  }
}

// ── 3. Audience ──────────────────────────────────────────────────────────────

class _AudienceStep extends StatelessWidget {
  const _AudienceStep({
    required this.draft,
    required this.ext,
    required this.onChanged,
  });

  final CampaignDraft draft;
  final AppThemeExtension ext;
  final VoidCallback onChanged;

  static const _placementLabels = {
    'event_feed': 'Feed',
    'explore': 'Explore',
    'search_results': 'Search results',
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Heading('Audience Targeting', ext: ext),
        // "Target areas", not "Location". The label used to be the latter and
        // this is the only place a campaign said anything about a place, so it
        // read as the venue — which it never was. The venue is its own field on
        // the creative step now.
        _Label('Target areas', ext: ext, required: true),
        Padding(
          padding: EdgeInsets.only(bottom: AppSpacing.sm.h),
          child: Text(
            'Where the people who should see this campaign are — not where the '
            'event itself takes place.',
            style: TextStyle(color: ext.searchHintColor, fontSize: 11.sp),
          ),
        ),
        Builder(builder: (context) {
          return LocationChips(
            places: draft.targetLocations,
            emptyLabel: 'Pick at least one country or city',
            onAdd: () async {
              final place = await LocationPickerSheet.show(
                context,
                title: 'Show this to people in…',
              );
              if (place == null) return;
              // The picker can return somewhere already chosen — Place
              // compares on country and point, so this is one entry either way.
              if (!draft.targetLocations.contains(place)) {
                draft.targetLocations.add(place);
              }
              onChanged();
            },
            onRemove: (place) {
              draft.targetLocations.remove(place);
              onChanged();
            },
          );
        }),
        _Label('Interest tags', ext: ext),
        Wrap(
          spacing: AppSpacing.sm.w,
          runSpacing: AppSpacing.xs.h,
          children: [
            for (final interest in kCampaignInterests)
              _Choice(
                label: interest,
                selected: draft.interests.contains(interest),
                ext: ext,
                onTap: () {
                  draft.interests.contains(interest)
                      ? draft.interests.remove(interest)
                      : draft.interests.add(interest);
                  onChanged();
                },
              ),
          ],
        ),
        _Label('Audience', ext: ext),
        Row(
          children: [
            for (final option in const [
              ('all', 'All'),
              ('creators', 'Creators'),
              ('explorers', 'Explorers'),
            ])
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    draft.audience = option.$1;
                    onChanged();
                  },
                  child: Row(
                    children: [
                      _Dot(selected: draft.audience == option.$1, ext: ext),
                      SizedBox(width: 6.w),
                      Flexible(
                        child: Text(
                          option.$2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: ext.greetingColor, fontSize: 13.sp,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        _Label('Target age', ext: ext),
        _AgeRange(
          ext: ext,
          values: draft.ages,
          onChanged: (v) {
            draft.ages = v;
            onChanged();
          },
        ),
        _Label('Placement', ext: ext, required: true),
        for (final entry in _placementLabels.entries)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              draft.placements.contains(entry.key)
                  ? draft.placements.remove(entry.key)
                  : draft.placements.add(entry.key);
              onChanged();
            },
            child: Row(
              children: [
                Checkbox(
                  value: draft.placements.contains(entry.key),
                  activeColor: ext.accentGold,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: (v) {
                    v == true
                        ? draft.placements.add(entry.key)
                        : draft.placements.remove(entry.key);
                    onChanged();
                  },
                ),
                SizedBox(width: 6.w),
                Text(
                  entry.value,
                  style: TextStyle(color: ext.greetingColor, fontSize: 13.sp),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// The design's radio: a ring that fills when chosen. Hand-drawn because
/// Material's Radio now wants a RadioGroup ancestor, and this is one line.
class _Dot extends StatelessWidget {
  const _Dot({required this.selected, required this.ext});

  final bool selected;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) => Container(
        width: 18.r,
        height: 18.r,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: selected
                ? ext.accentGold
                : ext.searchHintColor.withValues(alpha: 0.5),
            width: 1.6,
          ),
        ),
        child: selected
            ? Container(
                width: 9.r,
                height: 9.r,
                decoration: BoxDecoration(
                  shape: BoxShape.circle, color: ext.accentGold,
                ),
              )
            : null,
      );
}

/// The age band, as a range with its numbers spelled out above it — a slider
/// whose value you cannot read is a control you cannot set deliberately.
class _AgeRange extends StatelessWidget {
  const _AgeRange({
    required this.ext,
    required this.values,
    required this.onChanged,
  });

  final AppThemeExtension ext;
  final RangeValues values;
  final ValueChanged<RangeValues> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${values.start.round()} – ${values.end.round()} years',
          style: TextStyle(
            color: ext.accentGold,
            fontSize: 13.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
        RangeSlider(
          values: values,
          min: 13,
          max: 65,
          // One notch per year is unusable on a phone; five is enough to say
          // "25 to 55" and land on it every time.
          divisions: (65 - 13) ~/ 1,
          activeColor: ext.accentGold,
          inactiveColor: ext.searchHintColor.withValues(alpha: 0.25),
          labels: RangeLabels(
            '${values.start.round()}',
            '${values.end.round()}',
          ),
          onChanged: (v) {
            // Never let the handles cross into a band that means nothing.
            if (v.end - v.start < 1) return;
            onChanged(v);
          },
        ),
      ],
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.selected,
    required this.ext,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final AppThemeExtension ext;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 7.h),
          decoration: BoxDecoration(
            color: selected
                ? ext.accentGold.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(999.r),
            border: Border.all(
              color: selected
                  ? ext.accentGold
                  : ext.searchHintColor.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                Icon(Icons.check_rounded, size: 13.r, color: ext.accentGold),
                SizedBox(width: 4.w),
              ],
              Text(
                label,
                style: TextStyle(
                  color: selected ? ext.accentGold : ext.greetingColor,
                  fontSize: 12.sp,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
}

// ── 4. Budget ────────────────────────────────────────────────────────────────

class _BudgetStep extends StatefulWidget {
  const _BudgetStep({
    required this.draft,
    required this.ext,
    required this.repo,
    required this.onChanged,
    required this.onPickStart,
  });

  final CampaignDraft draft;
  final AppThemeExtension ext;
  final AdsRepository repo;
  final VoidCallback onChanged;
  final Future<void> Function() onPickStart;

  @override
  State<_BudgetStep> createState() => _BudgetStepState();
}

class _BudgetStepState extends State<_BudgetStep> {
  ReachEstimate? _estimate;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _refreshEstimate();
  }

  /// Naa's note on the design: show what the budget buys before they move on,
  /// so a number that reaches nobody can be revised here rather than after the
  /// campaign is live.
  Future<void> _refreshEstimate() async {
    final draft = widget.draft;
    if (draft.budgetValue <= 0 || draft.durationValue <= 0) {
      setState(() => _estimate = null);
      return;
    }
    setState(() => _loading = true);
    try {
      final estimate = await widget.repo.estimateReach(
        budgetMode: draft.budgetMode.value,
        budgetAmount: draft.budgetValue,
        durationDays: draft.durationValue,
      );
      if (mounted) setState(() => _estimate = estimate);
    } catch (e) {
      debugPrint('[CampaignWizard] estimate ERROR: $e');
      // A missing estimate is not a reason to block the step.
      if (mounted) setState(() => _estimate = null);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = widget.ext;
    final draft = widget.draft;
    final isDaily = draft.budgetMode == BudgetMode.daily;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Heading('Budget & Schedule', ext: ext),
        _Segmented(
          labels: const ['Daily budget', 'Total budget'],
          index: isDaily ? 0 : 1,
          ext: ext,
          onChanged: (i) {
            draft.budgetMode = i == 0 ? BudgetMode.daily : BudgetMode.total;
            widget.onChanged();
            _refreshEstimate();
          },
        ),
        _Label(
          isDaily ? 'Daily budget (GHS)' : 'Total budget (GHS)',
          ext: ext,
          required: true,
        ),
        _Input(
          controller: draft.budget,
          ext: ext,
          hint: '0.00',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          prefix: Padding(
            padding: EdgeInsets.only(left: AppSpacing.md.w),
            child: Text(
              'GHS',
              style: TextStyle(
                color: ext.accentGold,
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          onChanged: (_) {
            widget.onChanged();
            _refreshEstimate();
          },
        ),
        _Label('Duration', ext: ext, required: true),
        _Input(
          controller: draft.duration,
          ext: ext,
          hint: '14 days',
          keyboardType: TextInputType.number,
          onChanged: (_) {
            widget.onChanged();
            _refreshEstimate();
          },
        ),
        if (draft.derived > 0)
          Padding(
            padding: EdgeInsets.only(top: AppSpacing.sm.h),
            child: Text(
              isDaily
                  ? 'Estimated total: GHS ${draft.derived.toStringAsFixed(2)}'
                  : 'Estimated daily: GHS ${draft.derived.toStringAsFixed(2)}',
              style: TextStyle(
                color: ext.accentGold,
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        if (_loading || _estimate != null)
          Container(
            margin: EdgeInsets.only(top: AppSpacing.md.h),
            padding: EdgeInsets.all(AppSpacing.md.w),
            decoration: BoxDecoration(
              color: ext.accentGold.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadius.md.r),
            ),
            child: Row(
              children: [
                Icon(Icons.trending_up_rounded,
                    size: 17.r, color: ext.accentGold),
                SizedBox(width: AppSpacing.sm.w),
                Expanded(
                  child: _loading && _estimate == null
                      ? Text(
                          'Estimating reach…',
                          style: TextStyle(
                            color: ext.searchHintColor, fontSize: 12.sp,
                          ),
                        )
                      : Text.rich(
                          TextSpan(children: [
                            const TextSpan(text: 'Reaches about '),
                            TextSpan(
                              text: compactCount(_estimate!.dailyReach),
                              style: TextStyle(
                                color: ext.accentGold,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const TextSpan(text: ' people a day — around '),
                            TextSpan(
                              text: compactCount(_estimate!.totalReach),
                              style: TextStyle(
                                color: ext.accentGold,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const TextSpan(text: ' over the run. An estimate, '
                                'not a guarantee.'),
                          ]),
                          style: TextStyle(
                            color: ext.greetingColor,
                            fontSize: 12.sp,
                            height: 1.4,
                          ),
                        ),
                ),
              ],
            ),
          ),
        _Label('Start date', ext: ext, required: true),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPickStart,
          child: Container(
            padding: EdgeInsets.all(AppSpacing.md.w),
            decoration: BoxDecoration(
              color: ext.cardSurface,
              borderRadius: BorderRadius.circular(AppRadius.md.r),
              border: Border.all(
                color: ext.searchHintColor.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    draft.startDate == null
                        ? 'Select a date'
                        : _formatDate(draft.startDate!),
                    style: TextStyle(
                      color: draft.startDate == null
                          ? ext.searchHintColor
                          : ext.greetingColor,
                      fontSize: 14.sp,
                    ),
                  ),
                ),
                Icon(Icons.calendar_today_outlined,
                    size: 16.r, color: ext.searchHintColor),
              ],
            ),
          ),
        ),
        if (draft.endDate != null)
          Padding(
            padding: EdgeInsets.only(top: AppSpacing.sm.h),
            child: Text(
              // Derived, not a second field: two dates and a duration is one
              // number too many, and the review card has to agree with itself.
              'Ends ${_formatDate(draft.endDate!)}',
              style: TextStyle(color: ext.searchHintColor, fontSize: 12.sp),
            ),
          ),
      ],
    );
  }
}

const _kMonths = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _formatDate(DateTime d) => '${_kMonths[d.month - 1]} ${d.day}, ${d.year}';

// ── 5. Review ────────────────────────────────────────────────────────────────

class _ReviewStep extends StatelessWidget {
  const _ReviewStep({
    required this.draft,
    required this.ext,
    required this.onEdit,
    required this.onTermsChanged,
  });

  final CampaignDraft draft;
  final AppThemeExtension ext;
  final ValueChanged<int> onEdit;
  final ValueChanged<bool> onTermsChanged;

  @override
  Widget build(BuildContext context) {
    final total = draft.budgetMode == BudgetMode.daily
        ? draft.derived
        : draft.budgetValue;
    final daily = draft.budgetMode == BudgetMode.daily
        ? draft.budgetValue
        : draft.derived;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Heading('Review & Submit', ext: ext),
        _ReviewCard(
          title: '1. Campaign Type',
          ext: ext,
          onEdit: () => onEdit(0),
          rows: [
            ('Objective', draft.objective.label),
            ('Format', draft.format.label),
          ],
        ),
        _ReviewCard(
          title: '2. Creative',
          ext: ext,
          onEdit: () => onEdit(1),
          leading: draft.photos.isEmpty
              ? null
              : ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.sm.r),
                  child: XFileImage(draft.photos.first,
                      width: 48.w, height: 48.w, fit: BoxFit.cover),
                ),
          body: draft.headline.text.trim(),
          bodySub: draft.location.text.trim().isEmpty
              ? 'CTA: ${draft.ctaText.text.trim()}'
              : 'CTA: ${draft.ctaText.text.trim()}  ·  '
                  '${draft.location.text.trim()}',
        ),
        _ReviewCard(
          title: '3. Audience',
          ext: ext,
          onEdit: () => onEdit(2),
          rows: [
            (
              // Read back as what it is. It sat here as "Locations" beside a
              // creative that named no venue, which is how the one place a
              // campaign mentioned came to be the targeting.
              'Target areas',
              draft.targetLocations.map((p) => p.label).join(', '),
            ),
            ('Target Age',
                '${draft.ages.start.round()} – ${draft.ages.end.round()} years'),
            if (draft.interests.isNotEmpty)
              ('Interests', draft.interests.join(', ')),
            ('Audience', draft.audience[0].toUpperCase() +
                draft.audience.substring(1)),
          ],
        ),
        _ReviewCard(
          title: '4. Budget & Schedule',
          ext: ext,
          onEdit: () => onEdit(3),
          rows: [
            ('Daily Budget', 'GHS ${daily.toStringAsFixed(2)}'),
            ('Duration', '${draft.durationValue} days'),
            ('Total', 'GHS ${total.toStringAsFixed(2)}'),
            if (draft.startDate != null && draft.endDate != null)
              ('Schedule',
                  '${_formatDate(draft.startDate!)} – ${_formatDate(draft.endDate!)}'),
          ],
        ),
        SizedBox(height: AppSpacing.md.h),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onTermsChanged(!draft.agreedToTerms),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: draft.agreedToTerms,
                activeColor: ext.accentGold,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onChanged: (v) => onTermsChanged(v ?? false),
              ),
              SizedBox(width: AppSpacing.sm.w),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(top: 2.h),
                  child: Text(
                    'I agree to the Advertising Terms & Content Guidelines',
                    style: TextStyle(
                      color: ext.greetingColor, fontSize: 13.sp, height: 1.35,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.title,
    required this.ext,
    required this.onEdit,
    this.rows = const [],
    this.leading,
    this.body,
    this.bodySub,
  });

  final String title;
  final AppThemeExtension ext;
  final VoidCallback onEdit;
  final List<(String, String)> rows;
  final Widget? leading;
  final String? body;
  final String? bodySub;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: AppSpacing.md.h),
      padding: EdgeInsets.all(AppSpacing.lg.w),
      decoration: BoxDecoration(
        // Same outline-only card as the details screen — the review step is
        // showing the reader what that screen will show them.
        borderRadius: BorderRadius.circular(AppRadius.md.r),
        border: Border.all(
          color: ext.searchHintColor.withValues(alpha: 0.18),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: ext.greetingColor,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onEdit,
                child: Text(
                  'Edit',
                  style: TextStyle(
                    color: ext.accentGold,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.sm.h),
          if (body != null)
            Row(
              children: [
                if (leading != null) ...[
                  leading!,
                  SizedBox(width: AppSpacing.md.w),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        body!,
                        style: TextStyle(
                          color: ext.greetingColor,
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (bodySub != null)
                        Text(
                          bodySub!,
                          style: TextStyle(
                            color: ext.searchHintColor, fontSize: 12.sp,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          for (final (label, value) in rows)
            Padding(
              padding: EdgeInsets.only(bottom: 3.h),
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(
                    text: '$label: ',
                    style: TextStyle(
                      color: ext.greetingColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(text: value),
                ]),
                style: TextStyle(color: ext.searchHintColor, fontSize: 12.5.sp),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Submitted ────────────────────────────────────────────────────────────────

class CampaignSubmittedPage extends StatelessWidget {
  const CampaignSubmittedPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final page = Scaffold(
      backgroundColor: ext.homeBackground,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.xl.w),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 76.r,
                  height: 76.r,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: ext.accentGold.withValues(alpha: 0.14),
                  ),
                  child: Icon(Icons.check_rounded,
                      size: 34.r, color: ext.accentGold),
                ),
                SizedBox(height: AppSpacing.lg.h),
                Text(
                  'Campaign Submitted!',
                  style: TextStyle(
                    color: ext.greetingColor,
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: AppSpacing.sm.h),
                Text(
                  'Your campaign has been successfully sent for review. '
                  'Reviews are typically completed within 24 hours.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: ext.searchHintColor, fontSize: 13.sp, height: 1.5,
                  ),
                ),
                SizedBox(height: AppSpacing.lg.h),
                Container(
                  padding: EdgeInsets.all(AppSpacing.md.w),
                  decoration: BoxDecoration(
                    color: ext.accentGold.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(AppRadius.md.r),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'What happens next?',
                        style: TextStyle(
                          color: ext.accentGold,
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        // The 48 hours are real: an approved campaign that is
                        // not paid for within them lapses.
                        "You'll receive a push notification and email to make "
                        'payment within 48 hours. Your campaign will go live '
                        'once payment is confirmed.',
                        style: TextStyle(
                          color: ext.greetingColor,
                          fontSize: 12.5.sp,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: AppSpacing.xl.h),
                SizedBox(
                  height: 48.h,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ext.accentGold,
                      padding: EdgeInsets.symmetric(horizontal: 28.w),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999.r),
                      ),
                    ),
                    child: Text(
                      'Back to Campaigns',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return webWrap(page, backgroundColor: ext.homeBackground);
  }
}
