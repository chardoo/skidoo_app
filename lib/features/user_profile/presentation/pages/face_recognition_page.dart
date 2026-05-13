import 'dart:io';

import 'package:dio/dio.dart' as dio_pkg;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:skidoo_app/api/dio_client_service.dart';
import 'package:skidoo_app/core/di/service_locator.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/core/utils/snackbar_utils.dart';
import 'package:skidoo_app/services/auth_service.dart';

class FaceRecognitionPage extends StatefulWidget {
  const FaceRecognitionPage({super.key});

  @override
  State<FaceRecognitionPage> createState() => _FaceRecognitionPageState();
}

class _FaceRecognitionPageState extends State<FaceRecognitionPage> {
  final _picker = ImagePicker();
  final List<File> _photos = [];
  bool _uploading = false;

  Future<void> _pickPhotos() async {
    final picked = await _picker.pickMultiImage(imageQuality: 85);
    if (picked.isEmpty) return;
    setState(() {
      for (final xf in picked) {
        final f = File(xf.path);
        if (!_photos.any((p) => p.path == f.path)) _photos.add(f);
      }
    });
  }

  Future<void> _pickFromCamera() async {
    final picked = await _picker.pickImage(
        source: ImageSource.camera, imageQuality: 85);
    if (picked == null) return;
    final f = File(picked.path);
    if (!_photos.any((p) => p.path == f.path)) {
      setState(() => _photos.add(f));
    }
  }

  void _removePhoto(int index) => setState(() => _photos.removeAt(index));

  Future<void> _submit() async {
    if (_photos.isEmpty) {
      AppSnackBar.error(context, 'Add at least one photo.');
      return;
    }
    setState(() => _uploading = true);
    try {
      final email = await sl<AuthService>().getEmail();
      final files = await Future.wait(_photos.map((f) async =>
          dio_pkg.MultipartFile.fromFile(
            f.path,
            filename: f.uri.pathSegments.last,
          )));
      final formData = dio_pkg.FormData.fromMap({
        'email': email,
        'files': files,
      });
      await sl<Api>().dio.post(
        '/client/train-model',
        data: formData,
        options: dio_pkg.Options(
          contentType: 'multipart/form-data',
          receiveTimeout: const Duration(minutes: 3),
          sendTimeout: const Duration(minutes: 3),
        ),
      );
      if (!mounted) return;
      AppSnackBar.success(
          context, 'Face recognition training queued successfully.');
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) AppSnackBar.error(context, 'Training failed: $e');
    } finally {
      if (mounted) setState(() => _uploading = false);
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
          icon: Icon(Icons.arrow_back_ios_rounded,
              color: ext.greetingColor, size: 18.sp),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Face Recognition',
          style: TextStyle(
              color: ext.greetingColor,
              fontSize: 17.sp,
              fontWeight: FontWeight.w700),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 8.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Train Your Face Model',
                    style: TextStyle(
                      color: ext.greetingColor,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    'Upload clear face photos so we can recognise you in event photos automatically. '
                    'Use well-lit, front-facing shots for best results.',
                    style: TextStyle(
                        color: ext.searchHintColor, fontSize: 13.sp, height: 1.5),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Row(
                children: [
                  _AddPhotoButton(
                    icon: Icons.photo_library_outlined,
                    label: 'Gallery',
                    ext: ext,
                    onTap: _uploading ? null : _pickPhotos,
                  ),
                  SizedBox(width: 12.w),
                  _AddPhotoButton(
                    icon: Icons.camera_alt_outlined,
                    label: 'Camera',
                    ext: ext,
                    onTap: _uploading ? null : _pickFromCamera,
                  ),
                ],
              ),
            ),
            SizedBox(height: 16.h),
            if (_photos.isNotEmpty)
              Expanded(
                child: GridView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8.w,
                    mainAxisSpacing: 8.h,
                  ),
                  itemCount: _photos.length,
                  itemBuilder: (_, i) => _PhotoTile(
                    file: _photos[i],
                    onRemove: _uploading ? null : () => _removePhoto(i),
                  ),
                ),
              )
            else
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.face_outlined,
                          size: 56.sp,
                          color: ext.searchHintColor.withValues(alpha: 0.4)),
                      SizedBox(height: 12.h),
                      Text(
                        'No photos selected',
                        style: TextStyle(
                            color: ext.searchHintColor, fontSize: 14.sp),
                      ),
                    ],
                  ),
                ),
              ),
            Padding(
              padding:
                  EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 24.h),
              child: SizedBox(
                width: double.infinity,
                height: 50.h,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ext.accentGold,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    disabledBackgroundColor:
                        ext.accentGold.withValues(alpha: 0.5),
                  ),
                  onPressed:
                      (_uploading || _photos.isEmpty) ? null : _submit,
                  child: _uploading
                      ? SizedBox(
                          width: 22.w,
                          height: 22.w,
                          child: const CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          'Train Face Model (${_photos.length} photo${_photos.length == 1 ? '' : 's'})',
                          style: TextStyle(
                              fontSize: 15.sp, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddPhotoButton extends StatelessWidget {
  const _AddPhotoButton({
    required this.icon,
    required this.label,
    required this.ext,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final AppThemeExtension ext;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 14.h),
          decoration: BoxDecoration(
            color: ext.cardSurface,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: ext.accentGold.withValues(alpha: 0.3),
              width: 0.8,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: ext.accentGold, size: 24.sp),
              SizedBox(height: 4.h),
              Text(
                label,
                style: TextStyle(
                    color: ext.greetingColor,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.file, required this.onRemove});

  final File file;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8.r),
          child: Image.file(file, fit: BoxFit.cover),
        ),
        Positioned(
          top: 4.h,
          right: 4.w,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.close_rounded,
                  color: Colors.white, size: 14.sp),
            ),
          ),
        ),
      ],
    );
  }
}
