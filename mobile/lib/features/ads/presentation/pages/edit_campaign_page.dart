import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/core/utils/snackbar_utils.dart';
import 'package:skidoo_app/features/ads/data/repositories/ads_repository.dart';
import 'package:skidoo_app/features/ads/models/ad_campaign.dart';
import 'package:skidoo_app/features/ads/models/ad_set.dart';

const _objectives = ['awareness', 'traffic', 'conversion'];
const _objectiveLabels = {
  'awareness': 'Brand Awareness',
  'traffic': 'Drive Traffic',
  'conversion': 'Conversions',
};
const _audienceTypes = ['all', 'clients', 'photographers'];
const _audienceLabels = {
  'all': 'Everyone',
  'clients': 'Clients',
  'photographers': 'Photographers',
};
const _currencies = ['GHS', 'NGN', 'USD', 'ZAR', 'KES', 'EGP', 'XOF', 'RWF'];
const _eventTypes = [
  'Wedding', 'Birthday', 'Corporate', 'Concert',
  'Graduation', 'Engagement', 'Baby Shower', 'Other',
];

class EditCampaignPage extends StatefulWidget {
  const EditCampaignPage({super.key, required this.campaign});
  final AdCampaign campaign;

  @override
  State<EditCampaignPage> createState() => _EditCampaignPageState();
}

class _EditCampaignPageState extends State<EditCampaignPage> {
  final _repo = AdsRepository();
  final _picker = ImagePicker();
  bool _saving = false;

  // ── Campaign fields ──────────────────────────────────────────────────────
  late final TextEditingController _nameCtrl;
  late String _objective;
  late final TextEditingController _budgetCtrl;
  late String _currency;
  DateTime? _startAt;
  DateTime? _endAt;
  late bool _commentsEnabled;

  // ── Per-adset state (indexed by adset position) ──────────────────────────
  late final List<_AdSetState> _adsetStates;

