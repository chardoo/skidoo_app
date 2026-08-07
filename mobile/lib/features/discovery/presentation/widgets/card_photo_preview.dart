import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/widgets/jperg_image.dart';
import 'package:jperg_app/models/event_discovery/event_discovery.dart';
import 'package:jperg_app/core/widgets/video_player/jperg_video_player.dart';

/// Full-width swipeable photo/video carousel — Instagram / TikTok style.
/// Media is always shown uncropped at its native aspect ratio (`BoxFit
/// .contain`), backed by a blurred, dimmed cover-fit copy of the same
/// media so letterbox/pillarbox gaps never show bare edges.
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
    this.onMediaChanged,
  });

  final List<EventPicture> pics;
  final PageController pageController;
  final bool showBlur;
  final VoidCallback onDoubleTap;
  final bool scrollable;
  final VoidCallback onTap;

  /// Fires with the newly-visible slide index. Lets the parent react to *what*
  /// is on screen — the full-bleed card uses it to lift its caption clear of
  /// the video's progress bar, which only exists on video slides.
  final ValueChanged<int>? onMediaChanged;

  /// Which position this card occupies in the feed.
  final int cardIndex;

  /// Feed-level notifier for which card should be playing. Null = always play.
  final ValueNotifier<int>? activeCardIndex;

  @override
  State<PostPhotoCarousel> createState() => _PostPhotoCarouselState();
}

class _PostPhotoCarouselState extends State<PostPhotoCarousel> {
  /// Drives play/pause for all video slides in this carousel.
  final _activeIndex = ValueNotifier<int>(0);

  void _onPageChanged(int i) {
    _activeIndex.value = i;
    widget.onMediaChanged?.call(i);
  }

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
        final ext = Theme.of(context).extension<AppThemeExtension>() ??
            AppThemeExtension.dark;
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
                fit: BoxFit.contain,
              ),
              if (isLastLocked)
                _LockedOverlay(remaining: widget.pics.length - 3),
              // if (pic.owner) const _OwnerCornerRibbon(),
            ],
          );
        }

        return Semantics(
            button: true,
            label: 'Photo',
            child: GestureDetector(
              onTap: widget.onTap,
              onDoubleTap: widget.onDoubleTap,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // ── Blurred background — tiny decode, blur hides all detail ─
                  ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                    child: JpergImage(
                      imageUrl: pic.url,
                      fit: BoxFit.cover,
                      isBlurBackground: true,
                      placeholder: (_, __) =>
                          const JpergImagePlaceholder(spinner: true),
                      errorWidget: (_, __, ___) =>
                          const JpergImagePlaceholder(),
                    ),
                  ),
                  // Veil the blur layer so it doesn't compete with the main
                  // image. Follows the theme: a dark scrim in dark mode, a
                  // light wash in light mode — this fills the letterbox bands,
                  // so a fixed black one made the whole feed read as dark.
                  ColoredBox(color: ext.mediaBackdropVeil),
                  // ── Sharp full image, uncropped — actual size, no forced fill ──
                  JpergImage(
                    imageUrl: pic.url,
                    fit: BoxFit.contain,
                    semanticLabel: 'Event photo',
                    // Non-opaque — the blurred backdrop stays visible behind the
                    // spinner while the full-res image is still loading. The
                    // accent reads on that backdrop in either theme; white70
                    // disappeared into the light-mode wash.
                    placeholder: (_, __) => Center(
                      child: CircularProgressIndicator(
                          color: ext.accentGold, strokeWidth: 2),
                    ),
                    errorWidget: (_, __, ___) => const JpergImagePlaceholder(),
                  ),
                  if (isLastLocked)
                    _LockedOverlay(remaining: widget.pics.length - 3),
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
/// notifiers and forwards an [isActive] flag to [JpergVideoPlayer].

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
    final ext = Theme.of(context).extension<AppThemeExtension>() ??
        AppThemeExtension.dark;
    return GestureDetector(
      // Outer tap fires the card's own tap (e.g. open EventPicturesPage)
      // only when the video is not yet considered "tapped" by the player.
      onTap: widget.onTap,
      behavior: HitTestBehavior.translucent,
      child: JpergVideoPlayer(
        url: widget.url,
        isActive: _isSlideActive && _isCardActive,
        autoPlay: true,
        loop: true,
        fit: widget.fit,
        showControls: true,
        // A contained video letterboxes on nearly every card, so this fill is
        // most of the screen — it has to follow the theme. (The player's own
        // controls stay light either way: they sit over the video.)
        backgroundColor: ext.mediaLetterbox,
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

  /// Stands in for the media on a card that has none, so it fills the whole
  /// card — a background, not an overlay, which is why it has a light set at
  /// all. Same six hue families in both, just inverted in lightness so the
  /// tile belongs to the page it sits on.
  static const _darkPalette = [
    [Color(0xFF1a1a2e), Color(0xFF16213e)],
    [Color(0xFF0f3460), Color(0xFF533483)],
    [Color(0xFF1a0533), Color(0xFF3d0066)],
    [Color(0xFF001a2c), Color(0xFF003366)],
    [Color(0xFF1a0000), Color(0xFF4d0000)],
    [Color(0xFF002200), Color(0xFF004d00)],
  ];
  static const _lightPalette = [
    [Color(0xFFE6E7F2), Color(0xFFDCE0F0)],
    [Color(0xFFDDE6F5), Color(0xFFE7DDF3)],
    [Color(0xFFE8E0F2), Color(0xFFE4D9F5)],
    [Color(0xFFDCE8F2), Color(0xFFDBE6F7)],
    [Color(0xFFF5E2E2), Color(0xFFF7DCDC)],
    [Color(0xFFE0F0E0), Color(0xFFDCF0DC)],
  ];

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final palette = isLight ? _lightPalette : _darkPalette;
    final idx = name.isEmpty ? 0 : name.codeUnitAt(0) % palette.length;
    return Container(
      decoration: BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: palette[idx])),
      alignment: Alignment.center,
      child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: TextStyle(
              // The watermark has to invert with the tile or it vanishes.
              color: (isLight ? Colors.black : Colors.white)
                  .withValues(alpha: isLight ? 0.06 : 0.08),
              fontSize: 120,
              fontWeight: FontWeight.w900)),
    );
  }
}

class CardEmptyTile extends StatelessWidget {
  const CardEmptyTile({super.key});
  @override
  Widget build(BuildContext context) =>
      ColoredBox(color: JpergImagePlaceholder.colorOf(context));
}
