import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:jperg_app/core/common/widgets/app_back_button.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/theme/app_typography.dart';
import 'package:jperg_app/core/utils/snackbar_utils.dart';
import 'package:jperg_app/core/widgets/jperg_image.dart';
import 'package:jperg_app/core/widgets/video_player/jperg_video_player.dart';
import 'package:jperg_app/core/widgets/zoomable_photo.dart';
import 'package:jperg_app/components/media/media_rail_action.dart';
import 'package:jperg_app/core/theme/app_icons.dart';
import 'package:jperg_app/features/user_profile/data/album_download.dart';
import 'package:jperg_app/features/user_profile/data/owned_events.dart';
import 'package:jperg_app/features/user_profile/presentation/widgets/album_download_bar.dart';

/// One album this person owns, and everything in it.
///
/// Reached from My Events on the profile. What separates it from every other
/// grid in the app is the right it exercises: these photos are *theirs*, not
/// bought, so they come down at full resolution with no watermark and nothing
/// to pay. See `/common/events/{id}/owned-photos`, which gates on ownership
/// and never consults PaidImage.
class OwnedAlbumPage extends StatefulWidget {
  const OwnedAlbumPage({super.key, required this.event});

  final OwnedEvent event;

  @override
  State<OwnedAlbumPage> createState() => _OwnedAlbumPageState();
}

class _OwnedAlbumPageState extends State<OwnedAlbumPage> {
  final _repo = OwnedEventsRepository();
  final _scroll = ScrollController();

