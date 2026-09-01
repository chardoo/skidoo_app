import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/components/media/media_reaction_rail.dart';
import 'package:jperg_app/core/navigation/feed_chrome.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/ads/data/models/ad_model.dart';
import 'package:jperg_app/features/ads/data/models/feed_request_model.dart';
import 'package:jperg_app/features/ads/presentation/widgets/feed_item_card.dart';

/// A campaign and a request are pages of the feed, the same shape as the posts
/// they are dealt between.
///
/// They used to be Instagram-shaped columns — header, image, button row,
/// caption — scaled down inside a FittedBox to fit a pager built for full-bleed
/// media, so between two edge-to-edge posts they read as a different app.
///
/// What each card carries differs on purpose, and that is most of what is
/// pinned here: a campaign can be liked and discussed, while a request carries
/// share alone and answers itself through its button. A heart on somebody's
/// work enquiry says nothing they can use.
AdModel _ad({
  bool commentsEnabled = true,
  int likeCount = 0,
  bool viewerLiked = false,
  List<String> tags = const [],
}) =>
    AdModel.fromJson({
      'ad_id': 'ad-1',
      'campaign_id': 'camp-1',
      'adset_id': 'set-1',
      'headline': 'Wedding Season Promo',
      'body': 'Book your dream wedding shoot — 20% off this month.',
      'cta_text': 'Book Now',
      'cta_url': 'https://studio.example.com/book',
      'advertiser_id': 'adv-1',
      'advertiser_name': 'Kwame Studios',
      'placement': 'event_feed',
      'impression_token': 'tok',
      'comments_enabled': commentsEnabled,
      'comment_count': 10,
      'like_count': likeCount,
      'viewer_liked': viewerLiked,
      'content_tags': tags,
    });

FeedRequestModel _request({
  String? eventDate = '2026-09-15',
  String? eventTime = '10:00',
  String? coverageKind = 'full_day',
  int? coverageHours,
}) =>
    FeedRequestModel.fromJson({
      'id': 'req-1',
      'title': 'Praise Reloaded 2027',
      'description': 'A concert',
      'event_type': 'Concert',
      'location': 'Labadi Beach, Accra',
      'requester_id': 'user-1',
      'requester_name': 'Accra Creative Hub',
      'requester_type': 'client',
      'status': 'open',
      'currency': 'GHS',
      'budget_min': 4500,
      'budget_max': 6000,
      'event_date': eventDate,
      'event_time': eventTime,
      'coverage_kind': coverageKind,
      'coverage_hours': coverageHours,
      'createdAt': '2026-08-01T10:00:00+00:00',
      'updatedAt': '2026-08-01T10:00:00+00:00',
    });

Widget host(FeedItemData data) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData.dark().copyWith(extensions: [AppThemeExtension.dark]),
        home: Scaffold(body: FeedItemCard(data: data)),
      ),
    );

List<MediaReaction> railOf(WidgetTester t) =>
    t.widget<MediaReactionRail>(find.byType(MediaReactionRail)).actions;

