import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/core/utils/snackbar_utils.dart';
import 'package:skidoo_app/features/ads/data/repositories/ads_repository.dart';
import 'package:video_player/video_player.dart';

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
  bool _submitting = false;

  XFile? _asset;
  bool _assetIsVideo = false;
  VideoPlayerController? _videoCtrl;

  final _repo = AdsRepository();
  final _picker = ImagePicker();

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _locationCtrl.dispose();
    _budgetCtrl.dispose();
    _videoCtrl?.dispose();
    super.dispose();
  }

  Future<void> _pickMedia(BuildContext context) async {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _MediaPickerSheet(
        ext: ext,
        onPick: _handlePick,
      ),
    );
  }

  static const _maxBytes = 50 * 1024 * 1024; // 50 MB

  Future<void> _handlePick(ImageSource source, bool video) async {
    XFile? file;
    if (video) {
      file = await _picker.pickVideo(source: source, maxDuration: const Duration(minutes: 2));
    } else {
      file = await _picker.pickImage(source: source, imageQuality: 85);
    }
    if (file == null) return;

    final size = await File(file.path).length();
    if (size > _maxBytes) {
      if (!mounted) return;
      AppSnackBar.error(context, 'File is too large. Maximum size is 50 MB.');
      return;
    }

    VideoPlayerController? newCtrl;
    if (video) {
      newCtrl = VideoPlayerController.file(File(file.path));
      try {
        await newCtrl.initialize();
        await newCtrl.setVolume(0);
        await newCtrl.setLooping(true);
        await newCtrl.play();
      } catch (e) {
        debugPrint('[PostRequestPage] video preview error: $e');
        newCtrl.dispose();
        newCtrl = null;
      }
    }

    if (!mounted) {
      newCtrl?.dispose();
      return;
    }
    setState(() {
      _videoCtrl?.dispose();
      _videoCtrl = newCtrl;
      _asset = file;
      _assetIsVideo = video;
    });
  }

  void _removeAsset() {
    setState(() {
      _videoCtrl?.dispose();
      _videoCtrl = null;
      _asset = null;
      _assetIsVideo = false;
    });
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
      );
      debugPrint('[PostRequestPage] _submit — requestId=$requestId');

      if (_asset != null && requestId.isNotEmpty) {
        debugPrint('[PostRequestPage] _submit — uploading asset');
        await _repo.uploadRequestAsset(requestId, _asset!.path);
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

    return Scaffold(
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
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),

            SizedBox(height: 20.h),
            // ── Media picker ──────────────────────────────────────────────
            Row(
              children: [
                _SectionLabel('Media', ext),
                SizedBox(width: 6.w),
                Text(
                  '(optional)',
                  style:
                      TextStyle(color: ext.searchHintColor, fontSize: 12.sp),
                ),
              ],
            ),
            SizedBox(height: 4.h),
            Text(
              'Attach a photo or short video to attract more photographers.',
              style: TextStyle(color: ext.searchHintColor, fontSize: 12.sp),
            ),
            SizedBox(height: 10.h),
            _AssetPreview(
              asset: _asset,
              isVideo: _assetIsVideo,
              videoCtrl: _videoCtrl,
              ext: ext,
              onPick: () => _pickMedia(context),
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

            SizedBox(height: 32.h),

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
  }
}

// ── Asset preview / picker ────────────────────────────────────────────────────

class _AssetPreview extends StatelessWidget {
  const _AssetPreview({
    required this.asset,
    required this.isVideo,
    required this.videoCtrl,
    required this.ext,
    required this.onPick,
    required this.onRemove,
  });

