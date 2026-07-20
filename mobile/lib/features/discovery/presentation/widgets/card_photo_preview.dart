import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:skidoo_app/core/common/widgets/app_loading_indicator.dart';
import 'package:skidoo_app/core/widgets/skidoo_image.dart';
import 'package:skidoo_app/models/event_discovery/event_discovery.dart';
import 'package:skidoo_app/core/widgets/video_player/skidoo_video_player.dart';

/// Full-width swipeable photo/video carousel — Instagram / TikTok style.
class PostPhotoCarousel extends StatefulWidget {
  const PostPhotoCarousel({
    super.key,
    required this.pics,
    required this.pageController,
    required this.showBlur,
    required this.onDoubleTap,
    required this.onTap,
    this.scrollable = true,
    this.cardIndex = 0,
    this.activeCardIndex,
    this.fullBleed = false,
  });

  final List<EventPicture> pics;
  final PageController pageController;
  final bool showBlur;
  final VoidCallback onDoubleTap;
  final bool scrollable;
  final VoidCallback onTap;
  /// Which position this card occupies in the feed.
  final int cardIndex;
  /// Feed-level notifier for which card should be playing. Null = always play.
  final ValueNotifier<int>? activeCardIndex;

  /// True for the TikTok-style full-screen feed ([FullBleedEventCard]),
  /// where media should crop-to-fill the entire screen (`BoxFit.cover`) —
  /// never leave empty bars. False (default) for the classic bounded card
  /// ([EventDiscoveryCard]), which has its own fixed-aspect-ratio frame and
  /// deliberately letterboxes (`BoxFit.contain`) with a blurred backdrop
  /// filling the gaps instead of cropping the photo.
  final bool fullBleed;

  @override
  State<PostPhotoCarousel> createState() => _PostPhotoCarouselState();
}

class _PostPhotoCarouselState extends State<PostPhotoCarousel> {
  /// Drives play/pause for all video slides in this carousel.
  final _activeIndex = ValueNotifier<int>(0);

  void _onPageChanged(int i) => _activeIndex.value = i;

  @override
  void dispose() {
    _activeIndex.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: widget.pageController,
      physics: widget.scrollable
          ? const BouncingScrollPhysics()
          : const NeverScrollableScrollPhysics(),
      itemCount: widget.pics.length,
      onPageChanged: _onPageChanged,
      itemBuilder: (context, index) {
        final pic = widget.pics[index];
        final isLastLocked =
            widget.showBlur && index == 2 && widget.pics.length > 3;

        if (pic.isVideo) {
          return Stack(
            fit: StackFit.expand,
            children: [
              _SliderVideoItem(
                url: pic.url,
                index: index,
                activeIndex: _activeIndex,
                onTap: widget.onTap,
                cardIndex: widget.cardIndex,
                activeCardIndex: widget.activeCardIndex,
                fit: widget.fullBleed ? BoxFit.cover : BoxFit.contain,
              ),
              if (isLastLocked) _LockedOverlay(remaining: widget.pics.length - 3),
              // if (pic.owner) const _OwnerCornerRibbon(),
            ],
          );
        }

        return Semantics(button: true, label: 'Photo', child: GestureDetector(
          onTap: widget.onTap,
          onDoubleTap: widget.onDoubleTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (widget.fullBleed)
                // ── Full-screen feed: crop-to-fill, no letterbox/blur needed ──
                SkidooImage(
                  imageUrl: pic.url,
                  fit: BoxFit.cover,
                  semanticLabel: 'Event photo',
                  placeholder: (_, __) => const ColoredBox(
                    color: Color(0xFF111111),
                    child: AppLoadingIndicator(),
                  ),
                  errorWidget: (_, __, ___) =>
                      const ColoredBox(color: Color(0xFF111111)),
                )
              else ...[
                // ── Blurred background — tiny decode, blur hides all detail ─
                ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                  child: SkidooImage(
                    imageUrl: pic.url,
                    fit: BoxFit.cover,
                    isBlurBackground: true,
                    placeholder: (_, __) => const ColoredBox(
                      color: Color(0xFF111111),
                      child: AppLoadingIndicator(),
                    ),
                    errorWidget: (_, __, ___) =>
                        const ColoredBox(color: Color(0xFF111111)),
                  ),
                ),
                // Dim the blur layer so it doesn't compete with the main image
                const ColoredBox(color: Color(0x55000000)),
                // ── Sharp full image — physical-pixel resolution via DPR ──────
                SkidooImage(
                  imageUrl: pic.url,
                  fit: BoxFit.contain,
                  semanticLabel: 'Event photo',
                  // Non-opaque — the blurred backdrop stays visible behind the
                  // spinner while the full-res image is still loading.
                  placeholder: (_, __) => const Center(
                    child: CircularProgressIndicator(
                        color: Colors.white70, strokeWidth: 2),
                  ),
                  errorWidget: (_, __, ___) =>
                      const ColoredBox(color: Color(0xFF111111)),
                ),
              ],
              if (isLastLocked) _LockedOverlay(remaining: widget.pics.length - 3),
              // if (pic.owner) const _OwnerCornerRibbon(),
            ],
          ),
        ));
      },
    );
  }
}

