import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/common/widgets/app_back_button.dart';
import 'package:jperg_app/core/common/widgets/app_button.dart';
import 'package:jperg_app/core/common/widgets/selfie_capture_screen.dart';
import 'package:jperg_app/core/common/widgets/xfile_image.dart';
import 'package:jperg_app/core/theme/app_icons.dart';
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/theme/app_typography.dart';
import 'package:jperg_app/core/utils/snackbar_utils.dart';
import 'package:jperg_app/core/widgets/media_grid.dart';
import 'package:jperg_app/features/gallery/data/easy_search.dart';
import 'package:jperg_app/features/gallery/presentation/found/pages/event_scan_result_page.dart';
import 'package:jperg_app/features/home/presentation/widgets/unlock_photos_sheet.dart';

/// Find your photos from one event without saving your face.
///
/// Two things are needed and neither is optional: the selfies to compare, and
/// the code for the album to compare them against. The search is scoped to one
/// event *because* nothing is stored — with no enrolled face there is no index
/// to sweep, so "every event" would mean recognising every photo on the
/// platform on demand.
///
/// The selfies go out with the search and are not kept anywhere: not on the
/// face service (see `/similarity/match`), and not here either — this page
/// holds them for as long as it is open and no longer.
class EasySearchPage extends StatefulWidget {
  const EasySearchPage({super.key});

  static Future<void> push(BuildContext context) =>
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(builder: (_) => const EasySearchPage()),
      );

  @override
  State<EasySearchPage> createState() => _EasySearchPageState();
}

class _EasySearchPageState extends State<EasySearchPage> {
  /// Four, which is the face service's own ceiling on reference photos — not a
  /// number chosen here. More than four would be rejected by the server.
  static const _maxSelfies = EasySearch.maxFaces;

  final List<XFile> _selfies = [];
  String? _code;
  bool _starting = false;

  bool get _ready => _selfies.isNotEmpty && (_code?.isNotEmpty ?? false);

  Future<void> _addSelfie() async {
    if (_selfies.length >= _maxSelfies) return;
    final file = await SelfieCaptureScreen.push(context);
    if (file == null || !mounted) return;
    setState(() => _selfies.add(file));
  }

  void _removeSelfie(int i) => setState(() => _selfies.removeAt(i));

  Future<void> _pickCode() async {
    final code = await UnlockPhotosSheet.show(context);
    if (code == null || !mounted) return;
    final trimmed = code.trim();
    if (trimmed.isEmpty) return;
    setState(() => _code = trimmed);
  }

  /// Reads the selfies and hands the search to the result screen.
  ///
  /// The bytes are read here rather than inside the search so a file that
  /// cannot be read is reported on this page, where the person can retake it —
  /// by the time the result screen is up there is nothing useful to say about
  /// a missing file.
  Future<void> _submit() async {
    if (!_ready || _starting) return;
    setState(() => _starting = true);

    final faces = await EasySearch.readFaces(_selfies);
    if (!mounted) return;

    if (faces.isEmpty) {
      setState(() => _starting = false);
      AppSnackBar.error(
        context,
        'We could not read those selfies. Try taking them again.',
      );
      return;
    }

    final code = _code!;
    // pushReplacement: this page has done its job, and backing out of the
    // result should return to where Easy search was opened from rather than to
    // a form holding selfies that have already been sent.
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => EventScanResultPage(
          code: code,
          createSearch: () => EasySearch(code: code, faces: faces),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final canAdd = _selfies.length < _maxSelfies && !_starting;

    return Scaffold(
      backgroundColor: ext.homeBackground,
      appBar: AppBar(
        backgroundColor: ext.homeBackground,
        elevation: 0,
        leading: const AppBackButton(),
        title: Text(
          'Easy search',
          style: TextStyle(
            color: ext.greetingColor,
            fontFamily: AppTypography.displayFontFamily,
            fontSize: 16.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 16.h),
              child: Text(
                'Take up to $_maxSelfies clear selfies and enter the event '
                'code. We compare them to that album and keep nothing — your '
                'face is never saved.',
                style: TextStyle(
                  color: ext.searchHintColor,
                  fontSize: 14.sp,
                  height: 1.5,
                ),
              ),
            ),

            // ── The album ────────────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl.w),
              child: _CodeRow(
                ext: ext,
                code: _code,
                onTap: _starting ? null : _pickCode,
              ),
            ),

            SizedBox(height: AppSpacing.lg.h),

            // ── The selfies ──────────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl.w),
                child: MediaGrid(
                  columns: 3,
                  gutter: 10,
                  itemCount: _selfies.length + (canAdd ? 1 : 0),
                  itemBuilder: (_, i) {
                    if (i == _selfies.length) {
                      return _AddSelfieTile(
                        ext: ext,
                        onTap: _starting ? null : _addSelfie,
                        count: _selfies.length,
                        max: _maxSelfies,
                      );
                    }
                    return _SelfieTile(
                      file: _selfies[i],
                      onRemove: _starting ? null : () => _removeSelfie(i),
                    );
                  },
                ),
              ),
            ),

            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 24.h),
              child: AppButton(
                fullWidth: true,
                isLoading: _starting,
                onPressed: _ready && !_starting ? _submit : null,
                // The label names whichever half is still missing, so a
                // disabled button says why rather than just refusing.
                label: _selfies.isEmpty
                    ? 'Take a selfie to continue'
                    : (_code?.isEmpty ?? true)
                        ? 'Add an event code to continue'
                        : 'Find my photos',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The event code, as a row that is either an invitation or an answer.
class _CodeRow extends StatelessWidget {
  const _CodeRow({required this.ext, required this.code, required this.onTap});

  final AppThemeExtension ext;
  final String? code;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final has = code != null && code!.isNotEmpty;

    return Semantics(
      button: true,
      label: has ? 'Event code $code, change it' : 'Enter or scan an event code',
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md.r),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.lg.w,
            vertical: AppSpacing.md.h,
          ),
          decoration: BoxDecoration(
            color: ext.cardSurface,
            borderRadius: BorderRadius.circular(AppRadius.md.r),
            border: Border.all(
              color: has
                  ? ext.accentGold.withValues(alpha: 0.45)
                  : Colors.transparent,
              width: 1.2,
            ),
          ),
          child: Row(
            children: [
              Icon(
                has ? Icons.confirmation_number_rounded : Icons.qr_code_rounded,
                color: has ? ext.accentGold : ext.searchHintColor,
                size: 20.sp,
              ),
              SizedBox(width: AppSpacing.md.w),
              Expanded(
                child: Text(
                  has ? code! : 'Enter or scan the event code',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: has ? ext.greetingColor : ext.searchHintColor,
                    fontSize: 14.sp,
                    // Medium, not semibold: the brand ships four weights and
                    // w600 is not one of them.
                    fontWeight: has ? FontWeight.w500 : FontWeight.w400,
                  ),
                ),
              ),
              Text(
                has ? 'Change' : '',
                style: AppTypography.captionBold.copyWith(
                  color: ext.accentGold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
    return Semantics(
      button: true,
      label: 'Add selfie',
      child: GestureDetector(
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
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
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
          child: Semantics(
            image: true,
            label: 'Your photo',
            child: XFileImage(file, fit: BoxFit.cover),
          ),
        ),
        if (onRemove != null)
          Positioned(
            top: 4.h,
            right: 4.w,
            child: Semantics(
              button: true,
              label: 'Remove photo',
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  padding: EdgeInsets.all(3.w),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                  child: AppSvgIcon(
                    AppIcons.closeMd,
                    color: Colors.white,
                    size: 13.sp,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
