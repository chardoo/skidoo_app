import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/common/widgets/verified_badge.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/discovery/presentation/widgets/event_card/post_header.dart';
import 'package:jperg_app/models/event_discovery/event_discovery.dart';

/// A verified creator is verified on the feed too.
///
/// The badge existed on search rows and on both profile screens, but the feed
/// card — the surface where a creator's name is seen most — drew the name
/// alone. So the one place a reader meets a photographer before deciding
/// whether to open them was the one place the claim was missing.
///
/// `PostHeader` is the header for both the classic feed card and the Following
/// tab (`EventDiscoveryCard` → `PostHeader`), so covering it covers both.
///
/// The flag has to survive the trip as well as be drawn: nothing in the app
/// knew about `verified` on the feed payload, so [EventDiscovery.fromMap] is
/// tested here next to the widget that renders what it parsed.
Widget host(Widget child) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData.dark()
            .copyWith(extensions: const [AppThemeExtension.dark]),
        home: Scaffold(body: child),
      ),
    );

EventDiscovery event({bool verified = false}) => EventDiscovery(
      id: 'evt-1',
      eventName: 'Praise Reloaded 2026',
      photographerName: 'Kofi Mensah',
      photographerId: 'p1',
      photographerVerified: verified,
      pictures: const [],
    );

Widget header(EventDiscovery e, {bool onImage = false}) => PostHeader(
      event: e,
      ext: AppThemeExtension.dark,
      isAuthenticated: true,
      onImage: onImage,
    );

void main() {
  testWidgets('a verified creator gets the tick beside their name', (t) async {
    await t.pumpWidget(host(header(event(verified: true))));
    await t.pump();

    expect(find.byType(VerifiedBadge), findsOneWidget);
    expect(find.byIcon(Icons.verified_rounded), findsOneWidget);
  });

  testWidgets('an unverified creator gets nothing', (t) async {
    await t.pumpWidget(host(header(event())));
    await t.pump();

    expect(find.byIcon(Icons.verified_rounded), findsNothing);
  });

  testWidgets('it is the brand green, not blue', (t) async {
    await t.pumpWidget(host(header(event(verified: true))));
    await t.pump();

    final icon = t.widget<Icon>(find.byIcon(Icons.verified_rounded));
    expect(icon.color, AppThemeExtension.dark.accentGold);
    expect(icon.color, isNot(AppThemeExtension.dark.infoBlue));
  });

  testWidgets('over a photo it keeps the green and gains a shadow', (t) async {
    // The header is drawn over media on the full-bleed card, where the name
    // beside it carries shadows for the same reason: the green has to hold
    // against whatever the photo happens to be.
    await t.pumpWidget(host(header(event(verified: true), onImage: true)));
    await t.pump();

    final icon = t.widget<Icon>(find.byIcon(Icons.verified_rounded));
    expect(icon.color, AppThemeExtension.dark.accentGold);
    expect(icon.shadows, isNotNull);
    expect(icon.shadows!, isNotEmpty);
  });

  group('the flag survives the payload', () {
    test('the feed sends `verified` on the nested user object', () {
      final parsed = EventDiscovery.fromMap({
        'id': 'evt-1',
        'eventName': 'Praise Reloaded 2026',
        'user': {'id': 'p1', 'name': 'Kofi', 'verified': true},
        'pictures': <dynamic>[],
      });

      expect(parsed.photographerVerified, isTrue);
    });

    test('a profile payload spells it `verified_by_admin`', () {
      // Same account, same badge, different key — the column's own name is
      // what the profile endpoints answer with, so a card built from one of
      // those must not lose its tick.
      final parsed = EventDiscovery.fromMap({
        'id': 'evt-1',
        'eventName': 'Praise Reloaded 2026',
        'user': {'id': 'p1', 'name': 'Kofi', 'verified_by_admin': true},
        'pictures': <dynamic>[],
      });

      expect(parsed.photographerVerified, isTrue);
    });

    test('an unverified creator parses as false, not null', () {
      final parsed = EventDiscovery.fromMap({
        'id': 'evt-1',
        'eventName': 'Praise Reloaded 2026',
        'user': {'id': 'p1', 'name': 'Kofi'},
        'pictures': <dynamic>[],
      });

      expect(parsed.photographerVerified, isFalse);
    });

    test('it round-trips through toMap', () {
      // The feed snapshot is cached as JSON and read back, so a flag that
      // serialises away is a badge that disappears on the second launch.
      final restored = EventDiscovery.fromMap(
        event(verified: true).toMap(),
      );

      expect(restored.photographerVerified, isTrue);
    });
  });
}
