import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:skidoo_app/core/common/widgets/app_text_field.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/core/utils/snackbar_utils.dart';
import 'package:skidoo_app/core/validators/validators.dart';
import 'package:skidoo_app/core/validators/media_validator.dart';
import 'package:skidoo_app/features/ads/data/repositories/ads_repository.dart';
import 'package:skidoo_app/core/common/widgets/xfile_image.dart';
import 'package:skidoo_app/core/utils/web_wrap.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:skidoo_app/core/theme/app_input.dart';
import 'package:skidoo_app/core/theme/app_radius.dart';
import 'package:skidoo_app/core/theme/app_spacing.dart';
import 'package:skidoo_app/core/common/widgets/app_back_button.dart';

const _eventTypes = [
  'Wedding',
  'Birthday',
  'Corporate',
  'Concert',
  'Graduation',
  'Engagement',
  'Baby Shower',
  'Anniversary',
  'Sports',
  'Other',
];

class PostRequestPage extends StatefulWidget {
  const PostRequestPage({super.key});

  @override
  State<PostRequestPage> createState() => _PostRequestPageState();
}

class _PostRequestPageState extends State<PostRequestPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _budgetCtrl = TextEditingController();
  String? _selectedEventType;
  String _visibleTo = 'all';
  bool _submitting = false;
  bool _commentsEnabled = true;

  final List<XFile> _assets = [];
  static const _maxAssets = 5;

  final _repo = AdsRepository();
  final _picker = ImagePicker();

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _locationCtrl.dispose();
    _budgetCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickMedia() async {
    if (_assets.length >= _maxAssets) return;
    final file =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null) return;

    final error = await MediaValidator.validate(file, isVideo: false);
    if (!mounted) return;
    if (error != null) {
      AppSnackBar.error(context, error);
      return;
    }

    setState(() => _assets.add(file));
  }

  void _removeAsset(int index) {
    setState(() => _assets.removeAt(index));
  }

  Future<void> _submit() async {
    debugPrint('[PostRequestPage] _submit — validating form');
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    final budget = _budgetCtrl.text.isNotEmpty
        ? double.tryParse(_budgetCtrl.text.trim())
        : null;
    try {
      final requestId = await _repo.postRequest(
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        eventType: _selectedEventType!,
        location: _locationCtrl.text.trim(),
        budgetAmount: budget,
        currency: 'GHS',
        commentsEnabled: _commentsEnabled,
        visibleTo: _visibleTo,
      );
      debugPrint('[PostRequestPage] _submit — requestId=$requestId');

      if (_assets.isNotEmpty && requestId.isNotEmpty) {
        debugPrint(
            '[PostRequestPage] _submit — uploading ${_assets.length} asset(s)');
        for (final file in _assets) {
          await _repo.uploadRequestMedia(requestId, file);
        }
      }

      if (!mounted) return;
      AppSnackBar.success(
        context,
        'Request submitted! It will go live after admin review.',
      );
      Navigator.of(context).pop();
    } catch (e) {
      debugPrint('[PostRequestPage] _submit ERROR: $e');
      if (!mounted) return;
      AppSnackBar.error(context, 'Failed to submit. Please try again.');
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
            : AppBackButton(onPressed: () => Navigator.of(context).pop()),
        title: Text(
          'Post a Request',
          style: TextStyle(
            color: ext.greetingColor,
            fontSize: 17.sp,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: false,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.xl.w, vertical: AppSpacing.sm.h),
          children: [
            _FieldLabel('What are you looking for?', ext),
            SizedBox(height: AppSpacing.sm.h),
            _Field(
              controller: _titleCtrl,
              hint: 'e.g. Wedding photographer needed',
              validator: (v) =>
                  Validators.lengthBetween(v, 3, 100, field: 'Title'),
            ),

            SizedBox(height: AppSpacing.xl.h),
            _FieldLabel('Event type', ext),
            SizedBox(height: AppSpacing.sm.h),
            _EventTypeDropdown(
              value: _selectedEventType,
              ext: ext,
              onChanged: (v) => setState(() => _selectedEventType = v),
            ),

            SizedBox(height: AppSpacing.xl.h),
            _FieldLabel('Visible to', ext),
            SizedBox(height: AppSpacing.sm.h),
            _VisibleToSelector(
              value: _visibleTo,
              ext: ext,
              onChanged: (v) => setState(() => _visibleTo = v),
            ),

            SizedBox(height: AppSpacing.xl.h),
            _FieldLabel('Location', ext),
            SizedBox(height: AppSpacing.sm.h),
            _Field(
              controller: _locationCtrl,
              hint: 'e.g. Accra, Ghana',
              validator: (v) =>
                  Validators.lengthBetween(v, 2, 80, field: 'Location'),
            ),

            SizedBox(height: AppSpacing.xl.h),
            _FieldLabel('Description', ext),
            SizedBox(height: AppSpacing.sm.h),
            _Field(
              controller: _descCtrl,
              hint:
                  'Describe the event, date, style preferences, anything helpful...',
              maxLines: 4,
              validator: (v) =>
                  Validators.maxLength(v, 1000, field: 'Description'),
            ),

            SizedBox(height: AppSpacing.xl.h),
            // ── Media picker ──────────────────────────────────────────────
            Row(
              children: [
                _FieldLabel('Photos', ext),
                SizedBox(width: 6.w),
                Text(
                  '(optional)',
                  style: TextStyle(color: ext.searchHintColor, fontSize: 12.sp),
                ),
                const Spacer(),
                Text(
                  '${_assets.length}/$_maxAssets',
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
              'Add up to 5 photos to attract more photographers.',
              style: TextStyle(color: ext.searchHintColor, fontSize: 12.sp),
            ),
            SizedBox(height: 10.h),
            _MultiMediaPicker(
              assets: _assets,
              maxAssets: _maxAssets,
              ext: ext,
              onAdd: _pickMedia,
              onRemove: _removeAsset,
            ),

            SizedBox(height: AppSpacing.xl.h),
            _FieldLabel('Budget (optional)', ext),
            SizedBox(height: AppSpacing.xs.h),
            Text(
              'Enter a rough budget so photographers know what to expect.',
              style: TextStyle(color: ext.searchHintColor, fontSize: 12.sp),
            ),
            SizedBox(height: AppSpacing.sm.h),
            _Field(
              controller: _budgetCtrl,
              hint: 'e.g. 500',
              keyboardType: TextInputType.number,
              validator: (v) => Validators.optionalAmount(v, field: 'Budget'),
              prefixText: 'GHS  ',
            ),

            SizedBox(height: AppSpacing.lg.h),

            // ── Comments toggle ───────────────────────────────────────────
            SwitchListTile(
              value: _commentsEnabled,
              onChanged: (v) => setState(() => _commentsEnabled = v),
              title: Text(
                'Allow comments',
                style: TextStyle(color: ext.greetingColor, fontSize: 14.sp),
              ),
              subtitle: Text(
                'Let others comment on your request',
                style: TextStyle(color: ext.searchHintColor, fontSize: 12.sp),
              ),
              activeThumbColor: ext.accentGold,
              contentPadding: EdgeInsets.zero,
            ),

            SizedBox(height: AppSpacing.lg.h),

            // ── Submit ────────────────────────────────────────────────────
            _SubmitButton(
              submitting: _submitting,
              ext: ext,
              onTap: _submit,
            ),
            SizedBox(height: AppSpacing.xl.h),
          ],
        ),
      ),
    );
    return webWrap(page, backgroundColor: ext.homeBackground);
  }
}

