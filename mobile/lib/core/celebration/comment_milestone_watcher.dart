import 'package:flutter/material.dart';
import 'package:jperg_app/core/celebration/celebration_overlay.dart';
import 'package:jperg_app/core/celebration/comment_milestone.dart';

/// Watches for "you are the 100th comment" and throws the confetti.
///
/// Wrapped around a comment surface rather than mounted at the app root, and
/// deliberately so: a celebration should arrive while somebody is still looking
/// at the thread they posted into, not over whatever screen they had moved on
/// to. At the root it would also fire for a comment posted from a screen that
/// has since been popped.
///
/// It lives here rather than inside [CommentSheetShell], which was where it
/// started, because not every comment surface is that sheet. The web card's
/// inline panel is comment UI by any reading — same bloc, same input bar, same
/// thread — and it had no celebration at all, because it happens not to be a
/// bottom sheet. Anything that shows a comment thread should wrap itself in
/// this; the shell does it for the three that are sheets.
///
/// The overlay is opened from a post-frame callback. The notifier fires inside
/// a bloc's event handler, which can land mid-build, and inserting an
/// [OverlayEntry] during build throws.
class CommentMilestoneWatcher extends StatefulWidget {
  const CommentMilestoneWatcher({super.key, required this.child});

  final Widget child;

  @override
  State<CommentMilestoneWatcher> createState() =>
      _CommentMilestoneWatcherState();
}

class _CommentMilestoneWatcherState extends State<CommentMilestoneWatcher> {
  @override
  void initState() {
    super.initState();
    CommentMilestones.instance.pending.addListener(_onMilestone);
  }

  @override
  void dispose() {
    CommentMilestones.instance.pending.removeListener(_onMilestone);
    super.dispose();
  }

  void _onMilestone() {
    final message = CommentMilestones.instance.pending.value;
    if (message == null) return;
    // Consumed straight away, before the frame it will be drawn in: two
    // surfaces can be mounted at once during a transition, and both would
    // otherwise celebrate the same comment.
    CommentMilestones.instance.consume();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) CelebrationOverlay.show(context, message);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
