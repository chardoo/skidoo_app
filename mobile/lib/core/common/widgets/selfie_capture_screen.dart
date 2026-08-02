import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/platform/face_check.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/core/theme/app_radius.dart';
import 'package:skidoo_app/core/theme/app_spacing.dart';
import 'package:skidoo_app/core/common/widgets/app_back_button.dart';

/// Full-screen front-camera selfie capture with on-device face validation.
///
/// Usage:
/// ```dart
/// final xFile = await SelfieCaptureScreen.push(context);
/// if (xFile != null) { /* has a validated face (or web bypass) */ }
/// ```
///
/// Returns an [XFile] when a face is confirmed (or on web without ML validation),
/// or null if the user cancels.
class SelfieCaptureScreen extends StatefulWidget {
  const SelfieCaptureScreen({super.key});

  static Future<XFile?> push(BuildContext context) =>
      Navigator.of(context).push<XFile?>(
        MaterialPageRoute(builder: (_) => const SelfieCaptureScreen()),
      );

  @override
  State<SelfieCaptureScreen> createState() => _SelfieCaptureScreenState();
}

class _SelfieCaptureScreenState extends State<SelfieCaptureScreen>
    with WidgetsBindingObserver {
  CameraController? _ctrl;
  bool _cameraReady = false;
  bool _checking = false;
  String? _errorHint;
  // After a failed detection, let the user bypass the ML check.
  XFile? _lastCapturedFile;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      _ctrl?.dispose();
      _ctrl = null;
      if (mounted) setState(() => _cameraReady = false);
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (!mounted || cameras.isEmpty) return;
      final cam = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      // On web the camera plugin ignores imageFormatGroup; Platform.isAndroid
      // throws UnsupportedError on web so we must guard it.
      ImageFormatGroup? fmt;
      if (!kIsWeb) {
        // ignore: avoid_dynamic_calls
        fmt = (defaultTargetPlatform == TargetPlatform.android)
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888;
      }
      final ctrl = CameraController(
        cam,
        ResolutionPreset.high,
        imageFormatGroup: fmt,
      );
      await ctrl.initialize();
      if (!mounted) {
        ctrl.dispose();
        return;
      }
      setState(() {
        _ctrl = ctrl;
        _cameraReady = true;
      });
    } catch (_) {
      // Camera unavailable — preview stays hidden, user sees error.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ctrl?.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    if (!_cameraReady || _ctrl == null || _checking) return;
    setState(() {
      _checking = true;
      _errorHint = null;
      _lastCapturedFile = null;
    });
    try {
      final xFile = await _ctrl!.takePicture();
      // [FaceCheck] answers true where it can't tell — on web, or when the
      // platform detector is unavailable — so the photo is simply accepted.
      final hasFace = await FaceCheck.hasFace(xFile.path);
      if (!mounted) return;
      if (!hasFace) {
        setState(() {
          _checking = false;
          _lastCapturedFile = xFile;
          _errorHint =
              'No face detected — make sure your face fills the oval and the lighting is even.';
        });
        return;
      }
      Navigator.of(context).pop(xFile);
    } catch (_) {
      if (mounted) {
        setState(() {
          _checking = false;
          _errorHint = 'Could not analyse the photo. Please try again.';
        });
      }
    }
  }

  void _useAnyway() {
    if (_lastCapturedFile != null) {
      Navigator.of(context).pop(_lastCapturedFile);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Camera preview ────────────────────────────────────────────────
          if (_cameraReady && _ctrl != null)
            ClipRect(child: CameraPreview(_ctrl!))
          else
            const Center(
              child: CircularProgressIndicator(
                  color: Colors.white30, strokeWidth: 2),
            ),

          // ── Face-guide oval + dim surround ────────────────────────────────
          if (_cameraReady)
            CustomPaint(
              painter: _OvalGuidePainter(
                color: _errorHint != null
                    ? Colors.red.shade400
                    : ext.accentGold,
              ),
            ),

          // ── Top bar ───────────────────────────────────────────────────────
          SafeArea(
            bottom: false,
            child: Padding(
              padding:
                  EdgeInsets.symmetric(horizontal: AppSpacing.lg.w, vertical: 10.h),
              child: Row(
                children: [
                  if (!kIsWeb)
                    _CircleIconBtn(
                      icon: AppBackButton.icon,
                      onTap: () => Navigator.of(context).pop(null),
                    ),
                  const Spacer(),
                  Text(
                    'Take a Selfie',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16.sp,
                      shadows: const [
                        Shadow(blurRadius: 8, color: Colors.black54),
                      ],
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 36),
                ],
              ),
            ),
          ),

          // ── Bottom controls ───────────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                  24.w, 20.h, 24.w, bottomPad + 32.h),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.80),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Error pill + optional bypass button
                  if (_errorHint != null) ...[
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 14.w, vertical: 10.h),
                      decoration: BoxDecoration(
                        color: Colors.red.shade800.withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(AppRadius.md.r),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.face_retouching_off_rounded,
                              color: Colors.white, size: 18),
                          SizedBox(width: AppSpacing.sm.w),
                          Expanded(
                            child: Text(
                              _errorHint!,
                              style: TextStyle(
                                  color: Colors.white, fontSize: 13.sp),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_lastCapturedFile != null) ...[
                      SizedBox(height: AppSpacing.sm.h),
                      Semantics(button: true, label: 'Use anyway', child: GestureDetector(
                        onTap: _useAnyway,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 14.w, vertical: 9.h),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10.r),
                            border: Border.all(
                                color: Colors.white30, width: 0.8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check_circle_outline_rounded,
                                  color: Colors.white70, size: 16),
                              SizedBox(width: 6.w),
                              Text(
                                'Use this photo anyway',
                                style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      )),
                    ],
                    SizedBox(height: 14.h),
                  ],

                  // Guide hint
                  Text(
                    _errorHint == null
                        ? 'Centre your face inside the oval'
                        : 'Ensure good lighting and face the camera',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13.sp,
                    ),
                  ),
                  SizedBox(height: 22.h),

                  // Shutter button
                  Semantics(button: true, label: 'Capture', child: GestureDetector(
                    onTap: _cameraReady && !_checking ? _capture : null,
                    child: _ShutterButton(checking: _checking),
                  )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _CircleIconBtn extends StatelessWidget {
  const _CircleIconBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(button: true, label: 'Camera control', child: GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36.w,
        height: 36.w,
        decoration: const BoxDecoration(
          color: Colors.black45,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 18.sp),
      ),
    ));
  }
}

class _ShutterButton extends StatelessWidget {
  const _ShutterButton({required this.checking});
  final bool checking;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72.w,
      height: 72.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        color: checking ? Colors.white24 : Colors.white.withValues(alpha: 0.15),
      ),
      child: checking
          ? const Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.5),
              ),
            )
          : Center(
              child: Container(
                width: 54.w,
                height: 54.w,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
              ),
            ),
    );
  }
}

// ── Face-guide oval painter ───────────────────────────────────────────────────

class _OvalGuidePainter extends CustomPainter {
  const _OvalGuidePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.40;
    final rx = size.width * 0.36;
    final ry = size.height * 0.27;

    final oval = Rect.fromCenter(
        center: Offset(cx, cy), width: rx * 2, height: ry * 2);
    final full = Rect.fromLTWH(0, 0, size.width, size.height);

    // Dim surround with oval cut-out
    canvas.drawPath(
      Path()
        ..addRect(full)
        ..addOval(oval)
        ..fillType = PathFillType.evenOdd,
      Paint()..color = Colors.black.withValues(alpha: 0.45),
    );

    // Coloured oval border (gold = OK, red = error)
    canvas.drawOval(
      oval,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(_OvalGuidePainter old) => old.color != color;
}
