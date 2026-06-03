import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

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
        borderRadius: BorderRadius.circular(14.r),
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
        style: TextStyle(
          color: Colors.white,
          fontSize: 15.sp,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.2,
        ),
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hint,
          labelStyle: TextStyle(
            color: _isFocused ? _kLabelFocused : _kLabelIdle,
            fontSize: 14.sp,
            fontWeight: FontWeight.w400,
          ),
          hintStyle: TextStyle(
            color: _kHint,
            fontSize: 14.sp,
          ),
          prefixIcon: Padding(
            padding: EdgeInsets.only(left: 4.w),
            child: Icon(
              widget.prefixIcon,
              color: _isFocused ? _kLabelFocused : _kLabelIdle,
              size: 20.sp,
            ),
          ),
          suffixIcon: widget.suffix,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          contentPadding:
              EdgeInsets.symmetric(horizontal: 16.w, vertical: 18.h),
          errorStyle: TextStyle(
            color: _kError,
            fontSize: 11.5.sp,
            height: 0.1,
          ),
          errorMaxLines: 1,
        ),
      ),
    );
  }
}

// ── Phone field with country dial-code dropdown ────────────────────────────────

class _Country {
  const _Country(this.name, this.iso2, this.dial);
  final String name;
  final String iso2;
  final String dial;
}

const List<_Country> _kCountries = [
  _Country('Ghana', 'GH', '+233'),
  _Country('Nigeria', 'NG', '+234'),
  _Country('Kenya', 'KE', '+254'),
  _Country('South Africa', 'ZA', '+27'),
  _Country("Côte d'Ivoire", 'CI', '+225'),
  _Country('Senegal', 'SN', '+221'),
  _Country('Cameroon', 'CM', '+237'),
  _Country('Tanzania', 'TZ', '+255'),
  _Country('Uganda', 'UG', '+256'),
  _Country('Egypt', 'EG', '+20'),
  _Country('Morocco', 'MA', '+212'),
  _Country('United States', 'US', '+1'),
  _Country('Canada', 'CA', '+1'),
  _Country('United Kingdom', 'GB', '+44'),
  _Country('Ireland', 'IE', '+353'),
  _Country('Germany', 'DE', '+49'),
  _Country('France', 'FR', '+33'),
  _Country('Spain', 'ES', '+34'),
  _Country('Portugal', 'PT', '+351'),
  _Country('Italy', 'IT', '+39'),
  _Country('Netherlands', 'NL', '+31'),
  _Country('Belgium', 'BE', '+32'),
  _Country('Switzerland', 'CH', '+41'),
  _Country('Sweden', 'SE', '+46'),
  _Country('Norway', 'NO', '+47'),
  _Country('Denmark', 'DK', '+45'),
  _Country('United Arab Emirates', 'AE', '+971'),
  _Country('Saudi Arabia', 'SA', '+966'),
  _Country('India', 'IN', '+91'),
  _Country('China', 'CN', '+86'),
  _Country('Japan', 'JP', '+81'),
  _Country('Singapore', 'SG', '+65'),
  _Country('Australia', 'AU', '+61'),
  _Country('New Zealand', 'NZ', '+64'),
  _Country('Brazil', 'BR', '+55'),
  _Country('Mexico', 'MX', '+52'),
];

String _flagEmoji(String iso2) => iso2
    .toUpperCase()
    .codeUnits
    .map((c) => String.fromCharCode(0x1F1E6 + c - 0x41))
    .join();

/// A phone input with a country dial-code dropdown. The full E.164 number
/// (e.g. `+233241234567`) is written to [controller]; the visible field holds
/// only the national digits. [validator] validates those national digits.
class AuthPhoneField extends StatefulWidget {
  const AuthPhoneField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.initialIso2 = 'GH',
    this.textInputAction = TextInputAction.next,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final String initialIso2;
  final TextInputAction textInputAction;
  final String? Function(String?)? validator;

