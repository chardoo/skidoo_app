import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/models/event_discovery/event_discovery.dart';

/// TikTok-style text overlay at the bottom-left of a feed card's media —
/// event name plus a collapsible content-tags line.
class ImageFooter extends StatefulWidget {
  const ImageFooter({super.key, required this.event});
  final EventDiscovery event;

  @override
  State<ImageFooter> createState() => _ImageFooterState();
}

class _ImageFooterState extends State<ImageFooter> {
  bool _tagsExpanded = false;

  static const _heavy = [
    Shadow(blurRadius: 20, color: Colors.black),
    Shadow(blurRadius: 6, color: Colors.black87),
  ];
  static const _soft = [
    Shadow(blurRadius: 10, color: Colors.black87),
  ];

  String get _tagLine {
    final tags = widget.event.contentTags;
    if (tags.isEmpty) return '';
    return tags.map((t) => '#$t').join('  ');
  }

  @override
  Widget build(BuildContext context) {
    final tagLine = _tagLine;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Event name first — large and bold
        Text(
          widget.event.eventName,
          maxLines: _tagsExpanded ? null : 2,
          overflow:
              _tagsExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white,
            fontSize: 20.sp,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
            height: 1.15,
            shadows: _heavy,
          ),
        ),

        // Content tags — inline with "more / less" pinned to the right
        if (tagLine.isNotEmpty) ...[
          SizedBox(height: 4.h),
          Semantics(button: true, label: 'Toggle tags', child: GestureDetector(
            onTap: () => setState(() => _tagsExpanded = !_tagsExpanded),
            child: _tagsExpanded
                ? Text(
                    tagLine,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                      shadows: _soft,
                    ),
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Text(
                          tagLine,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                            shadows: _soft,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'more',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w500,
                          shadows: _soft,
                        ),
                      ),
                    ],
                  ),
          )),
        ],
      ],
    );
  }
}
