import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/ads/data/models/feed_request_model.dart';
import 'package:jperg_app/features/ads/presentation/widgets/photographer_tile.dart';

/// The rows on Request Details.
///
/// Every tile has a hairline border and the selected one adds a green rule down
/// its left edge. Those two together cannot be one `Border`: Flutter paints a
/// non-uniform border under a `borderRadius` only while a single colour is
/// visible (box_border.dart, `paintNonUniformBorder`), and a grey outline plus
/// a green edge is two. It throws "A borderRadius can only be given on borders
/// with uniform colors" — at paint time, where `dart analyze` and every model
/// test stay green. So the rule is a child inside a `ClipRRect` instead, and
/// these pump the thing to prove it.
Widget host(Widget child) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData.light().copyWith(
          extensions: const [AppThemeExtension.light],
        ),
        home: Scaffold(body: child),
      ),
    );

RequestInterest who({
  String? name = 'Kwame Studios',
  double? rating = 4.7,
  String? location = 'Accra',
  int followers = 1200,
}) =>
    RequestInterest(
      id: 'ph-1',
      name: name,
      location: location,
      followerCount: followers,
      rating: rating,
    );

void main() {
  Future<void> pump(
    WidgetTester tester, {
    bool highlighted = false,
    VoidCallback? onMessage,
    RequestInterest? person,
  }) async {
    await tester.pumpWidget(host(
      Builder(builder: (context) {
        final ext = Theme.of(context).extension<AppThemeExtension>()!;
        return PhotographerTile(
          person: person ?? who(),
          ext: ext,
          onTap: () {},
          highlighted: highlighted,
          onMessage: onMessage,
        );
      }),
    ));
    await tester.pump();
  }

  testWidgets('an ordinary row paints, and ends in a chevron', (tester) async {
    await pump(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Kwame Studios'), findsOneWidget);
    expect(find.text('4.7'), findsOneWidget);
    expect(find.textContaining('Accra'), findsOneWidget);
    expect(find.textContaining('1.2K followers'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
    expect(find.text('Message'), findsNothing);
  });

  testWidgets('the selected row paints its rule without throwing',
      (tester) async {
    await pump(tester, highlighted: true, onMessage: () {});
    expect(tester.takeException(), isNull,
        reason: 'the green rule must not be a BorderSide on the bordered, '
            'rounded decoration — two visible colours under a borderRadius '
            'throws');
    expect(find.text('Message'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
  });

  testWidgets('the message pill is tappable on its own', (tester) async {
    var messaged = 0;
    await pump(tester, highlighted: true, onMessage: () => messaged++);
    await tester.tap(find.text('Message'));
    await tester.pump();
    expect(messaged, 1);
  });

  testWidgets('an unrated photographer shows 0.0 rather than a gap',
      (tester) async {
    await pump(tester, person: who(rating: null));
    expect(tester.takeException(), isNull);
    expect(find.text('0.0'), findsOneWidget);
    expect(find.textContaining('1.2K followers'), findsOneWidget);
  });

  testWidgets('no location leaves no dangling separator', (tester) async {
    await pump(tester, person: who(location: null, followers: 4));
    expect(find.text('4 followers'), findsOneWidget);
  });

  testWidgets('a long name and a message pill still fit', (tester) async {
    await pump(
      tester,
      highlighted: true,
      onMessage: () {},
      person: who(name: 'A Studio With An Extremely Long Trading Name Indeed'),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a nameless photographer falls back rather than crashing',
      (tester) async {
    await pump(tester, person: who(name: null));
    expect(tester.takeException(), isNull);
    expect(find.text('Photographer'), findsOneWidget);
  });
}
