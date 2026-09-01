import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/components/media/media_action_buttons.dart';
import 'package:jperg_app/components/media/media_rail_action.dart';
import 'package:jperg_app/components/media/media_reaction_rail.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';

/// Every reaction in the app is a bare icon over the media. [MediaActionButtons]
/// was the odd one out — each action sat on a filled dark disc with a green
/// border and two shadows, while the viewer rail, the feed card and the web
/// column all drew the icon straight onto the photo.
Widget host(Widget child) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData.dark()
            .copyWith(extensions: const [AppThemeExtension.dark]),
        home: Scaffold(body: Center(child: child)),
      ),
    );

/// Every painted box inside [of] — the buttons' own chrome, if any is left.
Iterable<BoxDecoration> decorationsIn(WidgetTester t, Finder of) => t
    .widgetList<DecoratedBox>(
        find.descendant(of: of, matching: find.byType(DecoratedBox)))
    .map((d) => d.decoration)
    .whereType<BoxDecoration>();

void main() {
  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(390 * 3, 844 * 3);
    view.devicePixelRatio = 3;
  });

  tearDown(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  for (final axis in Axis.values) {
    testWidgets('MediaActionButtons draws no chrome behind an action — $axis',
        (t) async {
      await t.pumpWidget(host(MediaActionButtons(
        imageId: 'p1',
        imageUrl: 'https://cdn.example.com/p1.jpg',
        axis: axis,
        onSend: () {},
      )));

      for (final d in decorationsIn(t, find.byType(MediaActionButtons))) {
        expect(d.gradient, isNull, reason: 'the disc had a radial gradient');
        expect(d.color?.a ?? 0, 0, reason: 'no fill behind the icon');
        expect(d.border, isNull, reason: 'the disc had an accent ring');
        expect(d.boxShadow ?? const [], isEmpty,
            reason: 'the disc had a drop shadow and an accent glow');
      }
    });
  }

  testWidgets('the icon keeps a shadow, which is what the disc was for',
      (t) async {
    // Without the disc behind it a white glyph disappears into a bright photo.
    await t.pumpWidget(host(MediaActionButtons(
      imageId: 'p1',
      imageUrl: 'https://cdn.example.com/p1.jpg',
      onSend: () {},
    )));

    final icons = t.widgetList<Icon>(find.descendant(
      of: find.byType(MediaActionButtons),
      matching: find.byType(Icon),
    ));

    expect(icons, isNotEmpty);
    for (final icon in icons) {
      expect(icon.shadows ?? const [], isNotEmpty);
    }
  });

  testWidgets('the viewer rail was already bare, and stays that way',
      (t) async {
    await t.pumpWidget(host(MediaRailAction(
      icon: Icons.favorite_rounded,
      label: '206',
      onTap: () {},
    )));

    expect(decorationsIn(t, find.byType(MediaRailAction)), isEmpty);
  });

  // One state per test: pumping a second config into the same tree reuses the
  // element, and `initiallyLiked` is only read in initState — so the new value
  // would never take and the test would pass for the wrong reason.
  testWidgets('a resting reaction is an outline', (t) async {
    // The reference is an unfilled heart over the video.
    await t.pumpWidget(host(MediaActionButtons(
      imageId: 'p1',
      imageUrl: 'https://cdn.example.com/p1.jpg',
      showDownload: false,
      showComment: false,
    )));

    expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
    expect(find.byIcon(Icons.favorite_rounded), findsNothing);
  });

  testWidgets('an active one is filled', (t) async {
    // The fill is what "you liked this" looks like, so it must not collapse
    // into the outline — colour alone is a weak signal at this size, and no
    // signal at all to anyone who can't separate red from white.
    await t.pumpWidget(host(MediaActionButtons(
      imageId: 'p1',
      imageUrl: 'https://cdn.example.com/p1.jpg',
      initiallyLiked: true,
      showDownload: false,
      showComment: false,
    )));

    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border_rounded), findsNothing);
  });

  test('no reaction rail is left drawing a filled glyph at rest', () {
    // The feed card builds its own rail inline rather than going through
    // CardInteractionBar, so an audit of the shared widgets missed it entirely
    // and the one screen the change was asked for kept its solid icons. This
    // reads the sources instead of trusting that list.
    //
    // MediaReactionRail is on the list because the feed card and the Found
    // viewer now delegate their glyphs to it — leave it off and this guard
    // passes by checking two files that no longer name an icon at all.
    final rails = [
      'lib/components/media/media_reaction_rail.dart',
      'lib/features/gallery/presentation/found/widgets/found_action_rail.dart',
      'lib/features/discovery/presentation/widgets/full_bleed_event_card.dart',
      'lib/features/discovery/presentation/widgets/event_card/web_reactions_column.dart',
      'lib/features/discovery/presentation/widgets/card_interaction_bar.dart',
      'lib/components/media/media_action_buttons.dart',
    ];
    final filled = RegExp(
        r'Icons\.(favorite|thumb_down|thumb_up|mode_comment|bookmark|near_me)_rounded');

    for (final path in rails) {
      final source = File(path).readAsStringSync();
      for (final match in filled.allMatches(source)) {
        // A filled glyph is only legitimate as the *active* half of a
        // conditional — `liked ? filled : outline` — or declared as a
        // MediaReaction's `activeIcon`, which is that same conditional lifted
        // into the shared rail.
        final line = source.substring(0, match.start).split('\n').length;
        final context = source
            .split('\n')
            .sublist((line - 3).clamp(0, source.length), line)
            .join('\n');
        expect(context, anyOf(contains('?'), contains('activeIcon:')),
            reason: '$path:$line — ${match.group(0)} with no active-state '
                'condition around it, so it shows filled at rest');
      }
    }
  });

  // ── The shared rail ────────────────────────────────────────────────────────

  testWidgets('a rail draws each reaction hollow until it is active',
      (t) async {
    await t.pumpWidget(host(MediaReactionRail(actions: [
      MediaReaction.like(liked: false, count: 206, onTap: () {}),
      MediaReaction.bookmark(saved: false, onTap: () {}),
    ])));

    expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
    expect(find.byIcon(Icons.bookmark_border_rounded), findsOneWidget);
    expect(find.byIcon(Icons.favorite_rounded), findsNothing);
    expect(find.byIcon(Icons.bookmark_rounded), findsNothing);
  });

  testWidgets('an active reaction fills, and takes its own tint', (t) async {
    // The tint travels with the reaction rather than with the screen: the feed
    // card used to paint a saved bookmark amber while every other surface used
    // the gold token, purely because it passed its own colour in.
    await t.pumpWidget(host(MediaReactionRail(actions: [
      MediaReaction.like(liked: true, count: 206, onTap: () {}),
      MediaReaction.bookmark(saved: true, onTap: () {}),
    ])));

    const ext = AppThemeExtension.dark;
    expect(
        t.widget<Icon>(find.byIcon(Icons.favorite_rounded)).color, ext.likeRed);
    expect(t.widget<Icon>(find.byIcon(Icons.bookmark_rounded)).color,
        ext.accentGold);
  });

  group('the glyphs are sized and shadowed to read as native', () {
    // Two things made them look soft and heavy over a photo: a 28 sp glyph,
    // and a 4 px shadow with no offset — a blurred copy of the icon in every
    // direction, which thickens the stroke into something faintly out of
    // focus.
    testWidgets('a glyph lands on whole pixels', (t) async {
      // `.sp` is fractional on most devices (24 → 26.46 on a 430 pt phone) and
      // an icon font rasterised between the pixel grid comes out smeared.
      await t.pumpWidget(host(MediaReactionRail(actions: [
        MediaReaction.like(liked: false, count: 206, onTap: () {}),
      ])));

      final size = t.widget<Icon>(find.byType(Icon)).size!;
      expect(size, size.roundToDouble());
    });

    testWidgets('and is smaller than it was', (t) async {
      // The rail sits over somebody's photograph. At 28 the five glyphs were
      // the loudest thing on the screen.
      await t.pumpWidget(host(MediaReactionRail(actions: [
        MediaReaction.like(liked: false, count: 206, onTap: () {}),
      ])));

      expect(t.widget<Icon>(find.byType(Icon)).size, lessThan(28));
    });

    testWidgets('the shadow falls somewhere rather than everywhere', (t) async {
      await t.pumpWidget(host(MediaReactionRail(actions: [
        MediaReaction.like(liked: false, count: 206, onTap: () {}),
      ])));

      final shadow = t.widget<Icon>(find.byType(Icon)).shadows!.single;
      expect(shadow.offset, isNot(Offset.zero),
          reason: 'a centred shadow haloes the glyph instead of lifting it');
      expect(shadow.blurRadius, lessThanOrEqualTo(2),
          reason: 'wider than this and the stroke thickens');
    });

    testWidgets('the count is shadowed the same way as its glyph', (t) async {
      // A sharp number under a soft icon reads as two separate things.
      await t.pumpWidget(host(MediaReactionRail(actions: [
        MediaReaction.like(liked: false, count: 206, onTap: () {}),
      ])));

      final icon = t.widget<Icon>(find.byType(Icon)).shadows!.single;
      final count = t.widget<Text>(find.text('206')).style!.shadows!.single;
      expect(count.offset, icon.offset);
      expect(count.blurRadius, icon.blurRadius);
    });
  });

  testWidgets('a reaction with no count renders the glyph alone', (t) async {
    // Not a hardcoded "0" under an action that has no count behind it.
    await t.pumpWidget(host(MediaReactionRail(actions: [
      MediaReaction.share(onTap: () {}),
    ])));

    expect(find.byType(Text), findsNothing);
  });

  testWidgets('the two rails offer the same reactions from the same source',
      (t) async {
    // The Found viewer and the feed card each used to spell out their own
    // list, so a glyph changed on one silently skipped the other.
    final sources = [
      'lib/features/gallery/presentation/found/widgets/found_action_rail.dart',
      'lib/features/discovery/presentation/widgets/full_bleed_event_card.dart',
    ].map(File.new).map((f) => f.readAsStringSync());

    for (final source in sources) {
      expect(source, contains('MediaReactionRail('),
          reason: 'this rail went back to assembling its own actions');
      expect(RegExp(r'Icons\.\w+').allMatches(source).map((m) => m.group(0)),
          isNot(contains('Icons.favorite_border_rounded')),
          reason: 'the reaction glyphs belong to MediaReactionRail');
    }
  });
}
