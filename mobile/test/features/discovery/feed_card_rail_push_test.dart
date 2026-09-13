import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/components/comments/comment_sheet_scope.dart';
import 'package:jperg_app/core/cache/comment_counts.dart';
import 'package:jperg_app/core/navigation/feed_chrome.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/admin/data/models/app_config.dart';
import 'package:jperg_app/features/admin/data/repositories/app_config_repository.dart';
import 'package:jperg_app/features/discovery/presentation/bloc/discovery_bloc.dart';
import 'package:jperg_app/features/discovery/presentation/widgets/full_bleed_event_card.dart';
import 'package:jperg_app/models/event_discovery/event_discovery.dart';

/// Opening comments must not overflow the card's right-hand action rail.
///
/// [CommentPushArea] relays the whole card out into the strip above an open
/// sheet — around 253 dp of an 844 dp screen. The rail is stretched top to
/// bottom inside the card, so that strip becomes a *tight* height for it, and
/// its avatar, follow button and five reactions come to roughly 290 dp. A
/// Column cannot shrink: it overflowed by 37 px, striped in debug and silently
/// clipped in release, every time somebody opened comments on a feed card.
///
/// Pumped rather than asserted against the source, because the number that
/// matters — how tall the rail actually is — is not in the source. It is the
/// sum of an avatar radius, a spacer and five reaction buttons, and any one of
/// them growing puts the overflow back.
EventDiscovery event() => const EventDiscovery(
      id: 'e1',
      eventName: 'University Graduation',
      photographerName: 'Kwame Studios',
      photographerId: 'p1',
      commentCount: 2,
      pictures: [
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

class _StubDiscoveryBloc extends Bloc<DiscoveryEvent, DiscoveryState>
    implements DiscoveryBloc {
  _StubDiscoveryBloc() : super(const DiscoveryState());

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

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
    CommentSheetScope.reset();
    FeedChrome.hide();
  });

  tearDown(() {
    AppConfigRepository.current = const AppConfig();
    CommentCounts.instance.clear();
    CommentSheetScope.reset();
  });

  testWidgets('opening comments does not overflow the action rail', (t) async {
    // The card as the feed builds it: inside a [CommentPushArea], inside a
    // vertical PageView. The PageView is what makes this reproduce — its pages
    // carry tight constraints, which is why the push area re-lays the card out
    // rather than letting it keep its full height.
    late BuildContext sheetContext;
    await t.pumpWidget(ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData.dark().copyWith(extensions: [AppThemeExtension.dark]),
        home: Scaffold(
          body: BlocProvider<DiscoveryBloc>(
            create: (_) => _StubDiscoveryBloc(),
            child: PageView(
              scrollDirection: Axis.vertical,
              children: [
                CommentPushArea(
                  child: Builder(builder: (context) {
                    sheetContext = context;
                    return FullBleedEventCard(
                      event: event(),
                      cardIndex: 0,
                      activeCardIndex: ValueNotifier<int>(0),
                      onTap: () {},
                      onHide: () {},
                    );
                  }),
                ),
              ],
            ),
          ),
        ),
      ),
    ));
    await t.pump();
    expect(t.takeException(), isNull, reason: 'the card is broken at rest');

    showCommentSheet<void>(
      sheetContext,
      builder: (_) => const SizedBox(height: 300),
    );

    // Through the push and out the far side, one frame at a time. The overflow
    // appears partway down — the moment the band passes the rail's natural
    // height — so jumping to the end would step over the frames that show it.
    //
    // Fixed pumps rather than [WidgetTester.pumpAndSettle]: the card carries
    // animations that never end, and settling waits for a still frame that
    // never comes.
    for (var i = 0; i < 20; i++) {
      await t.pump(const Duration(milliseconds: 30));
      expect(t.takeException(), isNull,
          reason: 'the rail overflowed as the card was pushed into the strip');
    }
  });
}