  @override
  void initState() {
    super.initState();
    final c = widget.campaign;
    _nameCtrl = TextEditingController(text: c.name);
    _objective = c.objective.value;
    _budgetCtrl = TextEditingController(
        text: c.budgetAmount > 0 ? c.budgetAmount.toStringAsFixed(0) : '');
    _currency = c.currency;
    _startAt = c.startAt;
    _endAt = c.endAt;
    _commentsEnabled = c.commentsEnabled;

    _adsetStates = c.adSets.map(_AdSetState.from).toList();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _budgetCtrl.dispose();
    for (final s in _adsetStates) {
      s.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final initial = (isStart ? _startAt : _endAt) ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(now) ? now : initial,
      firstDate: now,
      lastDate: now.add(const Duration(days: 730)),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startAt = picked;
        if (_endAt != null && _endAt!.isBefore(picked)) _endAt = null;
      } else {
        _endAt = picked;
      }
    });
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      AppSnackBar.error(context, 'Campaign name cannot be empty.');
      return;
    }
    final budget = double.tryParse(_budgetCtrl.text.trim());
    if (_budgetCtrl.text.trim().isNotEmpty && (budget == null || budget <= 0)) {
      AppSnackBar.error(context, 'Enter a valid budget amount.');
      return;
    }
    for (final s in _adsetStates) {
      final daily = double.tryParse(s.dailyBudgetCtrl.text.trim());
      if (daily == null || daily <= 0) {
        AppSnackBar.error(context, 'Enter a valid daily budget for each ad set.');
        return;
      }
    }
    for (final s in _adsetStates) {
      for (final a in s.adStates) {
        if (a.headlineCtrl.text.trim().isEmpty) {
          AppSnackBar.error(context, 'Headline cannot be empty.');
          return;
        }
        final link = a.ctaUrlCtrl.text.trim();
        if (link.isNotEmpty) {
          final uri = Uri.tryParse(link);
          if (uri == null || !uri.hasScheme) {
            AppSnackBar.error(context, 'CTA link must start with https://.');
            return;
          }
        }
      }
    }

    setState(() => _saving = true);
    try {
      // Campaign-level fields can only be updated for drafts; the server rejects
      // changes to live campaigns at the campaign level.
      if (widget.campaign.status == CampaignStatus.draft) {
        await _repo.updateCampaign(
          widget.campaign.id,
          name: name,
          objective: _objective,
          budgetAmount: budget,
          currency: _currency,
          startAt: _startAt?.toIso8601String(),
          endAt: _endAt?.toIso8601String(),
          commentsEnabled: _commentsEnabled,
        );
      }

      // Ad set targeting / budget can always be updated regardless of status.
      for (final s in _adsetStates) {
        final daily = double.tryParse(s.dailyBudgetCtrl.text.trim());
        final loc = s.locationCtrl.text.trim();
        await _repo.updateAdSet(
          s.adset.id,
          dailyBudget: daily,
          targeting: {
            'audience': s.audience,
            if (s.eventType != null) 'event_types': [s.eventType!],
            if (loc.isNotEmpty) 'locations': [loc],
          },
        );
        // Ad creative updates (non-fatal if endpoint unavailable on this server).
        for (final a in s.adStates) {
          await _repo.updateAd(
            a.adId,
            headline: a.headlineCtrl.text.trim(),
            body: a.bodyCtrl.text.trim().isEmpty ? null : a.bodyCtrl.text.trim(),
            ctaText: a.ctaTextCtrl.text.trim().isEmpty ? null : a.ctaTextCtrl.text.trim(),
            ctaUrl: a.ctaUrlCtrl.text.trim().isEmpty ? null : a.ctaUrlCtrl.text.trim(),
            commentsEnabled: a.commentsEnabled,
          );
          if (a.newMedia != null) {
            await _repo.uploadAdCreative(a.adId, a.newMedia!.path, a.newMediaIsVideo);
          }
        }
      }

      if (!mounted) return;
      AppSnackBar.success(context, 'Campaign updated successfully.');
      Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint('[EditCampaignPage] _save ERROR: $e');
      if (!mounted) return;
      setState(() => _saving = false);
      AppSnackBar.error(context, 'Could not save changes. Try again.');
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
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: ext.greetingColor, size: 20.sp),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Edit Campaign',
          style: TextStyle(
            color: ext.greetingColor,
            fontSize: 17.sp,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: false,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 24.h),
              children: [
                // ── Campaign Details ─────────────────────────────────────
                _SectionHeader('Campaign Details', ext),
                SizedBox(height: 16.h),

                _ELabel('Campaign name', ext),
                SizedBox(height: 8.h),
                _EField(controller: _nameCtrl, hint: 'e.g. Summer Wedding Promo', ext: ext),

                SizedBox(height: 20.h),
                _ELabel('Objective', ext),
                SizedBox(height: 8.h),
                _EDropdown<String>(
                  value: _objective,
                  items: _objectives,
                  itemLabel: (v) => _objectiveLabels[v] ?? v,
                  ext: ext,
                  onChanged: (v) => setState(() => _objective = v ?? _objectives[0]),
                ),

                SizedBox(height: 20.h),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _ELabel('Total budget', ext),
                          SizedBox(height: 8.h),
                          _EField(
                            controller: _budgetCtrl,
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
                          _ELabel('Currency', ext),
                          SizedBox(height: 8.h),
                          _EDropdown<String>(
                            value: _currency,
                            items: _currencies,
                            itemLabel: (v) => v,
                            ext: ext,
                            onChanged: (v) =>
                                setState(() => _currency = v ?? _currencies[0]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 20.h),
                _ELabel('Campaign dates (optional)', ext),
                SizedBox(height: 8.h),
                Row(
                  children: [
                    Expanded(
                      child: _DateBtn(
                        label: _startAt == null
                            ? 'Start date'
                            : '${_startAt!.day}/${_startAt!.month}/${_startAt!.year}',
                        ext: ext,
                        onTap: () => _pickDate(isStart: true),
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: _DateBtn(
                        label: _endAt == null
                            ? 'End date'
                            : '${_endAt!.day}/${_endAt!.month}/${_endAt!.year}',
                        ext: ext,
                        onTap: () => _pickDate(isStart: false),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 20.h),
                _EToggleRow(
                  label: 'Allow comments',
                  subtitle: 'Let viewers comment on this campaign',
                  value: _commentsEnabled,
                  ext: ext,
                  onChanged: (v) => setState(() => _commentsEnabled = v),
                ),

                // ── Ad Sets ──────────────────────────────────────────────
                if (_adsetStates.isNotEmpty) ...[
                  SizedBox(height: 32.h),
                  _Divider(ext),
                  SizedBox(height: 24.h),
                  for (var i = 0; i < _adsetStates.length; i++) ...[
                    _SectionHeader(
                      _adsetStates.length == 1
                          ? 'Ad Set'
                          : 'Ad Set ${i + 1}',
                      ext,
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      _adsetStates[i].adset.placement.label,
                      style: TextStyle(
                          color: ext.searchHintColor, fontSize: 12.sp),
                    ),
                    SizedBox(height: 16.h),
                    _AdSetForm(
                      state: _adsetStates[i],
                      ext: ext,
                      onChanged: () => setState(() {}),
                    ),
                    if (i < _adsetStates.length - 1) ...[
                      SizedBox(height: 24.h),
                      _Divider(ext),
                      SizedBox(height: 24.h),
                    ],
                  ],
                ],

                // ── Ads (creative content) ────────────────────────────
                for (var si = 0; si < _adsetStates.length; si++) ...[
                  for (var ai = 0;
                      ai < _adsetStates[si].adStates.length;
                      ai++) ...[
                    SizedBox(height: 32.h),
                    _Divider(ext),
                    SizedBox(height: 24.h),
                    _SectionHeader(
                      _adsetStates[si].adStates.length == 1
                          ? 'Ad Creative'
                          : 'Ad Creative ${ai + 1}',
                      ext,
                    ),
                    SizedBox(height: 16.h),
                    _AdForm(
                      state: _adsetStates[si].adStates[ai],
                      ext: ext,
                      picker: _picker,
                      onChanged: () => setState(() {}),
                    ),
                  ],
                ],

                SizedBox(height: 16.h),
              ],
            ),
          ),

          // ── Save bar ─────────────────────────────────────────────────────
          Container(
            padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 24.h),
            decoration: BoxDecoration(
              color: ext.homeBackground,
              border: Border(
                top: BorderSide(
                    color: ext.searchHintColor.withValues(alpha: 0.1)),
              ),
            ),
            child: GestureDetector(
              onTap: _saving ? null : _save,
              child: Container(
                height: 50.h,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _saving
                        ? [
                            ext.accentGold.withValues(alpha: 0.5),
                            const Color(0xFFFF6B35).withValues(alpha: 0.5),
                          ]
                        : [ext.accentGold, const Color(0xFFFF6B35)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(14.r),
                ),
                alignment: Alignment.center,
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white),
                      )
                    : Text(
                        'Save Changes',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
    return _webWrap(ext, page);
  }

  static Widget _webWrap(AppThemeExtension ext, Widget child) {
    if (!kIsWeb) return child;
    return ColoredBox(
      color: ext.homeBackground,
      child: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(width: 480, child: child),
      ),
    );
  }
}

// ── Per-adset mutable state ───────────────────────────────────────────────────

class _AdSetState {
  _AdSetState({
    required this.adset,
    required this.dailyBudgetCtrl,
    required this.locationCtrl,
    required this.audience,
    required this.eventType,
    required this.adStates,
  });

  final AdSet adset;
  final TextEditingController dailyBudgetCtrl;
  final TextEditingController locationCtrl;
  String audience;
  String? eventType;
  final List<_AdState> adStates;

  factory _AdSetState.from(AdSet s) => _AdSetState(
        adset: s,
        dailyBudgetCtrl: TextEditingController(
            text: s.dailyBudget > 0 ? s.dailyBudget.toStringAsFixed(0) : ''),
        locationCtrl: TextEditingController(
            text: s.targeting.locations.isNotEmpty
                ? s.targeting.locations.first
                : ''),
        audience: s.targeting.audience ?? 'all',
        eventType: s.targeting.eventTypes.isNotEmpty
            ? s.targeting.eventTypes.first
            : null,
        adStates: s.ads.map(_AdState.from).toList(),
      );

  void dispose() {
    dailyBudgetCtrl.dispose();
    locationCtrl.dispose();
    for (final a in adStates) {
      a.dispose();
    }
  }
}

// ── Per-ad mutable state ──────────────────────────────────────────────────────

class _AdState {
  _AdState({
    required this.adId,
    required this.headlineCtrl,
    required this.bodyCtrl,
    required this.ctaTextCtrl,
    required this.ctaUrlCtrl,
    required this.existingMediaUrl,
    required this.commentsEnabled,
  });

  final String adId;
  final TextEditingController headlineCtrl;
  final TextEditingController bodyCtrl;
  final TextEditingController ctaTextCtrl;
  final TextEditingController ctaUrlCtrl;
  final String? existingMediaUrl;
  XFile? newMedia;
  bool newMediaIsVideo = false;
  bool commentsEnabled;

  factory _AdState.from(ad) => _AdState(
        adId: ad.id,
        headlineCtrl: TextEditingController(text: ad.headline),
        bodyCtrl: TextEditingController(text: ad.body ?? ''),
        ctaTextCtrl: TextEditingController(
            text: ad.ctaText == 'Learn More' ? '' : ad.ctaText),
        ctaUrlCtrl: TextEditingController(text: ad.ctaUrl),
        existingMediaUrl: ad.mediaUrl,
        commentsEnabled: ad.commentsEnabled,
      );

  void dispose() {
    headlineCtrl.dispose();
    bodyCtrl.dispose();
    ctaTextCtrl.dispose();
    ctaUrlCtrl.dispose();
  }
}

// ── Ad set form section ───────────────────────────────────────────────────────

class _AdSetForm extends StatelessWidget {
  const _AdSetForm(
      {required this.state, required this.ext, required this.onChanged});
  final _AdSetState state;
  final AppThemeExtension ext;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ELabel('Daily budget', ext),
        SizedBox(height: 8.h),
        _EField(
          controller: state.dailyBudgetCtrl,
          hint: 'e.g. 50',
          ext: ext,
          keyboardType: TextInputType.number,
        ),
        SizedBox(height: 20.h),
        _ELabel('Audience', ext),
        SizedBox(height: 8.h),
        _EDropdown<String>(
          value: state.audience,
          items: _audienceTypes,
          itemLabel: (v) => _audienceLabels[v] ?? v,
          ext: ext,
          onChanged: (v) {
            state.audience = v ?? 'all';
            onChanged();
          },
        ),
        SizedBox(height: 20.h),
        _ELabel('Target event type (optional)', ext),
        SizedBox(height: 8.h),
        _EDropdown<String>(
          value: state.eventType,
          items: _eventTypes,
          itemLabel: (v) => v,
          ext: ext,
          onChanged: (v) {
            state.eventType = v;
            onChanged();
          },
          hint: 'Any event type',
          nullable: true,
        ),
        SizedBox(height: 20.h),
        _ELabel('Target location (optional)', ext),
        SizedBox(height: 8.h),
        _EField(
            controller: state.locationCtrl, hint: 'e.g. Accra', ext: ext),
      ],
    );
  }
}

