import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/components/media/media_action_buttons.dart';
import 'package:skidoo_app/core/di/service_locator.dart';
import 'package:skidoo_app/features/discovery/domain/usecases/get_random_images_usecase.dart';
import 'package:skidoo_app/features/gallery/presentation/widgets/gallery_share_sheet.dart';
import 'package:skidoo_app/features/photo_comments/data/photo_comment_remote_data_source.dart';
import 'package:skidoo_app/models/event_discovery/event_discovery.dart';
import 'package:skidoo_app/models/photo_comment/photo_comment.dart';
import 'package:skidoo_app/services/auth_service.dart';
import 'package:video_player/video_player.dart';

// ── Flat entry: one picture + its parent event metadata ──────────────────────

class _PicEntry {
  const _PicEntry({
    required this.picture,
    required this.eventName,
    required this.photographerName,
  });

  final EventPicture picture;
  final String eventName;
  final String photographerName;
}

// ── Page ──────────────────────────────────────────────────────────────────────

class EventPicturesPage extends StatefulWidget {
  const EventPicturesPage({super.key, required this.event});

  final EventDiscovery event;

  @override
  State<EventPicturesPage> createState() => _EventPicturesPageState();
}

class _EventPicturesPageState extends State<EventPicturesPage> {
  late final PageController _pageCtrl;
  final _activeIndex = ValueNotifier<int>(0);
  late final List<_PicEntry> _entries;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _entries = widget.event.pictures
        .map((p) => _PicEntry(
              picture: p,
              eventName: widget.event.eventName,
              photographerName: widget.event.photographerName,
            ))
        .toList();
    _pageCtrl = PageController();
    _pageCtrl.addListener(_onPageChanged);
  }

  @override
  void dispose() {
    _pageCtrl.removeListener(_onPageChanged);
    _pageCtrl.dispose();
    _activeIndex.dispose();
    super.dispose();
  }

  void _onPageChanged() {
    final page = _pageCtrl.page?.round() ?? 0;
    if (page != _activeIndex.value) _activeIndex.value = page;
    // Preload more content when within 3 items of the end.
    if (!_isLoadingMore && _entries.isNotEmpty && page >= _entries.length - 3) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore) return;
    setState(() => _isLoadingMore = true);
    try {
      String? userId;
      try {
        userId = await sl<AuthService>().getUserId();
      } catch (_) {}

      final events = await sl<GetRandomImagesUseCase>().call(
        take: 5,
        userId: userId,
      );
      if (!mounted) return;

      final newEntries = <_PicEntry>[];
      for (final event in events) {
        for (final pic in event.pictures) {
          newEntries.add(_PicEntry(
            picture: pic,
            eventName: event.eventName,
            photographerName: event.photographerName,
          ));
        }
      }
      setState(() {
        if (newEntries.isNotEmpty) _entries.addAll(newEntries);
        _isLoadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_entries.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text('No media available',
              style: TextStyle(color: Colors.white54, fontSize: 15)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Full-screen vertical feed ─────────────────────────────────────
          PageView.builder(
            controller: _pageCtrl,
            scrollDirection: Axis.vertical,
            physics: const PageScrollPhysics(),
            itemCount: _entries.length,
            itemBuilder: (_, i) => _FeedCard(
              key: ValueKey(_entries[i].picture.id),
              entry: _entries[i],
              index: i,
              activeIndex: _activeIndex,
            ),
          ),

          // ── Floating back button ──────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: EdgeInsets.only(left: 14.w, top: 10.h),
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 36.w,
                  height: 36.w,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15), width: 1),
                  ),
                  child: Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 16.sp),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Full-screen feed card ─────────────────────────────────────────────────────

class _FeedCard extends StatefulWidget {
  const _FeedCard({
    super.key,
    required this.entry,
    required this.index,
    required this.activeIndex,
  });

  final _PicEntry entry;
  final int index;
  final ValueNotifier<int> activeIndex;

  @override
  State<_FeedCard> createState() => _FeedCardState();
}

class _FeedCardState extends State<_FeedCard> {
  PhotoComment? _topComment;
  bool _commentFetched = false;

  @override
  void initState() {
    super.initState();
    widget.activeIndex.addListener(_onActiveChanged);
    // Fetch comment immediately for the first visible card.
    if (widget.activeIndex.value == widget.index) _fetchComment();
  }

  @override
  void dispose() {
    widget.activeIndex.removeListener(_onActiveChanged);
    super.dispose();
  }

  void _onActiveChanged() {
    if (widget.activeIndex.value == widget.index && !_commentFetched) {
      _fetchComment();
    }
  }

  void _fetchComment() {
    if (_commentFetched) return;
    _commentFetched = true;
    sl<PhotoCommentRemoteDataSource>()
        .getComments(widget.entry.picture.id, page: 1, limit: 1)
        .then((list) {
      if (mounted && list.isNotEmpty) {
        setState(() => _topComment = list.first);
      }
    }).catchError((_) {});
  }