// ── Multi-image picker ────────────────────────────────────────────────────────

class _MultiMediaPicker extends StatelessWidget {
  const _MultiMediaPicker({
    required this.assets,
    required this.maxAssets,
    required this.ext,
    required this.onAdd,
    required this.onRemove,
  });

  final List<XFile> assets;
  final int maxAssets;
  final AppThemeExtension ext;
  final VoidCallback onAdd;
  final void Function(int index) onRemove;

  static const _thumbSize = 90.0;

  @override
  Widget build(BuildContext context) {
    final atLimit = assets.length >= maxAssets;
    return SizedBox(
      height: _thumbSize,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          // Existing thumbnails
          ...List.generate(assets.length, (i) {
            return Padding(
              padding: EdgeInsets.only(right: AppSpacing.sm.w),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10.r),
                    child: XFileImage(
                      assets[i],
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

          // Add button (shown when under limit)
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
                          'Add photo',
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

// ── Field label ───────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text, this.ext);
  final String text;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: ext.greetingColor,
        fontSize: 14.sp,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.1,
      ),
    );
  }
}

// ── Text field ────────────────────────────────────────────────────────────────

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.keyboardType,
    this.validator,
    this.prefixText,
  });

  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final String? prefixText;

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType ?? TextInputType.text,
      validator: validator,
      dense: true,
      hint: hint,
      prefixText: prefixText,
    );
  }
}

