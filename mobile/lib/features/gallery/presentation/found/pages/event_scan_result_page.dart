import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/common/widgets/app_widgets.dart';
import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/theme/app_typography.dart';
import 'package:jperg_app/core/utils/web_wrap.dart';
import 'package:jperg_app/features/gallery/data/event_scan.dart';
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

  /// The live scan, which outlives this page — see [EventScan] and
  /// [_openAlbumWhileScanning]. Not final: Retry starts a fresh one.
  late EventScan _scan = EventScan(code: widget.code);

  /// True once the orb has been up for [_minimumScan], so a fast scan does not
  /// flash its result.
  bool _minimumElapsed = false;

  /// Whether the person walked into the album rather than waiting. The scan
  /// keeps running when they do, so this page must not cancel it on the way
  /// out — see [dispose].
  bool _handedOver = false;

  FoundAlbum? _album;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scan.isRunning.addListener(_onScanState);
    _scan.start();
    Future<void>.delayed(_minimumScan, () {
      if (!mounted) return;
      setState(() => _minimumElapsed = true);
      _onScanState();
    });
  }

  @override
  void dispose() {
    _scan.isRunning.removeListener(_onScanState);
    // Only when they left without opening the album. A scan nobody is waiting
    // for should not keep spending recognition calls; one they walked into
    // must keep filling the grid they are looking at.
    if (_handedOver) {
      _scan.cancel();
    } else {
      _scan.dispose();
    }
    super.dispose();
  }

  /// Throws the failed scan away and runs another.
  void _restart() {
    _scan.isRunning.removeListener(_onScanState);
    _scan.dispose();
    setState(() {
      _scan = EventScan(code: widget.code);
      _loading = true;
      _error = null;
      _album = null;
    });
    _scan.isRunning.addListener(_onScanState);
    _scan.start();
  }

  /// Opens the album without waiting for the scan to finish.
  ///
  /// The scan is handed over rather than stopped: it keeps writing matches,
  /// and the album refetches on each batch (see AppCacheSignals.foundPhotos),
  /// so the grid fills while it is being read.
  Future<void> _openAlbumWhileScanning() async {
    final page = await sl<GetFoundPhotosUseCase>().albums(
      filters: FoundFilters(
        eventIds: {widget.code},
        status: FoundMatchStatus.all,
      ),
      limit: 1,
    );
    if (!mounted) return;
    if (page.albums.isEmpty) return;
    _album = page.albums.first;
    _openAlbum();
  }

  /// The stream ended, or the orb has been up long enough — either way, decide
  /// whether the result card can be shown yet.
  void _onScanState() {
    if (!mounted) return;
    if (_scan.isRunning.value || !_minimumElapsed) return;
    _showResult();
  }

  /// Turns the finished scan into the card.
  ///
  /// The album comes from `/client/my-photos`, not from the stream: the scan
  /// wrote an identification row per match as it went, so the rows are there
  /// by now, and the album page reads the same source — one answer, not two
  /// that can disagree.
  Future<void> _showResult() async {
    if (!_loading) return;
    try {
      final page = await sl<GetFoundPhotosUseCase>().albums(
        // `all`, not the default: the rows the scan just wrote are pending
        // until the person answers for them, and this screen is what asks.
        // Filtered to confirmed, a first scan answered "no photos" for an
        // event full of them.
        //
        // The code goes in as an event id and the server resolves either form.
        // A scanned QR carries the access code, not the id.
        filters: FoundFilters(
          eventIds: {widget.code},
          status: FoundMatchStatus.all,
        ),
        limit: 1,
      );
      if (!mounted) return;
      setState(() {
        _album = page.albums.isEmpty ? null : page.albums.first;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _scan.error.value != null || _scan.mineCount.value == 0
            ? 'We could not open that event. Check the code and try again.'
            : null;
      });
    }
  }

  void _openAlbum() {
    final album = _album;
    if (album == null) return;
    // Tells dispose to leave the scan running — the album is about to start
    // listening for what it finds next.
    _handedOver = _scan.isRunning.value;
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
    if (_loading) {
      return _Scanning(
        ext: ext,
        // Live, so a long scan shows progress rather than a spinner that could
        // be stuck. Counts photos of *this person* — an owner scanning their
        // own event receives the whole album, and "247 photos of you" would be
        // a lie about someone else's wedding.
        found: _scan.mineCount,
        // Offered the moment there is something to look at: waiting out a
        // large event to see photos already found is a wait for nothing. The
        // scan keeps running behind the album.
        onViewNow: _openAlbumWhileScanning,
      );
    }

    if (_error != null) {
      return AppErrorView(
        message: _error!,
        icon: Icons.qr_code_scanner_rounded,
        onRetry: _restart,
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
  const _Scanning({
    required this.ext,
    required this.found,
    required this.onViewNow,
  });

  final AppThemeExtension ext;

  /// Photos of this person found so far.
  final ValueListenable<int> found;

  final VoidCallback onViewNow;

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
        ValueListenableBuilder<int>(
          valueListenable: found,
          builder: (context, count, __) {
            // Nothing at all until the first match. "0 photos of you so far"
            // is a worse thing to read than the line above it, and it is what
            // the screen would say for the whole of an event they are not in.
            if (count == 0) return const SizedBox.shrink();
            final photoWord = count == 1 ? 'photo' : 'photos';
            return Column(
              children: [
                SizedBox(height: AppSpacing.xxl.h),
                Text(
                  '$count $photoWord of you so far',
                  textAlign: TextAlign.center,
                  style: AppTypography.body.copyWith(color: ext.accentGold),
                ),
                SizedBox(height: AppSpacing.sm.h),
                AppButton(
                  label: 'View photos',
                  variant: AppButtonVariant.text,
                  onPressed: onViewNow,
                ),
              ],
            );
          },
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