// ── Ad creative form section ──────────────────────────────────────────────────

class _AdForm extends StatelessWidget {
  const _AdForm({
    required this.state,
    required this.ext,
    required this.picker,
    required this.onChanged,
  });
  final _AdState state;
  final AppThemeExtension ext;
  final ImagePicker picker;
  final VoidCallback onChanged;

  static const _maxBytes = 50 * 1024 * 1024;

  Future<void> _pickMedia(BuildContext context, bool video) async {
    XFile? file;
    if (video) {
      file = await picker.pickVideo(
          source: ImageSource.gallery,
          maxDuration: const Duration(minutes: 2));
    } else {
      file = await picker.pickImage(
          source: ImageSource.gallery, imageQuality: 85);
    }
    if (file == null) return;
    final size = await File(file.path).length();
    if (size > _maxBytes) {
      if (context.mounted) {
        AppSnackBar.error(context, 'File is too large. Maximum size is 50 MB.');
      }
      return;
    }
    state.newMedia = file;
    state.newMediaIsVideo = video;
    onChanged();
  }

  void _showPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _MediaPickerSheet(
        ext: ext,
        onPhoto: () => _pickMedia(context, false),
        onVideo: () => _pickMedia(context, true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ELabel('Headline', ext),
        SizedBox(height: 8.h),
        _EField(
          controller: state.headlineCtrl,
          hint: 'Grab attention in one line',
          ext: ext,
        ),
        SizedBox(height: 20.h),
        _ELabel('Body text (optional)', ext),
        SizedBox(height: 8.h),
        _EField(
          controller: state.bodyCtrl,
          hint: 'Describe what you offer...',
          ext: ext,
          maxLines: 3,
        ),
        SizedBox(height: 20.h),
        _ELabel('CTA button text (optional)', ext),
        SizedBox(height: 8.h),
        _EField(
          controller: state.ctaTextCtrl,
          hint: 'e.g. Book Now · Learn More',
          ext: ext,
        ),
        SizedBox(height: 20.h),
        _ELabel('CTA link', ext),
        SizedBox(height: 8.h),
        _EField(
          controller: state.ctaUrlCtrl,
          hint: 'https://',
          ext: ext,
          keyboardType: TextInputType.url,
        ),
        SizedBox(height: 20.h),
        _EToggleRow(
          label: 'Allow comments',
          subtitle: 'Let viewers comment on this ad',
          value: state.commentsEnabled,
          ext: ext,
          onChanged: (v) {
            state.commentsEnabled = v;
            onChanged();
          },
        ),
        SizedBox(height: 20.h),
        _ELabel('Creative media', ext),
        SizedBox(height: 8.h),
        _MediaPreview(
          state: state,
          ext: ext,
          onTap: () => _showPicker(context),
          onRemove: () {
            state.newMedia = null;
            onChanged();
          },
        ),
      ],
    );
  }
}