// ── Event type dropdown ───────────────────────────────────────────────────────

class _EventTypeDropdown extends StatelessWidget {
  const _EventTypeDropdown({
    required this.value,
    required this.ext,
    required this.onChanged,
  });
  final String? value;
  final AppThemeExtension ext;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w),
      decoration: BoxDecoration(
        color: ext.searchFieldFill,
        borderRadius: BorderRadius.circular(AppRadius.md.r),
      ),
      // ignore: deprecated_member_use
      child: DropdownButtonFormField<String>(
        // ignore: deprecated_member_use
        value: value,
        hint: Text(
          'Select event type',
          style: TextStyle(color: ext.searchHintColor, fontSize: 14.sp),
        ),
        dropdownColor: ext.cardSurface,
        style: TextStyle(color: ext.greetingColor, fontSize: 14.sp),
        icon: Icon(Icons.expand_more_rounded,
            color: ext.searchHintColor, size: 20.sp),
        // The container this sits in draws the only outline — see
        // [kBorderlessInput].
        decoration: kBorderlessInput.copyWith(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
        validator: (v) => v == null ? 'Required' : null,
        items: _eventTypes
            .map((t) => DropdownMenuItem(value: t, child: Text(t)))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }
}

// ── Submit button ─────────────────────────────────────────────────────────────

class _SubmitButton extends StatelessWidget {
  const _SubmitButton({
    required this.submitting,
    required this.onTap,
    required this.ext,
  });
  final bool submitting;
  final VoidCallback onTap;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    return Semantics(
        button: true,
        label: 'Submit',
        child: GestureDetector(
          onTap: submitting ? null : onTap,
          child: Container(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.lg.h),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: submitting
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
            child: submitting
                ? SizedBox(
                    width: 20.w,
                    height: 20.w,
                    child: const CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : Text(
                    'Submit Request',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
          ),
        ));
  }
}

// ── Visible-to toggle — "Photographers" | "Clients" ──────────────────────────

class _VisibleToSelector extends StatelessWidget {
  const _VisibleToSelector({
    required this.value,
    required this.ext,
    required this.onChanged,
  });
  final String value;
  final AppThemeExtension ext;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8.w,
      runSpacing: 8.h,
      children: [
        _VisibleToChip(
          label: 'Everyone',
          selected: value == 'all',
          ext: ext,
          onTap: () => onChanged('all'),
        ),
        _VisibleToChip(
          label: 'Photographers',
          selected: value == 'photographers',
          ext: ext,
          onTap: () => onChanged('photographers'),
        ),
        _VisibleToChip(
          label: 'Clients',
          selected: value == 'clients',
          ext: ext,
          onTap: () => onChanged('clients'),
        ),
        _VisibleToChip(
          label: 'Followers',
          selected: value == 'followers',
          ext: ext,
          onTap: () => onChanged('followers'),
        ),
      ],
    );
  }
}

class _VisibleToChip extends StatelessWidget {
  const _VisibleToChip({
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
  Widget build(BuildContext context) {
    return Semantics(
        button: true,
        label: label,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 11.h),
            decoration: BoxDecoration(
              color: selected
                  ? ext.accentGold.withValues(alpha: 0.12)
                  : ext.searchFieldFill,
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(
                color: selected
                    ? ext.accentGold
                    : ext.searchHintColor.withValues(alpha: 0.25),
                width: selected ? 1.5 : 1.0,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: selected ? ext.accentGold : ext.searchHintColor,
                fontSize: 13.sp,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ));
  }
}
