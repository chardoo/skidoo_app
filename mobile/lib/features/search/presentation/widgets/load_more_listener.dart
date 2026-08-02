import 'package:flutter/widgets.dart';

/// Fires [onLoadMore] once the inner scroll view comes within [threshold] of
/// its end.
///
/// Wrapping the notification plumbing keeps the three paged screens from each
/// re-deriving "am I near the bottom" — and from forgetting the two guards
/// that matter: nested scroll views (the horizontal chip row) must not count,
/// and a view that has not been laid out yet has no extent to compare against.
///
/// De-duplication is the caller's job: [enabled] is what the bloc's
/// `isLoadingMore` / `hasNext` flags feed into, so a burst of scroll frames
/// dispatches one request, not thirty.
class LoadMoreListener extends StatelessWidget {
  const LoadMoreListener({
    super.key,
    required this.child,
    required this.onLoadMore,
    this.enabled = true,
    this.threshold = 400,
  });

  final Widget child;
  final VoidCallback onLoadMore;
  final bool enabled;
  final double threshold;

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        // depth > 0 is a nested scrollable — the horizontal chips, a filmstrip
        // — whose position says nothing about the page's own.
        if (!enabled || notification.depth != 0) return false;
        final metrics = notification.metrics;
        if (!metrics.hasContentDimensions) return false;
        if (metrics.pixels >= metrics.maxScrollExtent - threshold) {
          onLoadMore();
        }
        return false;
      },
      child: child,
    );
  }
}
