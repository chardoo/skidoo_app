import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/components/common/navbar.dart';

/// The strip along the bottom that belongs to the floating nav bar.
///
/// Two things have to be true of it, and they pull in opposite directions:
///
///   * the caption scrim stops short of it, or the bar is frosting a near-black
///     gradient and reads as an opaque slab — three rounds of lowering the tint
///     and the blur radius could not fix that, because there was genuinely
///     nothing back there to see;
///   * the caption itself clears it by as little as possible, because the
///     description and the hashtags are the post and the bar is a visitor.
///
/// The band used to be a literal 96 copied into three files, and this test
/// read that number out of the source. It is [AppNavbar.bandHeight] now — the
/// bar's own figure — so these assert the value instead, which is both the
/// real property and one that survives the next time the bar moves.
void main() {
  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(390 * 3, 844 * 3);
    view.devicePixelRatio = 3;
  });

  Future<double> bandWith(WidgetTester t, double inset) async {
    late double band;
    await t.pumpWidget(ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(390, 844),
            viewPadding: EdgeInsets.only(bottom: inset),
            padding: EdgeInsets.only(bottom: inset),
          ),
          child: Builder(builder: (context) {
            band = AppNavbar.bandHeight(context);
            return const SizedBox();
          }),
        ),
      ),
    ));
    await t.pump();
    return band;
  }

  testWidgets('the band is at least as tall as the bar that sits in it',
      (t) async {
    // The pill is 58 high. Anything less and the darkest end of the caption
    // gradient creeps back under it.
    for (final inset in [0.0, 34.0, 48.0]) {
      expect(await bandWith(t, inset), greaterThanOrEqualTo(58),
          reason: 'the band is shorter than the pill at inset $inset');
    }
  });

  testWidgets('a taller system inset makes a taller band', (t) async {
    // Android's button bar pushes the whole arrangement up, caption included.
    expect(await bandWith(t, 48), greaterThan(await bandWith(t, 34)));
  });

  test('the caption scrim still leaves the bar a strip of real photo', () {
    // Asserted against the source: the card needs the discovery bloc, a photo
    // carousel and a video player to build, none of which this is about. What
    // matters is the one geometric fact — the gradient does not reach
    // `bottom: 0` when there is a bar below it.
    final source = File(
      'lib/features/discovery/presentation/widgets/full_bleed_event_card.dart',
    ).readAsStringSync();

    expect(
      source,
      contains('bottom: _navBarUp ? AppNavbar.bandHeight(context) : 0'),
      reason: 'the scrim is pinned to the bottom edge again — the nav bar has '
          'nothing but black to frost',
    );
  });

  test('the caption clears the bar, and only just', () {
    // The gap that started this was ~40: the last hashtag sat a visible band
    // above the pill and read as a margin somebody chose. Ten was too little —
    // frosted glass has a soft edge and descenders hang into it. Twenty is the
    // answer, and the two feed cards have to agree or the caption jumps height
    // as somebody scrolls between an event and an ad.
    final event = File(
      'lib/features/discovery/presentation/widgets/full_bleed_event_card.dart',
    ).readAsStringSync();
    final ad = File(
      'lib/features/ads/presentation/widgets/feed_item_card.dart',
    ).readAsStringSync();

    final pattern = RegExp(r'_kCaptionOverBar\s*=\s*(\d+)');
    final onEvent = int.parse(pattern.firstMatch(event)!.group(1)!);
    final onAd = int.parse(pattern.firstMatch(ad)!.group(1)!);

    expect(onEvent, onAd, reason: 'the two feed cards disagree about the gap');
    expect(onEvent, greaterThanOrEqualTo(16),
        reason: 'the bar reads as sitting on the text');
    expect(onEvent, lessThanOrEqualTo(28),
        reason: 'the gap is reading as a margin again');
  });
}
