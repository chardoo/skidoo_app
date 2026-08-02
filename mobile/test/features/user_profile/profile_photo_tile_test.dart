import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/features/user_profile/data/repositories/profile_overview_repository.dart';
import 'package:skidoo_app/features/user_profile/presentation/widgets/profile_photo_tile.dart';

/// Two gestures share this tile: the photo opens, the corner icon removes.
///
/// The tile did nothing at all for a while — its GestureDetector used the
/// default deferToChild, and an Image does not absorb a hit, so a tap on the
/// photo found no child willing to take it. That is exactly the kind of thing
/// that looks fine in the source and is invisible until something taps it.
Future<void> _pump(
  WidgetTester tester, {
  required VoidCallback onOpen,
  required VoidCallback onRemove,
  bool isEvent = false,
}) async {
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (context, _) => MaterialApp(
        theme: ThemeData(extensions: const [AppThemeExtension.light]),
        home: Scaffold(
          body: SizedBox(
            width: 120,
            height: 120,
            child: Builder(
              builder: (context) => ProfilePhotoTile(
                photo: ProfilePhoto(
                  id: 'pic-1',
                  url: 'https://example.com/a.jpg',
                  isEvent: isEvent,
                ),
                ext: Theme.of(context).extension<AppThemeExtension>()!,
                removeIcon: Icons.favorite_rounded,
                removeTooltip: 'Unlike',
                onRemove: onRemove,
                onOpen: onOpen,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('tapping the photo opens it', (tester) async {
    var opened = 0;
    var removed = 0;
    await _pump(tester, onOpen: () => opened++, onRemove: () => removed++);

    // The middle of the tile — over the image, away from the corner icon.
    await tester.tapAt(tester.getCenter(find.byType(ProfilePhotoTile)));
    await tester.pump();

    expect(opened, 1, reason: 'a tap on the photo has to open it');
    expect(removed, 0);
  });

  testWidgets('tapping the corner icon removes instead of opening',
      (tester) async {
    var opened = 0;
    var removed = 0;
    await _pump(tester, onOpen: () => opened++, onRemove: () => removed++);

    await tester.tap(find.byIcon(Icons.favorite_rounded));
    await tester.pump();

    expect(removed, 1);
    expect(opened, 0, reason: 'removing must not also open the photo');
  });

  testWidgets('an event tile is marked and still opens', (tester) async {
    var opened = 0;
    await _pump(
      tester, isEvent: true, onOpen: () => opened++, onRemove: () {},
    );

    expect(find.byIcon(Icons.event_rounded), findsOneWidget);

    await tester.tapAt(tester.getCenter(find.byType(ProfilePhotoTile)));
    await tester.pump();

    expect(opened, 1);
  });
}
