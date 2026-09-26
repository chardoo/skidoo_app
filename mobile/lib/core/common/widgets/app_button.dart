import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';

/// App-wide button — one shape/radius/loading-state recipe, four variants.
///
///   • [primary]     — teal fill, white text. The default CTA everywhere.
///   • [secondary]   — subtle fill + hairline border. Toggled/"already done" states.
///   • [destructive] — red fill, white text. Logout / delete / report actions.
///   • [text]        — no fill, just a label. Cancel / dismiss / link actions.
///
/// Change the shape, radius, loading spinner, or the way a press feels here and
/// every button in the app picks it up.
///
/// ## Pressing one
///
/// Two things happen, and both are the button's job rather than the caller's.
///
/// It **answers the finger**: a small scale-down and a selection tick, held for
/// as long as the finger is. A filled teal button barely shows Material's ink
/// ripple, so on the CTAs that matter most there was no acknowledgement at all
/// between the tap and whatever the network did next — and a button that looks
/// inert is a button people press again.
///
/// It then **stops itself being pressed twice**. See [onPressed]: a handler
/// that returns a `Future` puts the button in its loading state until that
/// future completes, so the second tap of a double tap lands on a disabled
/// control instead of posting a second payment.
enum AppButtonVariant { primary, secondary, destructive, text }

