/// What fills an image slot before the photo lands.
///
/// A flat grey tile reads as "loading"; the photo's own colours read as "the
/// photograph is arriving". The hash is ~28 characters that come down with the
/// feed payload and decode on the device with no network at all, which is what
/// makes a fast scroll never show a hole.
import 'package:flutter/material.dart';
import 'package:flutter_blurhash/flutter_blurhash.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/widgets/jperg_image.dart';

/// A real hash, as `blurhash.encode` produces them server-side.
const _hash = 'L2F~gb%g2GyD:^jta|jadhf6fSf6';

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
      MaterialApp(home: Scaffold(body: SizedBox(width: 200, height: 200, child: child))),
    );

void main() {
  testWidgets('a hash paints the photo\'s colours', (tester) async {
    await _pump(tester, const JpergImagePlaceholder(blurhash: _hash));

    expect(find.byType(BlurHash), findsOneWidget);
  });

  testWidgets('and drops the spinner, which would read as a fault', (tester) async {
    // A progress ring over a recognisable image looks like something is wrong
    // rather than like something is on its way.
    await _pump(
      tester,
      const JpergImagePlaceholder(spinner: true, blurhash: _hash),
    );

    expect(find.byType(BlurHash), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('no hash keeps the flat neutral every slot had before',
      (tester) async {
    await _pump(tester, const JpergImagePlaceholder(spinner: true));

    expect(find.byType(BlurHash), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('an empty hash is treated as none, not as a hash', (tester) async {
    // The server stores NULL, but a payload round-tripped through a cache can
    // arrive as "" — decoding that throws inside the package.
    await _pump(tester, const JpergImagePlaceholder(blurhash: ''));

    expect(find.byType(BlurHash), findsNothing);
  });

  testWidgets('JpergImage hands its hash to the default placeholder',
      (tester) async {
    // The point of the whole wiring: a card that passes `blurhash` gets the
    // blurred stand-in without having to build a placeholder of its own.
    await _pump(
      tester,
      const JpergImage(
        imageUrl: 'https://cdn.example.com/newImages/abc.jpg',
        blurhash: _hash,
      ),
    );
    await tester.pump();

    expect(find.byType(BlurHash), findsOneWidget);
  });
}
