import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/features/gallery/presentation/found/models/found_album.dart';
import 'package:skidoo_app/features/gallery/presentation/found/pages/found_photo_viewer_page.dart';
import 'package:skidoo_app/features/gallery/presentation/found/widgets/found_album_section.dart';
import 'package:skidoo_app/features/gallery/presentation/found/widgets/found_filter_button.dart';
import 'package:skidoo_app/features/gallery/presentation/found/widgets/found_header.dart';

Map<String, dynamic> groupJson({int photoCount = 21, int preview = 6}) => {
      'event': {
        'id': 'evt-1',
        'eventName': 'Praise Reloaded 2026',
        'photographer': {'id': 'ph-1', 'name': 'Daniella Daniels'},
      },
      'photoCount': photoCount,
      'photos': [
        for (var i = 0; i < preview; i++)
          {
            'id': 'p$i',
            'url': 'https://cdn/p$i.jpg',
            'public': true,
            'event': {
              'id': 'evt-1',
              'eventName': 'Praise Reloaded 2026',
              'location': 'Accra',
              'photographer': {'id': 'ph-1', 'name': 'Daniella Daniels'},
            },
          },
      ],
      'moreCount': photoCount - preview,
    };

Widget host(Widget child) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData.dark()
            .copyWith(extensions: const [AppThemeExtension.dark]),
        home: Scaffold(body: child),
      ),
    );

/// Widget-level checks for the two states that are easy to regress: the
/// six-tile preview with its "+N" overlay, and the untitled expanded grid the
/// design switches to once a filter is applied.
void main() {
  setUp(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    // CachedNetworkImage reaches for path_provider; stub it so image tiles
    // lay out instead of blowing up the test.
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => Directory.systemTemp.path,
    );
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('com.tekartik.sqflite'),
      (call) async => call.method == 'getDatabasesPath'
          ? Directory.systemTemp.path
          : <String, dynamic>{},
    );
    final view = binding.platformDispatcher.views.first;
    view.physicalSize = const Size(390 * 3, 844 * 3);
    view.devicePixelRatio = 3;
  });

  final album = FoundAlbum.fromJson(groupJson());

  testWidgets('feed section: 6 tiles, +15 on the last one', (t) async {
    await t.pumpWidget(host(ListView(children: [
      const FoundHeader(count: 48),
      FoundFilterButton(activeCount: 1, onTap: () {}),
      FoundAlbumSection(
        album: album,
        onPhotoTap: (_) {},
        onOpenAlbum: () {},
      ),
    ])));
    await t.pump();
    expect(find.text('Found photos'), findsOneWidget);
    expect(find.text('48 found'), findsOneWidget);
    expect(find.text('Praise Reloaded 2026'), findsOneWidget);
    expect(find.text('+15'), findsOneWidget);
  });

  testWidgets('filtered section: untitled, but keeps its +N', (t) async {
    await t.pumpWidget(host(ListView(children: [
      FoundAlbumSection(
        album: album,
        expanded: true,
        onPhotoTap: (_) {},
        onOpenAlbum: () {},
      ),
    ])));
    await t.pump();
    expect(find.text('Praise Reloaded 2026'), findsNothing);
    // The regression: expanded mode dropped the "+N" on the premise that it
    // showed every match, while the feed only ever holds the preview slice —
    // 6 tiles of 21, with the header still counting all 21 and no way through.
    expect(find.text('+15'), findsOneWidget);
  });

  testWidgets('a null headline is suppressed, not guessed at', (t) async {
    await t.pumpWidget(host(ListView(children: const [FoundHeader(count: null)])));
    await t.pump();
    expect(find.text('Found photos'), findsOneWidget);
    // No "N found", and in particular no "0 found" — the count is unknown,
    // which is not the same as zero.
    expect(find.textContaining('found'), findsNothing);
  });

  testWidgets('viewer renders counter, badge, meta and filmstrip', (t) async {
    await t.pumpWidget(host(FoundPhotoViewerPage(
      photos: album.photos,
      initialIndex: 2,
      onViewAlbum: () {},
    )));
    await t.pump();
    // The counter is a Text.rich split across spans (tabular figures on the
    // numbers, a nudged WidgetSpan for " of "), so find.text can't reach it.
    expect(find.bySemanticsLabel('3 of 6'), findsOneWidget);
    expect(find.text('Public'), findsOneWidget);
    expect(find.text('Daniella Daniels'), findsOneWidget);
    expect(find.text('Praise Reloaded 2026 | Accra'), findsOneWidget);
    expect(find.text('View album'), findsOneWidget);
  });
}
