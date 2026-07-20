import 'package:flutter/services.dart';

/// Lets a single OTP box accept a full pasted code. `TextField.maxLength`
/// would otherwise silently truncate a paste to 1 character before it's
/// even visible to `onChanged`, so this formatter runs first: on a
/// multi-digit paste it hands the whole string to [onPaste] (which fills
/// the other boxes) and keeps only this box's own digit (by [index]) for
/// itself, so the box that received the paste still ends up correct.
class PasteAwareDigitFormatter extends TextInputFormatter {
  PasteAwareDigitFormatter({required this.index, required this.onPaste});

  final int index;
  final void Function(String digits, int pastedAtIndex) onPaste;

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digitsOnly = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.length > 1) {
      onPaste(digitsOnly, index);
      final own = index < digitsOnly.length ? digitsOnly[index] : '';
      return TextEditingValue(
        text: own,
        selection: TextSelection.collapsed(offset: own.length),
      );
    }
    return TextEditingValue(
      text: digitsOnly,
      selection: TextSelection.collapsed(offset: digitsOnly.length),
    );
  }
}