class AppButton extends StatefulWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.isLoading = false,
    this.icon,
    this.fullWidth = false,
    this.width,
    this.height,
    this.borderRadius,
  });

  final String label;

  /// What the press does.
  ///
  /// `FutureOr<void>` rather than [VoidCallback], which is the whole
  /// double-tap guard: **an `async` handler disables the button and shows the
  /// spinner until it finishes**, and every call site already written as
  /// `onPressed: () => _somethingAsync()` or `onPressed: _somethingAsync` gets
  /// that without being touched, because a `void Function()` is still a valid
  /// `FutureOr<void> Function()`.
  ///
  /// It cannot help a handler that hands its work to something else and returns
  /// straight away — a bloc event, a `unawaited` call. Those screens know when
  /// the work is done and nothing else does, so they still pass [isLoading]
  /// from their own state.
  final FutureOr<void> Function()? onPressed;

  final AppButtonVariant variant;

  /// Forces the loading state from outside.
  ///
  /// For work this button did not start or cannot await — a bloc's
  /// `state.isSaving`, a parent that disables a row of buttons together. An
  /// async [onPressed] does not need it.
  final bool isLoading;

  final IconData? icon;
  final bool fullWidth;
  final double? width;
  final double? height;

  /// Corner radius override. Defaults to the app's standard 14; pass
  /// [AppRadius.pill] for the fully-rounded pill the Found filter sheet uses.
  final double? borderRadius;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  /// How far the button shrinks under a finger.
  ///
  /// 3%. Enough to read as a press on a 50 dp-tall button without the label
  /// appearing to move — past about 5% the text visibly reflows and the whole
  /// thing reads as a wobble rather than a press.
  static const double _pressedScale = 0.97;

  /// Fast enough to feel like a consequence of the touch rather than an
  /// animation about to play.
  static const Duration _pressDuration = Duration(milliseconds: 90);

  /// True while an async [AppButton.onPressed] is still running.
  bool _awaitingPress = false;

  /// The button's own pressed/hovered/focused state, which is how the scale
  /// below follows the finger. Reading it from the button rather than wrapping
  /// the whole thing in a [GestureDetector] leaves the button's hit testing,
  /// its ripple and its disabled handling exactly as Material wrote them.
  final WidgetStatesController _states = WidgetStatesController();

  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _states.addListener(_onStatesChanged);
  }

  @override
  void dispose() {
    _states.removeListener(_onStatesChanged);
    _states.dispose();
    super.dispose();
  }

  void _onStatesChanged() {
    final pressed = _states.value.contains(WidgetState.pressed);
    if (pressed == _pressed) return;
    // Only on the way down. A tick on release as well reads as two events for
    // one press, and the release already has the scale springing back.
    if (pressed) HapticFeedback.selectionClick();
    setState(() => _pressed = pressed);
  }

  bool get _loading => widget.isLoading || _awaitingPress;

  /// Runs the handler, and holds the button disabled for as long as it takes.
  Future<void> _handlePress() async {
    final handler = widget.onPressed;
    // Re-entrancy belt and braces. The button is already disabled while
    // `_awaitingPress` is true, so this only catches a tap that was already in
    // flight when the state changed.
    if (handler == null || _awaitingPress) return;

    final result = handler();
    if (result is! Future<void>) return;

    setState(() => _awaitingPress = true);
    try {
      await result;
    } catch (error, stack) {
      // Reported here rather than left to escape.
      //
      // [ElevatedButton.onPressed] is `void`, so the future this method returns
      // is dropped the moment it is handed over — which means a handler that
      // throws produces an unhandled async error with no route back to the
      // button that started it. Reporting it names the button in the log and
      // keeps it on the app's own error path instead.
      //
      // Screens are still expected to catch their own failures and tell the
      // reader; this is the net under them, not a substitute.
      FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'jperg',
        context: ErrorDescription('while handling a press on "${widget.label}"'),
      ));
    } finally {
      // Whatever happened, the button comes back. A failed request that left it
      // spinning could only be retried by leaving the screen and returning,
      // which is the one moment a reader is most likely to want to retry.
      //
      // The screen may be gone by now — plenty of these handlers end by popping
      // the route they were pressed on.
      if (mounted) setState(() => _awaitingPress = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final effectiveWidth =
        widget.width ?? (widget.fullWidth ? double.infinity : null);

    final Color background;
    final Color foreground;
    final BorderSide side;
    switch (widget.variant) {
      case AppButtonVariant.primary:
        background = ext.accentGold;
        foreground = Colors.white;
        side = BorderSide.none;
        break;
      case AppButtonVariant.secondary:
        background = ext.searchFieldFill;
        foreground = ext.greetingColor;
        side = BorderSide(color: ext.searchHintColor.withValues(alpha: 0.35));
        break;
      case AppButtonVariant.destructive:
        background = const Color(0xFFB00020);
        foreground = Colors.white;
        side = BorderSide.none;
        break;
      case AppButtonVariant.text:
        background = Colors.transparent;
        foreground = ext.accentGold;
        side = BorderSide.none;
        break;
    }

    if (widget.variant == AppButtonVariant.text) {
      return _pressable(
        SizedBox(
          width: effectiveWidth,
          height: widget.height,
          child: TextButton(
            statesController: _states,
            onPressed:
                _loading || widget.onPressed == null ? null : _handlePress,
            style: TextButton.styleFrom(foregroundColor: foreground),
            child: _content(foreground),
          ),
        ),
      );
    }

    return _pressable(
      SizedBox(
        width: effectiveWidth,
        height: widget.height ?? 50.h,
        child: ElevatedButton(
          statesController: _states,
          onPressed: _loading || widget.onPressed == null ? null : _handlePress,
          style: ElevatedButton.styleFrom(
            backgroundColor: background,
            foregroundColor: foreground,
            disabledBackgroundColor: background.withValues(alpha: 0.5),
            elevation: 0,
            // A caller-supplied height is a budget, not a suggestion. 14.h above
            // and below the label needs ~48 before the text is even drawn, so a
            // compact button (the 40 the group-name Save and the confirm dialog
            // ask for) clipped its own label in half. With an explicit height the
            // SizedBox sets the size and the button centres the label inside it.
            //
            // Horizontal is the other way round: a button with no width of its
            // own is exactly as wide as its label, so with no padding the text
            // ran to the very edge — and under a pill radius the corner curve
            // cut straight through the first and last glyph. A button that was
            // given a width has already had its room measured, so it keeps the
            // tight fit it was sized for.
            padding: EdgeInsets.symmetric(
              horizontal: effectiveWidth == null ? 20.w : 0,
              vertical: widget.height != null ? 0 : 14.h,
            ),
            shape: RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular((widget.borderRadius ?? 14).r),
              side: side,
            ),
          ),
          child: _content(foreground),
        ),
      ),
    );
  }

  /// Wraps a button in the press response every button in the app shares.
  ///
  /// [AnimatedScale] rather than a scale rebuilt per frame: the whole response
  /// is one value moving between two numbers, and this is the widget that owns
  /// that. Alignment is centre by default, which is what makes the button look
  /// pressed rather than nudged.
  Widget _pressable(Widget child) => AnimatedScale(
        scale: _pressed ? _pressedScale : 1,
        duration: _pressDuration,
        curve: Curves.easeOut,
        child: child,
      );

  Widget _content(Color foreground) {
    if (_loading) {
      return SizedBox(
        width: 18.w,
        height: 18.w,
        child: CircularProgressIndicator(strokeWidth: 2, color: foreground),
      );
    }
    final text = Text(
      widget.label,
      maxLines: 1,
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700),
    );

    // Shrinks the widget.label rather than letting it spill. The widget.height is fixed and
    // the widget.width is often somebody else's (a full-widget.width CTA, a 84.w Save), so a
    // long widget.label or a large system text size has nowhere to grow — and a
    // button is the one place where a clipped word costs you the tap. Scales
    // down only when it has to; at ordinary sizes nothing moves.
    if (widget.icon == null) {
      return FittedBox(fit: BoxFit.scaleDown, child: text);
    }
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(widget.icon, size: 16.sp),
          SizedBox(width: 6.w),
          text,
        ],
      ),
    );
  }
}
