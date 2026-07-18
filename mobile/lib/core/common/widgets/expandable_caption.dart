import 'package:flutter/material.dart';

/// Caption/description text that truncates at [collapsedMaxLines] and shows
/// a tappable "more" link — but only when the text actually overflows at
/// that line count. Tapping "more" expands to the full text with a "less"
/// link to collapse back.
class ExpandableCaption extends StatefulWidget {
  const ExpandableCaption({
    super.key,
    required this.text,
    required this.style,
    this.collapsedMaxLines = 2,
    this.linkStyle,
    this.moreLabel = 'more',
    this.lessLabel = 'less',
  });

  final String text;
  final TextStyle style;
  final int collapsedMaxLines;
  final TextStyle? linkStyle;
  final String moreLabel;
  final String lessLabel;

  @override
  State<ExpandableCaption> createState() => _ExpandableCaptionState();
}

class _ExpandableCaptionState extends State<ExpandableCaption> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.text.isEmpty) return const SizedBox.shrink();

    final linkStyle = widget.linkStyle ??
        widget.style.copyWith(
          color: widget.style.color?.withValues(alpha: 0.6),
          fontWeight: FontWeight.w600,
        );

    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: widget.style),
          maxLines: widget.collapsedMaxLines,
          textDirection: Directionality.of(context),
        )..layout(maxWidth: constraints.maxWidth);
        final overflows = painter.didExceedMaxLines;

        if (!overflows) {
          return Text(widget.text, style: widget.style);
        }

        return Semantics(
          button: true,
          label: _expanded ? widget.lessLabel : widget.moreLabel,
          child: GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            behavior: HitTestBehavior.opaque,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.text,
                  style: widget.style,
                  maxLines: _expanded ? null : widget.collapsedMaxLines,
                  overflow:
                      _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                ),
                Text(_expanded ? widget.lessLabel : widget.moreLabel,
                    style: linkStyle),
              ],
            ),
          ),
        );
      },
    );
  }
}
