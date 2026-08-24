import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:jperg_app/core/common/widgets/app_widgets.dart';
import 'package:jperg_app/core/common/widgets/xfile_image.dart';
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/utils/snackbar_utils.dart';
import 'package:jperg_app/core/utils/web_wrap.dart';
import 'package:jperg_app/core/validators/media_validator.dart';
import 'package:jperg_app/features/ads/data/repositories/ads_repository.dart';
import 'package:jperg_app/features/location/data/models/place.dart';
import 'package:jperg_app/features/location/presentation/widgets/location_picker_sheet.dart';

/// Posting a request: fill it in, read it back, publish.
///
/// Three screens rather than one because publishing is the moment it becomes
/// visible to every photographer on the platform, and the design puts a
/// deliberate pause in front of that — the middle screen exists to be read.
///
/// The draft lives here and is handed down, so going back from the review step
/// returns to a filled form rather than an empty one.
class CreateRequestFlow extends StatefulWidget {
  const CreateRequestFlow({super.key});

  @override
  State<CreateRequestFlow> createState() => _CreateRequestFlowState();
}

class RequestDraft {
  String title = '';
  DateTime? eventDate;
  String? eventType;

  /// Where the shoot is, as a resolved place rather than typed text.
  ///
  /// It is one question doing two jobs, which is why it is one field. The
  /// requester is saying where the job is; the board reads the same answer to
  /// decide which photographers ever see it, because a wedding in Accra is not
  /// a job for someone who works in another country. Asking "where is it" and
  /// then "who should see it" would be asking the same thing twice.
  Place? place;

  /// Anywhere else worth reaching — a shoot near a border, or a client happy
  /// to fly someone in. Optional, and empty for almost every request.
  final List<Place> alsoReach = [];

  /// The event's location as the card shows it.
  String get location => place?.label ?? '';

  /// What the board filters and ranks on.
  List<Place> get targetLocations => [
        if (place != null) place!,
        for (final extra in alsoReach)
          if (extra != place) extra,
      ];

  String description = '';
  double? budgetMin;
  double? budgetMax;

  /// Required. A request without a photo of the venue, the couple, the thing
  /// being shot gives a photographer nothing to answer.
  final List<XFile> photos = [];

  bool get isComplete =>
      title.trim().isNotEmpty &&
      eventDate != null &&
      (eventType?.isNotEmpty ?? false) &&
      place != null &&
      photos.isNotEmpty;
}

const requestEventTypes = [
  'Wedding', 'Birthday', 'Corporate', 'Concert', 'Graduation',
  'Engagement', 'Baby Shower', 'Anniversary', 'Sports', 'Other',
];

class _CreateRequestFlowState extends State<CreateRequestFlow> {
  final _draft = RequestDraft();

  @override
  Widget build(BuildContext context) =>
      _NewRequestStep(draft: _draft, onContinue: _review);

  Future<void> _review() async {
    final published = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => _ReviewStep(draft: _draft)),
    );
    // Published: this screen goes too, so Back from the success screen does
    // not land on a form for a request that already exists.
    if (published == true && mounted) Navigator.of(context).pop(true);
  }
}

// ── Step one ────────────────────────────────────────────────────────────────
class _NewRequestStep extends StatefulWidget {
  const _NewRequestStep({required this.draft, required this.onContinue});

  final RequestDraft draft;
  final VoidCallback onContinue;

  @override
  State<_NewRequestStep> createState() => _NewRequestStepState();
}

class _NewRequestStepState extends State<_NewRequestStep> {
  final _picker = ImagePicker();
  late final _title = TextEditingController(text: widget.draft.title);
  late final _description = TextEditingController(text: widget.draft.description);
  late final _budgetMin = TextEditingController(
    text: widget.draft.budgetMin?.toStringAsFixed(0) ?? '',
  );
  late final _budgetMax = TextEditingController(
    text: widget.draft.budgetMax?.toStringAsFixed(0) ?? '',
  );

  @override
  void dispose() {
    for (final c in [_title, _description, _budgetMin, _budgetMax]) {
      c.dispose();
    }
    super.dispose();
  }