  @override
  State<AuthPhoneField> createState() => _AuthPhoneFieldState();
}

class _AuthPhoneFieldState extends State<AuthPhoneField> {
  final _focusNode = FocusNode();
  final _nationalCtrl = TextEditingController();
  bool _isFocused = false;
  late String _iso2 = widget.initialIso2;

  String get _dial =>
      _kCountries.firstWhere((c) => c.iso2 == _iso2, orElse: () => _kCountries.first).dial;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
    _nationalCtrl.addListener(_syncFullNumber);
  }

  void _onFocusChange() => setState(() => _isFocused = _focusNode.hasFocus);

  void _syncFullNumber() {
    // Drop a national trunk "0" (e.g. 024… → +23324…) so the E.164 number is
    // correct even when the user types the local leading zero out of habit.
    final national =
        _nationalCtrl.text.trim().replaceFirst(RegExp(r'^0+'), '');
    widget.controller.text = national.isEmpty ? '' : '$_dial$national';
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _nationalCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: _kFill,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: _isFocused ? _kBorderFocused : _kBorderIdle,
          width: _isFocused ? 1.5 : 1,
        ),
      ),
      child: TextFormField(
        controller: _nationalCtrl,
        focusNode: _focusNode,
        keyboardType: TextInputType.phone,
        textInputAction: widget.textInputAction,
        validator: widget.validator,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: TextStyle(color: Colors.white, fontSize: 15.sp, letterSpacing: 0.2),
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hint,
          labelStyle: TextStyle(
            color: _isFocused ? _kLabelFocused : _kLabelIdle,
            fontSize: 14.sp,
          ),
          hintStyle: TextStyle(color: _kHint, fontSize: 14.sp),
          prefixIcon: _DialCodeDropdown(
            iso2: _iso2,
            isFocused: _isFocused,
            onChanged: (v) {
              setState(() => _iso2 = v);
              _syncFullNumber();
            },
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 18.h),
          errorStyle: TextStyle(color: _kError, fontSize: 11.5.sp, height: 0.1),
          errorMaxLines: 1,
        ),
      ),
    );
  }
}

class _DialCodeDropdown extends StatelessWidget {
  const _DialCodeDropdown({
    required this.iso2,
    required this.isFocused,
    required this.onChanged,
  });

  final String iso2;
  final bool isFocused;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 12.w, right: 4.w),
      child: DropdownButtonHideUnderline(
        child: Semantics(
          button: true,
          label: 'Country code',
          child: DropdownButton<String>(
            value: iso2,
            isDense: true,
            dropdownColor: _kFill,
            borderRadius: BorderRadius.circular(12.r),
            style: TextStyle(color: Colors.white, fontSize: 14.sp),
            icon: Icon(Icons.arrow_drop_down_rounded,
                color: isFocused ? _kLabelFocused : _kLabelIdle, size: 20.sp),
            // Collapsed button shows flag + dial code only.
            selectedItemBuilder: (_) => _kCountries
                .map((c) => Align(
                      alignment: Alignment.centerLeft,
                      child: Text('${_flagEmoji(c.iso2)}  ${c.dial}',
                          style: TextStyle(
                              color: Colors.white, fontSize: 14.sp)),
                    ))
                .toList(),
            items: _kCountries
                .map((c) => DropdownMenuItem<String>(
                      value: c.iso2,
                      child: Text('${_flagEmoji(c.iso2)}  ${c.name} (${c.dial})',
                          style: const TextStyle(color: Colors.white)),
                    ))
                .toList(),
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
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
      suffix: Semantics(button: true, label: 'Show or hide password', child: GestureDetector(
        onTap: () => setState(() => _obscure = !_obscure),
        child: Padding(
          padding: EdgeInsets.only(right: 4.w),
          child: Icon(
            _obscure
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            color: _kLabelIdle,
            size: 20.sp,
          ),
        ),
      )),
    );
  }
}
