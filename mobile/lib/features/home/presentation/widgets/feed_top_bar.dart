import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';

/// Feed top bar — collapsed: plain-text Found/For You/Following tabs (active
/// tab bold + underlined), centred as a group, with a create (+) icon on the
/// far left and a search icon on the far right; no persistent search field or
/// avatar. Tapping the search icon swaps the whole row for a full-width
/// search input with a scan icon and a close button, matching the design
/// screenshot this was built from (no separate search-bar row above it, and
/// no scan entry point until search is open).
class FeedTopBar extends StatefulWidget {
  const FeedTopBar({
    super.key,
    required this.selectedTab,
    required this.onTabChanged,
    required this.isSearchOpen,
    required this.onSearchOpen,
    required this.onSearchClose,
    required this.onSearchChanged,
    this.onQrScan,
    this.onCreatePressed,
  });

  final int selectedTab;
  final ValueChanged<int> onTabChanged;
  final bool isSearchOpen;
  final VoidCallback onSearchOpen;
  final VoidCallback onSearchClose;
  final ValueChanged<String> onSearchChanged;

  /// Only reachable once search is open — sits next to the search field.
  final VoidCallback? onQrScan;

  /// Opens the create-a-request/campaign sheet. Shown as a "+" on the far
  /// left of the collapsed bar; hidden entirely when null (feature disabled).
  final VoidCallback? onCreatePressed;

  @override
  State<FeedTopBar> createState() => _FeedTopBarState();
}

class _FeedTopBarState extends State<FeedTopBar> {
  final _textCtrl = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void didUpdateWidget(FeedTopBar old) {
    super.didUpdateWidget(old);
    if (widget.isSearchOpen && !old.isSearchOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    } else if (!widget.isSearchOpen && old.isSearchOpen) {
      _textCtrl.clear();
      _focusNode.unfocus();
    }
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _closeSearch() {
    SystemChannels.textInput.invokeMethod('TextInput.hide');
    widget.onSearchClose();
  }

  void _clearText() {
    _textCtrl.clear();
    widget.onSearchChanged('');
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 8.h),
      child: SizedBox(
        height: 32.h,
        child: widget.isSearchOpen
            ? Row(
                children: [
                  // Leading back arrow — the primary, unambiguous way out of
                  // search (the old trailing "X" read as "clear", not "back",
                  // and was easy to miss next to the scan icon).
                  Semantics(
                    button: true,
                    label: 'Back',
                    child: GestureDetector(
                      onTap: _closeSearch,
                      child: Padding(
                        padding: EdgeInsets.only(right: 8.w),
                        child: Icon(Icons.arrow_back_rounded,
                            color: Colors.white, size: 24.sp),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _textCtrl,
                      builder: (context, value, _) => TextField(
                        controller: _textCtrl,
                        focusNode: _focusNode,
                        autofocus: true,
                        style: TextStyle(color: ext.greetingColor, fontSize: 15.sp),
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: 'Search',
                          hintStyle: TextStyle(color: ext.searchHintColor, fontSize: 15.sp),
                          prefixIcon: Icon(Icons.search_rounded,
                              color: ext.accentGold, size: 20.sp),
                          suffixIcon: value.text.isEmpty
                              ? null
                              : Semantics(
                                  button: true,
                                  label: 'Clear search',
                                  child: GestureDetector(
                                    onTap: _clearText,
                                    child: Icon(Icons.close_rounded,
                                        color: ext.searchHintColor, size: 18.sp),
                                  ),
                                ),
                          border: InputBorder.none,
                        ),
                        onChanged: widget.onSearchChanged,
                      ),
                    ),
                  ),
                  if (widget.onQrScan != null) ...[
                    SizedBox(width: 8.w),
                    Semantics(
                      button: true,
                      label: 'Scan QR code',
                      child: GestureDetector(
                        onTap: widget.onQrScan,
                        child: Icon(Icons.qr_code_scanner_rounded,
                            color: ext.searchHintColor, size: 20.sp),
                      ),
                    ),
                  ],
                ],
              )
            : Stack(
                alignment: Alignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _FeedTextTab(
                        label: 'Found',
                        active: widget.selectedTab == 0,
                        ext: ext,
                        onTap: () => widget.onTabChanged(0),
                      ),
                      SizedBox(width: 18.w),
                      _FeedTextTab(
                        label: 'For You',
                        active: widget.selectedTab == 1,
                        ext: ext,
                        onTap: () => widget.onTabChanged(1),
                      ),
                      SizedBox(width: 18.w),
                      _FeedTextTab(
                        label: 'Following',
                        active: widget.selectedTab == 2,
                        ext: ext,
                        onTap: () => widget.onTabChanged(2),
                      ),
                    ],
                  ),
                  if (widget.onCreatePressed != null)
                    Positioned(
                      left: 0,
                      child: Semantics(
                        button: true,
                        label: 'Create a request or campaign',
                        child: GestureDetector(
                          onTap: widget.onCreatePressed,
                          child: Icon(Icons.add_rounded,
                              color: Colors.white, size: 26.sp),
                        ),
                      ),
                    ),
                  Positioned(
                    right: 0,
                    child: Semantics(
                      button: true,
                      label: 'Open search',
                      child: GestureDetector(
                        onTap: widget.onSearchOpen,
                        child: Icon(Icons.search_rounded,
                            color: Colors.white, size: 24.sp),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _FeedTextTab extends StatelessWidget {
  const _FeedTextTab({
    required this.label,
    required this.active,
    required this.ext,
    required this.onTap,
  });

  final String label;
  final bool active;
  final AppThemeExtension ext;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: active,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: active ? Colors.white : Colors.white60,
                fontSize: 15.sp,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            SizedBox(height: 4.h),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: active ? 16.w : 0,
              height: 2,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(1.r),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