  static List<String> _hashtags(String eventName, String photographerName) {
    final words = eventName
        .split(RegExp(r'[\s\-_&]+'))
        .where((w) => w.length > 2)
        .map((w) => '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
        .toList();

    final tags = <String>[];
    if (words.isNotEmpty) tags.add('#${words.join('')}');
    if (photographerName.isNotEmpty) {
      final clean = photographerName.replaceAll(RegExp(r'\s+'), '');
      tags.add('#${clean}Photography');
    }
    tags.add('#skidoo');
    return tags.take(3).toList();
  }

  @override
  Widget build(BuildContext context) {
    final pic = widget.entry.picture;
    final eventName = widget.entry.eventName;
    final photographerName = widget.entry.photographerName;
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final sidebarBottom = (pic.isVideo ? 110.h : 64.h) + bottomPad;
    final infoBottom = (pic.isVideo ? 100.h : 54.h) + bottomPad;

    return Stack(
      fit: StackFit.expand,
      children: [
        // ── Media background ────────────────────────────────────────────────
        pic.isVideo
            ? _VideoBackground(
                url: pic.url,
                index: widget.index,
                activeIndex: widget.activeIndex,
              )
            : _PhotoBackground(url: pic.url),

        // ── Bottom gradient ─────────────────────────────────────────────────
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.62,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.9),
                    Colors.black.withValues(alpha: 0.0),
                  ],
                  stops: const [0.0, 1.0],
                ),
              ),
            ),
          ),
        ),

        // ── Top gradient ────────────────────────────────────────────────────
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: SizedBox(
            height: 120.h,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.55),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),

        // ── Action sidebar ──────────────────────────────────────────────────
        Positioned(
          right: 10.w,
          bottom: sidebarBottom,
          child: MediaActionButtons(
            imageId: pic.imageId,
            pictureId: pic.id,
            imageUrl: pic.url,
            eventName: eventName,
            photographerName: photographerName,
            initialLikeCount: pic.likeCount,
            initialCommentCount: pic.commentCount,
            initiallyLiked: pic.isLikedByUser,
            axis: Axis.vertical,
            showDownload: false,
            onSend: () => GalleryShareSheet.show(
              context,
              imageUrl: pic.url,
              photoLabel: eventName,
            ),
          ),
        ),

        // ── Info overlay ────────────────────────────────────────────────────
        Positioned(
          left: 16.w,
          right: 76.w, // leave room for the sidebar
          bottom: infoBottom,
          child: _InfoOverlay(
            eventName: eventName,
            photographerName: photographerName,
            hashtags: _hashtags(eventName, photographerName),
            topComment: _topComment,
          ),
        ),
      ],
    );
  }
}

// ── Info overlay ──────────────────────────────────────────────────────────────

class _InfoOverlay extends StatelessWidget {
  const _InfoOverlay({
    required this.eventName,
    required this.photographerName,
    required this.hashtags,
    required this.topComment,
  });

  final String eventName;
  final String photographerName;
  final List<String> hashtags;
  final PhotoComment? topComment;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Photographer row ──────────────────────────────────────────────
        Row(
          children: [
            _InitialsAvatar(name: photographerName, size: 30.w),
            SizedBox(width: 8.w),
            Flexible(
              child: Text(
                photographerName.isNotEmpty ? photographerName : 'Creator',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13.sp,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: 6.w),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
              decoration: BoxDecoration(
                color: const Color(0xFFF5A623).withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(4.r),
                border: Border.all(
                    color: const Color(0xFFF5A623).withValues(alpha: 0.4),
                    width: 0.5),
              ),
              child: Text(
                'creator',
                style: TextStyle(
                  color: const Color(0xFFF5A623),
                  fontSize: 9.sp,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ),

        SizedBox(height: 9.h),

        // ── Event name ────────────────────────────────────────────────────
        Text(
          eventName,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18.sp,
            height: 1.2,
            shadows: const [
              Shadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 1)),
            ],
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),

        SizedBox(height: 7.h),

        // ── Hashtags ──────────────────────────────────────────────────────
        Wrap(
          spacing: 8.w,
          runSpacing: 2.h,
          children: hashtags
              .map(
                (tag) => Text(
                  tag,
                  style: TextStyle(
                    color: const Color(0xFFF5A623).withValues(alpha: 0.9),
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.1,
                  ),
                ),
              )
              .toList(),
        ),

        // ── Top comment ───────────────────────────────────────────────────
        if (topComment != null) ...[
          SizedBox(height: 10.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 7.h),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.14), width: 0.5),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(top: 1.h),
                  child: Icon(Icons.chat_bubble_rounded,
                      color: Colors.white54, size: 11.sp),
                ),
                SizedBox(width: 6.w),
                Expanded(
                  child: RichText(
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '${topComment!.userName}  ',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 11.sp,
                          ),
                        ),
                        TextSpan(
                          text: topComment!.content,
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11.sp,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ── Initials avatar ───────────────────────────────────────────────────────────

class _InitialsAvatar extends StatelessWidget {
  const _InitialsAvatar({required this.name, required this.size});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final parts = name.trim().split(RegExp(r'\s+'));
    final initials = parts
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();

    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF5A623), Color(0xFFD4840F)],
        ),
      ),
      child: Center(
        child: Text(
          initials.isEmpty ? '?' : initials,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: size * 0.38,
            height: 1,
          ),
        ),
      ),
    );
  }
}

