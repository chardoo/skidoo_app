import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';

class PhotographersHeader extends StatelessWidget {
  const PhotographersHeader({
    super.key,
    required this.progress,
    required this.textCtrl,
    required this.isSearchOpen,
    required this.onSearchOpen,
    required this.onSearchClose,
    required this.onSearchChanged,
  });

  final Animation<double> progress;
  final TextEditingController textCtrl;
  final bool isSearchOpen;
  final VoidCallback onSearchOpen;
  final VoidCallback onSearchClose;
  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 8.h),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxW = constraints.maxWidth;
          const searchIconW = 44.0;

          return SizedBox(
            height: 44.h,
            child: Stack(
              children: [
                // ── Base row: title · search icon placeholder ──────────
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: progress,
                    builder: (_, child) => Opacity(
                      opacity: 1.0 - progress.value,
                      child: child,
                    ),
                    child: Row(
                      children: [
                        Text(
                          'Creators',
                          style: TextStyle(
                            color: ext.greetingColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 20.sp,
                          ),
                        ),
                        const Spacer(),
                        SizedBox(width: searchIconW.w),
                      ],
                    ),
                  ),
                ),

                // ── Animated search bar — expands from RIGHT ───────────
                Align(
                  alignment: Alignment.centerRight,
                  child: AnimatedBuilder(
                    animation: progress,
                    builder: (_, __) {
                      final w =
                          searchIconW + (maxW - searchIconW) * progress.value;
                      final expanded = progress.value > 0.6;

                      return Container(
                        width: w,
                        height: 44.h,
                        decoration: BoxDecoration(
                          color: Color.lerp(
                            Colors.transparent,
                            ext.searchFieldFill,
                            progress.value,
                          ),
                          borderRadius: BorderRadius.circular(22.r),
                        ),
                        clipBehavior: Clip.hardEdge,
                        child: expanded
                            ? PhotographersSearchField(
                                ext: ext,
                                controller: textCtrl,
                                onChanged: onSearchChanged,
                                onClose: onSearchClose,
                              )
                            : GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: onSearchOpen,
                                child: Icon(
                                  Icons.search_rounded,
                                  color: ext.searchIconColor,
                                  size: 22.sp,
                                ),
                              ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class PhotographersSearchField extends StatelessWidget {
  const PhotographersSearchField({
    super.key,
    required this.ext,
    required this.controller,
    required this.onChanged,
    required this.onClose,
  });

  final AppThemeExtension ext;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 14.w),
        Icon(Icons.search_rounded, color: ext.searchHintColor, size: 18.sp),
        SizedBox(width: 8.w),
        Expanded(
          child: TextField(
            controller: controller,
            autofocus: true,
            style: TextStyle(color: ext.greetingColor, fontSize: 14.sp),
            decoration: InputDecoration(
              hintText: 'Search creators...',
              hintStyle:
                  TextStyle(color: ext.searchHintColor, fontSize: 14.sp),
              border: InputBorder.none,
              focusedBorder: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
            onChanged: onChanged,
          ),
        ),
        GestureDetector(
          onTap: onClose,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w),
            child: Icon(Icons.close_rounded,
                color: ext.searchHintColor, size: 18.sp),
          ),
        ),
      ],
    );
  }
}
