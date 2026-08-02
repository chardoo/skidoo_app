import 'package:flutter/material.dart';

/// Base decoration for a [TextField] that already sits inside its own painted
/// container — a search pill, a chat composer, a form row with its own border.
///
/// Passing `border: InputBorder.none` is not enough on its own. A field
/// resolves its outline per state (`focusedBorder ?? border` when focused,
/// `enabledBorder ?? border` otherwise), and `InputDecoration.applyDefaults`
/// fills each empty slot from the app's [InputDecorationTheme] *before* that
/// resolution runs. So a theme that defines any state border outranks the
/// call site's `border`, and the field draws a second outline inside the
/// container the caller already painted.
///
/// Clearing every slot here is the only version that cannot be reintroduced by
/// a later change to the theme. Compose with `copyWith`:
///
/// ```dart
/// decoration: kBorderlessInput.copyWith(
///   hintText: 'Search',
///   hintStyle: TextStyle(color: ext.searchHintColor),
/// ),
/// ```
const kBorderlessInput = InputDecoration(
  border: InputBorder.none,
  enabledBorder: InputBorder.none,
  focusedBorder: InputBorder.none,
  disabledBorder: InputBorder.none,
  errorBorder: InputBorder.none,
  focusedErrorBorder: InputBorder.none,
);
