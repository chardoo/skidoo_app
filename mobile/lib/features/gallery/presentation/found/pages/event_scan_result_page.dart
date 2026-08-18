import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/common/widgets/app_widgets.dart';
import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/theme/app_typography.dart';
import 'package:jperg_app/core/utils/web_wrap.dart';
import 'package:jperg_app/features/gallery/domain/usecases/get_found_photos_usecase.dart';
import 'package:jperg_app/features/gallery/presentation/found/models/found_album.dart';
import 'package:jperg_app/features/gallery/presentation/found/models/found_filters.dart';
import 'package:jperg_app/features/gallery/presentation/found/pages/found_album_page.dart';
import 'package:jperg_app/features/gallery/presentation/found/widgets/found_scanning_orb.dart';

/// What a scanned event code opens: the search, then what it turned up.
///
/// Three states, and they are the design's three frames —
/// `QRScan-Scanning-photos`, `PrivatePhotos-Unlocked-Success`, and the album
/// itself. Before this the scanner dropped straight into a search results
/// page, so the moment that makes the feature worth using — *we found 24
/// photos of you* — was never shown to anyone.
///
/// The album it opens is in review mode: everything preselected, with "Tap to
/// deselect photos that aren't you". That is the right default here and only
/// here — the person has just been told these are photos of them, and the
/// screen's job is to let them disagree. Browsing the same album later from
/// the Found tab starts empty instead. See [PhotoSelection].
class EventScanResultPage extends StatefulWidget {
  const EventScanResultPage({super.key, required this.code});

  /// The scanned or typed event code. Treated as an event id, which is what
  /// the existing scan path does with it too.
  final String code;

  @override
  State<EventScanResultPage> createState() => _EventScanResultPageState();
}

class _EventScanResultPageState extends State<EventScanResultPage> {
  /// Long enough that the orb reads as work happening rather than as a flash
  /// of something on the way past. A search that answers instantly still shows
  /// it; a slow one is not padded.
  static const _minimumScan = Duration(milliseconds: 1400);

  FoundAlbum? _album;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scan();
  }

  Future<void> _scan() async {
    final started = DateTime.now();
    try {
      final page = await sl<GetFoundPhotosUseCase>().albums(
        // `all`, not the default: the album this opens is a review — everything
        // preselected, "tap to deselect photos that aren't you" — and the
        // matches waiting to be answered are exactly the ones it exists to ask
        // about. Filtered to confirmed, a first scan answered "no photos" for
        // an event full of them.
        //
        // The code goes in as an event id and the server resolves either form.
        // A scanned QR carries the access code, not the id.
        filters: FoundFilters(
          eventIds: {widget.code},
          status: FoundMatchStatus.all,
        ),
        limit: 1,
      );
      final elapsed = DateTime.now().difference(started);
      if (elapsed < _minimumScan) {
        await Future<void>.delayed(_minimumScan - elapsed);
      }
      if (!mounted) return;
      setState(() {
        _album = page.albums.isEmpty ? null : page.albums.first;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'We could not open that event. Check the code and try again.';
      });
    }
  }

  void _openAlbum() {
    final album = _album;
    if (album == null) return;
    // pushReplacement: the result card has done its job once it is tapped, and
    // backing out of the album should return to wherever the scan started
    // rather than to a card announcing a number.
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => FoundAlbumPage(
          album: album,
          reviewMode: true,
          // The album fetches the full set itself, so the card's answer and the
          // page behind it have to be asking the same question — otherwise the
          // count says 24 and the grid that opens is empty.
          filters: const FoundFilters(status: FoundMatchStatus.all),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    final page = Scaffold(
      backgroundColor: ext.homeBackground,
      appBar: AppBar(
        backgroundColor: ext.homeBackground,
        elevation: 0,
        leading: const AppBackButton(),
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.xxl.w),
          child: _buildState(ext),
        ),
      ),
    );

    return webWrap(page, backgroundColor: ext.homeBackground);
  }

  Widget _buildState(AppThemeExtension ext) {
    if (_loading) return _Scanning(ext: ext);

    if (_error != null) {
      return AppErrorView(
        message: _error!,
        icon: Icons.qr_code_scanner_rounded,
        onRetry: () {
          setState(() {
            _loading = true;
            _error = null;
          });
          _scan();
        },
      );
    }

    final album = _album;
    // photoCount, not mineCount: an event whose public photos she can see is
    // worth opening even when recognition found none of her in it.
    if (album == null || album.photoCount == 0) {
      return const AppEmptyState(
        icon: Icons.person_search_rounded,
        message: "We didn't find any photos of you in this event yet.\n"
            "We'll let you know if that changes.",
      );
    }

    return _FoundCard(album: album, ext: ext, onView: _openAlbum);
  }
}

class _Scanning extends StatelessWidget {
  const _Scanning({required this.ext});

  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FoundScanningOrb(color: ext.accentGold, size: 260.w),
        SizedBox(height: AppSpacing.xxxl.h),
        Text(
          'Scanning for your photos...',
          textAlign: TextAlign.center,
          style: AppTypography.headline.copyWith(color: ext.greetingColor),
        ),
        SizedBox(height: AppSpacing.sm.h),
        Text(
          'Analyzing event photos',
          textAlign: TextAlign.center,
          style: AppTypography.caption.copyWith(color: ext.searchHintColor),
        ),
      ],
    );
  }
}

class _FoundCard extends StatelessWidget {
  const _FoundCard({
    required this.album,
    required this.ext,
    required this.onView,
  });

  final FoundAlbum album;
  final AppThemeExtension ext;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    // The viewer's own share, not the row count. The album behind this card
    // now also carries the event's public photos, and "24 photos of you
    // found!" must not be counting other people's.
    final count = album.mineCount;
    final photoWord = count == 1 ? 'photo' : 'photos';

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.xl.w,
        vertical: AppSpacing.xxxl.h,
      ),
      decoration: BoxDecoration(
        color: ext.cardSurface,
        borderRadius: BorderRadius.circular(AppRadius.lg.r),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56.w,
            height: 56.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ext.accentGold.withValues(alpha: 0.18),
            ),
            alignment: Alignment.center,
            child:
                Icon(Icons.check_rounded, size: 28.sp, color: ext.accentGold),
          ),
          SizedBox(height: AppSpacing.lg.h),
          Text(
            album.title,
            textAlign: TextAlign.center,
            style: AppTypography.headline.copyWith(color: ext.greetingColor),
          ),
          SizedBox(height: AppSpacing.lg.h),
          // Amber on amber-tinted, the same pairing the price badge uses — the
          // count is the good news on this screen and it should carry the
          // colour that means "worth money" everywhere else.
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.lg.w,
              vertical: AppSpacing.sm.h,
            ),
            decoration: BoxDecoration(
              color: ext.publicAmber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppRadius.pill.r),
            ),
            child: Text(
              '$count $photoWord of you found!',
              style: TextStyle(
                color: ext.publicAmber,
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(height: AppSpacing.xxl.h),
          Semantics(
            button: true,
            child: GestureDetector(
              onTap: onView,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.sm.h),
                child: Text(
                  'View photos',
                  style: TextStyle(
                    color: ext.accentGold,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
