import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// Width of the right-side chat / messages panel on web desktop & laptop.
const double kWebChatPanelWidth = 460.0;

/// Gap above the panel so it clears the top bar / action cluster.
const double kWebChatPanelTopGap = 56.0;

/// Pushes [page] so that on web it occupies exactly the chat-panel column
/// (same width/position, sliding in from the right) — keeping every chat
/// sub-page (create group, group info, add people, …) inside the right panel.
/// On non-web platforms it falls back to a normal full-screen push.
///
/// Uses the root navigator so the page layers above the messages panel.
Future<T?> showWebPanelPage<T>(BuildContext context, Widget page) {
  final navigator = Navigator.of(context, rootNavigator: true);
  if (!kIsWeb) {
    return navigator.push<T>(MaterialPageRoute<T>(builder: (_) => page));
  }
  return navigator.push<T>(
    PageRouteBuilder<T>(
      opaque: false,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (_, animation, __) =>
          _WebPanelPageFrame(animation: animation, child: page),
    ),
  );
}

class _WebPanelPageFrame extends StatelessWidget {
  const _WebPanelPageFrame({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Tap outside the panel column to dismiss this page.
        Positioned.fill(
          child: GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: const ColoredBox(color: Color(0x14000000)),
          ),
        ),
        Positioned(
          top: kWebChatPanelTopGap,
          right: 0,
          bottom: 0,
          width: kWebChatPanelWidth,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOut)),
            child: child,
          ),
        ),
      ],
    );
  }
}
