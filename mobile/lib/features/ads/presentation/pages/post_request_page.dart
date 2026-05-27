import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/core/utils/snackbar_utils.dart';
import 'package:skidoo_app/features/ads/data/repositories/ads_repository.dart';
import 'package:skidoo_app/core/utils/web_wrap.dart';

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
    final file = await _picker.pickImage(
        source: ImageSource.gallery, imageQuality: 85);
    if (file == null) return;

    final size = await File(file.path).length();
    if (size > _maxBytes) {
      if (!mounted) return;
      AppSnackBar.error(context, 'File is too large. Maximum size is 50 MB.');
      return;
    }

    if (!mounted) return;
    setState(() => _assets.add(file));
  }

  static const _maxBytes = 50 * 1024 * 1024; // 50 MB

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
        debugPrint('[PostRequestPage] _submit — uploading ${_assets.length} asset(s)');
        for (final file in _assets) {
          await _repo.uploadRequestMedia(requestId, file.path);
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
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: ext.greetingColor, size: 20.sp),
          onPressed: () => Navigator.of(context).pop(),
        ),
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
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
          children: [
            _SectionLabel('What are you looking for?', ext),
            SizedBox(height: 8.h),
            _Field(
              controller: _titleCtrl,
              hint: 'e.g. Wedding photographer needed',
              ext: ext,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),

            SizedBox(height: 20.h),
            _SectionLabel('Event type', ext),
            SizedBox(height: 8.h),
            _EventTypeDropdown(
              value: _selectedEventType,
              ext: ext,
              onChanged: (v) => setState(() => _selectedEventType = v),
            ),

            SizedBox(height: 20.h),
            _SectionLabel('Visible to', ext),
            SizedBox(height: 8.h),
            _VisibleToSelector(
              value: _visibleTo,
              ext: ext,
              onChanged: (v) => setState(() => _visibleTo = v),
            ),

            SizedBox(height: 20.h),
            _SectionLabel('Location', ext),
            SizedBox(height: 8.h),
            _Field(
              controller: _locationCtrl,
              hint: 'e.g. Accra, Ghana',
              ext: ext,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),

            SizedBox(height: 20.h),
            _SectionLabel('Description', ext),
            SizedBox(height: 8.h),
            _Field(
              controller: _descCtrl,
              hint:
                  'Describe the event, date, style preferences, anything helpful...',
              ext: ext,
              maxLines: 4,
            ),

            SizedBox(height: 20.h),
            // ── Media picker ──────────────────────────────────────────────
            Row(
              children: [
                _SectionLabel('Photos', ext),
                SizedBox(width: 6.w),
                Text(
                  '(optional)',
                  style:
                      TextStyle(color: ext.searchHintColor, fontSize: 12.sp),
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
            SizedBox(height: 4.h),
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

            SizedBox(height: 20.h),
            _SectionLabel('Budget (optional)', ext),
            SizedBox(height: 4.h),
            Text(
              'Enter a rough budget so photographers know what to expect.',
              style:
                  TextStyle(color: ext.searchHintColor, fontSize: 12.sp),
            ),
            SizedBox(height: 8.h),
            _Field(
              controller: _budgetCtrl,
              hint: 'e.g. 500',
              ext: ext,
              keyboardType: TextInputType.number,
              prefix: Text(
                'GHS  ',
                style: TextStyle(
                  color: ext.searchHintColor,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            SizedBox(height: 16.h),

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

            SizedBox(height: 16.h),

            // ── Submit ────────────────────────────────────────────────────
            _SubmitButton(
              submitting: _submitting,
              onTap: _submit,
              ext: ext,
            ),
            SizedBox(height: 20.h),
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
              padding: EdgeInsets.only(right: 8.w),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10.r),
                    child: Image.file(
                      File(assets[i].path),
                      width: _thumbSize,
                      height: _thumbSize,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
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
                    ),
                  ),
                ],
              ),
            );
          }),

          // Add button (shown when under limit)
          if (!atLimit)
            GestureDetector(
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
                    SizedBox(height: 4.h),
                    Text(
                      'Add Photo',
                      style: TextStyle(
                        color: ext.searchHintColor,
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, this.ext);
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
    required this.ext,
    this.maxLines = 1,
    this.keyboardType,
    this.validator,
    this.prefix,
  });

  final TextEditingController controller;
  final String hint;
  final AppThemeExtension ext;
  final int maxLines;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final Widget? prefix;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      style: TextStyle(color: ext.greetingColor, fontSize: 14.sp),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: prefix != null
            ? Padding(
                padding: EdgeInsets.only(left: 14.w, right: 0),
                child: prefix,
              )
            : null,
        prefixIconConstraints: const BoxConstraints(minWidth: 0),
        hintStyle:
            TextStyle(color: ext.searchHintColor, fontSize: 14.sp),
        filled: true,
        fillColor: ext.searchFieldFill,
        contentPadding:
            EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide(
            color: ext.accentGold.withValues(alpha: 0.6),
            width: 1.2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide:
              const BorderSide(color: Colors.redAccent, width: 1.0),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide:
              const BorderSide(color: Colors.redAccent, width: 1.2),
        ),
      ),
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
        borderRadius: BorderRadius.circular(12.r),
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
        decoration: const InputDecoration(
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 14),
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
    return GestureDetector(
      onTap: submitting ? null : onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 16.h),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: submitting
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
    );
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
    return GestureDetector(
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
    );
  }
}
