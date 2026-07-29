import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:skidoo_app/core/common/widgets/app_text_field.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/core/utils/snackbar_utils.dart';
import 'package:skidoo_app/core/validators/media_validator.dart';
import 'package:skidoo_app/features/admin/data/models/exchange_rates.dart';
import 'package:skidoo_app/features/admin/data/repositories/app_config_repository.dart';
import 'package:skidoo_app/features/ads/data/repositories/ads_repository.dart';
import 'package:skidoo_app/features/ads/presentation/pages/ads_checkout_page.dart';
import 'package:skidoo_app/core/common/widgets/xfile_image.dart';
import 'package:skidoo_app/core/utils/web_wrap.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:skidoo_app/core/theme/app_radius.dart';
import 'package:skidoo_app/core/theme/app_spacing.dart';

const _objectives = ['awareness', 'traffic', 'conversion'];
const _objectiveLabels = {
  'awareness': 'Brand Awareness',
  'traffic': 'Drive Traffic',
  'conversion': 'Conversions',
};
const _placements = [
  'event_feed',
  'search_results',
  'post_recognition',
  'profile_page',
  'request_board',
];
const _placementLabels = {
  'event_feed': 'Event Feed',
  'search_results': 'Search Results',
  'post_recognition': 'After Face Recognition',
  'profile_page': 'Photographer Profile',
  'request_board': 'Request Board',
};
const _audienceTypes = ['all', 'clients', 'photographers'];
const _audienceLabels = {
  'all': 'Everyone',
  'clients': 'Clients',
  'photographers': 'Photographers',
};
const _currencies = ['GHS', 'NGN', 'USD', 'ZAR', 'KES', 'EGP', 'XOF', 'RWF'];
const _eventTypes = [
  'Wedding',
  'Birthday',
  'Corporate',
  'Concert',
  'Graduation',
  'Engagement',
  'Baby Shower',
  'Other',
];

class CreateCampaignPage extends StatefulWidget {
  /// Pass [existingCampaignId] when the campaign shell already exists (e.g.
  /// promoted from a request). The wizard will skip Step 1 and start directly
  /// at Step 2 (Ad Set), with the campaign ID pre-filled.
  const CreateCampaignPage({super.key, this.existingCampaignId});
  final String? existingCampaignId;

  @override
  State<CreateCampaignPage> createState() => _CreateCampaignPageState();
}

class _CreateCampaignPageState extends State<CreateCampaignPage> {
  int _step = 0;
  bool _loading = false;

  // Step 1 — Campaign shell
  final _nameCtrl = TextEditingController();
  String _objective = _objectives[0];
  String _currency = _currencies[0];
  final _budgetCtrl = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;

  // Step 2 — Ad set
  String _placement = _placements[0];
  String _audience = _audienceTypes[0];
  String? _targetEventType;
  final _locationCtrl = TextEditingController();
  final _dailyBudgetCtrl = TextEditingController();

  // Step 3 — Creative
  final _headlineCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _ctaTextCtrl = TextEditingController();
  final _ctaLinkCtrl = TextEditingController();

  // Step 3 — Creative media
  final List<XFile> _creatives = [];
  static const _maxCreatives = 5;
  bool _commentsEnabled = true;

  // Stored IDs from API calls
  String? _campaignId;
  String? _adsetId;

  final _repo = AdsRepository();
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final preFilledId = widget.existingCampaignId;
    if (preFilledId != null && preFilledId.isNotEmpty) {
      _campaignId = preFilledId;
      _step = 1;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _budgetCtrl.dispose();
    _locationCtrl.dispose();
    _dailyBudgetCtrl.dispose();
    _headlineCtrl.dispose();
    _bodyCtrl.dispose();
    _ctaTextCtrl.dispose();
    _ctaLinkCtrl.dispose();
    super.dispose();
  }

  String? _validateStep() {
    switch (_step) {
      case 0:
        if (_nameCtrl.text.trim().isEmpty) return 'Campaign name is required.';
        final budget = double.tryParse(_budgetCtrl.text.trim());
        if (budget == null || budget <= 0) return 'Enter a valid total budget.';
        final budgetGhs = AppConfigRepository.rates.toGhs(budget, _currency);
        final minGhs = AppConfigRepository.current.minCampaignBudgetGhs;
        if (budgetGhs < minGhs) {
          return 'Minimum budget is ${ExchangeRates.formatGhs(minGhs)}.';
        }
      case 1:
        final daily = double.tryParse(_dailyBudgetCtrl.text.trim());
        if (daily == null || daily <= 0) return 'Enter a valid daily budget.';
      case 2:
        if (_headlineCtrl.text.trim().isEmpty) return 'Headline is required.';
        final link = _ctaLinkCtrl.text.trim();
        if (link.isEmpty) return 'CTA link is required.';
        final uri = Uri.tryParse(link);
        if (uri == null || !uri.hasScheme) {
          return 'CTA link must start with https://.';
        }
    }
    return null;
  }

