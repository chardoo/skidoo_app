import 'package:skidoo_app/core/widgets/media_grid.dart';
import 'package:skidoo_app/core/widgets/skidoo_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/api/dio_client_service.dart';
import 'package:skidoo_app/core/di/service_locator.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/features/gallery/presentation/found/pages/found_photo_viewer_page.dart';
import 'package:skidoo_app/models/event_discovery/event_discovery.dart';
import 'package:skidoo_app/models/photos/Photo.dart';
import 'package:skidoo_app/core/utils/web_wrap.dart';
import 'package:skidoo_app/core/widgets/video_player/skidoo_video_player.dart';
import 'package:skidoo_app/core/theme/app_spacing.dart';
import 'package:skidoo_app/core/common/widgets/app_back_button.dart';

// ── Page ──────────────────────────────────────────────────────────────────────

class EventPicturesPage extends StatefulWidget {
  const EventPicturesPage({super.key, required this.event});
  final EventDiscovery event;

  @override
  State<EventPicturesPage> createState() => _EventPicturesPageState();
}

/// An event's pictures as [Photo]s, which is what the shared viewer speaks.
///
/// An [EventPicture] is only the media — the name, the photographer and the
/// avatar the viewer credits it to live on the parent event, so they are folded
/// in here rather than looked up again downstream.
///
/// Shared: the profile's liked and bookmarked grids open a photo inside its own
/// event's album, and they need the same mapping to do it.
List<Photo> photosOfEvent(EventDiscovery event) => [
      for (final p in event.pictures)
        Photo(
          p.id,
          event.eventName,
          p.imageId,
          p.url,
          event.photographerId,
          p.price.toDouble(),
          '',
          null,
          // Everything reachable from the public feed is public; the badge over
          // the photo reads "Public" accordingly.
          true,
          eventId: event.id,
          likeCount: p.likeCount,
          commentCount: p.commentCount,
          isLikedByUser: p.isLikedByUser,
          // Both switches have to be on: the owner can silence a whole event
          // or a single picture.
          commentsEnabled: event.commentsEnabled && p.commentsEnabled,
          mediaType: p.isVideo ? 'video' : 'image',
          width: p.width,
          height: p.height,
          durationSeconds: p.durationSeconds,
          photographerName: event.photographerName,
          photographerAvatarUrl: event.photographerProfileUrl ?? '',
        ),
    ];

class _EventPicturesPageState extends State<EventPicturesPage> {
  @override
  void initState() {
    super.initState();
    // Fire-and-forget view signal — non-fatal if it fails.
    sl<Api>()
        .dio
        .post('/recommend/${widget.event.id}/view')
        .then((_) =>
            debugPrint('[EventView] tracked view for event ${widget.event.id}'))
        .catchError((e) => debugPrint('[EventView] view tracking failed: $e'));
  }

