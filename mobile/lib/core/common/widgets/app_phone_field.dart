import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/common/widgets/app_text_field.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';

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
  // 'United Arab Emirates' in full is 384pt with the flag and dial beside
  // it — wider than the menu fits on a phone, so it was the one name that
  // had to elide. UAE is the ordinary short form.
  _Country('UAE', 'AE', '+971'),
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

/// The names in the dial-code menu, for the test that checks they still fit.
///
/// The list is private because nothing outside this file chooses from it; this
/// is the one fact about it worth asserting elsewhere — see
/// `country_menu_fits_test`.
@visibleForTesting
List<String> get countryNamesForTest =>
    _kCountries.map((c) => c.name).toList(growable: false);

String _flagEmoji(String iso2) => iso2
    .toUpperCase()
    .codeUnits
    .map((c) => String.fromCharCode(0x1F1E6 + c - 0x41))
    .join();

/// How wide the country menu opens.
///
/// Wide enough for the longest name in [_kCountries] — "United Kingdom" at
/// 196pt — beside a flag and a dial code, on one line, with room to spare.
/// Fixed rather than measured because the list is 36 entries written in this
/// file: measuring them would be a layout pass to rediscover something known
/// at compile time. `country_menu_fits_test` measures them anyway, and fails
/// if a name is added that no longer fits.
double get _kMenuWidth => 320.w;

/// One country, as three columns rather than one sentence.
class _CountryRow extends StatelessWidget {
  const _CountryRow({required this.country, required this.textColor});

  final _Country country;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    return Row(
      children: [
        Text(_flagEmoji(country.iso2), style: TextStyle(fontSize: 16.sp)),
        SizedBox(width: AppSpacing.md.w),
        // Elides rather than wraps. A name too long for the menu is one line
        // ending in an ellipsis, which keeps every row the same height — the
        // wrapping is what made the list look ragged.
        Expanded(
          child: Text(
            country.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: textColor, fontSize: 14.sp),
          ),
        ),
        SizedBox(width: AppSpacing.sm.w),
        // Quieter than the name, and last: the name is what somebody scans
        // for, the code is what they are checking once they have found it.
        Text(
          country.dial,
          // 12, not 13: the scale in AppTypography has no 13, and
          // brand_typography_test refuses sizes between two steps.
          style: TextStyle(color: ext.searchHintColor, fontSize: 12.sp),
        ),
      ],
    );
  }
}

/// A phone input with a country dial-code dropdown, styled like [AppTextField]
/// (theme-aware fill/border/focus). The full E.164 number (e.g.
/// `+233241234567`) is written to [controller]; the visible field holds only
/// the national digits. [validator] validates those national digits.
class AppPhoneField extends StatefulWidget {
  const AppPhoneField({
    super.key,
    required this.controller,
    this.label,
    this.hint,
    this.initialIso2 = 'GH',
    this.textInputAction = TextInputAction.next,
    this.validator,
  });

  final TextEditingController controller;
  final String? label;
  final String? hint;
  final String initialIso2;
  final TextInputAction textInputAction;
  final String? Function(String?)? validator;

  @override
  State<AppPhoneField> createState() => _AppPhoneFieldState();
}

class _AppPhoneFieldState extends State<AppPhoneField> {
  final _focusNode = FocusNode();
  final _nationalCtrl = TextEditingController();
  bool _isFocused = false;
  late String _iso2 = widget.initialIso2;

  String get _dial => _kCountries
      .firstWhere((c) => c.iso2 == _iso2, orElse: () => _kCountries.first)
      .dial;

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
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final textColor = ext.greetingColor;
    final idleLabel = ext.searchHintColor;
    final focusedColor = ext.accentGold;

