import 'dart:io' show File;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:skidoo_app/core/constants/photography_specialties.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/models/photographer/photographer_sample.dart';
import 'package:skidoo_app/core/theme/app_radius.dart';
import 'package:skidoo_app/core/theme/app_spacing.dart';

/// Minimum sample-work photos required, matching the design ("min. 4
/// photos") and used by both callers to gate their primary action.
const kMinSamplePhotos = 4;

/// Current snapshot of the form — handed to [PortfolioForm.onChanged] on
/// every edit so the caller (onboarding step or Account-section edit page)
/// always has the latest state without needing imperative access.
class PortfolioFormData {
  const PortfolioFormData({
    this.newProfilePhoto,
    this.newStudioImage,
    required this.studioName,
    required this.bio,
    required this.specialties,
    required this.keptExistingSamples,
    required this.newSampleFiles,
  });

  /// Newly picked profile photo, if the user changed it this session —
  /// uploaded separately via `POST /photographer/profile/{id}/photo`.
  final XFile? newProfilePhoto;

  /// Newly picked studio cover photo — a second, independent image from the
  /// personal avatar, uploaded via
  /// `POST /photographer/profile/{id}/studio-image`.
  final XFile? newStudioImage;
  final String studioName;
  final String bio;
  final Set<String> specialties;

  /// Samples fetched from the server (edit mode) that haven't been removed
  /// locally. The caller decides whether to actually delete removed ones.
  final List<PhotographerSample> keptExistingSamples;

  /// Newly picked sample files, not yet uploaded.
  final List<XFile> newSampleFiles;

  int get totalSampleCount => keptExistingSamples.length + newSampleFiles.length;
  bool get meetsMinimumSamples => totalSampleCount >= kMinSamplePhotos;
}

/// Shared "Set up your portfolio" form fields — profile photo, studio name,
/// bio, specialties, and a sample-work grid. Used both by the onboarding
/// step (empty initial state) and the Account-section edit page (prefilled
/// from `GET /photographer/profile` + `GET /photographer/samples`) so the
/// two surfaces can never drift apart.
class PortfolioForm extends StatefulWidget {
  const PortfolioForm({
    super.key,
    required this.onChanged,
    this.initialProfilePhotoUrl,
    this.initialStudioImageUrl,
    this.initialStudioName = '',
    this.initialBio = '',
    this.initialSpecialties = const {},
    this.initialSamples = const [],
  });

  final ValueChanged<PortfolioFormData> onChanged;
  final String? initialProfilePhotoUrl;
  final String? initialStudioImageUrl;
  final String initialStudioName;
  final String initialBio;
  final Set<String> initialSpecialties;
  final List<PhotographerSample> initialSamples;

  @override
  State<PortfolioForm> createState() => _PortfolioFormState();
}

class _PortfolioFormState extends State<PortfolioForm> {
  late final TextEditingController _nameCtrl =
      TextEditingController(text: widget.initialStudioName);
  late final TextEditingController _bioCtrl =
      TextEditingController(text: widget.initialBio);
  late final Set<String> _specialties = {...widget.initialSpecialties};
  late List<PhotographerSample> _keptExisting = [...widget.initialSamples];
  final List<XFile> _newSamples = [];
  XFile? _newProfilePhoto;
  XFile? _newStudioImage;

  @override
  void initState() {
    super.initState();
    _nameCtrl.addListener(_notify);
    _bioCtrl.addListener(_notify);
    // Let the caller see the initial snapshot too (e.g. to know whether the
    // min-samples gate is already met when prefilled in edit mode).
    WidgetsBinding.instance.addPostFrameCallback((_) => _notify());
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  void _notify() {
    widget.onChanged(PortfolioFormData(
      newProfilePhoto: _newProfilePhoto,
      newStudioImage: _newStudioImage,
      studioName: _nameCtrl.text.trim(),
      bio: _bioCtrl.text.trim(),
      specialties: _specialties,
      keptExistingSamples: _keptExisting,
      newSampleFiles: _newSamples,
    ));
  }

  Future<void> _pickProfilePhoto() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    setState(() => _newProfilePhoto = picked);
    _notify();
  }

