import 'package:camera/camera.dart';
import 'package:dio/dio.dart' as dio_pkg;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/api/dio_client_service.dart';
import 'package:skidoo_app/core/common/widgets/selfie_capture_screen.dart';
import 'package:skidoo_app/core/di/service_locator.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/core/utils/snackbar_utils.dart';
import 'package:skidoo_app/services/auth_service.dart';
import 'package:skidoo_app/core/utils/web_wrap.dart';

class FaceRecognitionPage extends StatefulWidget {
  const FaceRecognitionPage({super.key});

  @override
  State<FaceRecognitionPage> createState() => _FaceRecognitionPageState();
}

class _FaceRecognitionPageState extends State<FaceRecognitionPage> {
  // Validated selfie files — each was accepted by face detection.
  final List<XFile> _selfies = [];
  bool _uploading = false;

  static const _maxSelfies = 5;

  Future<void> _addSelfie() async {
    if (_selfies.length >= _maxSelfies) return;
    final xFile = await SelfieCaptureScreen.push(context);
    if (xFile == null || !mounted) return;
    setState(() => _selfies.add(xFile));
  }

  void _removeSelfie(int index) => setState(() => _selfies.removeAt(index));

  Future<void> _submit() async {
    if (_selfies.isEmpty) {
      AppSnackBar.error(context, 'Take at least one selfie first.');
      return;
    }
    setState(() => _uploading = true);
    try {
      final email = await sl<AuthService>().getEmail();
      final files = await Future.wait(_selfies.map((f) async {
        final bytes = await f.readAsBytes();
        final filename = f.name.isNotEmpty ? f.name : 'selfie.jpg';
        return dio_pkg.MultipartFile.fromBytes(bytes, filename: filename);
      }));
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
    final canAdd = _selfies.length < _maxSelfies && !_uploading;

    final page = Scaffold(
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
            // ── Header ──────────────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 20.h),
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
                    'Take up to $_maxSelfies clear selfies so we can '
                    'recognise you in event photos automatically. '
                    'Face the camera directly in good lighting.',
                    style: TextStyle(
                        color: ext.searchHintColor,
                        fontSize: 13.sp,
                        height: 1.5),
                  ),
                ],
              ),
            ),

            // ── Selfie grid ──────────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10.w,
                    mainAxisSpacing: 10.h,
                  ),
                  itemCount: _selfies.length + (canAdd ? 1 : 0),
                  itemBuilder: (_, i) {
                    if (i == _selfies.length) {
                      // "+" add-selfie tile
                      return _AddSelfieTile(
                        ext: ext,
                        onTap: _uploading ? null : _addSelfie,
                        count: _selfies.length,
                        max: _maxSelfies,
                      );
                    }
                    return _SelfieTile(
                      file: _selfies[i],
                      onRemove: _uploading ? null : () => _removeSelfie(i),
                    );
                  },
                ),
              ),
            ),

            // ── Submit button ────────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 24.h),
              child: SizedBox(
                width: double.infinity,
                height: 50.h,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ext.accentGold,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    disabledBackgroundColor:
                        ext.accentGold.withValues(alpha: 0.4),
                  ),
                  onPressed: (_uploading || _selfies.isEmpty) ? null : _submit,
                  child: _uploading
                      ? SizedBox(
                          width: 22.w,
                          height: 22.w,
                          child: const CircularProgressIndicator(
                              color: Colors.black, strokeWidth: 2),
                        )
                      : Text(
                          _selfies.isEmpty
                              ? 'Take a selfie to continue'
                              : 'Train with ${_selfies.length} selfie${_selfies.length == 1 ? '' : 's'}',
                          style: TextStyle(
                              fontSize: 15.sp, fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return webWrap(page, backgroundColor: ext.homeBackground);
  }

}

// ── Grid tiles ────────────────────────────────────────────────────────────────

class _AddSelfieTile extends StatelessWidget {
  const _AddSelfieTile({
    required this.ext,
    required this.onTap,
    required this.count,
    required this.max,
  });

  final AppThemeExtension ext;
  final VoidCallback? onTap;
  final int count;
  final int max;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: ext.cardSurface,
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(
            color: ext.accentGold.withValues(alpha: 0.35),
            width: 1.2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_a_photo_rounded,
                color: ext.accentGold, size: 26.sp),
            SizedBox(height: 6.h),
            Text(
              '$count / $max',
              style: TextStyle(
                  color: ext.searchHintColor,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelfieTile extends StatelessWidget {
  const _SelfieTile({required this.file, required this.onRemove});
  final XFile file;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10.r),
          child: kIsWeb
              ? Image.network(file.path, fit: BoxFit.cover)
              : FutureBuilder<Uint8List>(
                  future: file.readAsBytes(),
                  builder: (_, snap) => snap.hasData
                      ? Image.memory(snap.data!, fit: BoxFit.cover)
                      : const SizedBox(),
                ),
        ),
        // Face-confirmed badge
        Positioned(
          bottom: 4.h,
          left: 4.w,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
            decoration: BoxDecoration(
              color: Colors.green.shade700.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(4.r),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_rounded,
                    color: Colors.white, size: 10),
                SizedBox(width: 2.w),
                Text('Face OK',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 9.sp,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
        // Remove button
        Positioned(
          top: 4.h,
          right: 4.w,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.close_rounded,
                  color: Colors.white, size: 13.sp),
            ),
          ),
        ),
      ],
    );
  }
}
