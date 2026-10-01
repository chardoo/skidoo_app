/// The empty For You feed, which crashed on arrival.
///
/// Reported from a device as a layout assertion the moment the feed came back
/// with nothing:
///
///   LayoutBuilder does not support returning intrinsic dimensions.
///   The relevant error-causing widget was: SliverFillRemaining
///   home_navigation_page.dart:591
///
/// `SliverFillRemaining(hasScrollBody: false)` has to decide whether its child
/// is shorter than the space left, so it asks the child for
/// `getMaxIntrinsicHeight`. [AppEmptyState] is rooted in a `LayoutBuilder` —
/// it reads `constraints.maxHeight` to decide whether the box is too short for
/// the full treatment — and a `LayoutBuilder` cannot answer that question
/// without running its builder speculatively, so it throws instead.
///
/// The second line in the report, `Null check operator used on a null value`,
/// is the aftermath: the sliver's `geometry` is left null and the viewport
/// dereferences it on the next pass. One fault, two exceptions.
///
/// The fix is `hasScrollBody: true`, which fills the remaining extent without
/// ever asking for an intrinsic height.
///
/// Not "delete the scroll view", which was the first thing that looked right:
/// a `RefreshIndicator` wraps this screen, and when the feed is empty that
/// `CustomScrollView` is the only scrollable left in it. Pull-to-refresh is
/// then the sole way out of an empty feed, so the scroll view has to stay —
/// and the last test here is what keeps it.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/common/widgets/app_empty_state.dart';
import 'package:jperg_app/core/theme/app_icons.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';

/// The shape `_buildForYouContent` builds when the feed comes back empty.
Widget host({
  required bool hasScrollBody,
  Future<void> Function()? onRefresh,
}) {
  return ScreenUtilInit(
    designSize: const Size(390, 844),
    builder: (_, __) => MaterialApp(
      theme: ThemeData(extensions: const [AppThemeExtension.dark]),
      home: Scaffold(
        body: RefreshIndicator(
          onRefresh: onRefresh ?? () async {},
          child: Stack(
            children: [
              Positioned.fill(
                child: ColoredBox(
                  color: AppThemeExtension.dark.homeBackground,
                  child: CustomScrollView(
                    slivers: [
                      SliverFillRemaining(
                        hasScrollBody: hasScrollBody,
                        child: const AppEmptyState(
                          icon: AppIcons.camera,
                          message: 'No events yet',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

void main() {
  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(390 * 3, 844 * 3);
    view.devicePixelRatio = 3;
  });

  testWidgets('an empty feed lays out without throwing', (tester) async {
    // The report, reduced. With `hasScrollBody: false` this is the device
    // crash; the whole screen fails to lay out, so the reader gets nothing at
    // all rather than an empty state.
    await tester.pumpWidget(host(hasScrollBody: true));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('No events yet'), findsOneWidget);
  });

  testWidgets('the empty state fills the viewport rather than hugging its text',
      (tester) async {
    // What `SliverFillRemaining` was there for in the first place. If the fix
    // let the child shrink to its content, the empty state would sit in a band
    // at the top of a coloured screen instead of being centred in it.
    await tester.pumpWidget(host(hasScrollBody: true));
    await tester.pumpAndSettle();

    final viewport = tester.getSize(find.byType(CustomScrollView));
    final empty = tester.getSize(find.byType(AppEmptyState));
    expect(empty.height, viewport.height,
        reason: 'the empty state should take the whole remaining extent');
  });

  testWidgets('pull-to-refresh still works on an empty feed', (tester) async {
    // The way out, and the reason the scroll view cannot simply be deleted.
    // An empty feed with no gesture to reload it is a dead end, and this is
    // exactly the state a reader most wants to retry from.
    var refreshed = 0;

    await tester.pumpWidget(
        host(hasScrollBody: true, onRefresh: () async => refreshed++));
    await tester.pumpAndSettle();

    await tester.fling(find.byType(CustomScrollView), const Offset(0, 320), 1000);
    await tester.pumpAndSettle();

    expect(refreshed, 1, reason: 'the reader could not pull to reload');
  });

}