  void _sync() {
    widget.draft
      ..title = _title.text
      ..description = _description.text
      ..budgetMin = double.tryParse(_budgetMin.text.trim())
      ..budgetMax = double.tryParse(_budgetMax.text.trim());
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.draft.eventDate ?? now.add(const Duration(days: 7)),
      // A shoot in the past is not something anyone can answer.
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 3)),
    );
    if (picked != null) setState(() => widget.draft.eventDate = picked);
  }

  Future<void> _addPhoto() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery, imageQuality: 85,
    );
    if (file == null) return;
    final error = await MediaValidator.validate(file, isVideo: false);
    if (!mounted) return;
    if (error != null) {
      AppSnackBar.error(context, error);
      return;
    }
    setState(() => widget.draft.photos.add(file));
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final draft = widget.draft;

    final page = Scaffold(
      backgroundColor: ext.homeBackground,
      appBar: _stepBar(context, ext, 'New Request'),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg.w, AppSpacing.lg.h, AppSpacing.lg.w, AppSpacing.xxl.h,
        ),
        children: [
          _Field(
            ext: ext,
            label: 'Event Name',
            child: _Input(controller: _title, hint: 'Event name', ext: ext,
                onChanged: (_) => setState(_sync)),
          ),
          _Field(
            ext: ext,
            label: 'Event Date',
            child: _Tappable(
              ext: ext,
              onTap: _pickDate,
              child: Text(
                draft.eventDate == null
                    ? 'Event Date'
                    : _formatDate(draft.eventDate!),
                style: TextStyle(
                  color: draft.eventDate == null
                      ? ext.searchHintColor
                      : ext.greetingColor,
                  fontSize: 14.sp,
                ),
              ),
            ),
          ),
          _Field(
            ext: ext,
            label: 'Event Type',
            child: _Tappable(
              ext: ext,
              onTap: _pickType,
              trailing: Icon(Icons.expand_more_rounded,
                  color: ext.searchHintColor, size: 20.r),
              child: Text(
                draft.eventType ?? 'Select event type',
                style: TextStyle(
                  color: draft.eventType == null
                      ? ext.searchHintColor
                      : ext.greetingColor,
                  fontSize: 14.sp,
                ),
              ),
            ),
          ),
          _Field(
            ext: ext,
            label: 'Location',
            child: _LocationField(draft: widget.draft, ext: ext,
                onChanged: () => setState(_sync)),
          ),
          _Field(
            ext: ext,
            label: 'Description',
            child: _Input(
              controller: _description, hint: 'Description', ext: ext,
              maxLines: 4, onChanged: (_) => _sync(),
            ),
          ),
          _Field(
            ext: ext,
            label: 'Budget',
            child: Row(
              children: [
                Expanded(
                  child: _Input(
                    controller: _budgetMin, hint: 'From', ext: ext,
                    number: true, onChanged: (_) => setState(_sync),
                  ),
                ),
                SizedBox(width: AppSpacing.sm.w),
                Text('-', style: TextStyle(color: ext.searchHintColor)),
                SizedBox(width: AppSpacing.sm.w),
                Expanded(
                  child: _Input(
                    controller: _budgetMax, hint: 'To', ext: ext,
                    number: true, onChanged: (_) => setState(_sync),
                  ),
                ),
              ],
            ),
          ),
          // Not in the design, and required all the same: a photographer
          // answering a request needs to see what they would be shooting.
          _Field(
            ext: ext,
            label: 'Photos',
            child: _DraftPhotos(
              photos: draft.photos,
              ext: ext,
              onAdd: _addPhoto,
              onRemove: (file) => setState(() => draft.photos.remove(file)),
            ),
          ),
          SizedBox(height: AppSpacing.xl.h),
          _PrimaryButton(
            label: 'Continue',
            ext: ext,
            // Disabled rather than complaining after the fact: the button says
            // what is missing by not being ready yet.
            onPressed: draft.isComplete
                ? () {
                    _sync();
                    widget.onContinue();
                  }
                : null,
          ),
          if (!draft.isComplete) ...[
            SizedBox(height: AppSpacing.sm.h),
            Center(
              child: Text(
                draft.photos.isEmpty
                    ? 'Add at least one photo to continue'
                    : 'Fill in the name, date, type and location',
                style: TextStyle(color: ext.searchHintColor, fontSize: 12.sp),
              ),
            ),
          ],
        ],
      ),
    );
    return webWrap(page, backgroundColor: ext.homeBackground);
  }

  Future<void> _pickType() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final ext = Theme.of(sheetContext).extension<AppThemeExtension>()!;
        return Container(
          decoration: BoxDecoration(
            color: ext.homeBackground,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
          ),
          child: SafeArea(
            top: false,
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final type in requestEventTypes)
                  ListTile(
                    title: Text(type,
                        style: TextStyle(color: ext.greetingColor)),
                    onTap: () => Navigator.of(sheetContext).pop(type),
                  ),
              ],
            ),
          ),
        );
      },
    );
    if (picked != null) setState(() => widget.draft.eventType = picked);
  }
}

