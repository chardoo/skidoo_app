import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';

/// The six-box entry for an emailed code.
///
/// One widget because there are two of these screens — signup verification and
/// password reset — doing the identical job. They each held their own copy of
/// this, seventy lines apiece, and the copies had already drifted: the resend
/// label read differently, the button corners were rounded differently, and a
/// fix to one was a fix to one.
///
/// ## One field, not one per digit
///
/// Both screens started as six [TextField]s handing focus along the row. Moving
/// focus between fields tears down the platform text-input connection and
/// builds a new one, which the user sees as the keyboard dropping and springing
/// back **on every digit** — and each field drew its own focus ring, so the row
/// flickered through six states while a six-digit code was typed. Backspacing
/// was worse: the handler moved focus back on an empty field, so a correction
/// could bounce between two boxes.
///
/// So: one real field, transparent, laid over six boxes that are pure
/// decoration driven by its controller. One keyboard session for the whole
/// code, and paste and iOS SMS autofill come free.
///
/// ## The boxes have to be visible
///
/// Every box carries a border. Without one they are `searchFieldFill` on
/// `homeBackground`, which in the light theme is #EFEFE9 on #F7F7F2 — a
/// contrast ratio of about 1.06, meaning the row of slots is invisible and the
/// only thing on screen is the digits already typed. There is no way to see how
/// many are left, which is the one thing this control exists to show.
///
/// The three states are distinct for the same reason: filled boxes take a tint
/// of the accent so progress reads at a glance, the box awaiting the next digit
/// takes the full accent, and untouched boxes take a grey hairline.
class AppCodeField extends StatefulWidget {
  const AppCodeField({
    super.key,
    required this.controller,
    required this.focusNode,
    this.length = 6,
    this.autofocus = true,
    this.hasError = false,
    this.onChanged,
    this.onCompleted,
  });

  final TextEditingController controller;

  /// Owned by the caller, which needs it to dismiss the keyboard once the code
  /// is complete — deliberately, and once, rather than letting it flicker.
  final FocusNode focusNode;

  final int length;
  final bool autofocus;

  /// Turns the boxes red. A rejected code is explained in a banner below, but
  /// the eye is on the boxes — leaving them looking accepted while the message
  /// says otherwise reads as two screens disagreeing.
  final bool hasError;

  final ValueChanged<String>? onChanged;

  /// Fired when the last box is filled. The caller decides what that means:
  /// both screens unfocus and submit.
  final ValueChanged<String>? onCompleted;

  @override
  State<AppCodeField> createState() => _AppCodeFieldState();
}

class _AppCodeFieldState extends State<AppCodeField> {
  @override
  void initState() {
    super.initState();
    // The ring on the active box is driven by `hasFocus`, which is false on the
    // first build even with autofocus set — so without this the first box
    // stayed unringed until the first keystroke.
    widget.focusNode.addListener(_redraw);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_redraw);
    super.dispose();
  }

  void _redraw() {
    if (mounted) setState(() {});
  }

  void _onChanged(String value) {
    setState(() {}); // Redraw the boxes for the new digit and caret position.
    widget.onChanged?.call(value);
    if (value.length == widget.length) widget.onCompleted?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final digits = widget.controller.text;

    return Stack(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(widget.length, (i) {
            final filled = i < digits.length;
            // The caret sits on the first empty box — or on the last one when
            // the code is complete.
            final isCurrent = widget.focusNode.hasFocus &&
                (i == digits.length ||
                    (digits.length == widget.length && i == widget.length - 1));

            final Color border;
            if (widget.hasError) {
              border = ext.errorRed.withValues(alpha: isCurrent ? 1 : 0.55);
            } else if (isCurrent) {
              border = ext.accentGold;
            } else if (filled) {
              border = ext.accentGold.withValues(alpha: 0.35);
            } else {
              // The hairline that makes an empty slot a slot. Off the hint
              // colour rather than a fixed grey, so it holds in both themes.
              border = ext.searchHintColor.withValues(alpha: 0.30);
            }

            return Container(
              width: 44.w,
              height: 52.h,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: ext.searchFieldFill,
                borderRadius: BorderRadius.circular(AppRadius.md.r),
                border: Border.all(color: border, width: 1.5),
              ),
              child: Text(
                filled ? digits[i] : '',
                style: TextStyle(
                  color: widget.hasError ? ext.errorRed : ext.greetingColor,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
          }),
        ),
        // Invisible, but real: it owns the input connection and takes the taps,
        // so tapping any box opens the keyboard.
        Positioned.fill(
          child: TextField(
            controller: widget.controller,
            focusNode: widget.focusNode,
            autofocus: widget.autofocus,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            // Lets iOS offer the emailed code from the keyboard bar instead of
            // making the user retype it.
            autofillHints: const [AutofillHints.oneTimeCode],
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(widget.length),
            ],
            // Nothing here is selectable, and offering to select it is what
            // makes this pattern look broken on a device: a long press puts a
            // magnifier and a pair of drag handles over the boxes, aimed at
            // text that is transparent and 0.01 tall, and Android adds a Paste
            // bubble on top of the row.
            enableInteractiveSelection: false,
            magnifierConfiguration: TextMagnifierConfiguration.disabled,
            // Hidden rather than removed — the boxes above are the visible
            // rendering of this field's value.
            showCursor: false,
            cursorColor: Colors.transparent,
            style: const TextStyle(color: Colors.transparent, height: 0.01),
            decoration: const InputDecoration(
              counterText: '',
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              fillColor: Colors.transparent,
              filled: true,
            ),
            onChanged: _onChanged,
            onSubmitted: (value) {
              if (value.length == widget.length) {
                widget.onCompleted?.call(value);
              }
            },
          ),
        ),
      ],
    );
  }
}