    // Same structure as AppTextField, and for the same reason: the border is
    // this widget's AnimatedContainer, so an InputDecorator error would be
    // drawn inside the box. See the note on AppTextField.
    return FormField<String>(
      initialValue: widget.controller.text,
      validator: widget.validator,
      builder: (state) {
        final hasError = state.hasError;
        final accent =
            hasError ? ext.errorRed : (_isFocused ? focusedColor : idleLabel);

        final input = AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: ext.searchFieldFill,
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(
              color: hasError
                  ? ext.errorRed
                  : (_isFocused
                      ? focusedColor
                      : idleLabel.withValues(alpha: 0.25)),
              width: (_isFocused || hasError) ? 1.5 : 1,
            ),
          ),
          child: TextField(
            controller: _nationalCtrl,
            focusNode: _focusNode,
            keyboardType: TextInputType.phone,
            textInputAction: widget.textInputAction,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            // The validator reads the full E.164 number the parent controller
            // holds, not the national digits typed here, so the FormField is
            // fed the same value the form will submit.
            onChanged: (_) => state.didChange(widget.controller.text),
            style:
                TextStyle(color: textColor, fontSize: 15.sp, letterSpacing: 0.2),
            decoration: InputDecoration(
              labelText: widget.label,
              hintText: widget.hint,
              labelStyle: TextStyle(color: accent, fontSize: 14.sp),
              hintStyle: TextStyle(color: idleLabel, fontSize: 14.sp),
              prefixIcon: _DialCodeDropdown(
                iso2: _iso2,
                isFocused: _isFocused,
                textColor: textColor,
                idleColor: idleLabel,
                focusedColor: focusedColor,
                fillColor: ext.searchFieldFill,
                onChanged: (v) {
                  setState(() => _iso2 = v);
                  _syncFullNumber();
                  state.didChange(widget.controller.text);
                },
              ),
              prefixIconConstraints:
                  const BoxConstraints(minWidth: 0, minHeight: 0),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              // Matches AppTextField's vertical rhythm — the phone field sits
              // directly beside those in the signup form, so the two have to be
              // the same height.
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 10.w, vertical: 12.h),
            ),
          ),
        );

        // Always the Column, never the bare box — see the note on the same
        // line in [AppTextField]. Swapping the two shapes as the field went
        // valid or invalid rebuilt the TextField underneath and dropped the
        // keyboard mid-number.
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            input,
            if (hasError) AppFieldError(state.errorText!),
          ],
        );
      },
    );
  }
}

class _DialCodeDropdown extends StatelessWidget {
  const _DialCodeDropdown({
    required this.iso2,
    required this.isFocused,
    required this.textColor,
    required this.idleColor,
    required this.focusedColor,
    required this.fillColor,
    required this.onChanged,
  });

  final String iso2;
  final bool isFocused;
  final Color textColor;
  final Color idleColor;
  final Color focusedColor;
  final Color fillColor;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: AppSpacing.md.w, right: AppSpacing.xs.w),
      child: DropdownButtonHideUnderline(
        child: Semantics(
          button: true,
          label: 'Country code',
          child: DropdownButton<String>(
            value: iso2,
            isDense: true,
            dropdownColor: fillColor,
            borderRadius: BorderRadius.circular(AppRadius.md.r),
            style: TextStyle(color: textColor, fontSize: 14.sp),
            icon: Icon(Icons.arrow_drop_down_rounded,
                color: isFocused ? focusedColor : idleColor, size: 20.sp),
            // Collapsed button shows flag + dial code only.
            selectedItemBuilder: (_) => _kCountries
                .map((c) => Align(
                      alignment: Alignment.centerLeft,
                      child: Text('${_flagEmoji(c.iso2)}  ${c.dial}',
                          style: TextStyle(color: textColor, fontSize: 14.sp)),
                    ))
                .toList(),
            // The menu is as wide as the names in it, not as wide as the
            // button that opens it.
            //
            // A dropdown's menu takes the button's width by default, and this
            // button is deliberately tiny — it shows a flag and a dial code.
            // So every name was folded into two and three lines: the flag
            // alone on one row, "Cameroon" under it, "(+237)" under that.
            // Thirteen countries in, the list read as a column of fragments.
            menuWidth: _kMenuWidth,
            items: _kCountries
                .map((c) => DropdownMenuItem<String>(
                      value: c.iso2,
                      // One line each, laid out in columns rather than run
                      // together as a sentence: the name takes the room it
                      // needs and elides if it runs out, and the dial codes
                      // line up down the right where they can be compared.
                      child: _CountryRow(country: c, textColor: textColor),
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
