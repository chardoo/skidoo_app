import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/models/event_discovery/event_discovery.dart';
import 'package:skidoo_app/core/theme/app_spacing.dart';
import 'package:skidoo_app/core/widgets/skidoo_image.dart';

// ── Image slider ──────────────────────────────────────────────────────────────

class EventImageSlider extends StatefulWidget {
  const EventImageSlider({super.key, required this.pics, required this.ext});

  final List<EventPicture> pics;
  final AppThemeExtension ext;

  @override
  State<EventImageSlider> createState() => _EventImageSliderState();
}

class _EventImageSliderState extends State<EventImageSlider> {
  final _pageCtrl = PageController(viewportFraction: 0.88);
  int _current = 0;

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 200.h,
          child: PageView.builder(
            controller: _pageCtrl,
            itemCount: widget.pics.length,
            onPageChanged: (i) => setState(() => _current = i),
            itemBuilder: (_, i) => Padding(
              padding: EdgeInsets.symmetric(horizontal: 6.w),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14.r),
                child: SkidooImage(
                  imageUrl: widget.pics[i].url,
                  semanticLabel: 'Event photo',
                  fit: BoxFit.cover,
                  placeholder: (context, __) =>
                      Container(color: SkidooImagePlaceholder.colorOf(context)),
                  errorWidget: (context, __, ___) => Container(
                    color: SkidooImagePlaceholder.colorOf(context),
                    child: const Icon(Icons.broken_image_outlined,
                        color: Colors.white38),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (widget.pics.length > 1) ...[
          SizedBox(height: 10.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              widget.pics.length.clamp(0, 12),
              (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                margin: EdgeInsets.symmetric(horizontal: 3.w),
                width: _current == i ? 18.w : 6.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: _current == i
                      ? widget.ext.accentGold
                      : widget.ext.searchHintColor.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),
          ),
        ],
        SizedBox(height: AppSpacing.xs.h),
      ],
    );
  }
}
