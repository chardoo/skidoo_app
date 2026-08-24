import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/widgets/image_aspect.dart';

/// The server's `width`/`height` is a starting point, not the last word.
///
/// It has been wrong: dimensions recorded for an R2 upload ignored the EXIF
/// orientation tag, so every rotated phone photo was stored transposed. This
/// widget used to return early whenever a value was present, which made a bad
/// row permanent — a portrait photo in a landscape box, at roughly half size.
const _url = 'https://cdn.example.com/events/abc123.jpg';

/// 3024x4032 — the photo from the bug report, as a viewer sees it.
const _portrait = 3024 / 4032;

/// What the transposed row claimed instead.
const _landscape = 4032 / 3024;

/// Pumps a fresh [ResolvedAspect] and returns the ratio it hands its builder.
///
/// [key] matters when a test pumps twice: without a new one the element is
/// reused, so initState never runs again and the previous measurement carries
/// over into what is supposed to be a clean second reading.
Future<double> aspectHandedToBuilder(
  WidgetTester t, {
  required double? knownAspect,
  Key? key,
}) async {
  late double seen;
  await t.pumpWidget(MaterialApp(
    home: ResolvedAspect(
      key: key ?? UniqueKey(),
      imageUrl: _url,
      knownAspect: knownAspect,
      builder: (_, aspect) {
        seen = aspect;
        return const SizedBox();
      },
    ),
  ));
  await t.pump();
  return seen;
}

void main() {
  setUp(ImageAspectCache.clear);
  tearDown(ImageAspectCache.clear);

  testWidgets('a stored shape that matches the photo is kept', (t) async {
    ImageAspectCache.seed(_url, _portrait);
    final aspect = await aspectHandedToBuilder(t, knownAspect: _portrait);
    expect(aspect, closeTo(_portrait, 0.001));
  });

  testWidgets('a transposed stored shape loses to the photo itself', (t) async {
    // The bug, exactly: the row says landscape, the file is portrait.
    ImageAspectCache.seed(_url, _portrait);
    final aspect = await aspectHandedToBuilder(t, knownAspect: _landscape);

    expect(aspect, closeTo(_portrait, 0.001),
        reason: 'the measured shape must win over a transposed row');
    expect(aspect, lessThan(1), reason: 'a portrait photo needs a tall box');
  });

  testWidgets('small disagreements are ignored so the box does not twitch',
      (t) async {
    // Rounding, or a server that rounds differently. Not worth a relayout.
    ImageAspectCache.seed(_url, 1.500);
    final aspect = await aspectHandedToBuilder(t, knownAspect: 1.52);
    expect(aspect, 1.52, reason: 'within tolerance, the stored value stands');
  });

  testWidgets('the stored shape still draws the first frame', (t) async {
    // Nothing measured yet — this is the whole reason knownAspect exists, so
    // the box is right before any bytes arrive and never jumps.
    final aspect = await aspectHandedToBuilder(t, knownAspect: _landscape);
    expect(aspect, closeTo(_landscape, 0.001));
  });

  testWidgets('a row with no dimensions falls back to the measurement',
      (t) async {
    ImageAspectCache.seed(_url, _portrait);
    final aspect = await aspectHandedToBuilder(t, knownAspect: null);
    expect(aspect, closeTo(_portrait, 0.001));
  });

  testWidgets('with neither a row nor a measurement, the fallback is used',
      (t) async {
    late double seen;
    await t.pumpWidget(MaterialApp(
      home: ResolvedAspect(
        imageUrl: _url,
        knownAspect: null,
        fallback: 4 / 3,
        builder: (_, aspect) {
          seen = aspect;
          return const SizedBox();
        },
      ),
    ));
    await t.pump();
    expect(seen, closeTo(4 / 3, 0.001));
  });

  testWidgets('a nonsense stored value never reaches the builder', (t) async {
    ImageAspectCache.seed(_url, _portrait);
    final aspect = await aspectHandedToBuilder(t, knownAspect: 0);
    expect(aspect, closeTo(_portrait, 0.001));
  });

  testWidgets('the correction restores the height the photo had lost',
      (t) async {
    // What the reader actually saw. In a 390-wide slot the box height follows
    // width / aspect, so a transposed row gave the photo a box 1.78× too short
    // and `contain` shrank the image to fit it.
    const slotWidth = 390.0;

    ImageAspectCache.seed(_url, _portrait);
    final corrected = await aspectHandedToBuilder(t, knownAspect: _landscape);
    final correctedHeight = slotWidth / corrected;

    // Nothing measured — the uncorrected path, which is what shipped.
    ImageAspectCache.clear();
    final uncorrected = await aspectHandedToBuilder(t, knownAspect: _landscape);
    final uncorrectedHeight = slotWidth / uncorrected;

    expect(correctedHeight / uncorrectedHeight, closeTo(16 / 9, 0.02),
        reason: 'a 4:3 row on a 3:4 photo is off by (4/3)² ≈ 1.78×');
    expect(correctedHeight, greaterThan(uncorrectedHeight));
  });
}
