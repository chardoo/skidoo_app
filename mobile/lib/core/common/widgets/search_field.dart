import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/theme/app_input.dart';
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';

/// What surface a search field is sitting on, which is the only thing that may
/// differ between two of them.
///
/// The app had four separate drawings of this control — the glass pill, the
/// Search screen's own bar, the forward sheet's borderless filled box, and a
/// form field with a search icon in the location picker — and they disagreed on
/// height, corner radius, fill, border weight, icon colour and size, text size
/// and whether there was a clear button at all.
///
/// Only one of those differences was ever meaningful. [glass] is *translucent*
/// (white 10% / black 5%) because it is designed to sit over a photo; on an
/// opaque page background it nearly vanishes, which is why the Search screen
/// had its own opaque treatment and a test pinning it. So the tint is a
/// property of what is behind the field, and everything else — the shape, the
/// metrics, the icon, the clear button — is the same everywhere.
enum SearchFieldSurface {
  /// Over media or a photo header: the translucent fill.
  glass,

  /// On a page or sheet background: opaque, so it stays visible in light mode.
  page,
}

/// The one search box.
///
/// Every search box in the app is this widget, and the drawing is the chat
/// search field's: a rounded rectangle on an opaque fill, a hairline border
/// that turns gold on focus, a magnifier at the leading edge and a clear
/// button that appears with the text. The chat screens were the only place
/// that treatment existed — [ChatSearchField] is now this widget plus the
/// trailing Cancel, rather than a fifth copy of it.
///
/// Change the shape or the metrics here and they all move together; the only
/// thing a caller chooses is [surface], and only because a translucent fill is
/// unreadable on an opaque background.
class SearchField extends StatefulWidget {
  const SearchField({
    super.key,
    required this.controller,
    this.hint = 'Search',
    this.surface = SearchFieldSurface.page,
    this.onChanged,
    this.onSubmitted,
    this.focusNode,
    this.autofocus = false,
    this.onClear,
    this.height,
    this.loading = false,
    this.textInputAction = TextInputAction.search,
  });

  final TextEditingController controller;
  final String hint;

  /// Defaults to [SearchFieldSurface.page]. Every field in the app sits on a
  /// page or a sheet; [SearchFieldSurface.glass] is for the one that ends up
  /// over a photo, and four call sites were getting the translucent fill on a
  /// flat background only because it used to be the default.
  final SearchFieldSurface surface;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;
  final FocusNode? focusNode;
  final bool autofocus;

  /// What the clear button does. Optional: with nothing passed the field
  /// clears its own controller and reports the empty query through
  /// [onChanged], which is what every caller wrote by hand and what the share
  /// sheet forgot to — leaving it as the one search box with no way to empty
  /// it.
  final VoidCallback? onClear;
  final double? height;
  final bool loading;

  /// The keyboard's action key. Search by default, which is what every caller
  /// wants and what the hand-rolled copies of this widget each set for
  /// themselves before they were folded back in.
  final TextInputAction textInputAction;

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  /// Owned only when the caller did not supply one — disposing a caller's
  /// focus node would break the screens that keep it for the lifetime of the
  /// page.
  FocusNode? _ownedFocusNode;

  FocusNode get _focusNode =>
      widget.focusNode ?? (_ownedFocusNode ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(SearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _ownedFocusNode)?.removeListener(_onFocusChanged);
      _focusNode.addListener(_onFocusChanged);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _ownedFocusNode?.dispose();
    super.dispose();
  }

  // The border colour is the focus indicator, so focus has to repaint it.
  void _onFocusChanged() {
    if (mounted) setState(() {});
  }

  void _clear() {
    if (widget.onClear != null) {
      widget.onClear!();
      return;
    }
    widget.controller.clear();
    widget.onChanged?.call('');
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final onGlass = widget.surface == SearchFieldSurface.glass;
    final focused = _focusNode.hasFocus;

    final fill = onGlass ? ext.glassFill : ext.searchFieldFill;
    final iconColor = onGlass ? ext.glassIcon : ext.searchHintColor;
    final hintColor = onGlass ? ext.glassHint : ext.searchHintColor;
    // Focus is shown by the outline turning gold — the only state the field
    // has, and the reason the chat treatment reads as an input rather than as
    // a button. Over media the resting border is doing the work of separating
    // the field from a photo, so it keeps the heavier glass outline.
    final border = focused
        ? ext.accentGold
        : onGlass
            ? ext.glassBorder
            : ext.searchHintColor.withValues(alpha: 0.25);

    return Container(
      height: widget.height ?? 46.h,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(AppRadius.md.r),
        border: Border.all(color: border, width: onGlass && !focused ? 1.5 : 1),
      ),
      child: Row(
        children: [
          SizedBox(width: AppSpacing.md.w),
          // Always present, unlike the chat field it is taken from: there the
          // magnifier gave up its slot to the clear button, so the query
          // jumped left by the width of the icon on the first keystroke.
          Icon(Icons.search_rounded, color: iconColor, size: 20.sp),
          SizedBox(width: AppSpacing.md.w),
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: _focusNode,
              autofocus: widget.autofocus,
              onChanged: widget.onChanged,
              onSubmitted: widget.onSubmitted,
              textInputAction: widget.textInputAction,
              style: TextStyle(color: ext.greetingColor, fontSize: 15.sp),
              // The container above is the only outline this field gets — see
              // [kBorderlessInput] for why `border: InputBorder.none` alone
              // left a second one inside it whenever the field had focus.
              decoration: kBorderlessInput.copyWith(
                hintText: widget.hint,
                hintStyle: TextStyle(color: hintColor, fontSize: 15.sp),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: AppSpacing.md.h),
              ),
            ),
          ),
          if (widget.loading)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.md.w),
              child: SizedBox(
                width: 16.w,
                height: 16.w,
                child: CircularProgressIndicator(
                    color: ext.accentGold, strokeWidth: 2),
              ),
            )
          else
            // Watching the controller rather than reading it once.
            //
            // `controller.text` is read at build time, so as a plain condition
            // the button only appeared when something *else* rebuilt the
            // parent. Every caller happened to do that — a setState in
            // onChanged, or a ValueListenableBuilder wrapped around the whole
            // field — which is a requirement none of them could see and the
            // next one would not have met.
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: widget.controller,
              builder: (_, value, __) => value.text.isEmpty
                  ? SizedBox(width: AppSpacing.md.w)
                  : Semantics(
                      button: true,
                      label: 'Clear search',
                      child: GestureDetector(
                        onTap: _clear,
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10.w),
                          child: Icon(Icons.cancel,
                              color: iconColor, size: 18.sp),
                        ),
                      ),
                    ),
            ),
        ],
      ),
    );
  }
}