// ── Photo background ──────────────────────────────────────────────────────────

class _PhotoBackground extends StatelessWidget {
  const _PhotoBackground({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: url,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
      memCacheWidth: 800,
      filterQuality: FilterQuality.medium,
      placeholder: (_, __) => const ColoredBox(
        color: Color(0xFF0D0D0D),
        child: Center(
          child: CircularProgressIndicator(
              color: Colors.white24, strokeWidth: 2),
        ),
      ),
      errorWidget: (_, __, ___) => const ColoredBox(
        color: Color(0xFF0D0D0D),
        child: Center(
          child:
              Icon(Icons.broken_image_outlined, color: Colors.white24, size: 48),
        ),
      ),
    );
  }
}

// ── Video background ──────────────────────────────────────────────────────────

class _VideoBackground extends StatefulWidget {
  const _VideoBackground({
    required this.url,
    required this.index,
    required this.activeIndex,
  });

  final String url;
  final int index;
  final ValueNotifier<int> activeIndex;

  @override
  State<_VideoBackground> createState() => _VideoBackgroundState();
}

class _VideoBackgroundState extends State<_VideoBackground> {
  late final VideoPlayerController _ctrl;
  bool _initialized = false;
  bool _manualPause = false;
  bool _muted = false;

  bool get _isActive => widget.activeIndex.value == widget.index;

  @override
  void initState() {
    super.initState();
    _ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..setLooping(true)
      ..initialize().then((_) {
        if (!mounted) return;
        _ctrl.setVolume(1.0);
        setState(() => _initialized = true);
        _syncPlayback();
      });
    widget.activeIndex.addListener(_syncPlayback);
  }

  @override
  void dispose() {
    widget.activeIndex.removeListener(_syncPlayback);
    _ctrl
      ..pause()
      ..dispose();
    super.dispose();
  }

  void _syncPlayback() {
    if (!_initialized) return;
    if (_isActive && !_manualPause) {
      if (!_ctrl.value.isPlaying) _ctrl.play();
    } else {
      if (_ctrl.value.isPlaying) _ctrl.pause();
      if (!_isActive) _manualPause = false; // reset on leave
    }
  }

  void _togglePlayback() {
    if (!_initialized) return;
    setState(() {
      if (_ctrl.value.isPlaying) {
        _ctrl.pause();
        _manualPause = true;
      } else {
        _ctrl.play();
        _manualPause = false;
      }
    });
  }

  void _toggleMute() {
    setState(() {
      _muted = !_muted;
      _ctrl.setVolume(_muted ? 0.0 : 1.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const ColoredBox(
        color: Color(0xFF0D0D0D),
        child: Center(
          child: CircularProgressIndicator(
              color: Colors.white24, strokeWidth: 2),
        ),
      );
    }

    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: _ctrl,
      builder: (_, value, __) {
        final isPlaying = value.isPlaying;
        final w = value.size.width > 0 ? value.size.width : 9.0;
        final h = value.size.height > 0 ? value.size.height : 16.0;
        final duration = value.duration.inMilliseconds;
        final position = value.position.inMilliseconds;
        final progress =
            duration > 0 ? (position / duration).clamp(0.0, 1.0) : 0.0;

        return GestureDetector(
          onTap: _togglePlayback,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Video — cover-fills the screen.
              SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: w,
                    height: h,
                    child: VideoPlayer(_ctrl),
                  ),
                ),
              ),

              // Play/pause indicator.
              if (!isPlaying)
                Center(
                  child: Container(
                    width: 64.w,
                    height: 64.w,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: Colors.white38, width: 1.5),
                    ),
                    child: Icon(Icons.play_arrow_rounded,
                        color: Colors.white, size: 34.sp),
                  ),
                ),

              // Mute / unmute button — top right, below the status bar.
              Positioned(
                top: MediaQuery.paddingOf(context).top + 10.h,
                right: 14.w,
                child: GestureDetector(
                  onTap: _toggleMute,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 36.w,
                    height: 36.w,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.15),
                          width: 1),
                    ),
                    child: Icon(
                      _muted
                          ? Icons.volume_off_rounded
                          : Icons.volume_up_rounded,
                      color: Colors.white,
                      size: 16.sp,
                    ),
                  ),
                ),
              ),

              // Thin progress bar pinned to bottom of video.
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.white12,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFFF5A623)),
                  minHeight: 2,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
