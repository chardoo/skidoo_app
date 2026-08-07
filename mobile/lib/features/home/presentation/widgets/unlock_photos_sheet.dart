import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/utils/web_wrap.dart';
import 'package:jperg_app/core/common/widgets/app_drag_handle.dart';

/// "Unlock private photos" — the entry point for an event code a photographer
/// shared, either typed or scanned.
///
/// Resolves to the code the user supplied, or null if they dismissed the
/// sheet. Deliberately knows nothing about what a code *means*: the caller
/// resolves it to an event and shows that event's photos, so the same sheet
/// works wherever a code is useful.
///
/// Typing and scanning return the same thing — a raw code — so the caller
/// treats them identically.
///
/// The scanner is embedded here rather than pushed as a page (per the design)
/// so that switching between typing and scanning is a toggle rather than a
/// navigation. The full-screen [QrScanPage] still exists for entry points that
/// are only ever about scanning.
class UnlockPhotosSheet extends StatefulWidget {
  const UnlockPhotosSheet({super.key});

  static Future<String?> show(BuildContext context) {
    if (kIsWeb) {
      return showDialog<String>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.55),
        builder: (_) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(24),
          child: webWrap(
            const UnlockPhotosSheet(),
            backgroundColor: Colors.transparent,
            width: kWebColumnWidth,
          ),
        ),
      );
    }
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const UnlockPhotosSheet(),
    );
  }

  @override
  State<UnlockPhotosSheet> createState() => _UnlockPhotosSheetState();
}

enum _Mode { code, scan }

class _UnlockPhotosSheetState extends State<UnlockPhotosSheet> {
  _Mode _mode = _Mode.code;
  final _controller = TextEditingController();

  /// Created lazily and disposed on mode change: holding a camera open behind
  /// the "Enter Code" tab would keep the torch/preview alive for nothing and
  /// show a permission prompt to someone who only meant to type.
  MobileScannerController? _scanner;
  bool _handled = false;

  @override
  void initState() {
    super.initState();
    // Enables/disables the CTA as the field fills.
    _controller.addListener(_onTextChanged);
  }