  /// Opens the shared photo viewer — the same screen the Found tab, the album
  /// page and search all open, rather than a viewer only this page had.
  ///
  /// No "View album" button: the album is the page underneath, so it would go
  /// nowhere the back arrow doesn't already.
  void _openFullscreen(BuildContext context, int idx) {
    final photos = photosOfEvent(widget.event);
    if (photos.isEmpty) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => FoundPhotoViewerPage(
        photos: photos,
        initialIndex: idx.clamp(0, photos.length - 1),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final pics = event.pictures;

    final page = Scaffold(
      // The page paints its own background rather than leaving the Scaffold
      // transparent. `webWrap` below only fills the gutters, and only on web —
      // on a phone it returns the child untouched, so a transparent Scaffold
      // had nothing behind it and the screen came out black in both themes.
      backgroundColor: ext.homeBackground,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        cacheExtent: 600,
        slivers: [
          // ── App bar ───────────────────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            // Opaque because it is pinned: the grid scrolls underneath it, and
            // over a transparent bar the photos slide behind the event's name.
            backgroundColor: ext.homeBackground,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            leading: kIsWeb
                ? null
                : AppBackButton(onPressed: () => Navigator.of(context).pop()),
            // Just the event's name. The photographer is credited on each
            // photo in the viewer, and a count pill only restates what the
            // grid underneath already shows.
            title: Text(
              event.eventName,
              style: TextStyle(
                color: ext.greetingColor,
                fontWeight: FontWeight.w700,
                fontSize: 16.sp,
                letterSpacing: -0.3,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Divider(
                height: 1,
                thickness: 0.5,
                color: ext.searchHintColor.withValues(alpha: 0.12),
              ),
            ),
          ),

          // ── Media grid ────────────────────────────────────────────────────
          if (pics.isNotEmpty)
            SliverPadding(
              padding: EdgeInsets.fromLTRB(12.w, 14.h, 12.w, 24.h),
              sliver: SliverToBoxAdapter(
                child: MediaGrid(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: pics.length,
                  itemBuilder: (context, index) => _MediaTile(
                    picture: pics[index],
                    onTap: () => _openFullscreen(context, index),
                  ),
                ),
              ),
            ),

          // ── Empty state ───────────────────────────────────────────────────
          if (pics.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.photo_library_outlined,
                        size: 48.sp, color: ext.searchHintColor),
                    SizedBox(height: AppSpacing.md.h),
                    Text('No media available',
                        style: TextStyle(
                            color: ext.searchHintColor, fontSize: 14.sp)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
    return webWrap(page, backgroundColor: ext.homeBackground);
  }
}

// ── Media tile (image or video) ───────────────────────────────────────────────

class _MediaTile extends StatelessWidget {
  const _MediaTile({
    required this.picture,
    required this.onTap,
  });

  final EventPicture picture;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // A 28 % black drop shadow reads as depth against a near-black page and as
    // grime against a light one, where the tile only needs enough of a lift to
    // separate a pale photo from the background.
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Semantics(
        button: true,
        label: 'Photo',
        child: GestureDetector(
          onTap: onTap,
          // No height of its own: the grid cell is a square and the tile fills
          // it, which is what keeps every tile on screen identical.
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isLight ? 0.10 : 0.28),
                  blurRadius: isLight ? 8 : 12,
                  offset: Offset(0, isLight ? 2 : 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14.r),
              child: picture.isVideo
                  ? _VideoThumbTile(url: picture.url)
                  : _PhotoTile(url: picture.url),
            ),
          ),
        ));
  }
}

// ── Photo tile ────────────────────────────────────────────────────────────────

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    return SkidooImage(
      imageUrl: url,
      fit: BoxFit.cover,
      semanticLabel: 'Event photo',
      fadeInDuration: const Duration(milliseconds: 280),
      placeholder: (_, __) => const SkidooImagePlaceholder(),
      errorWidget: (context, __, ___) {
        final ext = Theme.of(context).extension<AppThemeExtension>()!;
        return ColoredBox(
          color: SkidooImagePlaceholder.colorOf(context),
          child: Center(
            // Was a hardcoded white12 — invisible on the light theme's pale
            // placeholder, so a broken photo showed as an empty tile.
            child: Icon(Icons.broken_image_outlined,
                color: ext.searchHintColor, size: 22.sp),
          ),
        );
      },
    );
  }
}

// ── Video thumbnail tile ──────────────────────────────────────────────────────
/// Shows the first video frame (paused, no controls) as a grid thumbnail
/// with a play badge overlay.

class _VideoThumbTile extends StatelessWidget {
  const _VideoThumbTile({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        SkidooVideoPlayer(
          url: url,
          autoPlay: false,
          showControls: false,
          fit: BoxFit.cover,
          backgroundColor: SkidooImagePlaceholder.colorOf(context),
        ),
        // Play badge
        Center(
          child: Container(
            width: 36.w,
            height: 36.w,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              shape: BoxShape.circle,
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.35), width: 1.2),
            ),
            child: Icon(Icons.play_arrow_rounded,
                color: Colors.white, size: 20.sp),
          ),
        ),
      ],
    );
  }
}
