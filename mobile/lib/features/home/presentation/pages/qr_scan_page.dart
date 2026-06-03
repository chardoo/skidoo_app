import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/core/utils/snackbar_utils.dart';

class QrScanPage extends StatefulWidget {
  const QrScanPage({super.key});

  @override
  State<QrScanPage> createState() => _QrScanPageState();
}

class _QrScanPageState extends State<QrScanPage> {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: [BarcodeFormat.qrCode],
  );

  bool _processing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleCode(String code) async {
    if (_processing) return;
    setState(() => _processing = true);
    try { await _controller.stop(); } catch (_) {}
    if (!mounted) return;
    // Return the event ID to the caller (HomeNavigationPage) which will
    // fire HomeImagesSearched and push SearchResultsPage.
    Navigator.of(context).pop(code.trim());
  }

  Future<void> _pickFromGallery() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file == null) return;
    final result = await _controller.analyzeImage(file.path);
    if (!mounted) return;
    final code = result?.barcodes.firstOrNull?.rawValue;
    if (code != null && code.isNotEmpty) {
      await _handleCode(code);
    } else {
      AppSnackBar.error(context, 'No QR code found in the selected image.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: kIsWeb ? null : IconButton(
          tooltip: 'Back',
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 20.sp),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Scan Event QR',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: false,
        actions: [
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: _controller,
            builder: (context, state, _) {
              final torchState = state.torchState;
              if (torchState == TorchState.unavailable) {
                return const SizedBox.shrink();
              }
              return IconButton(
                icon: Icon(
                  torchState == TorchState.on
                      ? Icons.flash_on_rounded
                      : Icons.flash_off_rounded,
                  color: Colors.white,
                  size: 22.sp,
                ),
                onPressed: () {
                  try { _controller.toggleTorch(); } catch (_) {}
                },
              );
            },
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Camera ────────────────────────────────────────────────────────
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              final code = capture.barcodes.firstOrNull?.rawValue;
              if (code != null && code.isNotEmpty) _handleCode(code);
            },
          ),

          // ── Scan-frame overlay ────────────────────────────────────────────
          _ScanOverlay(ext: ext),

          // ── Loading overlay ───────────────────────────────────────────────
          if (_processing)
            Container(
              color: Colors.black.withValues(alpha: 0.55),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 36.w,
                      height: 36.w,
                      child: CircularProgressIndicator(
                          color: ext.accentGold, strokeWidth: 2.5),
                    ),
                    SizedBox(height: 14.h),
                    Text(
                      'Loading event…',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),

          // ── Bottom bar ────────────────────────────────────────────────────
          if (!_processing)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.fromLTRB(24.w, 20.h, 24.w,
                    MediaQuery.of(context).padding.bottom + 20.h),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.85),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Point your camera at an event QR code',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 16.h),
                    Semantics(button: true, label: 'Pick from gallery', child: GestureDetector(
                      onTap: _pickFromGallery,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 24.w, vertical: 13.h),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(30.r),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.25),
                              width: 1.0),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.photo_library_outlined,
                                color: Colors.white, size: 18.sp),
                            SizedBox(width: 8.w),
                            Text(
                              'Choose from Gallery',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
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

// ── Scan frame overlay ────────────────────────────────────────────────────────

class _ScanOverlay extends StatelessWidget {
  const _ScanOverlay({required this.ext});
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final frameSize = size.width * 0.65;
    final top = (size.height - frameSize) / 2 - 40;

    return Stack(
      children: [
        // Dark surround — four rects around the frame
        Positioned.fill(
          child: CustomPaint(
            painter: _DimPainter(
              frameSize: frameSize,
              frameTop: top,
              centerX: size.width / 2,
            ),
          ),
        ),

        // Gold corner brackets
        Positioned(
          left: (size.width - frameSize) / 2,
          top: top,
          width: frameSize,
          height: frameSize,
          child: CustomPaint(painter: _CornerPainter(color: ext.accentGold)),
        ),
      ],
    );
  }
}

class _DimPainter extends CustomPainter {
  const _DimPainter({
    required this.frameSize,
    required this.frameTop,
    required this.centerX,
  });
  final double frameSize;
  final double frameTop;
  final double centerX;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withValues(alpha: 0.55);
    final frameLeft = centerX - frameSize / 2;
    final frameRect =
        Rect.fromLTWH(frameLeft, frameTop, frameSize, frameSize);
    final full = Rect.fromLTWH(0, 0, size.width, size.height);

    final path = Path()
      ..addRect(full)
      ..addRect(frameRect)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_DimPainter old) => false;
}

class _CornerPainter extends CustomPainter {
  const _CornerPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const len = 22.0;
    const r = 10.0;

    void drawCorner(double x, double y, double dx, double dy) {
      canvas.drawPath(
        Path()
          ..moveTo(x, y + dy * len)
          ..lineTo(x, y + dy * r)
          ..arcToPoint(Offset(x + dx * r, y),
              radius: const Radius.circular(r), clockwise: dy != dx)
          ..lineTo(x + dx * len, y),
        paint,
      );
    }

    drawCorner(0, 0, 1, 1);                          // top-left
    drawCorner(size.width, 0, -1, 1);                // top-right
    drawCorner(0, size.height, 1, -1);               // bottom-left
    drawCorner(size.width, size.height, -1, -1);     // bottom-right
  }

  @override
  bool shouldRepaint(_CornerPainter old) => old.color != color;
}
