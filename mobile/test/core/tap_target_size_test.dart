import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/components/media/media_rail_action.dart';
import 'package:jperg_app/core/common/widgets/app_button.dart';
import 'package:jperg_app/core/common/widgets/app_filter_chips.dart';
import 'package:jperg_app/core/common/widgets/profile_pill_button.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/utils/responsive.dart';

/// Controls are at least [kMinTapTarget] on the smallest phone the app runs on.
///
/// These are geometric on purpose, and they are pinned at **iPhone SE size**,
/// because that is the case that was wrong and the one no one was looking at.
/// Every size in this app is scaled off a 390×844 design by screenutil, so a
/// control written as `46.h` is 46pt only on a phone that is exactly 844 tall.
/// An SE is 667 — a factor of 0.79 — and the app's buttons came out at 36pt
/// there, its "Follow" chips at 25pt. App Review rejected the build for
/// "controls that are difficult to use due to size" in November 2026.
///
/// Testing this on a 390-wide view would pass on the broken code, which is the
/// whole reason the defect survived: on the design device the numbers are
/// right. If one of these fails, the fix is [TapTargetSize.tapH] / [tapW], not
/// a larger literal — a literal large enough to survive the SE is oversized on
/// every other phone.
const Size _iPhoneSE = Size(375, 667);

Widget host(Widget child) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData(extensions: const [AppThemeExtension.light]),
        home: Scaffold(body: Center(child: child)),
      ),
    );

/// The rendered height of the first [T], in logical pixels.
double heightOf<T extends Widget>(WidgetTester tester) =>
    tester.getSize(find.byType(T).first).height;

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = _iPhoneSE;
    view.devicePixelRatio = 1.0;
  });

  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  testWidgets('AppButton clears the minimum at its default height',
      (tester) async {
    await tester.pumpWidget(host(AppButton(label: 'Continue', onPressed: () {})));

    expect(heightOf<ElevatedButton>(tester),
        greaterThanOrEqualTo(kMinTapTarget));
  });

  testWidgets('AppButton clears the minimum even when asked for a short one',
      (tester) async {
    // 40.h is 31.6pt on this view. A caller asking for a compact button is
    // asking about the drawing, not about how big a thumb is.
    await tester.pumpWidget(host(
      AppButton(label: 'Save', height: 40.h, onPressed: () {}),
    ));

    expect(heightOf<ElevatedButton>(tester),
        greaterThanOrEqualTo(kMinTapTarget));
  });

  testWidgets('ProfilePillButton clears the minimum', (tester) async {
    await tester.pumpWidget(host(
      Builder(
        builder: (context) => ProfilePillButton(
          ext: Theme.of(context).extension<AppThemeExtension>()!,
          icon: Icons.share_outlined,
          label: 'Share',
          onTap: () {},
        ),
      ),
    ));

    expect(heightOf<ProfilePillButton>(tester),
        greaterThanOrEqualTo(kMinTapTarget));
  });

  for (final style in AppFilterRowStyle.values) {
    testWidgets('AppFilterChip (${style.name}) is tappable across 44pt',
        (tester) async {
      await tester.pumpWidget(host(
        AppFilterRow(
          labels: const ['All', 'Unread'],
          selected: 0,
          style: style,
          onSelect: (_) {},
        ),
      ));

      // The target is the chip's whole box, which fills the row...
      expect(heightOf<AppFilterChip>(tester),
          greaterThanOrEqualTo(kMinTapTarget));

      // ...while the pill inside it keeps the height it was drawn at, so a
      // secondary row still reads as lighter than the primary one above it.
      final pill = tester.getSize(
        find.descendant(
          of: find.byType(AppFilterChip).first,
          matching: find.byType(AnimatedContainer),
        ),
      );
      expect(pill.height, closeTo(AppFilterChip.heightFor(style).h, 0.01));
      expect(pill.height, lessThanOrEqualTo(heightOf<AppFilterChip>(tester)));
    });
  }

  testWidgets('a secondary chip is still drawn smaller than a primary one',
      (tester) async {
    // Guards the fix against being "simplified" into making every chip 44pt,
    // which would lose the distinction the two styles exist for.
    expect(AppFilterChip.heightFor(AppFilterRowStyle.secondary),
        lessThan(AppFilterChip.heightFor(AppFilterRowStyle.primary)));
  });

  testWidgets('MediaRailAction floors a small tapTargetSize', (tester) async {
    // What the owned-album download asked for: 32.r, which is 25pt here.
    await tester.pumpWidget(host(
      MediaRailAction(
        icon: Icons.download_outlined,
        semanticLabel: 'Download photo',
        iconSize: 16.sp,
        tapTargetSize: 32.r,
        onTap: () {},
      ),
    ));

    final box = tester.getSize(
      find.descendant(
        of: find.byType(MediaRailAction),
        matching: find.byType(SizedBox),
      ).first,
    );
    expect(box.width, greaterThanOrEqualTo(kMinTapTarget));
    expect(box.height, greaterThanOrEqualTo(kMinTapTarget));
  });

  test('tapH and tapW only ever lift, never shrink', () {
    // A phone taller and wider than the design: the floor must not claw back
    // the extra room a large screen is entitled to.
    ScreenUtil.configure(
      data: MediaQueryData(size: const Size(430, 932)),
      designSize: const Size(390, 844),
    );

    expect(60.tapH, closeTo(60.h, 0.01));
    expect(60.tapW, closeTo(60.w, 0.01));
    expect(30.tapH, kMinTapTarget);
  });
}