  final XFile? asset;
  final bool isVideo;
  final VideoPlayerController? videoCtrl;
  final AppThemeExtension ext;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    if (asset == null) {
      // Empty picker tap target
      return GestureDetector(
        onTap: onPick,
        child: Container(
          height: 130.h,
          decoration: BoxDecoration(
            color: ext.searchFieldFill,
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(
              color: ext.searchHintColor.withValues(alpha: 0.25),
              width: 1.2,
              strokeAlign: BorderSide.strokeAlignInside,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _MediaTypeButton(
                    icon: Icons.image_outlined,
                    label: 'Photo',
                    color: ext.accentGold,
                  ),
                  SizedBox(width: 20.w),
                  const _MediaTypeButton(
                    icon: Icons.videocam_outlined,
                    label: 'Video',
                    color: Color(0xFF8B5CF6),
                  ),
                ],
              ),
              SizedBox(height: 10.h),
              Text(
                'Tap to add media',
                style: TextStyle(
                  color: ext.searchHintColor,
                  fontSize: 12.sp,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Preview of selected asset
    return ClipRRect(
      borderRadius: BorderRadius.circular(14.r),
      child: Stack(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: isVideo
                ? (videoCtrl != null && videoCtrl!.value.isInitialized
                    ? VideoPlayer(videoCtrl!)
                    : Container(color: Colors.black))
                : Image.file(File(asset!.path), fit: BoxFit.cover),
          ),
          // Asset type pill
          Positioned(
            top: 8.h,
            left: 10.w,
            child: _AssetTypePill(isVideo: isVideo),
          ),
          // Remove button
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
          // Re-pick tap on the bottom strip
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: GestureDetector(
              onTap: onPick,
              child: Container(
                color: Colors.black.withValues(alpha: 0.45),
                padding: EdgeInsets.symmetric(vertical: 7.h),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.edit_rounded,
                        color: Colors.white70, size: 14.sp),
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

class _MediaTypeButton extends StatelessWidget {
  const _MediaTypeButton({
    required this.icon,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24.sp),
        ),
        SizedBox(height: 4.h),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ── Asset type pill ───────────────────────────────────────────────────────────

class _AssetTypePill extends StatelessWidget {
  const _AssetTypePill({required this.isVideo});
  final bool isVideo;

  @override
  Widget build(BuildContext context) {
    final color = isVideo ? const Color(0xFF8B5CF6) : const Color(0xFF3B82F6);
    final icon = isVideo ? Icons.play_circle_rounded : Icons.image_rounded;
    final label = isVideo ? 'Video' : 'Image';

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: color.withValues(alpha: 0.7), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10.sp, color: color),
          SizedBox(width: 3.w),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 9.sp,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Media picker bottom sheet ─────────────────────────────────────────────────

class _MediaPickerSheet extends StatelessWidget {
  const _MediaPickerSheet({required this.ext, required this.onPick});
  final AppThemeExtension ext;
  final Future<void> Function(ImageSource, bool) onPick;

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
              child: Text(
                'Add Media',
                style: TextStyle(
                  color: ext.greetingColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 16.sp,
                ),
              ),
            ),
            Divider(
                height: 1, color: ext.searchHintColor.withValues(alpha: 0.1)),
            _SheetOption(
              ext: ext,
              icon: Icons.image_rounded,
              color: ext.accentGold,
              title: 'Photo from Gallery',
              onTap: () async {
                Navigator.of(context).pop();
                await onPick(ImageSource.gallery, false);
              },
            ),
            _SheetOption(
              ext: ext,
              icon: Icons.videocam_rounded,
              color: const Color(0xFF8B5CF6),
              title: 'Video from Gallery',
              onTap: () async {
                Navigator.of(context).pop();
                await onPick(ImageSource.gallery, true);
              },
            ),
            _SheetOption(
              ext: ext,
              icon: Icons.camera_alt_rounded,
              color: const Color(0xFF3B82F6),
              title: 'Take a Photo',
              onTap: () async {
                Navigator.of(context).pop();
                await onPick(ImageSource.camera, false);
              },
            ),
            _SheetOption(
              ext: ext,
              icon: Icons.videocam_outlined,
              color: const Color(0xFF10B981),
              title: 'Record a Video',
              onTap: () async {
                Navigator.of(context).pop();
                await onPick(ImageSource.camera, true);
              },
            ),
            SizedBox(height: 8.h),
          ],
        ),
      ),
    );
  }
}

class _SheetOption extends StatelessWidget {
  const _SheetOption({
    required this.ext,
    required this.icon,
    required this.color,
    required this.title,
    required this.onTap,
  });
  final AppThemeExtension ext;
  final IconData icon;
  final Color color;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 40.w,
        height: 40.w,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 20.sp),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: ext.greetingColor,
          fontWeight: FontWeight.w600,
          fontSize: 14.sp,
        ),
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
