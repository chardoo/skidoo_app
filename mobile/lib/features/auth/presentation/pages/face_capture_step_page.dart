import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:dio/dio.dart' as dio_pkg;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/api/dio_client_service.dart';
import 'package:jperg_app/core/common/widgets/selfie_capture_screen.dart';
import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/auth/presentation/pages/audience_preference_page.dart';
import 'package:jperg_app/features/auth/presentation/widgets/onboarding_step_scaffold.dart';
import 'package:jperg_app/services/auth_service.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';

enum _Step { intro, scanning, confirmed }

/// Skippable "Add your face" step, run once right after email verification.
/// Reuses the existing [SelfieCaptureScreen] for the actual camera + ML-Kit
/// capture, then uploads via the same `/client/train-model` endpoint the
/// post-signup "add your photos" reminder (FaceRecognitionPage) already uses
/// — so a face added here or added later end up in the exact same place.
///
/// Runs in two modes. During sign-up it is step 1 of the 4-step wizard and
/// hands off to the audience-preference question when done. Reached later from
/// the Found gate ([standalone]) it is a single errand: capture, upload, pop —
/// no wizard chrome, and no re-running questions the user already answered
/// when they created the account.
class FaceCaptureStepPage extends StatefulWidget {
  const FaceCaptureStepPage({super.key, this.standalone = false});

  /// True when opened by an already-onboarded user who just needs a face on
  /// file. Suppresses the step counter and returns to the caller instead of
  /// continuing into the sign-up wizard.
  final bool standalone;

  @override
  State<FaceCaptureStepPage> createState() => _FaceCaptureStepPageState();
}

class _FaceCaptureStepPageState extends State<FaceCaptureStepPage> {
  _Step _step = _Step.intro;
  XFile? _captured;
  bool _uploading = false;
  String _name = '';
  // Selfies are used for face-training only by default — the user must
  // explicitly opt in for the same photo to also become their profile photo.
  bool _useAsProfile = false;

  @override
  void initState() {
    super.initState();
    sl<AuthService>().getName().then((v) {
      if (mounted) setState(() => _name = v);
    });
  }

  Future<void> _scan() async {
    final xFile = await SelfieCaptureScreen.push(context);
    if (!mounted || xFile == null) return;
    setState(() {
      _captured = xFile;
      _step = _Step.scanning;
    });
    // Brief "scanning" beat — the actual face validation already happened
    // inside SelfieCaptureScreen; this is just the confirmation animation.
    await Future.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    setState(() => _step = _Step.confirmed);
  }

  void _retake() {
    setState(() {
      _captured = null;
      _step = _Step.intro;
    });
  }

