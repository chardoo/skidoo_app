import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:jperg_app/core/widgets/jperg_image.dart';
import 'package:jperg_app/features/ads/models/ad_media.dart';

/// The position indicator under a carousel: one dot per item, the current one
/// stretched into a bar.
///
/// Shared rather than per-screen so a campaign looks the same wherever it is
/// shown — the feed and its own detail page are the same campaign, and two
/// different indicators would read as two different kinds of thing.
class MediaPageDots extends StatelessWidget {
  const MediaPageDots({super.key, required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 18.0 : 6.0,
          height: 6.0,
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.white.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}

/// Every image on a request or a campaign, one swipe apart.
///
/// **Never advances on its own.** A campaign's images are not a slideshow to be
/// watched — they are the thing being decided about, and a picture that slides
/// away while it is being read takes the decision with it. The only thing that
/// moves this is a finger.
///
/// Each frame is drawn the way the feed draws one: a blurred copy of the image
/// fills the box, and the image itself sits on top under [BoxFit.contain]. That
/// is what lets a portrait shot and a wide one share a fixed-height frame
/// without either being cropped — [BoxFit.cover] in a short box takes a slice
/// out of the middle of a tall photo, which on a campaign is as likely as not
/// the half that mattered.
class MediaCarousel extends StatefulWidget {
  const MediaCarousel({
    super.key,
    required this.media,
    required this.height,
    this.onTap,
  });

  final List<AdMedia> media;

  /// The frame's height. The images inside adapt to it rather than the other
  /// way round, so a list of mixed shapes stays a tidy column.
  final double height;

  final VoidCallback? onTap;

  @override
  State<MediaCarousel> createState() => _MediaCarouselState();
}

class _MediaCarouselState extends State<MediaCarousel> {
  final _controller = PageController();
  int _current = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.media.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // A single image gets no PageView: there is nothing to page to, and
            // one would swallow horizontal drags that belong to whatever this
            // sits inside.
            if (widget.media.length == 1)
              _MediaFrame(media: widget.media.first)
            else
              PageView.builder(
                controller: _controller,
                itemCount: widget.media.length,
                onPageChanged: (i) {
                  if (i != _current && mounted) setState(() => _current = i);
                },
                itemBuilder: (_, i) => _MediaFrame(media: widget.media[i]),
              ),
            if (widget.media.length > 1)
              Positioned(
                left: 0,
                right: 0,
                bottom: 10,
                child: MediaPageDots(
                  count: widget.media.length,
                  current: _current,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MediaFrame extends StatelessWidget {
  const _MediaFrame({required this.media});

  final AdMedia media;

  @override
  Widget build(BuildContext context) {
    if (media.url.isEmpty) return const JpergImagePlaceholder();

    return Stack(
      fit: StackFit.expand,
      children: [
        ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: JpergImage(
            imageUrl: media.url,
            fit: BoxFit.cover,
            isBlurBackground: true,
            placeholder: (_, __) => const JpergImagePlaceholder(),
            errorWidget: (_, __, ___) => const JpergImagePlaceholder(),
          ),
        ),
        const ColoredBox(color: Color(0x55000000)),
        JpergImage(
          imageUrl: media.url,
          fit: BoxFit.contain,
          placeholder: (_, __) => const Center(
            child: CircularProgressIndicator(
              color: Colors.white70,
              strokeWidth: 2,
            ),
          ),
          errorWidget: (_, __, ___) => const JpergImagePlaceholder(),
        ),
        // Marked, not played. This frame is a still in a list; tapping through
        // to the page that plays it is the caller's business.
        if (media.isVideo)
          const Center(
            child: Icon(
              Icons.play_circle_rounded,
              color: Colors.white70,
              size: 54,
            ),
          ),
      ],
    );
  }
}