// ── Step two ────────────────────────────────────────────────────────────────
class _ReviewStep extends StatefulWidget {
  const _ReviewStep({required this.draft});

  final RequestDraft draft;

  @override
  State<_ReviewStep> createState() => _ReviewStepState();
}

class _ReviewStepState extends State<_ReviewStep> {
  final _repo = AdsRepository();
  bool _publishing = false;

  Future<void> _publish() async {
    if (_publishing) return;
    setState(() => _publishing = true);
    final draft = widget.draft;
    try {
      final requestId = await _repo.postRequest(
        title: draft.title.trim(),
        description: draft.description.trim(),
        eventType: draft.eventType!.toLowerCase(),
        location: draft.location.trim(),
        targetLocations:
            draft.targetLocations.map((p) => p.toJson()).toList(),
        eventDate: draft.eventDate,
        budgetMin: draft.budgetMin,
        budgetMax: draft.budgetMax,
        currency: 'GHS',
      );

      // Photos are part of the request, so a failure here is a failure to
      // publish — not a request quietly posted without them.
      for (final photo in draft.photos) {
        await _repo.uploadRequestMedia(requestId, photo);
      }

      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const _PublishedStep()),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint('[CreateRequest] publish ERROR: $e');
      if (!mounted) return;
      setState(() => _publishing = false);
      AppSnackBar.error(
        context,
        'Could not publish your request. Please try again.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final draft = widget.draft;

    final page = Scaffold(
      backgroundColor: ext.homeBackground,
      appBar: _stepBar(context, ext, 'Review Request'),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg.w, AppSpacing.lg.h, AppSpacing.lg.w, AppSpacing.xxl.h,
        ),
        children: [
          _ReadBack(label: 'Event Name', value: draft.title, ext: ext),
          _ReadBack(
            label: 'Event Date',
            value: draft.eventDate == null ? '' : _formatDate(draft.eventDate!),
            ext: ext,
          ),
          _ReadBack(label: 'Event Type', value: draft.eventType ?? '', ext: ext),
          _ReadBack(label: 'Location', value: draft.location, ext: ext),
          _ReadBack(
            label: 'Description', value: draft.description, ext: ext, tall: true,
          ),
          _ReadBack(label: 'Budget', value: _budgetLabel(draft), ext: ext),
          if (draft.photos.isNotEmpty)
            _Field(
              label: 'Photos',
              ext: ext,
              child: SizedBox(
                height: 72.w,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: draft.photos.length,
                  separatorBuilder: (_, __) => SizedBox(width: 8.w),
                  itemBuilder: (_, i) => ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.sm.r),
                    child: SizedBox(
                      width: 72.w,
                      height: 72.w,
                      child: XFileImage(draft.photos[i], fit: BoxFit.cover),
                    ),
                  ),
                ),
              ),
            ),
          SizedBox(height: AppSpacing.xl.h),
          _PrimaryButton(
            label: 'Publish Request',
            ext: ext,
            busy: _publishing,
            onPressed: _publish,
          ),
        ],
      ),
    );
    return webWrap(page, backgroundColor: ext.homeBackground);
  }
}