  void _onTextChanged() => setState(() {});

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _scanner?.dispose();
    super.dispose();
  }

  void _setMode(_Mode mode) {
    if (mode == _mode) return;
    setState(() {
      _mode = mode;
      if (mode == _Mode.scan) {
        _scanner = MobileScannerController(
          detectionSpeed: DetectionSpeed.noDuplicates,
          formats: const [BarcodeFormat.qrCode],
        );
      } else {
        _scanner?.dispose();
        _scanner = null;
      }
    });
  }

  /// One result only — the detector fires repeatedly while the code is in
  /// frame, and popping twice would tear down the caller's route as well.
  void _submit(String value) {
    final code = value.trim();
    if (code.isEmpty || _handled) return;
    _handled = true;
    Navigator.of(context).pop(code);
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      decoration: BoxDecoration(
        color: ext.homeBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xxl.r)),
      ),
      // Lifts the sheet above the keyboard so the field and CTA stay visible
      // while typing a code.
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppDragHandle(),
              Padding(
                padding: EdgeInsets.fromLTRB(AppSpacing.xxl.w, AppSpacing.lg.h,
                    AppSpacing.xxl.w, AppSpacing.xxl.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Unlock private photos',
                      style: TextStyle(
                        color: ext.greetingColor,
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: AppSpacing.sm.h),
                    Text(
                      'Enter code or scan QR code shared by creators to view '
                      'private photos.',
                      style: TextStyle(
                        color: ext.searchHintColor,
                        fontSize: 13.sp,
                        height: 1.4,
                      ),
                    ),
                    SizedBox(height: AppSpacing.xl.h),
                    _ModeToggle(
                      mode: _mode,
                      onChanged: _setMode,
                      ext: ext,
                    ),
                    SizedBox(height: AppSpacing.xl.h),
                    if (_mode == _Mode.code)
                      _CodeEntry(
                        controller: _controller,
                        ext: ext,
                        onSubmit: () => _submit(_controller.text),
                      )
                    else
                      _ScannerPane(
                        controller: _scanner,
                        ext: ext,
                        onDetect: _submit,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Two-segment pill: the active half is filled with the accent, per the
/// design. One shared track so the halves can't drift apart in width.
class _ModeToggle extends StatelessWidget {
  const _ModeToggle({
    required this.mode,
    required this.onChanged,
    required this.ext,
  });

  final _Mode mode;
  final ValueChanged<_Mode> onChanged;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ext.searchFieldFill,
        borderRadius: BorderRadius.circular(AppRadius.pill.r),
      ),
      child: Row(
        children: [
          Expanded(
            child: _Segment(
              label: 'Enter Code',
              selected: mode == _Mode.code,
              onTap: () => onChanged(_Mode.code),
              ext: ext,
            ),
          ),
          Expanded(
            child: _Segment(
              label: 'Scan QR',
              selected: mode == _Mode.scan,
              onTap: () => onChanged(_Mode.scan),
              ext: ext,
            ),
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.ext,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          padding: EdgeInsets.symmetric(vertical: AppSpacing.md.h),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? ext.accentGold : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.pill.r),
          ),
          child: Text(
            label,
            style: TextStyle(
              // White on the accent in both themes — the accent is the same
              // green either way, so the label that sits on it is too.
              color: selected ? Colors.white : ext.searchHintColor,
              fontSize: 14.sp,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _CodeEntry extends StatelessWidget {
  const _CodeEntry({
    required this.controller,
    required this.ext,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final AppThemeExtension ext;
  final VoidCallback onSubmit;

  bool get _canSubmit => controller.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          textInputAction: TextInputAction.go,
          onSubmitted: (_) => onSubmit(),
          style: TextStyle(color: ext.greetingColor, fontSize: 15.sp),
          decoration: InputDecoration(
            hintText: 'eg. AFRICA-26',
            hintStyle: TextStyle(color: ext.searchHintColor, fontSize: 15.sp),
            filled: true,
            fillColor: Colors.transparent,
            contentPadding: EdgeInsets.symmetric(
                horizontal: AppSpacing.lg.w, vertical: AppSpacing.lg.h),
            // Accent outline in both states, per the design — the field is the
            // one thing being asked for, so it stays emphasised.
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md.r),
              borderSide: BorderSide(color: ext.accentGold),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md.r),
              borderSide: BorderSide(color: ext.accentGold, width: 1.5),
            ),
          ),
        ),
        SizedBox(height: AppSpacing.xl.h),
        Center(
          child: Semantics(
            button: true,
            enabled: _canSubmit,
            label: 'Unlock photos',
            child: GestureDetector(
              onTap: _canSubmit ? onSubmit : null,
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.huge.w, vertical: AppSpacing.md.h),
                decoration: BoxDecoration(
                  // Resting state is the neutral fill from the design; it only
                  // takes the accent once there is something to submit.
                  color: _canSubmit ? ext.accentGold : ext.searchFieldFill,
                  borderRadius: BorderRadius.circular(AppRadius.pill.r),
                ),
                child: Text(
                  'Unlock photos',
                  style: TextStyle(
                    color: _canSubmit ? Colors.white : ext.greetingColor,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Live camera preview inside the sheet.
class _ScannerPane extends StatelessWidget {
  const _ScannerPane({
    required this.controller,
    required this.ext,
    required this.onDetect,
  });

  final MobileScannerController? controller;
  final AppThemeExtension ext;
  final ValueChanged<String> onDetect;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md.r),
        child: SizedBox(
          width: 200.w,
          height: 200.w,
          child: controller == null
              ? ColoredBox(color: ext.searchFieldFill)
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    MobileScanner(
                      controller: controller!,
                      onDetect: (capture) {
                        final code = capture.barcodes.firstOrNull?.rawValue;
                        if (code != null && code.isNotEmpty) onDetect(code);
                      },
                      errorBuilder: (context, error) => ColoredBox(
                        color: ext.searchFieldFill,
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.all(AppSpacing.lg.w),
                            child: Text(
                              'Camera unavailable. Enter the code instead.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: ext.searchHintColor, fontSize: 13.sp),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Framing guide — the preview is small, so the corners do
                    // the work an overlay would on a full-screen scanner.
                    IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.all(color: ext.accentGold, width: 2),
                          borderRadius:
                              BorderRadius.circular(AppRadius.md.r),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