// ── Inline video player for the feed carousel ─────────────────────────────────
/// Thin stateful wrapper that listens to [activeIndex] and [activeCardIndex]
/// notifiers and forwards an [isActive] flag to [SkidooVideoPlayer].

class _SliderVideoItem extends StatefulWidget {
  const _SliderVideoItem({
    required this.url,
    required this.index,
    required this.activeIndex,
    required this.onTap,
    this.cardIndex = 0,
    this.activeCardIndex,
    this.fit = BoxFit.contain,
  });

  final String url;
  final int index;
  final ValueNotifier<int> activeIndex;
  final VoidCallback onTap;
  final int cardIndex;
  final ValueNotifier<int>? activeCardIndex;
  final BoxFit fit;

  @override
  State<_SliderVideoItem> createState() => _SliderVideoItemState();
}

class _SliderVideoItemState extends State<_SliderVideoItem> {
  bool get _isSlideActive => widget.activeIndex.value == widget.index;
  bool get _isCardActive =>
      widget.activeCardIndex == null ||
      widget.activeCardIndex!.value == widget.cardIndex;

  @override
  void initState() {
    super.initState();
    widget.activeIndex.addListener(_onNotifier);
    widget.activeCardIndex?.addListener(_onNotifier);
  }

  void _onNotifier() => setState(() {});

  @override
  void dispose() {
    widget.activeIndex.removeListener(_onNotifier);
    widget.activeCardIndex?.removeListener(_onNotifier);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Outer tap fires the card's own tap (e.g. open EventPicturesPage)
      // only when the video is not yet considered "tapped" by the player.
      onTap: widget.onTap,
      behavior: HitTestBehavior.translucent,
      child: SkidooVideoPlayer(
        url: widget.url,
        isActive: _isSlideActive && _isCardActive,
        autoPlay: true,
        loop: true,
        fit: widget.fit,
        showControls: true,
        backgroundColor: Colors.black,
        listenToPauseNotifier: true,
      ),
    );
  }
}

// ── Locked overlay ────────────────────────────────────────────────────────────
class _LockedOverlay extends StatelessWidget {
  const _LockedOverlay({required this.remaining});
  final int remaining;
  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          color: Colors.black.withValues(alpha: 0.55),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.12),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3), width: 1.5),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.lock_rounded,
                    color: Colors.white, size: 24),
              ),
              const SizedBox(height: 12),
              Text('+$remaining more photos',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3)),
              const SizedBox(height: 4),
              const Text('Sign in to unlock',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Gradient placeholder ──────────────────────────────────────────────────────
class CardGradientPlaceholder extends StatelessWidget {
  const CardGradientPlaceholder({super.key, required this.name});
  final String name;
  static const _palette = [
    [Color(0xFF1a1a2e), Color(0xFF16213e)],
    [Color(0xFF0f3460), Color(0xFF533483)],
    [Color(0xFF1a0533), Color(0xFF3d0066)],
    [Color(0xFF001a2c), Color(0xFF003366)],
    [Color(0xFF1a0000), Color(0xFF4d0000)],
    [Color(0xFF002200), Color(0xFF004d00)],
  ];
  @override
  Widget build(BuildContext context) {
    final idx = name.isEmpty ? 0 : name.codeUnitAt(0) % _palette.length;
    return Container(
      decoration: BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: _palette[idx])),
      alignment: Alignment.center,
      child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.08),
              fontSize: 120,
              fontWeight: FontWeight.w900)),
    );
  }
}

class CardEmptyTile extends StatelessWidget {
  const CardEmptyTile({super.key});
  @override
  Widget build(BuildContext context) =>
      Container(color: const Color(0xFF111111));
}
