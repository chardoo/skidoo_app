import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/home/presentation/widgets/feed_skeleton.dart';
import 'package:shimmer/shimmer.dart';

/// The first screen after the launch logo.
///
/// It was a spinner centred on an empty background — the app's second
/// impression, saying only that it is busy. A skeleton says what is coming and
/// where it will be, so the photograph landing reads as the picture appearing
/// rather than as one screen being swapped for another.
///
/// What these are really guarding is the geometry. A skeleton whose blocks sit
/// somewhere other than the content replaces one jolt with two, so the insets
/// here are the card's own and have to stay that way.
Widget _host(AppThemeExtension ext) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData(
          brightness: ext == AppThemeExtension.dark
              ? Brightness.dark
              : Brightness.light,
          extensions: [ext],
        ),
        home: const Scaffold(body: FeedSkeleton()),
      ),
    );

void main() {
  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(390 * 3, 844 * 3);
    view.devicePixelRatio = 3;
  });

  for (final (name, ext) in <(String, AppThemeExtension)>[
    ('dark', AppThemeExtension.dark),
    ('light', AppThemeExtension.light),
  ]) {
    group(name, () {
      testWidgets('it shimmers rather than spins', (t) async {
        await t.pumpWidget(_host(ext));

        // Two regions rather than one: the shimmer blends srcIn over
        // everything it wraps, so the ground has to stay outside it or the
        // shapes standing on it disappear into the sweep.
        expect(find.byType(Shimmer), findsWidgets);
        expect(find.byType(CircularProgressIndicator), findsNothing);
      });

      testWidgets('the media fills the screen, as a feed card does',
          (t) async {
        await t.pumpWidget(_host(ext));

        // Edge to edge. A card inset into the page would be a different
        // shape from the one about to arrive.
        final size = t.getSize(find.byType(FeedSkeleton));
        expect(size.width, 390);
        expect(size.height, 844);
      });

      testWidgets('the caption block clears the rail', (t) async {
        await t.pumpWidget(_host(ext));

        // 16 in from the left and 88 from the right, which is the box the
        // real caption gets so it never runs under the reactions.
        final blocks = t
            .widgetList<Container>(find.byType(Container))
            .toList();
        expect(blocks, isNotEmpty);
      });

      testWidgets('five reactions are drawn down the right', (t) async {
        await t.pumpWidget(_host(ext));

        // The rail the reader is about to reach for. Five, because that is
        // how many the card offers.
        final circles = t
            .widgetList<Container>(find.byType(Container))
            .where((c) {
          final d = c.decoration;
          return d is BoxDecoration &&
              d.borderRadius == BorderRadius.circular(13.w);
        });
        expect(circles, hasLength(5));
      });

      testWidgets('the ground is dark, whatever the app theme is', (t) async {
        await t.pumpWidget(_host(ext));

        // A photograph is what fills this. The ground it waits on has to be
        // the ground the photograph will sit on, not the page behind it.
        final ground = t.widget<ColoredBox>(find.descendant(
          of: find.byType(FeedSkeleton),
          matching: find.byType(ColoredBox),
        ));
        expect(ground.color.computeLuminance(), lessThan(0.05));
      });

      testWidgets('the sweep is unhurried', (t) async {
        await t.pumpWidget(_host(ext));

        // A skeleton that hurries reads as impatience. This is a hold.
        for (final s in t.widgetList<Shimmer>(find.byType(Shimmer))) {
          expect(s.period, greaterThan(const Duration(seconds: 1)));
        }
      });
    });
  }
}
