import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/cache/comment_counts.dart';
import 'package:jperg_app/core/navigation/feed_chrome.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/admin/data/models/app_config.dart';
import 'package:jperg_app/features/admin/data/repositories/app_config_repository.dart';
import 'package:jperg_app/features/discovery/presentation/bloc/discovery_bloc.dart';
import 'package:jperg_app/features/discovery/presentation/widgets/full_bleed_event_card.dart';
import 'package:jperg_app/features/photographers/presentation/pages/creator_profile_page.dart';
import 'package:jperg_app/models/event_discovery/event_discovery.dart';

// The guest feed's card hands every gated tap to `onTap`, which the discovery
// page turns into the login sheet — and, on success, into Home rather than back
// onto the guest feed. The album, the reactions and the more menu all went that
// way; the creator's avatar and the "by <name>" line did not, and opened the
// profile outright.
//
// openPhotographerProfile now refuses a guest on its own, so this is the second
// of two gates. It earns its place by deciding *which* login path the card
// takes: its own, the one that signs the person into the app proper.

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
    FeedChrome.hide();
  });

  tearDown(() {
    AppConfigRepository.current = const AppConfig();
    CommentCounts.instance.clear();
  });

  /// The card as the guest feed builds it, counting what `onTap` is asked for.
  Future<int Function()> pumpGuestCard(WidgetTester t,
      {bool authenticated = false}) async {
    var taps = 0;
    await t.pumpWidget(ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData.dark().copyWith(extensions: [AppThemeExtension.dark]),
        home: Scaffold(
          body: BlocProvider<DiscoveryBloc>(
            create: (_) => _StubDiscoveryBloc(),
            child: FullBleedEventCard(
              event: event(),
              cardIndex: 0,
              activeCardIndex: ValueNotifier<int>(0),
              onTap: () => taps++,
              onHide: () {},
              isAuthenticated: authenticated,
            ),
          ),
        ),
      ),
    ));
    await t.pump();
    return () => taps;
  }

  testWidgets('the creator avatar asks a guest to sign in', (t) async {
    final taps = await pumpGuestCard(t);

    // Matched on the [Semantics] widget rather than through
    // `find.bySemanticsLabel`: the rail's avatar sits inside a merged node, so
    // the label never surfaces as a node of its own to search for.
    await t.tap(find.byWidgetPredicate((w) =>
        w is Semantics &&
        w.properties.label == "View Kwame Studios's profile"));
    await t.pump();

    expect(taps(), 1, reason: 'the tap must go to the card\'s own login path');
    expect(find.byType(CreatorProfilePage), findsNothing,
        reason: 'a signed-out viewer reached a creator profile');
  });

  testWidgets('the "by <name>" line is gated with it', (t) async {
    // The same destination as the avatar, and it was added later — the kind of
    // second entry point a per-tap gate gets wrong.
    final taps = await pumpGuestCard(t);

    await t.tap(find.text('Kwame Studios'));
    await t.pump();

    expect(taps(), 1);
    expect(find.byType(CreatorProfilePage), findsNothing);
  });
}
