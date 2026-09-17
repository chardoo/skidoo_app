import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/user_profile/data/repositories/profile_overview_repository.dart';
import 'package:jperg_app/features/user_profile/presentation/widgets/profile_photo_grid.dart';

/// Scrolling the Liked or Saved grid has to fetch the rest.
///
/// Both tabs were a single fetch: the grid drew whatever the first response
/// held and no amount of scrolling could reach page two. Liked was worse
/// again, because the server clipped that first response to ten.
///
/// The trap in fixing it is that a scroll listener can only fire if there is a
/// scroll. A first page that does not fill the screen leaves nothing to drag —
/// the reader scrolls, nothing moves, and nothing more ever loads. Ten items
/// in a three-column grid is four rows, which is exactly that case on a tall
/// phone, so the grid also asks for more whenever it is too short to scroll.
ProfilePhoto _photo(int i) => ProfilePhoto(id: 'p$i', url: 'https://x/$i.jpg');

Widget _host(Widget child) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme:
            ThemeData.dark().copyWith(extensions: [AppThemeExtension.dark]),
        home: Scaffold(body: child),
      ),
    );

ProfilePhotoGrid _grid({
  required int count,
  VoidCallback? onLoadMore,
  bool loadingMore = false,
}) =>
    ProfilePhotoGrid(
      photos: [for (var i = 0; i < count; i++) _photo(i)],
      loading: false,
      ext: AppThemeExtension.dark,
      emptyTitle: 'Nothing liked yet',
      emptyHint: 'Photos you like show up here.',
      removeIcon: Icons.favorite_rounded,
      removeTooltip: 'Unlike',
      onRemove: (_) async {},
      onOpen: (_) {},
      onLoadMore: onLoadMore,
      loadingMore: loadingMore,
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

  group('a grid too short to scroll', () {
    testWidgets('asks for more on its own', (t) async {
      var asked = 0;
      await t.pumpWidget(_host(_grid(count: 6, onLoadMore: () => asked++)));
      await t.pump();

      // Six tiles is two rows. There is nothing to drag, so a scroll listener
      // alone would wait forever.
      expect(asked, greaterThan(0));
    });

    testWidgets('but not when there is nothing more to ask for', (t) async {
      await t.pumpWidget(_host(_grid(count: 6)));
      await t.pump();

      expect(t.takeException(), isNull);
    });

    testWidgets('and not while a page is already in the air', (t) async {
      var asked = 0;
      await t.pumpWidget(_host(
        _grid(count: 6, onLoadMore: () => asked++, loadingMore: true),
      ));
      await t.pump();

      expect(asked, 0);
    });
  });

  group('a grid long enough to scroll', () {
    testWidgets('asks for more as the bottom comes near', (t) async {
      var asked = 0;
      await t.pumpWidget(_host(_grid(count: 90, onLoadMore: () => asked++)));
      await t.pump();
      final atRest = asked;

      await t.drag(find.byType(GridView), const Offset(0, -4000));
      await t.pump();

      expect(asked, greaterThan(atRest));
    });

    testWidgets('and does not while the top is still on screen', (t) async {
      var asked = 0;
      await t.pumpWidget(_host(_grid(count: 300, onLoadMore: () => asked++)));
      await t.pump();

      // A long list at rest is nowhere near its end.
      expect(asked, 0);
    });
  });

  testWidgets('a page on its way is visible', (t) async {
    await t.pumpWidget(_host(
      // Short, so the trailing cells are on screen — a builder only builds
      // what is visible, and at the foot of a long grid they are not.
      _grid(count: 6, onLoadMore: () {}, loadingMore: true),
    ));
    await t.pump();

    // Otherwise the grid ends in what looks like the last row.
    expect(find.byType(CircularProgressIndicator), findsWidgets);
  });
}
