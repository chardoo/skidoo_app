import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// The feed card's caption scrim has to stop short of the bottom edge.
///
/// The floating nav bar sits in that last strip and frosts whatever is behind
/// it. The scrim used to run to 67 % black straight underneath, so the bar was
/// faithfully blurring a near-black gradient and reading as an opaque slab —
/// three rounds of lowering the tint and the blur radius could not fix it,
/// because there was genuinely nothing back there to see.
///
/// Asserted against the source rather than a pumped widget: the card needs the
/// discovery bloc, a photo carousel and a video player to build, none of which
/// this is about. What matters is the one geometric fact — the gradient does
/// not reach `bottom: 0`.
void main() {
  const path =
      'lib/features/discovery/presentation/widgets/full_bleed_event_card.dart';

  test('the caption scrim leaves the nav bar a strip of real photo', () async {
    final source = await File(path).readAsString();

    // The Positioned holding the gradient must be offset from the bottom.
    expect(
      source,
      contains('bottom: _navBand'),
      reason: 'the scrim is pinned to the bottom edge again — the nav bar has '
          'nothing but black to frost',
    );
    expect(
      RegExp(r'_navBand\s*=\s*(\d+)').firstMatch(source),
      isNotNull,
      reason: 'the band the nav occupies has to be a named number',
    );
  });

  test('the band is at least as tall as the bar that sits in it', () {
    final source = File(path).readAsStringSync();
    final band =
        int.parse(RegExp(r'_navBand\s*=\s*(\d+)').firstMatch(source)!.group(1)!);

    // The pill is 58 high and floats on a margin above the home indicator.
    // Anything less and the darkest end of the gradient creeps back under it.
    expect(band, greaterThanOrEqualTo(58));
  });
}
