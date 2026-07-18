import 'package:flutter/material.dart';

/// Hover-revealed prev/next arrow for the web carousel.
class CarouselArrow extends StatefulWidget {
  const CarouselArrow({
    super.key,
    required this.isLeft,
    required this.enabled,
    required this.onTap,
  });

  final bool isLeft;
  final bool enabled;
  final VoidCallback onTap;

  @override
  State<CarouselArrow> createState() => _CarouselArrowState();
}

class _CarouselArrowState extends State<CarouselArrow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Semantics(
        button: true,
        label: widget.isLeft ? 'Previous photo' : 'Next photo',
        child: GestureDetector(
        onTap: widget.enabled ? widget.onTap : null,
        child: AnimatedOpacity(
          opacity: widget.enabled ? 1.0 : 0.3,
          duration: const Duration(milliseconds: 150),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: _hover ? 0.7 : 0.45),
              shape: BoxShape.circle,
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.25), width: 1),
            ),
            alignment: Alignment.center,
            child: Icon(
              widget.isLeft
                  ? Icons.chevron_left_rounded
                  : Icons.chevron_right_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
      ),
      ),
    );
  }
}
