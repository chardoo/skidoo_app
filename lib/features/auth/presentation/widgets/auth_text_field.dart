import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ── Shared design tokens ───────────────────────────────────────────────────────
const _kFill          = Color(0xFF151821);
const _kBorderIdle    = Color(0xFF252836);
const _kBorderFocused = Color(0xFFFF8303);
const _kLabelIdle     = Color(0xFF9BA3B2);
const _kLabelFocused  = Color(0xFFFF8303);
const _kHint          = Color(0xFF4A5568);
const _kError         = Color(0xFFFF4757);

/// A premium styled text field for the auth screens.
class AuthTextField extends StatefulWidget {
  const AuthTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.prefixIcon,
    this.hint,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.validator,
    this.suffix,
    this.readOnly = false,
    this.onTap,
    this.inputFormatters,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData prefixIcon;
  final bool obscureText;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final String? Function(String?)? validator;
  final Widget? suffix;
  final bool readOnly;
  final VoidCallback? onTap;
  final List<TextInputFormatter>? inputFormatters;

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  final _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    setState(() => _isFocused = _focusNode.hasFocus);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: _kFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _isFocused ? _kBorderFocused : _kBorderIdle,
          width: _isFocused ? 1.5 : 1,
        ),
        boxShadow: _isFocused
            ? [
                BoxShadow(
                  color: _kBorderFocused.withValues(alpha: 0.18),
                  blurRadius: 16,
                  spreadRadius: 0,
                  offset: const Offset(0, 2),
                ),
              ]
            : [],
      ),
      child: TextFormField(
        controller: widget.controller,
        focusNode: _focusNode,
        obscureText: widget.obscureText,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        validator: widget.validator,
        readOnly: widget.readOnly,
        onTap: widget.onTap,
        inputFormatters: widget.inputFormatters,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.2,
        ),
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hint,
          labelStyle: TextStyle(
            color: _isFocused ? _kLabelFocused : _kLabelIdle,
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
          hintStyle: const TextStyle(
            color: _kHint,
            fontSize: 14,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Icon(
              widget.prefixIcon,
              color: _isFocused ? _kLabelFocused : _kLabelIdle,
              size: 20,
            ),
          ),
          suffixIcon: widget.suffix,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          errorStyle: const TextStyle(
            color: _kError,
            fontSize: 11.5,
            height: 0.1,
          ),
          errorMaxLines: 1,
        ),
      ),
    );
  }
}

/// Password variant with the toggle eye built-in.
class AuthPasswordField extends StatefulWidget {
  const AuthPasswordField({
    super.key,
    required this.controller,
    required this.label,
    this.textInputAction = TextInputAction.done,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final TextInputAction textInputAction;
  final String? Function(String?)? validator;

  @override
  State<AuthPasswordField> createState() => _AuthPasswordFieldState();
}

class _AuthPasswordFieldState extends State<AuthPasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return AuthTextField(
      controller: widget.controller,
      label: widget.label,
      prefixIcon: Icons.lock_outline_rounded,
      obscureText: _obscure,
      keyboardType: TextInputType.visiblePassword,
      textInputAction: widget.textInputAction,
      validator: widget.validator,
      suffix: GestureDetector(
        onTap: () => setState(() => _obscure = !_obscure),
        child: Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Icon(
            _obscure
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            color: _kLabelIdle,
            size: 20,
          ),
        ),
      ),
    );
  }
}
