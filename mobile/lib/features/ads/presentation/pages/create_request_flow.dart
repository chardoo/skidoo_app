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
  String location = '';
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
      location.trim().isNotEmpty &&
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
  late final _location = TextEditingController(text: widget.draft.location);
  late final _description = TextEditingController(text: widget.draft.description);
  late final _budgetMin = TextEditingController(
    text: widget.draft.budgetMin?.toStringAsFixed(0) ?? '',
  );
  late final _budgetMax = TextEditingController(
    text: widget.draft.budgetMax?.toStringAsFixed(0) ?? '',
  );

  @override
  void dispose() {
    for (final c in [_title, _location, _description, _budgetMin, _budgetMax]) {
      c.dispose();
    }
    super.dispose();
  }

  void _sync() {
    widget.draft
      ..title = _title.text
      ..location = _location.text
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
            child: _Input(controller: _location, hint: 'Location', ext: ext,
                onChanged: (_) => setState(_sync)),
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
          : AppBackButton(onPressed: () => Navigator.of(context).pop()),
      title: Text(
        title,
        style: TextStyle(
          color: ext.greetingColor,
          fontWeight: FontWeight.w700,
          fontSize: 16.sp,
        ),
      ),
    );

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
