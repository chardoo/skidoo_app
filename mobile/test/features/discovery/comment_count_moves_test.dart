import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/cache/comment_counts.dart';
import 'package:jperg_app/core/navigation/feed_chrome.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/admin/data/models/app_config.dart';
import 'package:jperg_app/features/admin/data/repositories/app_config_repository.dart';
import 'package:jperg_app/features/ads/data/models/ad_model.dart';
import 'package:jperg_app/features/ads/presentation/widgets/feed_item_card.dart';
import 'package:jperg_app/features/discovery/presentation/bloc/discovery_bloc.dart';
import 'package:jperg_app/features/discovery/presentation/widgets/full_bleed_event_card.dart';
import 'package:jperg_app/models/event_discovery/event_discovery.dart';

/// Commenting has to move the number beside the glyph, now.
///
/// It did not. Both feed cards drew `commentCount` straight off the object the
/// feed was fetched with, and nothing rebuilt them when a comment was posted —
/// so the ordinary experience of commenting was to write one, close the sheet,
/// and find the badge still reading what it read before. On an event it was
/// worse than stale: the card never even told anyone a comment had been sent.
///
/// [CommentCounts] is the live number, reported by the comment sheets as they
/// post. These pin that both cards read it and both follow it.
EventDiscovery event({int commentCount = 2}) => EventDiscovery(
      id: 'e1',
      eventName: 'University Graduation',
      photographerName: 'Kwame Studios',
      photographerId: 'p1',
      commentCount: commentCount,
      pictures: const [
        EventPicture(
          id: 'pic0',
          url: 'https://cdn.example.com/0.jpg',
          imageId: 'img0',
          price: 0,
          width: 1000,
          height: 1500,
        ),
      ],
    );

AdModel ad({int commentCount = 2, bool commentsEnabled = true}) =>
    AdModel.fromJson({
      'ad_id': 'ad-1',
      'campaign_id': 'camp-1',
      'headline': 'Wedding Season Promo',
      'body': 'Book your dream wedding shoot.',
      'cta_text': 'Book Now',
      'cta_url': 'https://studio.example.com/book',
      'advertiser_id': 'adv-1',
      'advertiser_name': 'Kwame Studios',
      'placement': 'event_feed',
      'impression_token': 'tok',
      'comment_count': commentCount,
      'comments_enabled': commentsEnabled,
    });

class _StubDiscoveryBloc extends Bloc<DiscoveryEvent, DiscoveryState>
    implements DiscoveryBloc {
  _StubDiscoveryBloc() : super(const DiscoveryState());

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Widget host(Widget card) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData.dark().copyWith(extensions: [AppThemeExtension.dark]),
        home: Scaffold(
          body: BlocProvider<DiscoveryBloc>(
            create: (_) => _StubDiscoveryBloc(),
            child: card,
          ),
        ),
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

    AppConfigRepository.current = const AppConfig(feedSlideIntervalSeconds: 0);
    CommentCounts.instance.clear();
    FeedChrome.hide();
  });

  tearDown(() {
    AppConfigRepository.current = const AppConfig();
    CommentCounts.instance.clear();
  });

  testWidgets('a post card follows the live count', (t) async {
    await t.pumpWidget(host(FullBleedEventCard(
      event: event(commentCount: 2),
      cardIndex: 0,
      activeCardIndex: ValueNotifier<int>(0),
      onTap: () {},
      onHide: () {},
    )));
    await t.pump();

    expect(find.text('2'), findsOneWidget);

    // What the sheet does on the way out — see FullBleedEventCard's
    // onCommentSent. An event's comments are chat messages, so this is the
    // client's half of an increment the server makes on the same path.
    CommentCounts.instance.adjust('e1', 1, base: 2);
    await t.pump();

    expect(find.text('3'), findsOneWidget);
    expect(find.text('2'), findsNothing);
  });

  testWidgets('a campaign card follows the live count', (t) async {
    await t.pumpWidget(host(FeedItemCard(
      data: FeedItemData.fromAd(ad(commentCount: 2), onCtaTap: () {}),
    )));
    await t.pump();

    expect(find.text('2'), findsOneWidget);

    // The ads comment sheet reports the server's figure rather than guessing.
    CommentCounts.instance.report('ad-1', 3);
    await t.pump();

    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('one post is not another post', (t) async {
    // Keyed by target id, so commenting on one card cannot move the badge on
    // the one behind it.
    await t.pumpWidget(host(FullBleedEventCard(
      event: event(commentCount: 2),
      cardIndex: 0,
      activeCardIndex: ValueNotifier<int>(0),
      onTap: () {},
      onHide: () {},
    )));
    await t.pump();

    CommentCounts.instance.report('some-other-event', 99);
    await t.pump();

    expect(find.text('2'), findsOneWidget);
    expect(find.text('99'), findsNothing);
  });

  testWidgets('a closed thread still shows a moving count', (t) async {
    // The glyph is drawn unavailable, not the number: comments left before the
    // owner closed the thread are still there and still readable elsewhere.
    await t.pumpWidget(host(FeedItemCard(
      data: FeedItemData.fromAd(
        ad(commentCount: 2, commentsEnabled: false),
        onCtaTap: () {},
      ),
    )));
    await t.pump();

    CommentCounts.instance.report('ad-1', 5);
    await t.pump();

    expect(find.text('5'), findsOneWidget);
  });
}