  Future<void> _continueWithPhoto() async {
    if (_captured == null) {
      _finish();
      return;
    }
    setState(() => _uploading = true);
    try {
      final email = await sl<AuthService>().getEmail();
      final bytes = await _captured!.readAsBytes();
      final filename = _captured!.name.isNotEmpty ? _captured!.name : 'selfie.jpg';
      final formData = dio_pkg.FormData.fromMap({
        'email': email,
        'files': [dio_pkg.MultipartFile.fromBytes(bytes, filename: filename)],
        'use_as_profile': _useAsProfile.toString(),
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
      await sl<AuthService>().setHasAddedFaces(true);
    } catch (_) {
      // Non-blocking — the "add your photos" nudge will pick this up later
      // if the upload failed, same as skipping this step outright.
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
    _finish();
  }

  /// Where to go once the face is dealt with — including when the upload
  /// failed or the user skipped, which both land here.
  ///
  /// Standalone callers get popped straight back to where they came from (the
  /// Found tab), because everything past this point belongs to sign-up: the
  /// audience question, and the wizard steps after it. Sending an existing
  /// user back through "what best describes you" is asking them to redo
  /// account setup to add a selfie.
  void _finish() {
    if (!mounted) return;
    if (widget.standalone) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AudiencePreferencePage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_step == _Step.scanning) return const _ScanningView();

    if (_step == _Step.confirmed) {
      return OnboardingStepScaffold(
        currentStep: 1,
        totalSteps: widget.standalone ? 1 : 4,
        title: _name.isNotEmpty ? 'Looks great, $_name!' : 'Looks great!',
        subtitle: "Your face data is encrypted and used only to find your "
            "photos. It's never shared with third parties.",
        primaryLabel: 'Continue',
        primaryLoading: _uploading,
        onPrimaryPressed: _continueWithPhoto,
        onSkip: _uploading ? null : _retake,
        skipLabel: 'Retake photo',
        child: _ConfirmedPhoto(
          file: _captured!,
          useAsProfile: _useAsProfile,
          uploading: _uploading,
          onUseAsProfileChanged: (v) => setState(() => _useAsProfile = v),
        ),
      );
    }

    return OnboardingStepScaffold(
      currentStep: 1,
      totalSteps: widget.standalone ? 1 : 4,
      title: 'Add your face',
      subtitle: "We use your selfie to find you in photos. It's stored "
          'privately and never shared.',
      primaryLabel: 'Scan my face',
      onPrimaryPressed: _scan,
      onSkip: _finish,
      child: Builder(builder: (context) {
        final ext = Theme.of(context).extension<AppThemeExtension>()!;
        return Center(child: DottedCircle(color: ext.accentGold, size: 140.w));
      }),
    );
  }
}

class _ConfirmedPhoto extends StatelessWidget {
  const _ConfirmedPhoto({
    required this.file,
    required this.useAsProfile,
    required this.uploading,
    required this.onUseAsProfileChanged,
  });

  final XFile file;
  final bool useAsProfile;
  final bool uploading;
  final ValueChanged<bool> onUseAsProfileChanged;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    return Column(
      children: [
        Center(
          child: Container(
            width: 140.w,
            height: 140.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: ext.accentGold, width: 3),
              boxShadow: [
                BoxShadow(
                    color: ext.accentGold.withValues(alpha: 0.25),
                    blurRadius: 20),
              ],
            ),
            child: ClipOval(
              child: kIsWeb
                  ? Image.network(file.path, fit: BoxFit.cover)
                  : Image.file(File(file.path), fit: BoxFit.cover),
            ),
          ),
        ),
        SizedBox(height: AppSpacing.xxl.h),
        InkWell(
          borderRadius: BorderRadius.circular(10.r),
          onTap: uploading ? null : () => onUseAsProfileChanged(!useAsProfile),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 6.h, horizontal: AppSpacing.xs.w),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 22.w,
                  height: 22.w,
                  child: Checkbox(
                    value: useAsProfile,
                    activeColor: ext.accentGold,
                    onChanged: uploading
                        ? null
                        : (v) => onUseAsProfileChanged(v ?? false),
                  ),
                ),
                SizedBox(width: AppSpacing.sm.w),
                Flexible(
                  child: Text(
                    'Use this photo as my profile picture too',
                    style: TextStyle(color: ext.greetingColor, fontSize: 13.sp),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ScanningView extends StatefulWidget {
  const _ScanningView();

  @override
  State<_ScanningView> createState() => _ScanningViewState();
}

class _ScanningViewState extends State<_ScanningView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _ctrl,
              builder: (context, child) {
                final scale = 1.0 + (_ctrl.value * 0.12);
                return Transform.scale(scale: scale, child: child);
              },
              child: Container(
                width: 140.w,
                height: 140.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF1D9E75).withValues(alpha: 0.15),
                  border: Border.all(
                      color: const Color(0xFF1D9E75).withValues(alpha: 0.6), width: 2),
                ),
              ),
            ),
            SizedBox(height: 28.h),
            Text(
              'scanning face...',
              style: TextStyle(color: Colors.white70, fontSize: 15.sp),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dashed-circle placeholder used before a face photo is captured.
class DottedCircle extends StatelessWidget {
  const DottedCircle({super.key, required this.color, required this.size});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _DashedCirclePainter(color: color),
      child: SizedBox(
        width: size,
        height: size,
        child: Icon(Icons.face_retouching_natural_rounded, color: color, size: size * 0.4),
      ),
    );
  }
}

class _DashedCirclePainter extends CustomPainter {
  const _DashedCirclePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    const dashCount = 36;
    final radius = size.width / 2;
    final center = Offset(size.width / 2, size.height / 2);
    for (var i = 0; i < dashCount; i++) {
      final angle = (i / dashCount) * 2 * math.pi;
      if (i.isEven) continue;
      final start = center +
          Offset(radius * 0.94 * math.cos(angle), radius * 0.94 * math.sin(angle));
      final end = center + Offset(radius * math.cos(angle), radius * math.sin(angle));
      canvas.drawLine(start, end, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DashedCirclePainter oldDelegate) =>
      oldDelegate.color != color;
}
