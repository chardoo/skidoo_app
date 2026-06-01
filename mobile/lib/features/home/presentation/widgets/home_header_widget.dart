import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:skidoo_app/l10n/app_localizations.dart';
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
    this.onQrScan,
  });

  final String userName;
  final String userInitial;
  final bool isSearchOpen;
  final VoidCallback onSearchOpen;
  final VoidCallback onSearchClose;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onAvatarTap;
  final VoidCallback? onQrScan;

  @override
  State<HomeHeaderWidget> createState() => _HomeHeaderWidgetState();
}

class _HomeHeaderWidgetState extends State<HomeHeaderWidget> {
  late final TextEditingController _textCtrl;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _textCtrl = TextEditingController();
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(HomeHeaderWidget old) {
    super.didUpdateWidget(old);
    if (widget.isSearchOpen && !old.isSearchOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNode.requestFocus();
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

  void _handleClose() {
    SystemChannels.textInput.invokeMethod('TextInput.hide');
    widget.onSearchClose();
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 10.h),
      child: SizedBox(
        height: 46.h,
        child: Row(
          children: [
            // ── Brand mark (hidden when search is open) ───────────────────
            // if (!widget.isSearchOpen) ...[
            //   Image.asset(
            //     'assets/logo/skiido_mark.png',
            //     height: 36.h,
            //     width: 36.h,
            //     fit: BoxFit.contain,
            //   ),
            //   SizedBox(width: 10.w),
            // ],

            // ── Search field ──────────────────────────────────────────────
            Expanded(
              child: GestureDetector(
                onTap: widget.isSearchOpen ? null : widget.onSearchOpen,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  height: 46.h,
                  decoration: BoxDecoration(
                    color: ext.glassFill,
                    borderRadius: BorderRadius.circular(23.r),
                    border: Border.all(
                      color: widget.isSearchOpen
                          ? ext.accentGold.withValues(alpha: 0.6)
                          : ext.glassBorder,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      SizedBox(width: 14.w),
                      Icon(
                        Icons.search_rounded,
                        color: widget.isSearchOpen
                            ? ext.accentGold
                            : ext.glassIcon,
                        size: 20.sp,
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: widget.isSearchOpen
                            ? TextField(
                                controller: _textCtrl,
                                focusNode: _focusNode,
                                style: TextStyle(
                                  color: ext.greetingColor,
                                  fontSize: 14.sp,
                                ),
                                decoration: InputDecoration(
                                  hintText: l10n.homeSearchEvents,
                                  hintStyle: TextStyle(
                                    color: ext.searchHintColor,
                                    fontSize: 14.sp,
                                  ),
                                  border: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                onChanged: widget.onSearchChanged,
                              )
                            : _TypewriterHint(
                                text: l10n.homeSearchAiPlaceholder,
                                style: TextStyle(
                                  color: ext.glassHint,
                                  fontSize: 14.sp,
                                ),
                              ),
                      ),
                      // Right side: close (search open) or QR scan button
                      if (widget.isSearchOpen)
                        Semantics(
                          button: true,
                          label: 'Close search',
                          child: GestureDetector(
                            onTap: _handleClose,
                            child: Padding(
                              padding:
                                  EdgeInsets.symmetric(horizontal: 12.w),
                              child: Icon(
                                Icons.close_rounded,
                                color: ext.searchHintColor,
                                size: 18.sp,
                              ),
                            ),
                          ),
                        )
                      else if (widget.onQrScan != null)
                        Semantics(
                          button: true,
                          label: 'Scan QR code',
                          child: GestureDetector(
                            onTap: widget.onQrScan,
                            child: Padding(
                              padding:
                                  EdgeInsets.symmetric(horizontal: 12.w),
                              child: Icon(
                                Icons.qr_code_scanner_rounded,
                                color: ext.glassIcon,
                                size: 20.sp,
                              ),
                            ),
                          ),
                        )
                      else
                        SizedBox(width: 14.w),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(width: 12.w),

            // ── Profile avatar ────────────────────────────────────────────
            Semantics(
              button: true,
              label: 'Profile',
              child: GestureDetector(
              onTap: widget.onAvatarTap,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      ext.accentGold,
                      const Color(0xFFFF6B35),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: CircleAvatar(
                  radius: 19.r,
                  backgroundColor: ext.glassFill,
                  child: Text(
                    widget.userInitial,
                    style: TextStyle(
                      color: ext.glassIcon,
                      fontWeight: FontWeight.w800,
                      fontSize: 14.sp,
                    ),
                  ),
                ),
              ),
            ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Typewriter placeholder ────────────────────────────────────────────────────

class _TypewriterHint extends StatefulWidget {
  const _TypewriterHint({required this.text, required this.style});
  final String text;
  final TextStyle style;

  @override
  State<_TypewriterHint> createState() => _TypewriterHintState();
}

class _TypewriterHintState extends State<_TypewriterHint> {
  int _charCount = 0;
  bool _cursorVisible = true;

  Timer? _typeTimer;
  Timer? _cursorTimer;

  static const _typeSpeed = Duration(milliseconds: 60);
  static const _eraseSpeed = Duration(milliseconds: 32);
  static const _pauseFull = Duration(milliseconds: 1800);
  static const _pauseEmpty = Duration(milliseconds: 550);
  static const _cursorBlink = Duration(milliseconds: 520);

  @override
  void initState() {
    super.initState();
    _startCursorBlink();
    _scheduleType();
  }

  void _startCursorBlink() {
    _cursorTimer = Timer.periodic(_cursorBlink, (_) {
      if (mounted) setState(() => _cursorVisible = !_cursorVisible);
    });
  }

  void _scheduleType() {
    _typeTimer = Timer.periodic(_typeSpeed, (_) {
      if (!mounted) return;
      if (_charCount < widget.text.length) {
        setState(() => _charCount++);
      } else {
        _typeTimer?.cancel();
        _typeTimer = Timer(_pauseFull, _scheduleErase);
      }
    });
  }

  void _scheduleErase() {
    _typeTimer = Timer.periodic(_eraseSpeed, (_) {
      if (!mounted) return;
      if (_charCount > 0) {
        setState(() => _charCount--);
      } else {
        _typeTimer?.cancel();
        _typeTimer = Timer(_pauseEmpty, () {
          if (!mounted) return;
          _scheduleType();
        });
      }
    });
  }

  @override
  void dispose() {
    _typeTimer?.cancel();
    _cursorTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visible = widget.text.substring(0, _charCount);
    // Cursor is a thin pipe that blinks; hidden chars use a zero-width space
    // so the field height stays stable even when empty.
    return Text.rich(
      TextSpan(
        text: visible,
        children: [
          TextSpan(
            text: _cursorVisible ? '|' : '​',
            style: widget.style.copyWith(
              fontWeight: FontWeight.w300,
              color: _cursorVisible
                  ? (widget.style.color ?? Colors.grey)
                  : Colors.transparent,
            ),
          ),
        ],
      ),
      style: widget.style,
      maxLines: 1,
      overflow: TextOverflow.clip,
    );
  }
}