// ── Step three ──────────────────────────────────────────────────────────────
class _PublishedStep extends StatelessWidget {
  const _PublishedStep();

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    final page = Scaffold(
      backgroundColor: ext.homeBackground,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xxl.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 110.r,
                height: 110.r,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ext.accentGold.withValues(alpha: 0.12),
                ),
                child: Icon(Icons.check_rounded,
                    color: ext.accentGold, size: 44.r),
              ),
              SizedBox(height: AppSpacing.xl.h),
              Text(
                'Your request is live!',
                style: TextStyle(
                  color: ext.greetingColor,
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: AppSpacing.sm.h),
              Text(
                "We'll notify you when photographers express interest.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: ext.searchHintColor, fontSize: 14.sp, height: 1.4,
                ),
              ),
              SizedBox(height: AppSpacing.xl.h),
              Container(
                padding: EdgeInsets.all(AppSpacing.lg.w),
                decoration: BoxDecoration(
                  color: ext.accentGold.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppRadius.md.r),
                ),
                child: Text(
                  // Said once, here, so nobody is surprised in a month.
                  'Requests are automatically closed after 30 days.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: ext.searchHintColor, fontSize: 13.sp,
                  ),
                ),
              ),
              SizedBox(height: AppSpacing.xxl.h),
              _PrimaryButton(
                label: 'Done',
                ext: ext,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
    return webWrap(page, backgroundColor: ext.homeBackground);
  }
}

// ── Shared bits ─────────────────────────────────────────────────────────────
String _formatDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}.'
    '${d.month.toString().padLeft(2, '0')}.${d.year}';

String _budgetLabel(RequestDraft draft) {
  if (draft.budgetMin != null && draft.budgetMax != null) {
    return 'GHS ${draft.budgetMin!.toStringAsFixed(0)} - '
        'GHS ${draft.budgetMax!.toStringAsFixed(0)}';
  }
  final single = draft.budgetMin ?? draft.budgetMax;
  return single == null ? '' : 'GHS ${single.toStringAsFixed(0)}';
}

PreferredSizeWidget _stepBar(
  BuildContext context, AppThemeExtension ext, String title,
) =>
    AppBar(
      elevation: 0,
      centerTitle: true,
      backgroundColor: Colors.transparent,
      leading: kIsWeb
          ? null
          : const AppBackButton(),
      title: Text(
        title,
        style: TextStyle(
          color: ext.greetingColor,
          fontWeight: FontWeight.w700,
          fontSize: 16.sp,
        ),
      ),
    );

/// Where the shoot is, picked rather than typed.
///
/// It was a free-text box, and free text is why targeting could not work: the
/// board had nothing to gate on and nothing to measure a distance from, so
/// every open request went to every photographer whatever country they work in.
///
/// The line underneath says who the answer reaches, because that consequence
/// is not obvious from a field labelled "Location" and it is the reason the
/// field changed.
class _LocationField extends StatelessWidget {
  const _LocationField({
    required this.draft,
    required this.ext,
    required this.onChanged,
  });

  final RequestDraft draft;
  final AppThemeExtension ext;
  final VoidCallback onChanged;

  Future<void> _pick(BuildContext context) async {
    final place = await LocationPickerSheet.show(
      context,
      title: 'Where is the shoot?',
    );
    if (place == null) return;
    draft.place = place;
    // Somewhere chosen as the venue is no longer an "also reach" — it is the
    // place itself, and listing it twice would say the same thing twice.
    draft.alsoReach.remove(place);
    onChanged();
  }

  Future<void> _addExtra(BuildContext context) async {
    final place = await LocationPickerSheet.show(
      context,
      title: 'Also show photographers in…',
    );
    if (place == null) return;
    if (place != draft.place && !draft.alsoReach.contains(place)) {
      draft.alsoReach.add(place);
      onChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    final place = draft.place;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          button: true,
          label: 'Choose the location',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _pick(context),
            child: Container(
              padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.md.w, vertical: 13.h),
              decoration: BoxDecoration(
                color: ext.searchFieldFill,
                borderRadius: BorderRadius.circular(AppRadius.md.r),
              ),
              child: Row(
                children: [
                  Icon(Icons.place_outlined,
                      size: 18.r, color: ext.searchHintColor),
                  SizedBox(width: AppSpacing.sm.w),
                  Expanded(
                    child: Text(
                      place?.label ?? 'Choose a location',
                      style: TextStyle(
                        color: place == null
                            ? ext.searchHintColor
                            : ext.greetingColor,
                        fontSize: 14.sp,
                      ),
                    ),
                  ),
                  Icon(Icons.expand_more_rounded,
                      size: 20.r, color: ext.searchHintColor),
                ],
              ),
            ),
          ),
        ),
        if (place != null) ...[
          SizedBox(height: AppSpacing.sm.h),
          Text(
            place.isCountryWide
                ? 'Photographers across ${place.country ?? place.countryCode} '
                    'will see this.'
                : 'Photographers near ${place.label} see this first.',
            style: TextStyle(color: ext.searchHintColor, fontSize: 12.sp),
          ),
          SizedBox(height: AppSpacing.sm.h),
          LocationChips(
            places: draft.alsoReach,
            emptyLabel: '',
            onAdd: () => _addExtra(context),
            onRemove: (extra) {
              draft.alsoReach.remove(extra);
              onChanged();
            },
          ),
        ],
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child, required this.ext});

  final String label;
  final Widget child;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(bottom: AppSpacing.lg.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: ext.greetingColor,
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: AppSpacing.xs.h),
            child,
          ],
        ),
      );
}