void main() {
  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(390 * 3, 844 * 3);
    view.devicePixelRatio = 3;
    FeedChrome.hide();
  });

  tearDown(FeedChrome.hide);

  group('a campaign', () {
    testWidgets('names itself, its advertiser and what it is offering',
        (t) async {
      await t.pumpWidget(host(FeedItemData.fromAd(_ad(), onCtaTap: () {})));
      await t.pump();

      expect(find.text('Sponsored'), findsOneWidget);
      expect(find.text('Kwame Studios'), findsOneWidget);
      expect(find.text('Wedding Season Promo'), findsOneWidget);
      expect(find.text('Book Now'), findsOneWidget);
    });

    testWidgets('shows its tags as hashtags', (t) async {
      await t.pumpWidget(host(FeedItemData.fromAd(
        _ad(tags: ['wedding', 'photography']),
        onCtaTap: () {},
      )));
      await t.pump();

      expect(find.text('#wedding #photography'), findsOneWidget);
    });

    testWidgets('carries a heart with the count the server sent', (t) async {
      await t.pumpWidget(host(FeedItemData.fromAd(
        _ad(likeCount: 206, viewerLiked: true),
        onCtaTap: () {},
      )));
      await t.pump();

      final like = railOf(t).first;
      expect(like.count, 206);
      expect(like.active, isTrue, reason: 'the viewer has liked this one');
    });

    testWidgets('keeps the heart when the advertiser closed the thread',
        (t) async {
      // "Allow comments" closes the thread and nothing else. It used to take
      // the like with it, which left a campaign somebody liked yesterday with
      // no way to like it today.
      await t.pumpWidget(host(FeedItemData.fromAd(
        _ad(commentsEnabled: false),
        onCtaTap: () {},
      )));
      await t.pump();

      final labels = railOf(t).map((a) => a.semanticLabel ?? '').toList();
      expect(labels.any((l) => l.toLowerCase().contains('like')), isTrue);
      // The comment button stays too, drawn unavailable — a rail with none at
      // all reads as one that never had comments.
      expect(labels.any((l) => l.toLowerCase().contains('comment')), isTrue);
    });
  });

  group('a request', () {
    testWidgets('reads as a brief: who, what, when, where, how long, how much',
        (t) async {
      await t.pumpWidget(host(FeedItemData.fromRequest(_request())));
      await t.pump();

      expect(find.text('Photographer Request'), findsOneWidget);
      expect(find.text('Accra Creative Hub'), findsOneWidget);
      expect(find.text('Praise Reloaded 2027'), findsOneWidget);
      expect(find.text('Sep 15, 2026 · 10:00 AM'), findsOneWidget);
      expect(find.text('Labadi Beach, Accra'), findsOneWidget);
      expect(find.text('Full Day Coverage (~8 hrs)'), findsOneWidget);
      expect(find.text('GHS 4500 - GHS 6000'), findsOneWidget);
      expect(find.text('Express interest'), findsOneWidget);
    });

    testWidgets('leaves out what the requester did not say', (t) async {
      // Every one of these is optional, and a row drawn as an icon beside a
      // dash is worse than no row.
      await t.pumpWidget(host(FeedItemData.fromRequest(
        _request(eventDate: null, eventTime: null, coverageKind: null),
      )));
      await t.pump();

      expect(find.textContaining('Coverage'), findsNothing);
      expect(find.textContaining('2026'), findsNothing);
      // What it does know is still there.
      expect(find.text('Labadi Beach, Accra'), findsOneWidget);
    });

    testWidgets('shows the date alone when no time was given', (t) async {
      await t.pumpWidget(host(FeedItemData.fromRequest(
        _request(eventTime: null),
      )));
      await t.pump();

      expect(find.text('Sep 15, 2026'), findsOneWidget);
    });

    testWidgets('words hourly coverage with its hours', (t) async {
      await t.pumpWidget(host(FeedItemData.fromRequest(
        _request(coverageKind: 'hourly', coverageHours: 3),
      )));
      await t.pump();

      expect(find.text('Hourly Coverage (~3 hrs)'), findsOneWidget);
    });

    testWidgets('carries share and nothing to react with', (t) async {
      await t.pumpWidget(host(FeedItemData.fromRequest(_request())));
      await t.pump();

      final labels =
          railOf(t).map((a) => (a.semanticLabel ?? '').toLowerCase()).toList();
      expect(labels.any((l) => l.contains('share')), isTrue);
      expect(labels.any((l) => l.contains('like')), isFalse,
          reason: 'a job going begging is not a post to like');
      expect(labels.any((l) => l.contains('comment')), isFalse);
    });
  });

  group('the chrome', () {
    testWidgets('a tap brings the navigation bar up, as on a post', (t) async {
      await t.pumpWidget(host(FeedItemData.fromAd(_ad(), onCtaTap: () {})));
      await t.pump();

      expect(FeedChrome.visible.value, isFalse);

      await t.tapAt(const Offset(195, 300)); // the media, not the copy block
      await t.pump(const Duration(milliseconds: 400));

      expect(FeedChrome.visible.value, isTrue);
    });

    testWidgets('the copy steps over the bar when it appears', (t) async {
      await t.pumpWidget(host(FeedItemData.fromAd(_ad(), onCtaTap: () {})));
      await t.pump();

      final resting = t.getRect(find.text('Kwame Studios')).bottom;

      FeedChrome.show();
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));

      final lifted = t.getRect(find.text('Kwame Studios')).bottom;
      expect(resting - lifted, greaterThanOrEqualTo(58.0),
          reason: 'the advertiser, the offer and the button all sit in this '
              'block, and the bar frosts whatever is behind it');
    });
  });
}