  Future<void> _pickStudioImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    setState(() => _newStudioImage = picked);
    _notify();
  }

  Future<void> _addSamplePhotos() async {
    final picked = await ImagePicker().pickMultiImage(imageQuality: 85);
    if (picked.isEmpty) return;
    setState(() => _newSamples.addAll(picked));
    _notify();
  }

  void _removeExistingSample(PhotographerSample sample) {
    setState(() => _keptExisting = _keptExisting.where((s) => s.id != sample.id).toList());
    _notify();
  }

  void _removeNewSample(XFile file) {
    setState(() => _newSamples.remove(file));
    _notify();
  }

  void _toggleSpecialty(String tag) {
    setState(() {
      if (!_specialties.remove(tag)) _specialties.add(tag);
    });
    _notify();
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Semantics(
            button: true,
            label: 'Change profile photo',
            child: GestureDetector(
              onTap: _pickProfilePhoto,
              child: _ProfilePhotoPicker(
                ext: ext,
                localFile: _newProfilePhoto,
                networkUrl: widget.initialProfilePhotoUrl,
              ),
            ),
          ),
        ),
        SizedBox(height: AppSpacing.xl.h),
        _FieldLabel('Studio cover photo (optional)', ext: ext),
        SizedBox(height: AppSpacing.sm.h),
        Semantics(
          button: true,
          label: 'Change studio cover photo',
          child: GestureDetector(
            onTap: _pickStudioImage,
            child: _StudioImagePicker(
              ext: ext,
              localFile: _newStudioImage,
              networkUrl: widget.initialStudioImageUrl,
            ),
          ),
        ),
        SizedBox(height: AppSpacing.xxl.h),
        _FieldLabel('Studio name', ext: ext),
        SizedBox(height: 6.h),
        _TextInput(controller: _nameCtrl, hint: 'Username', ext: ext),
        SizedBox(height: AppSpacing.lg.h),
        _FieldLabel('Bio summary', ext: ext),
        SizedBox(height: 6.h),
        _TextInput(controller: _bioCtrl, hint: 'Tell people about your work', ext: ext, maxLines: 4),
        SizedBox(height: AppSpacing.xl.h),
        _FieldLabel('Specialties', ext: ext),
        SizedBox(height: AppSpacing.sm.h),
        Wrap(
          spacing: 8.w,
          runSpacing: 8.h,
          children: kPhotographySpecialties.map((tag) {
            final selected = _specialties.contains(tag);
            return Semantics(
              button: true,
              selected: selected,
              label: tag,
              child: GestureDetector(
                onTap: () => _toggleSpecialty(tag),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: AppSpacing.sm.h),
                  decoration: BoxDecoration(
                    color: selected ? ext.accentGold : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.xl.r),
                    border: Border.all(
                      color: selected ? ext.accentGold : ext.searchHintColor.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(
                      color: selected ? Colors.white : ext.searchHintColor,
                      fontSize: 12.5.sp,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        SizedBox(height: AppSpacing.xl.h),
        _FieldLabel('Sample work (min. $kMinSamplePhotos photos)', ext: ext),
        SizedBox(height: AppSpacing.sm.h),
        Wrap(
          spacing: 10.w,
          runSpacing: 10.h,
          children: [
            for (final sample in _keptExisting)
              _SampleThumb(
                ext: ext,
                image: Image.network(sample.url, fit: BoxFit.cover),
                onRemove: () => _removeExistingSample(sample),
              ),
            for (final file in _newSamples)
              _SampleThumb(
                ext: ext,
                image: kIsWeb
                    ? Image.network(file.path, fit: BoxFit.cover)
                    : Image.file(File(file.path), fit: BoxFit.cover),
                onRemove: () => _removeNewSample(file),
              ),
            Semantics(
              button: true,
              label: 'Add sample photos',
              child: GestureDetector(
                onTap: _addSamplePhotos,
                child: Container(
                  width: 72.w,
                  height: 72.w,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(
                        color: ext.accentGold.withValues(alpha: 0.5), width: 1.2),
                  ),
                  child: Icon(Icons.add_rounded, color: ext.accentGold),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text, {required this.ext});
  final String text;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
          color: ext.greetingColor, fontSize: 13.sp, fontWeight: FontWeight.w600),
    );
  }
}

class _TextInput extends StatelessWidget {
  const _TextInput({
    required this.controller,
    required this.hint,
    required this.ext,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String hint;
  final AppThemeExtension ext;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    // SelectionContainer.disabled works around a Flutter framework bug
    // (`!_selectionStartsInScrollable` assertion, flutter/flutter#111690) —
    // a TextField's own selection-drag machinery conflicts with the
    // ancestor Scrollable's edge-autoscroll-on-selection delegate. This
    // field always sits inside a scrollable (OnboardingStepScaffold or
    // PortfolioEditPage's own SingleChildScrollView), so it always needs
    // this to avoid crashing on a long-press text selection.
    return SelectionContainer.disabled(
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: TextStyle(color: ext.greetingColor, fontSize: 14.sp),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: ext.searchHintColor, fontSize: 14.sp),
          filled: true,
          fillColor: ext.searchFieldFill,
          contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: AppSpacing.md.h),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md.r),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class _ProfilePhotoPicker extends StatelessWidget {
  const _ProfilePhotoPicker({required this.ext, this.localFile, this.networkUrl});
  final AppThemeExtension ext;
  final XFile? localFile;
  final String? networkUrl;

  @override
  Widget build(BuildContext context) {
    final size = 88.w;
    Widget content;
    if (localFile != null) {
      content = ClipOval(
        child: kIsWeb
            ? Image.network(localFile!.path, fit: BoxFit.cover, width: size, height: size)
            : Image.file(File(localFile!.path), fit: BoxFit.cover, width: size, height: size),
      );
    } else if (networkUrl != null && networkUrl!.isNotEmpty) {
      content = ClipOval(
        child: Image.network(networkUrl!, fit: BoxFit.cover, width: size, height: size),
      );
    } else {
      content = Icon(Icons.add_a_photo_outlined, color: ext.accentGold, size: 28.sp);
    }
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
            color: ext.accentGold.withValues(alpha: 0.6),
            width: 1.5,
            style: BorderStyle.solid),
      ),
      child: content,
    );
  }
}

class _StudioImagePicker extends StatelessWidget {
  const _StudioImagePicker({required this.ext, this.localFile, this.networkUrl});
  final AppThemeExtension ext;
  final XFile? localFile;
  final String? networkUrl;

  @override
  Widget build(BuildContext context) {
    Widget content;
    if (localFile != null) {
      content = kIsWeb
          ? Image.network(localFile!.path, fit: BoxFit.cover, width: double.infinity)
          : Image.file(File(localFile!.path), fit: BoxFit.cover, width: double.infinity);
    } else if (networkUrl != null && networkUrl!.isNotEmpty) {
      content = Image.network(networkUrl!, fit: BoxFit.cover, width: double.infinity);
    } else {
      content = Center(
        child: Icon(Icons.add_photo_alternate_outlined, color: ext.accentGold, size: 28.sp),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md.r),
      child: Container(
        height: 110.h,
        width: double.infinity,
        decoration: BoxDecoration(
          color: ext.searchFieldFill,
          borderRadius: BorderRadius.circular(AppRadius.md.r),
          border: Border.all(color: ext.accentGold.withValues(alpha: 0.4)),
        ),
        child: content,
      ),
    );
  }
}

class _SampleThumb extends StatelessWidget {
  const _SampleThumb({required this.ext, required this.image, required this.onRemove});
  final AppThemeExtension ext;
  final Widget image;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final size = 72.w;
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10.r),
          child: SizedBox(width: size, height: size, child: image),
        ),
        Positioned(
          top: 2,
          right: 2,
          child: Semantics(
            button: true,
            label: 'Remove photo',
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                    color: Colors.black54, shape: BoxShape.circle),
                child: Icon(Icons.close_rounded, color: Colors.white, size: 12.sp),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
