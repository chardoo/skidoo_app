/// Every country in the dial-code menu gets one line.
///
/// A `DropdownButton`'s menu takes the width of the button that opens it, and
/// this button is deliberately tiny — it shows a flag and a dial code and
/// nothing else. So the menu inherited that width and folded every name: the
/// flag alone on one row, "Cameroon" under it, "(+237)" under that. Thirteen
/// countries in, the list read as a column of fragments.
///
/// The fix is a `menuWidth` wide enough for the longest name, so the guard
/// that matters is the one the fix can silently outgrow: somebody adds a
/// country whose name is longer than the width allows for. It elides rather
/// than wrapping now, which keeps the rows even — but a country name cut
/// short is still a loss, and this is what notices.
///
/// Measured in design units. `_kMenuWidth` is `300.w` and the row's text is
/// `.sp`, and ScreenUtil scales both from the same design width — so the
/// question "does this name fit" has the same answer at 300 against 14pt as
/// it does on any real screen, without a widget tree to ask it in.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/common/widgets/app_phone_field.dart';

/// `_kMenuWidth`, unscaled.
const double menuWidth = 320;

/// What the row spends before the name gets any: the flag, the two gaps
/// either side of the name, and the widest dial code. Mirrors `_CountryRow`.
// Measured, not guessed: a flag emoji at 16pt is 32 wide and '+971' at
// 12pt is 48. Estimating these is how the first pass picked a width that
// was 84pt short of the longest name.
const double flag = 32, gapBeforeName = 12, gapAfterName = 8, dial = 48;
const double available = menuWidth - flag - gapBeforeName - gapAfterName - dial;

double widthOf(String name) {
  final painter = TextPainter(
    // The size `_CountryRow` draws a name at, in design units.
    text: TextSpan(text: name, style: const TextStyle(fontSize: 14)),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout();
  return painter.width;
}

void main() {
  test('every country name fits the menu on one line', () {
    final tooWide = [
      for (final name in countryNamesForTest)
        if (widthOf(name) > available) name,
    ];

    expect(
      tooWide,
      isEmpty,
      reason: 'these would be cut short in the dial-code menu: $tooWide — '
          'widen _kMenuWidth to match',
    );
  });

  test('the longest name is the one the width was chosen for', () {
    // If this changes, the width above was picked against a different list.
    final longest = countryNamesForTest
        .reduce((a, b) => widthOf(a) >= widthOf(b) ? a : b);
    expect(longest, 'United Kingdom');
  });

  test('the list has not quietly become long enough to need a search box', () {
    // A dropdown is the right shape for a short, curated list. Past roughly
    // fifty it is a scroll with no way to jump, and this should become the
    // filtered country step the location picker already has.
    expect(
      countryNamesForTest.length,
      lessThanOrEqualTo(50),
      reason: 'a menu this long wants a filter, not more scrolling',
    );
  });
}
