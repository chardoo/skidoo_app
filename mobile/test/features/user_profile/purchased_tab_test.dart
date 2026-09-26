import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/user_profile/data/repositories/profile_overview_repository.dart';
import 'package:jperg_app/features/user_profile/presentation/widgets/profile_photo_grid.dart';

/// The Purchased tab on the profile.
///
/// It is a different list from Found and that is the whole reason it exists:
/// Found is what face recognition matched this person *in*, which they may or
/// may not have paid for. This is what they paid for, which is mostly photos
/// of somebody else. Neither list contains the other.
///
/// What is pinned here is the reading of the response — the rows arrive
/// wrapped, `{"picture": {...}}`, unlike every other grid on this screen — and
/// the two things a purchase is not: removable, and watermarked.

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.pages);

  /// Response body per request, in order. One entry replays for every call.
  final List<Map<String, dynamic>> pages;
  final sent = <Map<String, dynamic>>[];

  @override
  Future<ResponseBody> fetch(
      RequestOptions options, Stream<List<int>>? _, Future<void>? __) async {
    final body = options.data;
    sent.add(body is Map<String, dynamic> ? body : const {});
    final page = pages.length == 1 ? pages.first : pages[sent.length - 1];
    return ResponseBody.fromString(
      jsonEncode(page),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

ProfileOverviewRepository repoWith(_FakeAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'))
    ..httpClientAdapter = adapter;
  return ProfileOverviewRepository.forTest(dio);
}

Map<String, dynamic> row(String id, {String url = 'https://x/p.jpg'}) => {
      'picture': {
        'id': id,
        'url': url,
        'width': 800,
        'height': 600,
        'mediaType': 'image',
        'eventId': 'e1',
      }
    };

Map<String, dynamic> body(List<Map<String, dynamic>> rows, {bool more = false}) =>
    {
      'data': rows,
      'pagination': {'hasNext': more},
    };

Widget host(Widget child) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData(extensions: const [AppThemeExtension.light]),
        home: Scaffold(body: child),
      ),
    );

void main() {
  group('reading the response', () {
    test('a purchase row is unwrapped from its picture', () async {
      // Every other grid on this screen gets the asset at the top level. This
      // endpoint nests it, and reading it as though it did not would produce a
      // grid of blank tiles rather than an error.
      final adapter = _FakeAdapter([body([row('p1'), row('p2')])]);

      final page = await repoWith(adapter).getPurchasedPhotos('u1');

      expect(page.photos.map((p) => p.id), ['p1', 'p2']);
      expect(page.photos.first.url, 'https://x/p.jpg');
      expect(page.photos.first.width, 800);
    });

    test('the client id goes in the body, where the endpoint wants it',
        () async {
      // A POST with the id in the body, not a GET with it in the path — and
      // the server checks it against the token, so sending the wrong one is a
      // 403 rather than somebody else's purchases.
      final adapter = _FakeAdapter([body(const [])]);

      await repoWith(adapter).getPurchasedPhotos('u1', page: 2, limit: 30);

      expect(adapter.sent.single['clientId'], 'u1');
      expect(adapter.sent.single['page'], 2);
      expect(adapter.sent.single['limit'], 30);
    });

    test('a purchase whose picture is gone is skipped, not rendered blank',
        () async {
      // The PaidImage row outlives a picture its photographer deleted.
      final adapter = _FakeAdapter([
        body([
          row('p1'),
          {'picture': null},
          {'picture': <String, dynamic>{'id': 'p3', 'url': ''}},
        ])
      ]);

      final page = await repoWith(adapter).getPurchasedPhotos('u1');

      expect(page.photos.map((p) => p.id), ['p1']);
    });

    test('there is more when the server says so, not when the page is full',
        () async {
      final full = _FakeAdapter([body([row('p1')], more: true)]);
      expect((await repoWith(full).getPurchasedPhotos('u1')).hasMore, isTrue);

      final last = _FakeAdapter([body([row('p1')], more: false)]);
      expect((await repoWith(last).getPurchasedPhotos('u1')).hasMore, isFalse);
    });

    test('every purchase is marked as owned', () async {
      // What keeps the paid-preview watermark off a photo this person bought.
      final adapter = _FakeAdapter([body([row('p1')])]);

      final page = await repoWith(adapter).getPurchasedPhotos('u1');

      expect(page.photos.single.isPurchased, isTrue);
    });
  });

  group('the grid', () {
    final bought = [
      const ProfilePhoto(id: 'p1', url: 'https://x/1.jpg', isPurchased: true),
      const ProfilePhoto(id: 'p2', url: 'https://x/2.jpg', isPurchased: true),
    ];

    testWidgets('offers no way to remove a purchase', (t) async {
      // Un-liking and un-bookmarking undo something free and reversible. A
      // purchase is neither, and the corner of a photo somebody paid for is
      // the wrong place to put a tap that destroys it.
      await t.pumpWidget(host(ProfilePhotoGrid(
        photos: bought,
        loading: false,
        ext: AppThemeExtension.light,
        emptyTitle: 'No purchased photos yet',
        emptyHint: 'All your purchased photos live here.',
        onOpen: (_) {},
      )));
      await t.pump();

      expect(find.byIcon(Icons.favorite_rounded), findsNothing);
      expect(find.byIcon(Icons.bookmark_rounded), findsNothing);
      expect(find.byIcon(Icons.close_rounded), findsNothing);
    });

    testWidgets('the other grids keep theirs', (t) async {
      // The corner action is optional, not gone.
      await t.pumpWidget(host(ProfilePhotoGrid(
        photos: bought,
        loading: false,
        ext: AppThemeExtension.light,
        emptyTitle: 'x',
        emptyHint: 'y',
        removeIcon: Icons.bookmark_rounded,
        removeTooltip: 'Remove bookmark',
        onRemove: (_) async {},
        onOpen: (_) {},
      )));
      await t.pump();

      expect(find.byIcon(Icons.bookmark_rounded), findsNWidgets(2));
    });

    testWidgets('says so when there is nothing bought yet', (t) async {
      await t.pumpWidget(host(ProfilePhotoGrid(
        photos: const [],
        loading: false,
        ext: AppThemeExtension.light,
        emptyTitle: 'No purchased photos yet',
        emptyHint: 'All your purchased photos live here.',
        onOpen: (_) {},
      )));
      await t.pump();

      expect(find.text('No purchased photos yet'), findsOneWidget);
      expect(find.text('All your purchased photos live here.'), findsOneWidget);
    });
  });
}
