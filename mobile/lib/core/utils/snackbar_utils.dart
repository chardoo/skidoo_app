import 'package:flutter/material.dart';

/// App-wide SnackBar helpers — four semantic types, consistent style everywhere.
///
/// Types:
///   • [error]      — red,   for failures and blocking problems
///   • [success]    — green, for completed actions
///   • [info]       — dark grey, for neutral status messages
///   • [withAction] — dark surface + teal action (e.g. "Content hidden / Undo")
///
/// All types: floating, 12-px radius, standard margin, hides the current bar first.
class AppSnackBar {
  AppSnackBar._();

  static const _kError   = Color(0xFFB00020);
  static const _kSuccess = Color(0xFF2E7D32);
  static const _kInfo    = Color(0xFF37474F);
  static const _kDark    = Color(0xFF2C2C2E);
  static const _kGold    = Color(0xFF1D9E75);

  /// Spelled out, never inherited.
  ///
  /// Every background above is a fixed, saturated, *dark* colour in both
  /// themes, so the text over it has to be fixed too. Left to the theme it is
  /// not: Material resolves snackbar content to `colorScheme.onInverseSurface`,
  /// the app's scheme never set that, and the fallback for it is
  /// `colorScheme.surface` — near-black in dark mode. So an error in dark mode
  /// was #1F1F1D text on a #B00020 field, about 1.3:1, which is a snackbar
  /// that arrives, says nothing legible, and leaves.
  ///
  /// The size is a plain number rather than `.sp` on purpose: this runs from
  /// failure paths, including ones that fire before a screen — and therefore
  /// before screenutil — is up. It is the same 14 as [AppTypography.sm].
  static const _kContentStyle = TextStyle(color: Colors.white, fontSize: 14);

  static const _kDefaultMargin =
      EdgeInsets.fromLTRB(16, 0, 16, 16);
  static const _kShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(12)),
  );

  static void error(
    BuildContext context,
    String message, {
    EdgeInsetsGeometry? margin,
  }) =>
      _show(context, message, backgroundColor: _kError, margin: margin);

  static void success(
    BuildContext context,
    String message, {
    EdgeInsetsGeometry? margin,
  }) =>
      _show(context, message, backgroundColor: _kSuccess, margin: margin);

  static void info(
    BuildContext context,
    String message, {
    EdgeInsetsGeometry? margin,
  }) =>
      _show(context, message, backgroundColor: _kInfo, margin: margin);

  /// Shows a dark snackbar with a branded action button.
  /// Returns the [Future<SnackBarClosedReason>] so callers can react to
  /// whether the user tapped the action or let it dismiss naturally.
  static Future<SnackBarClosedReason> withAction(
    BuildContext context,
    String message, {
    required String actionLabel,
    required VoidCallback onAction,
    Duration duration = const Duration(seconds: 4),
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    return messenger
        .showSnackBar(SnackBar(
          duration: duration,
          behavior: SnackBarBehavior.floating,
          margin: _kDefaultMargin,
          backgroundColor: _kDark,
          shape: _kShape,
          content: Text(message, style: _kContentStyle),
          action: SnackBarAction(
            label: actionLabel,
            textColor: _kGold,
            onPressed: onAction,
          ),
        ))
        .closed;
  }

  /// Use when [BuildContext] is not safe across an async gap.
  /// Capture [ScaffoldMessenger.of(context)] before the await, then call this.
  static void errorOnMessenger(ScaffoldMessengerState messenger, String message) =>
      _showOnMessenger(messenger, message, backgroundColor: _kError);

  static void successOnMessenger(ScaffoldMessengerState messenger, String message) =>
      _showOnMessenger(messenger, message, backgroundColor: _kSuccess);

  static void infoOnMessenger(ScaffoldMessengerState messenger, String message) =>
      _showOnMessenger(messenger, message, backgroundColor: _kInfo);

  static void _show(
    BuildContext context,
    String message, {
    required Color backgroundColor,
    EdgeInsetsGeometry? margin,
  }) {
    _showOnMessenger(
      ScaffoldMessenger.of(context),
      message,
      backgroundColor: backgroundColor,
      margin: margin,
    );
  }

  static void _showOnMessenger(
    ScaffoldMessengerState messenger,
    String message, {
    required Color backgroundColor,
    EdgeInsetsGeometry? margin,
  }) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message, style: _kContentStyle),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        margin: margin ?? _kDefaultMargin,
        shape: _kShape,
        duration: const Duration(seconds: 3),
      ));
  }
}