class _Input extends StatelessWidget {
  const _Input({
    required this.controller,
    required this.hint,
    required this.ext,
    this.maxLines = 1,
    this.number = false,
    this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final AppThemeExtension ext;
  final int maxLines;
  final bool number;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        maxLines: maxLines,
        onChanged: onChanged,
        keyboardType: number ? TextInputType.number : TextInputType.text,
        style: TextStyle(color: ext.greetingColor, fontSize: 14.sp),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: ext.searchHintColor, fontSize: 14.sp),
          filled: true,
          fillColor: ext.searchFieldFill,
          contentPadding:
              EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md.r),
            borderSide: BorderSide.none,
          ),
        ),
      );
}

class _Tappable extends StatelessWidget {
  const _Tappable({
    required this.child,
    required this.ext,
    required this.onTap,
    this.trailing,
  });

  final Widget child;
  final AppThemeExtension ext;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 16.h),
          decoration: BoxDecoration(
            color: ext.searchFieldFill,
            borderRadius: BorderRadius.circular(AppRadius.md.r),
          ),
          child: Row(
            children: [
              Expanded(child: child),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      );
}

class _ReadBack extends StatelessWidget {
  const _ReadBack({
    required this.label,
    required this.value,
    required this.ext,
    this.tall = false,
  });

  final String label;
  final String value;
  final AppThemeExtension ext;
  final bool tall;

  @override
  Widget build(BuildContext context) => _Field(
        label: label,
        ext: ext,
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(minHeight: tall ? 90.h : 0),
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
          decoration: BoxDecoration(
            color: ext.searchFieldFill,
            borderRadius: BorderRadius.circular(AppRadius.md.r),
          ),
          child: Text(
            value.isEmpty ? '—' : value,
            style: TextStyle(
              color: ext.searchHintColor, fontSize: 14.sp, height: 1.4,
            ),
          ),
        ),
      );
}

class _DraftPhotos extends StatelessWidget {
  const _DraftPhotos({
    required this.photos,
    required this.ext,
    required this.onAdd,
    required this.onRemove,
  });

  final List<XFile> photos;
  final AppThemeExtension ext;
  final VoidCallback onAdd;
  final void Function(XFile) onRemove;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8.w,
      runSpacing: 8.h,
      children: [
        for (final photo in photos)
          SizedBox(
            width: 72.w,
            height: 72.w,
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.sm.r),
                    child: XFileImage(photo, fit: BoxFit.cover),
                  ),
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onRemove(photo),
                    child: Padding(
                      padding: EdgeInsets.all(4.r),
                      child: Container(
                        padding: EdgeInsets.all(2.r),
                        decoration: const BoxDecoration(
                          color: Colors.black54, shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.close_rounded,
                            size: 12.r, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onAdd,
          child: Container(
            width: 72.w,
            height: 72.w,
            decoration: BoxDecoration(
              color: ext.searchFieldFill,
              borderRadius: BorderRadius.circular(AppRadius.sm.r),
              border: Border.all(
                color: ext.searchHintColor.withValues(alpha: 0.25), width: 0.8,
              ),
            ),
            child: Icon(Icons.add_rounded,
                color: ext.searchHintColor, size: 22.r),
          ),
        ),
      ],
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.ext,
    required this.onPressed,
    this.busy = false,
  });

  final String label;
  final AppThemeExtension ext;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 52.h,
        child: ElevatedButton(
          onPressed: busy ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: ext.accentGold,
            disabledBackgroundColor: ext.accentGold.withValues(alpha: 0.4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999.r),
            ),
          ),
          child: busy
              ? SizedBox(
                  width: 18.r,
                  height: 18.r,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white,
                  ),
                )
              : Text(
                  label,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      );
}