// ── Media preview tile ────────────────────────────────────────────────────────

class _MediaPreview extends StatelessWidget {
  const _MediaPreview({
    required this.state,
    required this.ext,
    required this.onTap,
    required this.onRemove,
  });
  final _AdState state;
  final AppThemeExtension ext;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    // New local pick takes priority
    if (state.newMedia != null) {
      return _LocalMediaTile(
        path: state.newMedia!.path,
        isVideo: state.newMediaIsVideo,
        ext: ext,
        onTap: onTap,
        onRemove: onRemove,
      );
    }
    // Existing remote media
    if (state.existingMediaUrl != null && state.existingMediaUrl!.isNotEmpty) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14.r),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: CachedNetworkImage(
                imageUrl: state.existingMediaUrl!,
                fit: BoxFit.cover,
                placeholder: (_, __) =>
                    ColoredBox(color: ext.searchFieldFill),
                errorWidget: (_, __, ___) =>
                    ColoredBox(color: ext.searchFieldFill),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: GestureDetector(
              onTap: onTap,
              child: ClipRRect(
                borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(14.r)),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.5),
                  padding: EdgeInsets.symmetric(vertical: 8.h),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.edit_rounded,
                          color: Colors.white70, size: 14.sp),
                      SizedBox(width: 6.w),
                      Text(
                        'Change media',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }
    // No media yet
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 100.h,
        decoration: BoxDecoration(
          color: ext.searchFieldFill,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
              color: ext.searchHintColor.withValues(alpha: 0.25), width: 1.2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate_outlined,
                color: ext.searchHintColor, size: 28.sp),
            SizedBox(height: 6.h),
            Text(
              'Tap to add photo or video',
              style: TextStyle(color: ext.searchHintColor, fontSize: 12.sp),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocalMediaTile extends StatelessWidget {
  const _LocalMediaTile({
    required this.path,
    required this.isVideo,
    required this.ext,
    required this.onTap,
    required this.onRemove,
  });
  final String path;
  final bool isVideo;
  final AppThemeExtension ext;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14.r),
      child: Stack(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: isVideo
                ? Container(
                    color: Colors.black,
                    child: Center(
                      child: Icon(Icons.videocam_rounded,
                          color: Colors.white54, size: 40.sp),
                    ),
                  )
                : Image.file(File(path), fit: BoxFit.cover),
          ),
          Positioned(
            top: 8.h,
            left: 10.w,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 3.h),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Text(
                isVideo ? 'Video' : 'Image',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 9.sp,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ),
          Positioned(
            top: 6.h,
            right: 8.w,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.close_rounded,
                    color: Colors.white, size: 16.sp),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: GestureDetector(
              onTap: onTap,
              child: Container(
                color: Colors.black.withValues(alpha: 0.45),
                padding: EdgeInsets.symmetric(vertical: 7.h),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.edit_rounded, color: Colors.white70, size: 14.sp),
                    SizedBox(width: 5.w),
                    Text(
                      'Change media',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Media picker sheet ────────────────────────────────────────────────────────

class _MediaPickerSheet extends StatelessWidget {
  const _MediaPickerSheet(
      {required this.ext, required this.onPhoto, required this.onVideo});
  final AppThemeExtension ext;
  final VoidCallback onPhoto;
  final VoidCallback onVideo;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ext.homeBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: EdgeInsets.symmetric(vertical: 12.h),
              width: 36.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: ext.searchHintColor.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 8.h),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Change Creative',
                  style: TextStyle(
                    color: ext.greetingColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 16.sp,
                  ),
                ),
              ),
            ),
            Divider(
                height: 1,
                color: ext.searchHintColor.withValues(alpha: 0.1)),
            ListTile(
              onTap: () {
                Navigator.of(context).pop();
                onPhoto();
              },
              leading: Container(
                width: 40.w,
                height: 40.w,
                decoration: BoxDecoration(
                  color: ext.accentGold.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.image_rounded,
                    color: ext.accentGold, size: 20.sp),
              ),
              title: Text('Photo from Gallery',
                  style: TextStyle(
                      color: ext.greetingColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 14.sp)),
            ),
            ListTile(
              onTap: () {
                Navigator.of(context).pop();
                onVideo();
              },
              leading: Container(
                width: 40.w,
                height: 40.w,
                decoration: const BoxDecoration(
                  color: Color(0x1A8B5CF6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.videocam_rounded,
                    color: Color(0xFF8B5CF6)),
              ),
              title: Text('Video from Gallery',
                  style: TextStyle(
                      color: ext.greetingColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 14.sp)),
            ),
            SizedBox(height: 8.h),
          ],
        ),
      ),
    );
  }
}

