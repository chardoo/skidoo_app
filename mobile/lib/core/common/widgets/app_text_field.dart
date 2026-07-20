import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/core/theme/app_spacing.dart';

/// App-wide text field — one focus animation, one fill/border/label recipe,
/// theme-aware (follows light/dark instead of being hardcoded). Change the
/// radius, focus color, or padding here and every field in the app updates.
///
/// Set [filled] to false for a bare field with no background/border — used
/// inside dialogs/sheets that already provide their own chrome.
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

  @override
  void initState() {
    super.initState();
    _ownsFocusNode = widget.focusNode == null;
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() => setState(() => _isFocused = _focusNode.hasFocus);

  @override
  void dispose() {
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

    final field = TextFormField(
      controller: widget.controller,
      focusNode: _focusNode,
      obscureText: widget.obscureText,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      validator: widget.validator,
      maxLines: widget.obscureText ? 1 : widget.maxLines,
      minLines: widget.minLines,
      maxLength: widget.maxLength,
      maxLengthEnforcement: widget.maxLengthEnforcement,
      buildCounter: widget.buildCounter,
      textCapitalization: widget.textCapitalization,
      readOnly: widget.readOnly,
      onTap: widget.onTap,
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onFieldSubmitted,
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
          color: _isFocused ? focusedColor : idleLabel,
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
                  color: _isFocused ? focusedColor : idleLabel,
                  size: 20.sp,
                ),
              ),
        suffixIcon: widget.suffix,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        focusedErrorBorder: InputBorder.none,
        contentPadding: widget.dense
            ? EdgeInsets.symmetric(horizontal: AppSpacing.md.w, vertical: 10.h)
            : EdgeInsets.symmetric(horizontal: AppSpacing.lg.w, vertical: 18.h),
        errorStyle: TextStyle(color: ext.errorRed, fontSize: 11.5.sp, height: 0.1),
        errorMaxLines: 1,
      ),
    );

    if (!widget.filled) return field;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: ext.searchFieldFill,
        borderRadius: BorderRadius.circular(widget.borderRadius ?? 14.r),
        border: Border.all(
          color: _isFocused
              ? focusedColor
              : ext.searchHintColor.withValues(alpha: 0.25),
          width: _isFocused ? 1.5 : 1,
        ),
        boxShadow: _isFocused
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
