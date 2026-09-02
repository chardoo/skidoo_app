import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';

/// The validation message under a form field.
///
/// One widget so every field in the app puts its error in the same place, at
/// the same size, with the same gap above it — see [AppTextField] for why the
/// message cannot be left to [InputDecoration].
class AppFieldError extends StatelessWidget {
  const AppFieldError(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    return Padding(
      padding: EdgeInsets.only(
        top: AppSpacing.xs.h,
        left: AppSpacing.xs.w,
        right: AppSpacing.xs.w,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            // Nudged down onto the text's optical baseline — an icon aligned
            // to the top of a 1.35-height line box floats above the words.
            padding: EdgeInsets.only(top: 1.h),
            child: Icon(Icons.error_outline_rounded,
                size: 13.sp, color: ext.errorRed),
          ),
          SizedBox(width: AppSpacing.xs.w),
          Expanded(
            child: Text(
              message,
              // Wraps rather than truncating: "Please choose a password that
              // doesn't contain your name or email address" is three lines on
              // a phone, and the half a user can read is not the useful half.
              style: TextStyle(
                color: ext.errorRed,
                fontSize: 11.5.sp,
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// App-wide text field — one focus animation, one fill/border/label recipe,
/// theme-aware (follows light/dark instead of being hardcoded). Change the
/// radius, focus color, or padding here and every field in the app updates.
///
/// Set [filled] to false for a bare field with no background/border — used
/// inside dialogs/sheets that already provide their own chrome.
///
/// ## Why the error text is not [InputDecoration]'s job here
///
/// The fill and border are drawn by the [AnimatedContainer] wrapping the
/// input, not by `InputDecorator` — that is what buys the animated focus glow.
/// But it also means anything `InputDecorator` renders lands *inside* that box,
/// error text included, so the message appeared within the field's own border.
/// The previous fix for that was `errorStyle: height: 0.1`, which collapsed the
/// line box to a tenth of its height and dragged the text up until it struck
/// through the bottom border — legible as neither a border nor a sentence.
///
/// So the field owns its own [FormField]: the input sits in the box, and the
/// message sits below it with room to wrap. Validation still runs from the
/// enclosing [Form] exactly as it did with `TextFormField`.
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.controller,
    this.label,
    this.hint,
    this.prefixIcon,
    this.prefixText,
    this.suffix,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.validator,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.readOnly = false,
    this.onTap,
    this.onChanged,
    this.onFieldSubmitted,
    this.inputFormatters,
    this.dense = false,
    this.filled = true,
    this.autofocus = false,
    this.focusNode,
    this.borderRadius,
    this.textCapitalization = TextCapitalization.none,
    this.buildCounter,
    this.maxLengthEnforcement,
    this.textAlign = TextAlign.start,
  });

  final TextEditingController controller;
  final String? label;
  final String? hint;
  final IconData? prefixIcon;
  final String? prefixText;
  final Widget? suffix;
  final bool obscureText;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final String? Function(String?)? validator;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final bool readOnly;
  final VoidCallback? onTap;
  final void Function(String)? onChanged;
  final void Function(String)? onFieldSubmitted;
  final List<TextInputFormatter>? inputFormatters;
  final bool dense;
  final bool filled;
  final bool autofocus;
  final FocusNode? focusNode;

  /// Override the fill's corner radius — e.g. 22.r for a fully-rounded
  /// "pill" message/comment input vs. the default 14.r form-field look.
  final double? borderRadius;
  final TextCapitalization textCapitalization;
  final InputCounterWidgetBuilder? buildCounter;
  final MaxLengthEnforcement? maxLengthEnforcement;
  final TextAlign textAlign;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late final FocusNode _focusNode = widget.focusNode ?? FocusNode();
  bool _ownsFocusNode = false;
  bool _isFocused = false;

  /// The [FormField] this input drives, held so the controller can push
  /// programmatic edits into it — see [_handleControllerChanged].
  FormFieldState<String>? _fieldState;

  @override
  void initState() {
    super.initState();
    _ownsFocusNode = widget.focusNode == null;
    _focusNode.addListener(_onFocusChange);
    widget.controller.addListener(_handleControllerChanged);
  }

  void _onFocusChange() => setState(() => _isFocused = _focusNode.hasFocus);

  /// Text set on the controller from outside — a phone field rewriting the
  /// number, a form prefilling a value — never passes through `onChanged`, so
  /// the FormField would keep validating a value the user can no longer see.
  /// Mirrors what `TextFormField` does internally.
  void _handleControllerChanged() {
    final state = _fieldState;
    if (state != null && widget.controller.text != state.value) {
      state.didChange(widget.controller.text);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    _focusNode.removeListener(_onFocusChange);
    if (_ownsFocusNode) _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final textColor = ext.greetingColor;
    final idleLabel = ext.searchHintColor;
    final focusedColor = ext.accentGold;

    return FormField<String>(
      initialValue: widget.controller.text,
      validator: widget.validator,
      builder: (state) {
        _fieldState = state;
        final hasError = state.hasError;
        // The label and border follow the error, so a field that is being
        // complained about looks like one even before the message is read.
        final accent =
            hasError ? ext.errorRed : (_isFocused ? focusedColor : idleLabel);

        final field = TextField(
          controller: widget.controller,
          focusNode: _focusNode,
          obscureText: widget.obscureText,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          maxLines: widget.obscureText ? 1 : widget.maxLines,
          minLines: widget.minLines,
          maxLength: widget.maxLength,
          maxLengthEnforcement: widget.maxLengthEnforcement,
          buildCounter: widget.buildCounter,
          textCapitalization: widget.textCapitalization,
          readOnly: widget.readOnly,
          onTap: widget.onTap,
          // onChanged: (value) {
          //   state.didChange(value);
          //   widget.onChanged?.call(value);
          // },
          onChanged: (value) {
            state.didChange(value);
            widget.onChanged?.call(value);
          },
          onSubmitted: (value) {
            if (value.trim().isEmpty) {
              FocusScope.of(context).unfocus();
            }
            widget.onFieldSubmitted?.call(value);
          },
          // onSubmitted: widget.onFieldSubmitted,
          inputFormatters: widget.inputFormatters,
          autofocus: widget.autofocus,
          textAlign: widget.textAlign,
          style: TextStyle(
            color: textColor,
            fontSize: 15.sp,
            fontWeight: FontWeight.w400,
            letterSpacing: 0.2,
          ),
          decoration: InputDecoration(
            isDense: widget.dense,
            labelText: widget.label,
            hintText: widget.hint,
            prefixText: widget.prefixText,
            labelStyle: TextStyle(
              color: accent,
              fontSize: 14.sp,
              fontWeight: FontWeight.w400,
            ),
            hintStyle: TextStyle(color: idleLabel, fontSize: 14.sp),
            prefixIcon: widget.prefixIcon == null
                ? null
                : Padding(
                    padding: EdgeInsets.only(left: AppSpacing.xs.w),
                    child: Icon(
                      widget.prefixIcon,
                      color: accent,
                      size: 20.sp,
                    ),
                  ),
            suffixIcon: widget.suffix,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            // 12, not the 18 this used to carry. Because the border is drawn by
            // the AnimatedContainer below rather than by InputDecorator, a
            // floating [label] stacks a whole extra row *on top of* this padding
            // — so 18 produced a 75 px field on the signup/onboarding forms
            // against Material's 56 dp for a filled field. 12 lands at 63.5 with
            // a label and 50 without; the no-label case can't go below 50
            // anyway, since Flutter clamps to the 48 dp minimum touch target.
            contentPadding: widget.dense
                ? EdgeInsets.symmetric(
                    horizontal: AppSpacing.md.w, vertical: 10.h)
                : EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg.w, vertical: 12.h),
          ),
        );

        final input = widget.filled
            ? AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                decoration: BoxDecoration(
                  color: ext.searchFieldFill,
                  borderRadius:
                      BorderRadius.circular(widget.borderRadius ?? 14.r),
                  border: Border.all(
                    color: hasError
                        ? ext.errorRed
                        : (_isFocused
                            ? focusedColor
                            : ext.searchHintColor.withValues(alpha: 0.25)),
                    width: (_isFocused || hasError) ? 1.5 : 1,
                  ),
                  boxShadow: _isFocused && !hasError
                      ? [
                          BoxShadow(
                            color: focusedColor.withValues(alpha: 0.18),
                            blurRadius: 16,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                child: field,
              )
            : field;

        if (!hasError) return input;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [input, AppFieldError(state.errorText!)],
        );
      },
    );
  }
}

/// Password variant with the visibility toggle built in.
class AppPasswordField extends StatefulWidget {
  const AppPasswordField({
    super.key,
    required this.controller,
    this.label,
    this.hint,
    this.textInputAction = TextInputAction.done,
    this.validator,
  });

  final TextEditingController controller;
  final String? label;
  final String? hint;
  final TextInputAction textInputAction;
  final String? Function(String?)? validator;

  @override
  State<AppPasswordField> createState() => _AppPasswordFieldState();
}

class _AppPasswordFieldState extends State<AppPasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    return AppTextField(
      controller: widget.controller,
      label: widget.label,
      hint: widget.hint,
      prefixIcon: Icons.lock_outline_rounded,
      obscureText: _obscure,
      keyboardType: TextInputType.visiblePassword,
      textInputAction: widget.textInputAction,
      validator: widget.validator,
      suffix: Semantics(
        button: true,
        label: 'Show or hide password',
        child: GestureDetector(
          onTap: () => setState(() => _obscure = !_obscure),
          child: Padding(
            padding: EdgeInsets.only(right: AppSpacing.xs.w),
            child: Icon(
              _obscure
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              color: ext.searchHintColor,
              size: 20.sp,
            ),
          ),
        ),
      ),
    );
  }
}
