import 'dart:io' show File;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/common/widgets/app_widgets.dart';
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/utils/image_pick.dart';
import 'package:jperg_app/core/utils/snackbar_utils.dart';
import 'package:jperg_app/core/utils/web_wrap.dart';
import 'package:jperg_app/features/ads/data/repositories/ads_repository.dart';
import 'package:jperg_app/features/ads/models/ad_campaign.dart';
import 'package:jperg_app/features/ads/models/ad_media.dart';
import 'package:jperg_app/features/ads/presentation/pages/campaign_wizard_page.dart';

/// Edit Campaign — the whole wizard on one page.
///
/// Not a wizard, deliberately: this is for changing one thing about something
/// that already exists, most often a duplicate whose dates were left off on
/// purpose. Stepping through five screens to correct a headline is the wrong
/// shape for that, and the design draws it as a single form.
class EditCampaignFormPage extends StatefulWidget {
  const EditCampaignFormPage({super.key, required this.campaign});

  final AdCampaign campaign;

  @override
  State<EditCampaignFormPage> createState() => _EditCampaignFormPageState();
}

class _EditCampaignFormPageState extends State<EditCampaignFormPage> {
  final _repo = AdsRepository();

  late final _headline = TextEditingController(text: _c.headline ?? _c.name);
  late final _copy = TextEditingController(text: _c.body ?? '');
  late final _ctaText = TextEditingController(text: _c.ctaText ?? 'Book Now');
  late final _ctaUrl = TextEditingController(text: _c.ctaUrl ?? '');
  late final _budget = TextEditingController(
    text: (_c.budgetMode == BudgetMode.daily
            ? (_c.dailyBudget ?? _c.budgetAmount)
            : _c.budgetAmount)
        .toStringAsFixed(2),
  );
  late final _duration =
      TextEditingController(text: '${_c.durationDays ?? 14}');

  late CampaignObjective _objective = _c.objective;
  late CampaignFormat _format = _c.format;
  late BudgetMode _budgetMode = _c.budgetMode;
  late final _placements = _c.placements.isEmpty
      ? <String>{'event_feed'}
      : _c.placements.toSet();
  // Prefilled from the campaign. Opening on empty chips and then saving would
  // write the emptiness back over whatever the wizard chose.
  late final _locations = _c.locations.toSet();
  late final _interests = _c.interests.toSet();
  late String _audience = _c.audience;
  // Prefilled from the campaign, falling back to the widest band rather than a
  // narrower guess that would silently shrink the audience on save.
  late RangeValues _ages = RangeValues(
    (_c.ageMin ?? 18).toDouble(),
    (_c.ageMax ?? 65).toDouble(),
  );

  /// Media already on the server, and the files picked in this session. Kept
  /// apart because removing one is a DELETE and removing the other is just
  /// forgetting it.
  late List<AdMedia> _existing = List.of(_c.media);
  final _added = <XFile>[];
  final _removed = <String>{};

  late DateTime? _startDate = _c.startAt;
  late DateTime? _endDate = _c.endAt;

  bool _saving = false;

  AdCampaign get _c => widget.campaign;

  double get _budgetValue => double.tryParse(_budget.text.trim()) ?? 0;
  int get _durationValue => int.tryParse(_duration.text.trim()) ?? 0;

  double get _derived => _durationValue <= 0
      ? 0
      : _budgetMode == BudgetMode.daily
          ? _budgetValue * _durationValue
          : _budgetValue / _durationValue;

  int get _mediaCount => _existing.length + _added.length;

  bool get _mediaOk {
    final (low, high) = _format.mediaRange;
    return _mediaCount >= low && _mediaCount <= high;
  }