// ── Shared form primitives ────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title, this.ext);
  final String title;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        color: ext.greetingColor,
        fontSize: 16.sp,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.3,
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider(this.ext);
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 0.5,
      color: ext.searchHintColor.withValues(alpha: 0.15),
    );
  }
}

class _ELabel extends StatelessWidget {
  const _ELabel(this.text, this.ext);
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

class _EField extends StatelessWidget {
  const _EField({
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
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: TextStyle(color: ext.greetingColor, fontSize: 14.sp),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
            TextStyle(color: ext.searchHintColor, fontSize: 14.sp),
        filled: true,
        fillColor: ext.searchFieldFill,
        contentPadding:
            EdgeInsets.symmetric(horizontal: 14.w, vertical: 13.h),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide(
              color: ext.accentGold.withValues(alpha: 0.6), width: 1.2),
        ),
      ),
    );
  }
}

class _EDropdown<T> extends StatelessWidget {
  const _EDropdown({
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
        borderRadius: BorderRadius.circular(12.r),
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
                style: TextStyle(
                    color: ext.searchHintColor, fontSize: 14.sp))
            : null,
        items: [
          if (nullable)
            DropdownMenuItem<T>(
              value: null,
              child: Text(hint ?? 'None',
                  style: TextStyle(
                      color: ext.searchHintColor, fontSize: 14.sp)),
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

class _EToggleRow extends StatelessWidget {
  const _EToggleRow({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.ext,
    required this.onChanged,
  });
  final String label;
  final String subtitle;
  final bool value;
  final AppThemeExtension ext;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ext.searchFieldFill,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        activeThumbColor: ext.accentGold,
        contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 2.h),
        title: Text(
          label,
          style: TextStyle(
            color: ext.greetingColor,
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: ext.searchHintColor, fontSize: 12.sp),
        ),
      ),
    );
  }
}

class _DateBtn extends StatelessWidget {
  const _DateBtn(
      {required this.label, required this.ext, required this.onTap});
  final String label;
  final AppThemeExtension ext;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 13.h),
        decoration: BoxDecoration(
          color: ext.searchFieldFill,
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_outlined,
                color: ext.searchHintColor, size: 16.sp),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: (label == 'Start date' || label == 'End date')
                      ? ext.searchHintColor
                      : ext.greetingColor,
                  fontSize: 13.sp,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