  Future<void> _nextStep() async {
    debugPrint('[CreateCampaignPage] _nextStep — current step=$_step');
    final validationError = _validateStep();
    if (validationError != null) {
      AppSnackBar.error(context, validationError);
      return;
    }
    setState(() => _loading = true);
    try {
      switch (_step) {
        case 0:
          await _createCampaignShell();
        case 1:
          await _createAdSet();
        case 2:
          await _createAd();
        case 3:
          await _pay();
          return;
      }
      debugPrint('[CreateCampaignPage] advancing to step ${_step + 1}');
      setState(() => _step++);
    } catch (e) {
      debugPrint('[CreateCampaignPage] _nextStep ERROR at step=$_step: $e');
      if (!mounted) return;
      AppSnackBar.error(context, 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createCampaignShell() async {
    debugPrint(
        '[CreateCampaignPage] _createCampaignShell name="${_nameCtrl.text.trim()}" objective=$_objective budget=${_budgetCtrl.text.trim()} currency=$_currency');
    final result = await _repo.createCampaign(
      name: _nameCtrl.text.trim(),
      objective: _objective,
      budgetAmount: double.tryParse(_budgetCtrl.text.trim()) ?? 0,
      currency: _currency,
      startAt: _startDate?.toUtc().toIso8601String(),
      endAt: _endDate?.toUtc().toIso8601String(),
    );
    _campaignId = result.id;
    debugPrint(
        '[CreateCampaignPage] _createCampaignShell — campaignId=$_campaignId');
    if (_campaignId!.isEmpty) {
      throw Exception('Campaign creation failed — no ID returned.');
    }
  }

  Future<void> _createAdSet() async {
    debugPrint(
        '[CreateCampaignPage] _createAdSet campaignId=$_campaignId placement=$_placement audience=$_audience');
    final result = await _repo.createAdSet(
      campaignId: _campaignId!,
      name:
          '${_nameCtrl.text.trim()} — ${_placementLabels[_placement] ?? _placement}',
      placement: _placement,
      dailyBudget: double.tryParse(_dailyBudgetCtrl.text.trim()) ?? 0,
      audience: _audience,
      eventTypes: _targetEventType != null ? [_targetEventType!] : [],
      locations: _locationCtrl.text.trim().isNotEmpty
          ? [_locationCtrl.text.trim()]
          : [],
    );
    _adsetId = result.id;
    debugPrint('[CreateCampaignPage] _createAdSet — adsetId=$_adsetId');
    if (_adsetId!.isEmpty) {
      throw Exception('Ad set creation failed — no ID returned.');
    }
  }

  Future<void> _createAd() async {
    final mediaType = _creatives.isNotEmpty ? 'image' : 'text';
    debugPrint(
        '[CreateCampaignPage] _createAd adsetId=$_adsetId headline="${_headlineCtrl.text.trim()}" mediaType=$mediaType');
    final result = await _repo.createAd(
      adsetId: _adsetId!,
      headline: _headlineCtrl.text.trim(),
      body: _bodyCtrl.text.trim(),
      mediaType: mediaType,
      ctaText: _ctaTextCtrl.text.trim().isEmpty
          ? 'Learn More'
          : _ctaTextCtrl.text.trim(),
      ctaUrl: _ctaLinkCtrl.text.trim(),
      commentsEnabled: _commentsEnabled,
    );
    final adId = result.id;
    debugPrint('[CreateCampaignPage] _createAd — adId=$adId');
    if (adId.isEmpty) {
      throw Exception('Ad creation failed — no ID returned.');
    }
    if (_creatives.isNotEmpty) {
      // Upload images at the campaign level so campaign.media is populated in
      // the API response. The ad-creative endpoint replaces rather than appends,
      // so sending N files there would only keep the last one.
      debugPrint(
          '[CreateCampaignPage] _createAd — uploading ${_creatives.length} image(s) to campaignId=$_campaignId');
      for (final file in _creatives) {
        final count = await _repo.uploadCampaignMedia(_campaignId!, file);
        debugPrint(
            '[CreateCampaignPage] _createAd — media_count after upload: $count');
      }
    }
  }

  Future<void> _pickCreative() async {
    if (_creatives.length >= _maxCreatives) return;
    final remaining = _maxCreatives - _creatives.length;
    final picked =
        await _picker.pickMultiImage(imageQuality: 85, limit: remaining);
    if (picked.isEmpty || !mounted) return;

    final valid = <XFile>[];
    for (final file in picked) {
      final error = await MediaValidator.validate(file, isVideo: false);
      if (!mounted) return;
      if (error != null) {
        AppSnackBar.error(context, error);
        return;
      }
      valid.add(file);
    }
    if (!mounted) return;
    setState(() => _creatives.addAll(valid));
  }

  void _removeCreative(int index) {
    setState(() => _creatives.removeAt(index));
  }

  Future<void> _pay() async {
    debugPrint(
        '[CreateCampaignPage] _pay — requesting authorization URL for campaignId=$_campaignId');
    final result = await _repo.payCampaign(_campaignId!);
    debugPrint(
      '[CreateCampaignPage] _pay — authorization_url="${result.authorizationUrl.isEmpty ? 'EMPTY' : result.authorizationUrl}" '
      'reference="${result.reference}"',
    );
    if (!mounted) return;
    if (result.authorizationUrl.isEmpty) {
      AppSnackBar.error(
          context, 'Could not get payment URL. Please try again.');
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdsCheckoutPage(
          authorizationUrl: result.authorizationUrl,
          reference: result.reference,
          amountGhs: result.amountGhs,
          originalAmount: result.originalAmount,
          originalCurrency: result.originalCurrency,
          onSuccess: () {},
        ),
      ),
    );
    if (!mounted) return;
    try {
      final verify = await _repo.verifyPayment(_campaignId!);
      debugPrint(
          '[CreateCampaignPage] _pay verify — success=${verify.success} status=${verify.status}');
      if (!mounted) return;
      if (verify.success) {
        AppSnackBar.success(
          context,
          verify.message.isNotEmpty
              ? verify.message
              : 'Payment confirmed! Your campaign is under review.',
        );
        Navigator.of(context).popUntil((r) => r.isFirst);
      }
    } catch (e) {
      debugPrint('[CreateCampaignPage] _pay verifyPayment ERROR: $e');
    }
  }

  Future<void> _pickDate(bool isStart) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
      } else {
        _endDate = picked;
      }
    });
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
                icon: Icon(Icons.arrow_back_ios_new_rounded,
                    color: ext.greetingColor, size: 20.sp),
                onPressed: () => Navigator.of(context).pop(),
              ),
        title: Text(
          'Create Campaign',
          style: TextStyle(
            color: ext.greetingColor,
            fontSize: 17.sp,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(52.h),
          child: _StepIndicator(currentStep: _step, ext: ext),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _buildStep(context, ext),
            ),
          ),
          _BottomBar(
            step: _step,
            loading: _loading,
            onNext: _nextStep,
            onBack: _step > 0 ? () => setState(() => _step--) : null,
            ext: ext,
          ),
        ],
      ),
    );
    return webWrap(page, backgroundColor: ext.homeBackground);
  }

  Widget _buildStep(BuildContext context, AppThemeExtension ext) {
    switch (_step) {
      case 0:
        return _Step1(
          key: const ValueKey(0),
          nameCtrl: _nameCtrl,
          budgetCtrl: _budgetCtrl,
          objective: _objective,
          currency: _currency,
          startDate: _startDate,
          endDate: _endDate,
          ext: ext,
          onObjectiveChanged: (v) =>
              setState(() => _objective = v ?? _objectives[0]),
          onCurrencyChanged: (v) =>
              setState(() => _currency = v ?? _currencies[0]),
          onPickStart: () => _pickDate(true),
          onPickEnd: () => _pickDate(false),
        );
      case 1:
        return _Step2(
          key: const ValueKey(1),
          placement: _placement,
          audience: _audience,
          targetEventType: _targetEventType,
          locationCtrl: _locationCtrl,
          dailyBudgetCtrl: _dailyBudgetCtrl,
          ext: ext,
          onPlacementChanged: (v) =>
              setState(() => _placement = v ?? _placements[0]),
          onAudienceChanged: (v) =>
              setState(() => _audience = v ?? _audienceTypes[0]),
          onEventTypeChanged: (v) => setState(() => _targetEventType = v),
        );
      case 2:
        return _Step3(
          key: const ValueKey(2),
          headlineCtrl: _headlineCtrl,
          bodyCtrl: _bodyCtrl,
          ctaTextCtrl: _ctaTextCtrl,
          ctaLinkCtrl: _ctaLinkCtrl,
          creatives: _creatives,
          maxCreatives: _maxCreatives,
          commentsEnabled: _commentsEnabled,
          onCommentsToggle: (v) => setState(() => _commentsEnabled = v),
          ext: ext,
          onPickCreative: _pickCreative,
          onRemoveCreative: _removeCreative,
        );
      case 3:
        return _Step4(
          key: const ValueKey(3),
          // Campaign
          name: _nameCtrl.text.trim(),
          objective: _objective,
          budget: _budgetCtrl.text.trim(),
          currency: _currency,
          startDate: _startDate,
          endDate: _endDate,
          // Ad set
          placement: _placement,
          audience: _audience,
          dailyBudget: _dailyBudgetCtrl.text.trim(),
          targetEventType: _targetEventType,
          location: _locationCtrl.text.trim(),
          // Creative
          headline: _headlineCtrl.text.trim(),
          body: _bodyCtrl.text.trim(),
          ctaText: _ctaTextCtrl.text.trim().isEmpty
              ? 'Learn More'
              : _ctaTextCtrl.text.trim(),
          ctaLink: _ctaLinkCtrl.text.trim(),
          mediaCount: _creatives.length,
          commentsEnabled: _commentsEnabled,
          ext: ext,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

// ── Step indicator ─────────────────────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.currentStep, required this.ext});
  final int currentStep;
  final AppThemeExtension ext;

  static const _labels = ['Campaign', 'Targeting', 'Creative', 'Review'];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 12.h),
      child: Row(
        children: List.generate(_labels.length * 2 - 1, (i) {
          if (i.isOdd) {
            final stepIdx = i ~/ 2;
            final done = stepIdx < currentStep;
            return Expanded(
              child: Container(
                height: 2.h,
                color: done
                    ? ext.accentGold
                    : ext.searchHintColor.withValues(alpha: 0.2),
              ),
            );
          }
          final stepIdx = i ~/ 2;
          final done = stepIdx < currentStep;
          final active = stepIdx == currentStep;
          return _StepDot(
            label: _labels[stepIdx],
            done: done,
            active: active,
            ext: ext,
          );
        }),
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({
    required this.label,
    required this.done,
    required this.active,
    required this.ext,
  });
  final String label;
  final bool done;
  final bool active;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 22.w,
          height: 22.w,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done || active ? ext.accentGold : ext.searchFieldFill,
          ),
          alignment: Alignment.center,
          child: done
              ? Icon(Icons.check_rounded, color: Colors.white, size: 12.sp)
              : Text(
                  '${_StepIndicator._labels.indexOf(label) + 1}',
                  style: TextStyle(
                    color: active ? Colors.white : ext.searchHintColor,
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
        SizedBox(height: 3.h),
        Text(
          label,
          style: TextStyle(
            color: active || done ? ext.greetingColor : ext.searchHintColor,
            fontSize: 9.sp,
            fontWeight: active ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

// ── Bottom action bar ─────────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.step,
    required this.loading,
    required this.onNext,
    required this.onBack,
    required this.ext,
  });
  final int step;
  final bool loading;
  final VoidCallback onNext;
  final VoidCallback? onBack;
  final AppThemeExtension ext;

  static const _nextLabels = [
    'Continue',
    'Continue',
    'Continue',
    'Pay & Launch',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 24.h),
      decoration: BoxDecoration(
        color: ext.homeBackground,
        border: Border(
          top: BorderSide(
            color: ext.searchHintColor.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: Row(
        children: [
          if (onBack != null)
            Semantics(
                button: true,
                label: 'Back',
                child: GestureDetector(
                  onTap: onBack,
                  child: Container(
                    width: 48.w,
                    height: 50.h,
                    decoration: BoxDecoration(
                      color: ext.searchFieldFill,
                      borderRadius: BorderRadius.circular(AppRadius.md.r),
                    ),
                    alignment: Alignment.center,
                    child: Icon(Icons.arrow_back_rounded,
                        color: ext.greetingColor, size: 20.sp),
                  ),
                )),
          if (onBack != null) SizedBox(width: AppSpacing.md.w),
          Expanded(
            child: Semantics(
                button: true,
                label: 'Next',
                child: GestureDetector(
                  onTap: loading ? null : onNext,
                  child: Container(
                    height: 50.h,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: loading
                            ? [
                                ext.accentGold.withValues(alpha: 0.5),
                                ext.accentGoldDark.withValues(alpha: 0.5),
                              ]
                            : [ext.accentGold, ext.accentGoldDark],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                    alignment: Alignment.center,
                    child: loading
                        ? SizedBox(
                            width: 20.w,
                            height: 20.w,
                            child: const CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _nextLabels[step],
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              if (step == 3) ...[
                                SizedBox(width: 6.w),
                                Icon(Icons.lock_rounded,
                                    color: Colors.white, size: 15.sp),
                              ],
                            ],
                          ),
                  ),
                )),
          ),
        ],
      ),
    );
  }
}

// ── Step 1: Campaign shell ────────────────────────────────────────────────────

class _Step1 extends StatelessWidget {
  const _Step1({
    super.key,
    required this.nameCtrl,
    required this.budgetCtrl,
    required this.objective,
    required this.currency,
    required this.startDate,
    required this.endDate,
    required this.ext,
    required this.onObjectiveChanged,
    required this.onCurrencyChanged,
    required this.onPickStart,
    required this.onPickEnd,
  });

  final TextEditingController nameCtrl;
  final TextEditingController budgetCtrl;
  final String objective;
  final String currency;
  final DateTime? startDate;
  final DateTime? endDate;
  final AppThemeExtension ext;
  final ValueChanged<String?> onObjectiveChanged;
  final ValueChanged<String?> onCurrencyChanged;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;

  @override
  Widget build(BuildContext context) {
    return _StepScroll(
      ext: ext,
      stepTitle: 'Campaign Details',
      stepSubtitle: 'Set your campaign name, goal, and budget.',
      children: [
        _CLabel('Campaign name', ext),
        SizedBox(height: AppSpacing.sm.h),
        _CField(
            controller: nameCtrl, hint: 'e.g. Summer Wedding Promo', ext: ext),
        SizedBox(height: AppSpacing.xl.h),
        _CLabel('Objective', ext),
        SizedBox(height: AppSpacing.sm.h),
        _CDropdown<String>(
          value: objective,
          items: _objectives,
          itemLabel: (v) => _objectiveLabels[v] ?? v,
          ext: ext,
          onChanged: onObjectiveChanged,
        ),
        SizedBox(height: AppSpacing.xl.h),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CLabel('Total budget', ext),
                  SizedBox(height: AppSpacing.sm.h),
                  _CField(
                    controller: budgetCtrl,
                    hint: 'e.g. 1000',
                    ext: ext,
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CLabel('Currency', ext),
                  SizedBox(height: AppSpacing.sm.h),
                  _CDropdown<String>(
                    value: currency,
                    items: _currencies,
                    itemLabel: (v) => v,
                    ext: ext,
                    onChanged: onCurrencyChanged,
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: AppSpacing.xl.h),
        _CLabel('Campaign dates (optional)', ext),
        SizedBox(height: AppSpacing.sm.h),
        Row(
          children: [
            Expanded(
              child: _DatePickerTile(
                label: startDate == null
                    ? 'Start date'
                    : '${startDate!.day}/${startDate!.month}/${startDate!.year}',
                ext: ext,
                onTap: onPickStart,
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: _DatePickerTile(
                label: endDate == null
                    ? 'End date'
                    : '${endDate!.day}/${endDate!.month}/${endDate!.year}',
                ext: ext,
                onTap: onPickEnd,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Step 2: Targeting ─────────────────────────────────────────────────────────

class _Step2 extends StatelessWidget {
  const _Step2({
    super.key,
    required this.placement,
    required this.audience,
    required this.targetEventType,
    required this.locationCtrl,
    required this.dailyBudgetCtrl,
    required this.ext,
    required this.onPlacementChanged,
    required this.onAudienceChanged,
    required this.onEventTypeChanged,
  });

  final String placement;
  final String audience;
  final String? targetEventType;
  final TextEditingController locationCtrl;
  final TextEditingController dailyBudgetCtrl;
  final AppThemeExtension ext;
  final ValueChanged<String?> onPlacementChanged;
  final ValueChanged<String?> onAudienceChanged;
  final ValueChanged<String?> onEventTypeChanged;

  @override
  Widget build(BuildContext context) {
    return _StepScroll(
      ext: ext,
      stepTitle: 'Targeting',
      stepSubtitle: 'Choose where and who sees your ad.',
      children: [
        _CLabel('Placement', ext),
        SizedBox(height: AppSpacing.sm.h),
        _CDropdown<String>(
          value: placement,
          items: _placements,
          itemLabel: (v) => _placementLabels[v] ?? v,
          ext: ext,
          onChanged: onPlacementChanged,
        ),
        SizedBox(height: AppSpacing.xl.h),
        _CLabel('Audience', ext),
        SizedBox(height: AppSpacing.sm.h),
        _CDropdown<String>(
          value: audience,
          items: _audienceTypes,
          itemLabel: (v) => _audienceLabels[v] ?? v,
          ext: ext,
          onChanged: onAudienceChanged,
        ),
        SizedBox(height: AppSpacing.xl.h),
        _CLabel('Daily budget', ext),
        SizedBox(height: AppSpacing.sm.h),
        _CField(
          controller: dailyBudgetCtrl,
          hint: 'e.g. 50',
          ext: ext,
          keyboardType: TextInputType.number,
        ),
        SizedBox(height: AppSpacing.xl.h),
        _CLabel('Target event type (optional)', ext),
        SizedBox(height: AppSpacing.sm.h),
        _CDropdown<String>(
          value: targetEventType,
          items: _eventTypes,
          itemLabel: (v) => v,
          ext: ext,
          onChanged: onEventTypeChanged,
          hint: 'Any event type',
          nullable: true,
        ),
        SizedBox(height: AppSpacing.xl.h),
        _CLabel('Target location (optional)', ext),
        SizedBox(height: AppSpacing.sm.h),
        _CField(controller: locationCtrl, hint: 'e.g. Accra', ext: ext),
      ],
    );
  }
}

// ── Step 3: Creative ──────────────────────────────────────────────────────────

class _Step3 extends StatelessWidget {
  const _Step3({
    super.key,
    required this.headlineCtrl,
    required this.bodyCtrl,
    required this.ctaTextCtrl,
    required this.ctaLinkCtrl,
    required this.creatives,
    required this.maxCreatives,
    required this.commentsEnabled,
    required this.onCommentsToggle,
    required this.ext,
    required this.onPickCreative,
    required this.onRemoveCreative,
  });

  final TextEditingController headlineCtrl;
  final TextEditingController bodyCtrl;
  final TextEditingController ctaTextCtrl;
  final TextEditingController ctaLinkCtrl;
  final List<XFile> creatives;
  final int maxCreatives;
  final bool commentsEnabled;
  final ValueChanged<bool> onCommentsToggle;
  final AppThemeExtension ext;
  final VoidCallback onPickCreative;
  final void Function(int) onRemoveCreative;

  @override
  Widget build(BuildContext context) {
    return _StepScroll(
      ext: ext,
      stepTitle: 'Your Ad',
      stepSubtitle: 'Write what people will see in the feed.',
      children: [
        _CLabel('Headline', ext),
        SizedBox(height: AppSpacing.sm.h),
        _CField(
          controller: headlineCtrl,
          hint: 'Grab attention in one line',
          ext: ext,
        ),
        SizedBox(height: AppSpacing.xl.h),
        _CLabel('Body text', ext),
        SizedBox(height: AppSpacing.sm.h),
        _CField(
          controller: bodyCtrl,
          hint: 'Describe what you offer...',
          ext: ext,
          maxLines: 3,
        ),
        SizedBox(height: AppSpacing.xl.h),
        Row(
          children: [
            _CLabel('Creative photos', ext),
            SizedBox(width: 6.w),
            Text('(optional)',
                style: TextStyle(color: ext.searchHintColor, fontSize: 12.sp)),
            const Spacer(),
            Text(
              '${creatives.length}/$maxCreatives',
              style: TextStyle(
                color: ext.searchHintColor,
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        SizedBox(height: AppSpacing.xs.h),
        Text(
          'Select up to 5 photos at once to make your ad stand out.',
          style: TextStyle(color: ext.searchHintColor, fontSize: 12.sp),
        ),
        SizedBox(height: 10.h),
        _CampaignMultiPicker(
          creatives: creatives,
          maxCreatives: maxCreatives,
          ext: ext,
          onAdd: onPickCreative,
          onRemove: onRemoveCreative,
        ),
        SizedBox(height: AppSpacing.xl.h),
        _CLabel('CTA button text (optional)', ext),
        SizedBox(height: AppSpacing.sm.h),
        _CField(
          controller: ctaTextCtrl,
          hint: 'e.g. Book Now · View Gallery · Learn More',
          ext: ext,
        ),
        SizedBox(height: AppSpacing.xl.h),
        _CLabel('CTA link', ext),
        SizedBox(height: AppSpacing.sm.h),
        _CField(
          controller: ctaLinkCtrl,
          hint: 'https://',
          ext: ext,
          keyboardType: TextInputType.url,
        ),
        SizedBox(height: AppSpacing.lg.h),
        SwitchListTile(
          value: commentsEnabled,
          onChanged: onCommentsToggle,
          title: Text(
            'Allow comments',
            style: TextStyle(color: ext.greetingColor, fontSize: 14.sp),
          ),
          subtitle: Text(
            'Let viewers comment on this ad',
            style: TextStyle(color: ext.searchHintColor, fontSize: 12.sp),
          ),
          activeThumbColor: ext.accentGold,
          contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.xs.w),
        ),
      ],
    );
  }
}

// ── Step 4: Review & Pay ──────────────────────────────────────────────────────

class _Step4 extends StatelessWidget {
  const _Step4({
    super.key,
    // Campaign
    required this.name,
    required this.objective,
    required this.budget,
    required this.currency,
    required this.startDate,
    required this.endDate,
    // Ad set
    required this.placement,
    required this.audience,
    required this.dailyBudget,
    required this.targetEventType,
    required this.location,
    // Creative
    required this.headline,
    required this.body,
    required this.ctaText,
    required this.ctaLink,
    required this.mediaCount,
    required this.commentsEnabled,
    required this.ext,
  });

  final String name;
  final String objective;
  final String budget;
  final String currency;
  final DateTime? startDate;
  final DateTime? endDate;
  final String placement;
  final String audience;
  final String dailyBudget;
  final String? targetEventType;
  final String location;
  final String headline;
  final String body;
  final String ctaText;
  final String ctaLink;
  final int mediaCount;
  final bool commentsEnabled;
  final AppThemeExtension ext;

  String _fmt(DateTime d) => '${d.day}/${d.month}/${d.year}';

  @override
  Widget build(BuildContext context) {
    String budgetDisplay = budget.isEmpty ? '—' : '$currency $budget';
    if (budget.isNotEmpty && currency != 'GHS') {
      final amount = double.tryParse(budget);
      if (amount != null) {
        final ghsAmount = AppConfigRepository.rates.toGhs(amount, currency);
        budgetDisplay =
            '$currency $budget  ≈  ${ExchangeRates.formatGhs(ghsAmount)} (est.)';
      }
    }

    String dailyDisplay = dailyBudget.isEmpty ? '—' : '$currency $dailyBudget';
    if (dailyBudget.isNotEmpty && currency != 'GHS') {
      final amount = double.tryParse(dailyBudget);
      if (amount != null) {
        final ghsAmount = AppConfigRepository.rates.toGhs(amount, currency);
        dailyDisplay =
            '$currency $dailyBudget  ≈  ${ExchangeRates.formatGhs(ghsAmount)}/day (est.)';
      }
    }

    return _StepScroll(
      ext: ext,
      stepTitle: 'Review & Pay',
      stepSubtitle:
          'Your campaign will go live after payment and admin approval.',
      children: [
        // ── Campaign ────────────────────────────────────────────────────────
        _SectionLabel('Campaign', ext),
        SizedBox(height: 10.h),
        _ReviewRow('Name', name.isEmpty ? '—' : name, ext),
        _ReviewRow('Objective', _objectiveLabels[objective] ?? objective, ext),
        _ReviewRow('Total budget', budgetDisplay, ext),
        _ReviewRow('Start date',
            startDate != null ? _fmt(startDate!) : 'Not set', ext),
        _ReviewRow(
            'End date', endDate != null ? _fmt(endDate!) : 'Not set', ext),

        SizedBox(height: AppSpacing.xl.h),

        // ── Ad Set ──────────────────────────────────────────────────────────
        _SectionLabel('Targeting', ext),
        SizedBox(height: 10.h),
        _ReviewRow('Placement', _placementLabels[placement] ?? placement, ext),
        _ReviewRow('Audience', _audienceLabels[audience] ?? audience, ext),
        _ReviewRow('Daily budget', dailyDisplay, ext),
        _ReviewRow('Event type', targetEventType ?? 'Any', ext),
        _ReviewRow('Location', location.isEmpty ? 'Any' : location, ext),

        SizedBox(height: AppSpacing.xl.h),

        // ── Creative ────────────────────────────────────────────────────────
        _SectionLabel('Creative', ext),
        SizedBox(height: 10.h),
        _ReviewRow('Headline', headline.isEmpty ? '—' : headline, ext),
        _ReviewRow('Body', body.isEmpty ? '—' : body, ext),
        _ReviewRow('CTA button', ctaText, ext),
        _ReviewRow('CTA link', ctaLink.isEmpty ? '—' : ctaLink, ext),
        _ReviewRow(
            'Photos',
            mediaCount == 0
                ? 'None (text-only)'
                : '$mediaCount image${mediaCount == 1 ? '' : 's'}',
            ext),
        _ReviewRow('Comments', commentsEnabled ? 'Enabled' : 'Disabled', ext),

        SizedBox(height: AppSpacing.xxl.h),
        Container(
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            color: ext.accentGold.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppRadius.md.r),
            border: Border.all(
              color: ext.accentGold.withValues(alpha: 0.3),
              width: 0.8,
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.lock_outline_rounded,
                  color: ext.accentGold, size: 16.sp),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  'Tapping "Pay & Launch" will open the Paystack payment page. After payment, your campaign moves to admin review.',
                  style: TextStyle(
                    color: ext.greetingColor.withValues(alpha: 0.72),
                    fontSize: 12.sp,
                    height: 1.5,
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, this.ext);
  final String text;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        color: ext.searchHintColor,
        fontSize: 11.sp,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow(this.label, this.value, this.ext);
  final String label;
  final String value;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.sm.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90.w,
            child: Text(
              label,
              style: TextStyle(
                color: ext.searchHintColor,
                fontSize: 13.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: ext.greetingColor,
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared step scroll wrapper ────────────────────────────────────────────────

class _StepScroll extends StatelessWidget {
  const _StepScroll({
    required this.ext,
    required this.stepTitle,
    required this.stepSubtitle,
    required this.children,
  });

  final AppThemeExtension ext;
  final String stepTitle;
  final String stepSubtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 8.h),
      children: [
        Text(
          stepTitle,
          style: TextStyle(
            color: ext.greetingColor,
            fontSize: 20.sp,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.4,
          ),
        ),
        SizedBox(height: AppSpacing.xs.h),
        Text(
          stepSubtitle,
          style: TextStyle(
            color: ext.searchHintColor,
            fontSize: 13.sp,
          ),
        ),
        SizedBox(height: AppSpacing.xxl.h),
        ...children,
      ],
    );
  }
}

// ── Shared form controls for campaign wizard ──────────────────────────────────

class _CLabel extends StatelessWidget {
  const _CLabel(this.text, this.ext);
  final String text;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: ext.greetingColor,
        fontSize: 13.sp,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _CField extends StatelessWidget {
  const _CField({
    required this.controller,
    required this.hint,
    required this.ext,
    this.maxLines = 1,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String hint;
  final AppThemeExtension ext;
  final int maxLines;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType ?? TextInputType.text,
      dense: true,
      hint: hint,
    );
  }
}

class _CDropdown<T> extends StatelessWidget {
  const _CDropdown({
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.ext,
    required this.onChanged,
    this.hint,
    this.nullable = false,
  });

  final T? value;
  final List<T> items;
  final String Function(T) itemLabel;
  final AppThemeExtension ext;
  final ValueChanged<T?> onChanged;
  final String? hint;
  final bool nullable;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w),
      decoration: BoxDecoration(
        color: ext.searchFieldFill,
        borderRadius: BorderRadius.circular(AppRadius.md.r),
      ),
      child: DropdownButton<T>(
        value: value,
        isExpanded: true,
        underline: const SizedBox.shrink(),
        dropdownColor: ext.cardSurface,
        style: TextStyle(color: ext.greetingColor, fontSize: 14.sp),
        icon: Icon(Icons.expand_more_rounded,
            color: ext.searchHintColor, size: 20.sp),
        hint: hint != null
            ? Text(hint!,
                style: TextStyle(color: ext.searchHintColor, fontSize: 14.sp))
            : null,
        items: [
          if (nullable)
            DropdownMenuItem<T>(
              value: null,
              child: Text(
                hint ?? 'None',
                style: TextStyle(color: ext.searchHintColor, fontSize: 14.sp),
              ),
            ),
          ...items.map(
            (t) => DropdownMenuItem<T>(
              value: t,
              child: Text(itemLabel(t)),
            ),
          ),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

// ── Campaign multi-image picker ───────────────────────────────────────────────

class _CampaignMultiPicker extends StatelessWidget {
  const _CampaignMultiPicker({
    required this.creatives,
    required this.maxCreatives,
    required this.ext,
    required this.onAdd,
    required this.onRemove,
  });

  final List<XFile> creatives;
  final int maxCreatives;
  final AppThemeExtension ext;
  final VoidCallback onAdd;
  final void Function(int index) onRemove;

  static const _thumbSize = 90.0;

  @override
  Widget build(BuildContext context) {
    final atLimit = creatives.length >= maxCreatives;
    return SizedBox(
      height: _thumbSize,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          ...List.generate(creatives.length, (i) {
            return Padding(
              padding: EdgeInsets.only(right: AppSpacing.sm.w),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10.r),
                    child: XFileImage(
                      creatives[i],
                      width: _thumbSize,
                      height: _thumbSize,
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Semantics(
                        button: true,
                        label: 'Remove media',
                        child: GestureDetector(
                          onTap: () => onRemove(i),
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.65),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.close_rounded,
                                color: Colors.white, size: 14.sp),
                          ),
                        )),
                  ),
                ],
              ),
            );
          }),
          if (!atLimit)
            Semantics(
                button: true,
                label: 'Add',
                child: GestureDetector(
                  onTap: onAdd,
                  child: Container(
                    width: _thumbSize,
                    height: _thumbSize,
                    decoration: BoxDecoration(
                      color: ext.searchFieldFill,
                      borderRadius: BorderRadius.circular(10.r),
                      border: Border.all(
                        color: ext.searchHintColor.withValues(alpha: 0.25),
                        width: 1.2,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate_outlined,
                            color: ext.accentGold, size: 26.sp),
                        SizedBox(height: AppSpacing.xs.h),
                        Text(
                          'Add Photos',
                          style: TextStyle(
                            color: ext.searchHintColor,
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                )),
        ],
      ),
    );
  }
}

class _DatePickerTile extends StatelessWidget {
  const _DatePickerTile({
    required this.label,
    required this.ext,
    required this.onTap,
  });
  final String label;
  final AppThemeExtension ext;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
        button: true,
        label: label,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 13.h),
            decoration: BoxDecoration(
              color: ext.searchFieldFill,
              borderRadius: BorderRadius.circular(AppRadius.md.r),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today_outlined,
                    color: ext.searchHintColor, size: 16.sp),
                SizedBox(width: AppSpacing.sm.w),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: ext.searchHintColor,
                      fontSize: 13.sp,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ));
  }
}