  final List<OwnedPhoto> _photos = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  int _page = 1;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _loadingMore) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 400) {
      _loadMore();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final page = await _repo.getOwnedPhotos(widget.event.id, page: 1);
      if (!mounted) return;
      setState(() {
        _photos
          ..clear()
          ..addAll(page.items);
        _page = 1;
        _hasMore = page.hasMore;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      // Said out loud rather than drawn as an empty album: "no photos" and
      // "we could not fetch your photos" are different things, and showing
      // the first when the second happened tells somebody their wedding
      // album is empty.
      setState(() {
        _loading = false;
        _error = 'Could not load this album. Pull down to try again.';
      });
    }
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    try {
      final next = await _repo.getOwnedPhotos(widget.event.id, page: _page + 1);
      if (!mounted) return;
      final seen = {for (final p in _photos) p.id};
      setState(() {
        _photos.addAll(next.items.where((p) => seen.add(p.id)));
        _page += 1;
        _hasMore = next.hasMore;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  /// Save the whole album.
  ///
  /// Everything loaded *and* everything not yet paged in: somebody asking for
  /// "all" means all of it, and handing them only the hundred rows the grid
  /// happens to have scrolled through would be a quiet lie. So the rest is
  /// fetched first, then the run starts.
  Future<void> _downloadAll() async {
    if (AlbumDownloader.progress.value.running) return;

    final messenger = ScaffoldMessenger.of(context);
    var all = List<OwnedPhoto>.from(_photos);

    if (_hasMore) {
      AppSnackBar.info(context, 'Preparing the album…');
      var page = _page;
      var more = true;
      final seen = {for (final p in all) p.id};
      while (more) {
        try {
          final next =
              await _repo.getOwnedPhotos(widget.event.id, page: page + 1);
          all.addAll(next.items.where((p) => seen.add(p.id)));
          more = next.hasMore;
          page += 1;
        } catch (_) {
          // Save what we have rather than refusing the whole thing over one
          // failed page.
          more = false;
        }
      }
    }

    if (all.isEmpty) return;

    final result = await AlbumDownloader.instance.downloadAll(
      all,
      eventId: widget.event.id,
      eventName: widget.event.name,
    );

    if (!mounted) return;
    final message = switch (result) {
      _ when result.cancelled =>
        'Stopped. ${result.saved} of ${result.total} saved.',
      _ when result.failed > 0 =>
        '${result.saved} saved, ${result.failed} could not be saved.',
      _ => 'Saved ${result.saved} '
          '${result.saved == 1 ? 'photo' : 'photos'} to your gallery.',
    };
    if (result.failed > 0 && result.saved == 0) {
      AppSnackBar.errorOnMessenger(messenger, message);
    } else {
      AppSnackBar.successOnMessenger(messenger, message);
    }
  }

  Future<void> _downloadOne(OwnedPhoto photo) async {
    final messenger = ScaffoldMessenger.of(context);
    AppSnackBar.info(context, 'Saving…');
    final ok = await AlbumDownloader.instance.saveOne(photo);
    if (!mounted) return;
    if (ok) {
      AppSnackBar.successOnMessenger(messenger, 'Saved to your gallery.');
    } else {
      AppSnackBar.errorOnMessenger(messenger, 'Could not save that one.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: Text(
          widget.event.name.isEmpty ? 'Album' : widget.event.name,
          style: AppTypography.title,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          // Watches the downloader rather than this screen's state, so the
          // button reflects a run started here, left, and come back to.
          ValueListenableBuilder<AlbumDownloadProgress>(
            valueListenable: AlbumDownloader.progress,
            builder: (context, progress, _) {
              final busy = progress.running;
              return TextButton.icon(
                onPressed: busy || _photos.isEmpty ? null : _downloadAll,
                icon: Icon(
                  busy ? Icons.downloading_rounded : Icons.download_outlined,
                  size: 18.sp,
                ),
                label: Text(busy ? 'Saving' : 'Save all'),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          const AlbumDownloadBar(),
          Expanded(child: _body(ext)),
        ],
      ),
    );
  }

  Widget _body(AppThemeExtension ext) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error.isNotEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: 120.h),
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 32.w),
                child: Text(
                  _error,
                  textAlign: TextAlign.center,
                  style: AppTypography.body,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_photos.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: 120.h),
            Center(
              child: Text(
                'No photos in this album yet.',
                style: AppTypography.body,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: GridView.builder(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: EdgeInsets.all(2.w),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 2,
          mainAxisSpacing: 2,
        ),
        itemCount: _photos.length + (_loadingMore ? 3 : 0),
        itemBuilder: (_, i) {
          if (i >= _photos.length) {
            return Center(
              child: SizedBox(
                width: 18.w,
                height: 18.w,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: ext.accentGold),
              ),
            );
          }
          final photo = _photos[i];
          return _PhotoTile(
            photo: photo,
            onDownload: () => _downloadOne(photo),
          );
        },
      ),
    );
  }
}

/// One frame, with its own save control.
///
/// The control is always visible rather than hidden behind a long-press: the
/// single download is half of what this screen is for, and a gesture nobody
/// is told about is a feature nobody uses.
///
/// Tapping the frame itself opens it full-screen — the same two destinations
/// the chat's shared-media grid uses, so a photo zooms and a video plays in
/// the app's own player rather than in whatever this screen invented.
class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.photo, required this.onDownload});

  final OwnedPhoto photo;
  final VoidCallback onDownload;

  void _open(BuildContext context) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => photo.isVideo
            // The original, not the badged render: an owner's copy carries
            // no watermark on screen either, not just on the way to disk.
            ? _AlbumVideoView(url: photo.downloadUrl)
            : _AlbumPhotoView(url: photo.downloadUrl),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return Semantics(
      button: true,
      label: photo.isVideo ? 'Open video' : 'Open photo',
      child: GestureDetector(
        onTap: () => _open(context),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: ext.searchFieldFill),
            // JpergImage derives a still frame from a video URL, so a clip
            // gets a poster rather than a grey square — the same behaviour
            // the shared-media grid relies on.
            JpergImage(imageUrl: photo.url, fit: BoxFit.cover),
            if (photo.isVideo)
              Center(
                child: Icon(
                  Icons.play_circle_fill_rounded,
                  color: Colors.white.withValues(alpha: 0.9),
                  size: 28.sp,
                ),
              ),
            Positioned(
              right: 2,
              bottom: 2,
              // The rail's own control, so the glyph, the press-scale and the
              // busy state are the ones every other download in the app
              // uses. This was a hand-rolled InkWell with the *filled*
              // arrow — the one solid glyph in a product where every
              // reaction is hollow at rest, which read as a different kind
              // of button. See [MediaReaction.download].
              child: MediaRailAction(
                icon: Icons.download_outlined,
                semanticLabel: 'Download photo',
                iconSize: 16.sp,
                tapTargetSize: 32.r,
                onTap: onDownload,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A frame of the album, full-screen and zoomable.
class _AlbumPhotoView extends StatelessWidget {
  const _AlbumPhotoView({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: ZoomablePhoto(imageUrl: url, semanticLabel: 'Album photo'),
          ),
          const _CloseButton(),
        ],
      ),
    );
  }
}

/// A clip from the album, in the app's player.
class _AlbumVideoView extends StatelessWidget {
  const _AlbumVideoView({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: JpergVideoPlayer(
              url: url,
              fit: BoxFit.contain,
              autoPlay: true,
              // Not looped: this is somebody reviewing their own footage,
              // not a feed card holding attention.
              loop: false,
            ),
          ),
          const _CloseButton(),
        ],
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      right: 12,
      child: Semantics(
        button: true,
        label: 'Close',
        child: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.black54,
              shape: BoxShape.circle,
            ),
            child: const AppSvgIcon(AppIcons.closeMd, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
