import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/widgets/jperg_image.dart';

/// The bug: grids, carousels and list tiles get one `url` per item and hand it
/// straight to [JpergImage]. When that item was a video the image loader was
/// asked to decode an mp4 and every clip rendered as a broken-image icon.
void main() {
  Widget host(Widget child) => MaterialApp(
        theme: ThemeData.dark()
            .copyWith(extensions: [AppThemeExtension.dark]),
        home: Scaffold(body: SizedBox(width: 200, height: 200, child: child)),
      );

  String loadedUrl(WidgetTester t) =>
      t.widget<CachedNetworkImage>(find.byType(CachedNetworkImage)).imageUrl;

  testWidgets('a Cloudinary video loads its poster frame, not the mp4',
      (t) async {
    await t.pumpWidget(host(const JpergImage(
      imageUrl:
          'https://res.cloudinary.com/jperg/video/upload/v1/events/clip.mp4',
    )));

    final url = loadedUrl(t);
    expect(url, contains('so_0'));
    expect(url, endsWith('/events/clip.jpg'));
    expect(url, isNot(contains('.mp4')));
  });

  testWidgets('an image url is untouched by the video path', (t) async {
    await t.pumpWidget(host(const JpergImage(
      imageUrl:
          'https://res.cloudinary.com/jperg/image/upload/v1/events/shot.jpg',
    )));

    final url = loadedUrl(t);
    expect(url, contains('f_auto'));
    expect(url, isNot(contains('so_0')));
  });

  testWidgets('a video with no derivable poster shows the empty slot, '
      'not an error icon', (t) async {
    await t.pumpWidget(host(const JpergImage(
      imageUrl: 'https://cdn.example.com/clip.mp4',
      errorWidget: _neverWidget,
    )));

    expect(find.byType(CachedNetworkImage), findsNothing);
    expect(find.byType(JpergImagePlaceholder), findsOneWidget);
  });
}

Widget _neverWidget(BuildContext _, String __, dynamic ___) =>
    const Icon(Icons.broken_image_outlined);
