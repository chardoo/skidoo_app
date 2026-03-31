import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';

class HomeHeaderWidget extends StatefulWidget {
  const HomeHeaderWidget({
    super.key,
    required this.userName,
    required this.userInitial,
    required this.isSearchOpen,
    required this.onSearchOpen,
    required this.onSearchClose,
    required this.onSearchChanged,
    required this.onAvatarTap,
  });

  final String userName;
  final String userInitial;
  final bool isSearchOpen;
  final VoidCallback onSearchOpen;
  final VoidCallback onSearchClose;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onAvatarTap;

  @override
  State<HomeHeaderWidget> createState() => _HomeHeaderWidgetState();
}

class _HomeHeaderWidgetState extends State<HomeHeaderWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _progress;
  late final TextEditingController _textCtrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _progress = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
    _textCtrl = TextEditingController();
  }

  @override
  void didUpdateWidget(HomeHeaderWidget old) {
    super.didUpdateWidget(old);
    if (widget.isSearchOpen != old.isSearchOpen) {
      widget.isSearchOpen ? _ctrl.forward() : _ctrl.reverse();
      if (!widget.isSearchOpen) _textCtrl.clear();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 12.h),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxW = constraints.maxWidth;
          const searchIconW = 44.0;

          return SizedBox(
            height: 44.h,
            child: Stack(
              children: [
                // ── Base row: avatar · logo · search icon ─────────────
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _progress,
                    builder: (_, child) => Opacity(
                      opacity: 1.0 - _progress.value,
                      child: child,
                    ),
                    child: Row(
                      children: [
                        // Avatar
                        GestureDetector(
                          onTap: widget.onAvatarTap,
                          child: CircleAvatar(
                            radius: 20.r,
                            backgroundColor: ext.avatarBackground,
                            child: Text(
                              widget.userInitial,
                              style: TextStyle(
                                color: ext.avatarForeground,
                                fontWeight: FontWeight.bold,
                                fontSize: 15.sp,
                              ),
                            ),
                          ),
                        ),

                        // Logo — centered between avatar and search icon
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 28.w,
                                height: 28.h,
                                decoration: BoxDecoration(
                                  color: ext.logoBadgeBackground,
                                  borderRadius: BorderRadius.circular(6.r),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'S',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16.sp,
                                  ),
                                ),
                              ),
                              SizedBox(width: 7.w),
                              Text(
                                'SKIDDO',
                                style: TextStyle(
                                  color: ext.logoTextColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 19.sp,
                                  letterSpacing: 2,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Search icon placeholder (same width as animated bar)
                        SizedBox(width: searchIconW.w),
                      ],
                    ),
                  ),
                ),

                // ── Animated search bar — expands from RIGHT ──────────
                Align(
                  alignment: Alignment.centerRight,
                  child: AnimatedBuilder(
                    animation: _progress,
                    builder: (_, __) {
                      final w = searchIconW + (maxW - searchIconW) * _progress.value;
                      final expanded = _progress.value > 0.6;

                      return Container(
                        width: w,
                        height: 44.h,
                        decoration: BoxDecoration(
                          color: Color.lerp(
                            Colors.transparent,
                            ext.searchFieldFill,
                            _progress.value,
                          ),
                          borderRadius: BorderRadius.circular(22.r),
                        ),
                        clipBehavior: Clip.hardEdge,
                        child: expanded
                            ? _SearchFieldContent(
                                ext: ext,
                                controller: _textCtrl,
                                onChanged: widget.onSearchChanged,
                                onClose: () {
                                  SystemChannels.textInput
                                      .invokeMethod('TextInput.hide');
                                  widget.onSearchClose();
                                },
                              )
                            : GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: widget.onSearchOpen,
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

// ── Search field content ──────────────────────────────────────────────────────

class _SearchFieldContent extends StatelessWidget {
  const _SearchFieldContent({
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
              hintText: 'Search events...',
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