  bool get _complete =>
      _mediaOk &&
      _locations.isNotEmpty &&
      _headline.text.trim().isNotEmpty &&
      _copy.text.trim().isNotEmpty &&
      _ctaText.text.trim().isNotEmpty &&
      _ctaUrl.text.trim().isNotEmpty &&
      _placements.isNotEmpty &&
      _budgetValue > 0 &&
      _durationValue > 0 &&
      _startDate != null &&
      _endDate != null &&
      _endDate!.isAfter(_startDate!);

  @override
  void dispose() {
    _headline.dispose();
    _copy.dispose();
    _ctaText.dispose();
    _ctaUrl.dispose();
    _budget.dispose();
    _duration.dispose();
    super.dispose();
  }

  void _syncEnd() {
    if (_startDate == null || _durationValue <= 0) return;
    setState(() => _endDate = _startDate!.add(Duration(days: _durationValue)));
  }

  Future<void> _pickStart() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() => _startDate = picked);
    _syncEnd();
  }

  Future<void> _pickImages() async {
    final (_, high) = _format.mediaRange;
    final room = high - _mediaCount;
    if (room <= 0) {
      AppSnackBar.error(
        context,
        '${_format.label} campaigns take at most $high '
        '${high == 1 ? 'file' : 'files'}.',
      );
      return;
    }
    final picked = await pickImagesUpTo(ImagePicker(), limit: room);
    if (picked.isEmpty) return;
    setState(() => _added.addAll(picked.take(room)));
  }

  Future<void> _save() async {
    if (!_complete || _saving) return;
    setState(() => _saving = true);
    try {
      // Media first. If an upload fails the campaign is left as it was, rather
      // than saved with a creative that does not match what is on screen.
      for (final id in _removed) {
        await _repo.deleteCampaignMedia(_c.id, id);
      }
      for (final file in _added) {
        await _repo.uploadCampaignMedia(_c.id, file);
      }
      await _repo.editCampaign(
        _c.id,
        name: _headline.text.trim(),
        objective: _objective.value,
        format: _format.value,
        headline: _headline.text.trim(),
        body: _copy.text.trim(),
        ctaText: _ctaText.text.trim(),
        ctaUrl: _ctaUrl.text.trim(),
        locations: _locations.toList(),
        // Sent even when empty — clearing every interest tag is a real edit,
        // and omitting the field would silently keep the old ones.
        interests: _interests.toList(),
        audience: _audience,
        ageMin: _ages.start.round(),
        ageMax: _ages.end.round(),
        placements: _placements.toList(),
        budgetMode: _budgetMode.value,
        budgetAmount: _budgetValue,
        durationDays: _durationValue,
        startAt: _startDate?.toIso8601String(),
        endAt: _endDate?.toIso8601String(),
      );
      // Saving and submitting are one action here — the button says "Submit
      // for review", and a draft saved but not submitted goes nowhere.
      await _repo.submitCampaign(_c.id);
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const CampaignSubmittedPage()),
      );
    } catch (e) {
      debugPrint('[EditCampaign] save ERROR: $e');
      if (!mounted) return;
      setState(() => _saving = false);
      AppSnackBar.error(context, 'Could not save your changes. Try again.');
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
            : AppBackButton(onPressed: () => Navigator.of(context).pop(false)),
        title: Text(
          'Edit Campaign',
          style: TextStyle(
            color: ext.greetingColor,
            fontWeight: FontWeight.w700,
            fontSize: 16.sp,
          ),
        ),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg.w, AppSpacing.md.h, AppSpacing.lg.w, AppSpacing.xxl.h,
        ),
        children: [
          _Section('1. Type', ext: ext),
          _FieldLabel('Campaign type', ext: ext, required: true),
          _Dropdown<CampaignObjective>(
            ext: ext,
            value: _objective,
            items: [
              for (final o in CampaignObjective.values) (o, o.label),
            ],
            onChanged: (v) => setState(() => _objective = v),
          ),
          _FieldLabel('Campaign format', ext: ext),
          _Segments(
            ext: ext,
            labels: [for (final f in CampaignFormat.values) f.label],
            index: CampaignFormat.values.indexOf(_format),
            onChanged: (i) =>
                setState(() => _format = CampaignFormat.values[i]),
          ),

          _Section('2. Campaign Creative', ext: ext),
          _FieldLabel('Campaign headline', ext: ext, required: true),
          _Text(controller: _headline, ext: ext, maxLength: 60,
              onChanged: (_) => setState(() {})),
          _FieldLabel('Campaign copy', ext: ext, required: true),
          _Text(controller: _copy, ext: ext, maxLines: 4,
              onChanged: (_) => setState(() {})),
          _FieldLabel('Call to action', ext: ext, required: true),
          _Text(controller: _ctaText, ext: ext, maxLength: 50,
              onChanged: (_) => setState(() {})),
          _FieldLabel('Destination URL', ext: ext, required: true),
          _Text(controller: _ctaUrl, ext: ext, keyboardType: TextInputType.url,
              onChanged: (_) => setState(() {})),

          _FieldLabel(
            _format.mediaRange.$2 == 1
                ? 'Cover image / flyer upload'
                : 'Images (${_format.mediaRange.$1}–${_format.mediaRange.$2})',
            ext: ext,
            required: true,
          ),
          _EditPhotoStrip(
            ext: ext,
            existing: _existing,
            added: _added,
            max: _format.mediaRange.$2,
            onPick: _pickImages,
            onRemoveExisting: (m) => setState(() {
              // Marked, not deleted — nothing is destroyed until Save, so
              // backing out of the form leaves the campaign untouched.
              _removed.add(m.id);
              _existing = [..._existing]..remove(m);
            }),
            onRemoveAdded: (f) => setState(() => _added.remove(f)),
          ),

          _Section('3. Audience settings', ext: ext),
          _FieldLabel('Location', ext: ext, required: true),
          Wrap(
            spacing: AppSpacing.sm.w,
            runSpacing: AppSpacing.xs.h,
            children: [
              for (final location in kCampaignLocations)
                _Chip(
                  ext: ext,
                  label: location,
                  selected: _locations.contains(location),
                  onTap: () => setState(() {
                    _locations.contains(location)
                        ? _locations.remove(location)
                        : _locations.add(location);
                  }),
                ),
            ],
          ),
          _FieldLabel('Interest tags', ext: ext),
          Wrap(
            spacing: AppSpacing.sm.w,
            runSpacing: AppSpacing.xs.h,
            children: [
              for (final interest in kCampaignInterests)
                _Chip(
                  ext: ext,
                  label: interest,
                  selected: _interests.contains(interest),
                  onTap: () => setState(() {
                    _interests.contains(interest)
                        ? _interests.remove(interest)
                        : _interests.add(interest);
                  }),
                ),
            ],
          ),
          _FieldLabel('Audience', ext: ext),
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
                    onTap: () => setState(() => _audience = option.$1),
                    child: Row(
                      children: [
                        _Radio(ext: ext, selected: _audience == option.$1),
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
          _FieldLabel('Target age', ext: ext),
          Text(
            '${_ages.start.round()} – ${_ages.end.round()} years',
            style: TextStyle(
              color: ext.accentGold,
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          RangeSlider(
            values: _ages,
            min: 13,
            max: 65,
            divisions: 65 - 13,
            activeColor: ext.accentGold,
            inactiveColor: ext.searchHintColor.withValues(alpha: 0.25),
            labels: RangeLabels(
              '${_ages.start.round()}', '${_ages.end.round()}',
            ),
            onChanged: (v) {
              if (v.end - v.start < 1) return;
              setState(() => _ages = v);
            },
          ),
          _FieldLabel('Placement', ext: ext, required: true),
          for (final entry in const [
            ('event_feed', 'Feed'),
            ('explore', 'Explore'),
            ('search_results', 'Search results'),
          ])
            CheckboxListTile(
              value: _placements.contains(entry.$1),
              activeColor: ext.accentGold,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
              title: Text(
                entry.$2,
                style: TextStyle(color: ext.greetingColor, fontSize: 13.sp),
              ),
              onChanged: (v) => setState(() {
                v == true
                    ? _placements.add(entry.$1)
                    : _placements.remove(entry.$1);
              }),
            ),

          _Section('4. Budget & Schedule', ext: ext),
          _Segments(
            ext: ext,
            labels: const ['Daily budget', 'Total budget'],
            index: _budgetMode == BudgetMode.daily ? 0 : 1,
            onChanged: (i) => setState(
                () => _budgetMode = i == 0 ? BudgetMode.daily : BudgetMode.total),
          ),
          _FieldLabel(
            _budgetMode == BudgetMode.daily
                ? 'Daily budget (${_c.currency})'
                : 'Total budget (${_c.currency})',
            ext: ext,
            required: true,
          ),
          _Text(
            controller: _budget,
            ext: ext,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
          ),
          _FieldLabel('Duration', ext: ext, required: true),
          _Text(
            controller: _duration,
            ext: ext,
            keyboardType: TextInputType.number,
            onChanged: (_) {
              setState(() {});
              _syncEnd();
            },
          ),
          if (_derived > 0)
            Padding(
              padding: EdgeInsets.only(top: AppSpacing.sm.h),
              child: Text(
                _budgetMode == BudgetMode.daily
                    ? 'Estimated total: ${_c.currency} '
                        '${_derived.toStringAsFixed(2)}'
                    : 'Estimated daily: ${_c.currency} '
                        '${_derived.toStringAsFixed(2)}',
                style: TextStyle(
                  color: ext.accentGold,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          _FieldLabel('Start date', ext: ext, required: true),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _pickStart,
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
                      _startDate == null
                          ? 'Select a date'
                          : _fmt(_startDate!),
                      style: TextStyle(
                        color: _startDate == null
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
          if (_endDate != null)
            Padding(
              padding: EdgeInsets.only(top: AppSpacing.sm.h),
              child: Text(
                'Ends ${_fmt(_endDate!)}',
                style: TextStyle(color: ext.searchHintColor, fontSize: 12.sp),
              ),
            ),

          SizedBox(height: AppSpacing.xxl.h),
          Center(
            child: SizedBox(
              height: 48.h,
              child: ElevatedButton(
                onPressed: (_complete && !_saving) ? _save : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ext.accentGold,
                  disabledBackgroundColor:
                      ext.searchHintColor.withValues(alpha: 0.25),
                  padding: EdgeInsets.symmetric(horizontal: 32.w),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999.r),
                  ),
                ),
                child: _saving
                    ? SizedBox(
                        width: 18.r,
                        height: 18.r,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        'Submit for review',
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
    return webWrap(page, backgroundColor: ext.homeBackground);
  }
}

const _kMonths = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _fmt(DateTime d) => '${_kMonths[d.month - 1]} ${d.day}, ${d.year}';

class _Section extends StatelessWidget {
  const _Section(this.text, {required this.ext});

  final String text;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(top: AppSpacing.lg.h, bottom: AppSpacing.xs.h),
        child: Text(
          text,
          style: TextStyle(
            color: ext.greetingColor,
            fontSize: 16.sp,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
      );
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text, {required this.ext, this.required = false});

  final String text;
  final AppThemeExtension ext;
  final bool required;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(top: AppSpacing.md.h, bottom: AppSpacing.xs.h),
        child: Text.rich(
          TextSpan(children: [
            TextSpan(text: text),
            if (required)
              TextSpan(text: ' *', style: TextStyle(color: ext.accentGold)),
          ]),
          style: TextStyle(
            color: ext.greetingColor,
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
}

class _Text extends StatelessWidget {
  const _Text({
    required this.controller,
    required this.ext,
    this.maxLines = 1,
    this.maxLength,
    this.keyboardType,
    this.onChanged,
  });

  final TextEditingController controller;
  final AppThemeExtension ext;
  final int maxLines;
  final int? maxLength;
  final TextInputType? keyboardType;
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

class _Dropdown<T> extends StatelessWidget {
  const _Dropdown({
    required this.ext,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final AppThemeExtension ext;
  final T value;
  final List<(T, String)> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.md.w),
        decoration: BoxDecoration(
          color: ext.cardSurface,
          borderRadius: BorderRadius.circular(AppRadius.md.r),
          border: Border.all(
            color: ext.searchHintColor.withValues(alpha: 0.2),
          ),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: value,
            isExpanded: true,
            dropdownColor: ext.cardSurface,
            icon: Icon(Icons.expand_more_rounded, color: ext.searchHintColor),
            style: TextStyle(color: ext.greetingColor, fontSize: 14.sp),
            items: [
              for (final (v, label) in items)
                DropdownMenuItem(value: v, child: Text(label)),
            ],
            onChanged: (v) => v == null ? null : onChanged(v),
          ),
        ),
      );
}

class _Segments extends StatelessWidget {
  const _Segments({
    required this.ext,
    required this.labels,
    required this.index,
    required this.onChanged,
  });

  final AppThemeExtension ext;
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Container(
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

/// The creative, mid-edit: what is already stored, and what has just been
/// picked. The two look the same and behave differently — removing a stored one
/// is a DELETE at save time, removing a picked one is forgetting it.
class _EditPhotoStrip extends StatelessWidget {
  const _EditPhotoStrip({
    required this.ext,
    required this.existing,
    required this.added,
    required this.max,
    required this.onPick,
    required this.onRemoveExisting,
    required this.onRemoveAdded,
  });

  final AppThemeExtension ext;
  final List<AdMedia> existing;
  final List<XFile> added;
  final int max;
  final VoidCallback onPick;
  final ValueChanged<AdMedia> onRemoveExisting;
  final ValueChanged<XFile> onRemoveAdded;

  int get _count => existing.length + added.length;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 96.h,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final media in existing)
                _Thumb(
                  ext: ext,
                  child: Image.network(
                    media.url,
                    width: 96.w,
                    height: 96.h,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => ColoredBox(
                      color: ext.avatarBackground,
                      child: Icon(Icons.broken_image_outlined,
                          color: ext.searchHintColor),
                    ),
                  ),
                  onRemove: () => onRemoveExisting(media),
                ),
              for (final file in added)
                _Thumb(
                  ext: ext,
                  child: kIsWeb
                      ? Image.network(file.path,
                          width: 96.w, height: 96.h, fit: BoxFit.cover)
                      : Image.file(File(file.path),
                          width: 96.w, height: 96.h, fit: BoxFit.cover),
                  onRemove: () => onRemoveAdded(file),
                ),
              if (_count < max)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
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
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_photo_alternate_outlined,
                            color: ext.accentGold, size: 22.r),
                        SizedBox(height: 3.h),
                        Text(
                          'Upload',
                          style: TextStyle(
                            color: ext.accentGold,
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.only(top: 6.h),
          child: Text(
            '$_count of $max',
            style: TextStyle(color: ext.searchHintColor, fontSize: 11.sp),
          ),
        ),
      ],
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({
    required this.ext,
    required this.child,
    required this.onRemove,
  });

  final AppThemeExtension ext;
  final Widget child;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(right: AppSpacing.sm.w),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md.r),
              child: child,
            ),
            Positioned(
              top: 2,
              right: 2,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onRemove,
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
      );
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.ext,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final AppThemeExtension ext;
  final String label;
  final bool selected;
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

class _Radio extends StatelessWidget {
  const _Radio({required this.ext, required this.selected});

  final AppThemeExtension ext;
  final bool selected;

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
