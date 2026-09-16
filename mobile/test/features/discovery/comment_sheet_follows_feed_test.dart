import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:jperg_app/components/comments/comment_sheet_scope.dart';
import 'package:jperg_app/core/cache/comment_counts.dart';
import 'package:jperg_app/core/navigation/feed_chrome.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/admin/data/models/app_config.dart';
import 'package:jperg_app/features/admin/data/repositories/app_config_repository.dart';
import 'package:jperg_app/features/chat/domain/usecases/chat_usecases.dart';
// ChatRoomEvent and ChatRoomState are parts of this library, not imports.
import 'package:jperg_app/features/chat/presentation/bloc/room/chat_room_bloc.dart';
import 'package:jperg_app/features/discovery/presentation/bloc/discovery_bloc.dart';
import 'package:jperg_app/features/discovery/presentation/feed_active_event.dart';
import 'package:jperg_app/features/discovery/presentation/pages/event_comment_page.dart';
import 'package:jperg_app/features/discovery/presentation/widgets/full_bleed_event_card.dart';
import 'package:jperg_app/models/chat/chat_message.dart';
import 'package:jperg_app/models/chat/chat_room.dart';
import 'package:jperg_app/models/event_discovery/event_discovery.dart';
import 'package:jperg_app/services/auth_service.dart';

/// The comment sheet is about the post under it, not the post that opened it.
///
/// The sheet's barrier deliberately stops at its own top edge so the band above
/// stays live — a reader is meant to keep swiping the media while reading about
/// it. But a vertical swipe in that band does not page a carousel, it pages the
/// *feed*: the post changed and the sheet did not, leaving the previous post's
/// thread under the new post's picture, behind an input bar that would file a
/// comment against the post that had scrolled away.
///
/// So the card in front publishes itself ([FeedActiveEvent]) and the sheet
/// follows.
///
/// What is asserted here is the *binding* — which room the sheet asks for,
/// which it leaves, and what it renders for a post with comments off. The
/// thread's contents are one layer further down, rendered from ChatRoomBloc's
/// state, and are covered where that bloc is tested; the room the sheet joins
/// is what decides whose contents those are.

EventDiscovery _event(
  String id, {
  String name = 'Event',
  bool commentsEnabled = true,
}) =>
    EventDiscovery(
      id: id,
      eventName: name,
      photographerName: 'Kwame Studios',
      photographerId: 'p1',
      commentsEnabled: commentsEnabled,
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

ChatMessage _message(String roomId) => ChatMessage(
      id: '$roomId-m1',
      roomId: roomId,
      senderId: 'someone',
      senderName: 'Ama',
      senderRole: 'user',
      content: 'a comment in $roomId',
      createdAt: DateTime(2026, 1, 1),
    );

/// Records what the sheet asks of it, and answers a join with that room's own
/// messages — which is the whole question here: whose thread is on screen.
///
/// The emit is deferred a turn rather than made in the same microtask as the
/// join, because that is what a real room does: it goes to the network. An
/// answer that lands before the list has ever been built puts this sheet in a
/// state it cannot reach in the app.
class _StubChatRoomBloc extends Bloc<ChatRoomEvent, ChatRoomState>
    implements ChatRoomBloc {
  _StubChatRoomBloc() : super(const ChatRoomState()) {
    on<ChatRoomEvent>((event, emit) async {
      received.add(event);
      if (event is ChatRoomJoined) {
        await Future<void>.delayed(Duration.zero);
        emit(ChatRoomState(messages: [_message(event.roomId)]));
      } else if (event is ChatRoomLeft) {
        await Future<void>.delayed(Duration.zero);
        emit(const ChatRoomState());
      }
    });
  }

  final received = <ChatRoomEvent>[];

  List<String> get joinedRooms =>
      received.whereType<ChatRoomJoined>().map((e) => e.roomId).toList();

  List<String> get kinds =>
      received.map((e) => e.runtimeType.toString()).toList();

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// One room per event, named after it, so a thread can be traced back to the
/// post it belongs to.
class _StubGetEventRoom implements GetEventRoomUseCase {
  final asked = <String>[];

  @override
  Future<ChatRoom> call(String eventId) async {
    asked.add(eventId);
    return ChatRoom(
      id: 'room-$eventId',
      type: RoomType.event,
      eventId: eventId,
      createdAt: DateTime(2026, 1, 1),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _StubAuth implements AuthService {
  @override
  Future<String> getUserId() async => 'me';

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _StubDiscoveryBloc extends Bloc<DiscoveryEvent, DiscoveryState>
    implements DiscoveryBloc {
  _StubDiscoveryBloc() : super(const DiscoveryState());

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  late _StubChatRoomBloc bloc;
  late _StubGetEventRoom rooms;

  setUp(() async {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(390 * 3, 844 * 3);
    view.devicePixelRatio = 3;

    AppConfigRepository.current = const AppConfig(feedSlideIntervalSeconds: 0);
    CommentCounts.instance.clear();
    CommentSheetScope.reset();
    FeedActiveEvent.reset();
    FeedChrome.hide();

    bloc = _StubChatRoomBloc();
    rooms = _StubGetEventRoom();
    await GetIt.I.reset();
    GetIt.I.registerFactory<ChatRoomBloc>(() => bloc);
    GetIt.I.registerSingleton<GetEventRoomUseCase>(rooms);
    GetIt.I.registerSingleton<AuthService>(_StubAuth());
  });

  tearDown(() async {
    AppConfigRepository.current = const AppConfig();
    CommentCounts.instance.clear();
    CommentSheetScope.reset();
    FeedActiveEvent.reset();
    await GetIt.I.reset();
  });

  /// Fixed pumps rather than [WidgetTester.pumpAndSettle]: these carry
  /// animations that never end, so settling waits for a still frame that never
  /// comes.
  Future<void> settle(WidgetTester t) async {
    for (var i = 0; i < 6; i++) {
      await t.pump(const Duration(milliseconds: 40));
    }
  }

  Future<void> openSheetOn(WidgetTester t, EventDiscovery on) async {
    late BuildContext ctx;
    await t.pumpWidget(ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData.dark().copyWith(extensions: [AppThemeExtension.dark]),
        home: Scaffold(
          body: Builder(builder: (context) {
            ctx = context;
            return const SizedBox.expand();
          }),
        ),
      ),
    ));
    EventCommentPage.show(ctx, on);
    await settle(t);
  }

  /// The swipe, as the feed reports it.
  Future<void> swipeTo(WidgetTester t, EventDiscovery next) async {
    FeedActiveEvent.publish(next);
    await settle(t);
  }

  group('the sheet follows the feed', () {
    testWidgets('a swipe rebinds it to the post now in front', (t) async {
      await openSheetOn(t, _event('e1', name: 'Graduation'));
      expect(find.text('Graduation'), findsOneWidget);
      expect(rooms.asked, ['e1']);

      await swipeTo(t, _event('e2', name: 'Beach Wedding'));

      // The header and the room move together. Before this, both stayed on e1
      // while the picture above showed e2.
      expect(find.text('Beach Wedding'), findsOneWidget);
      expect(find.text('Graduation'), findsNothing);
      expect(find.text('by Kwame Studios'), findsOneWidget);
      expect(rooms.asked, ['e1', 'e2']);
      expect(bloc.joinedRooms, ['room-e1', 'room-e2']);
    });

    testWidgets('it leaves the old room before joining the new one', (t) async {
      await openSheetOn(t, _event('e1'));
      await swipeTo(t, _event('e2'));

      // Staying joined to the room of a post the reader has scrolled past
      // keeps its socket traffic arriving, and the sheet would paint it.
      expect(bloc.kinds, contains('ChatRoomLeft'));
      expect(bloc.kinds.indexOf('ChatRoomLeft'),
          lessThan(bloc.kinds.lastIndexOf('ChatRoomJoined')));
    });

    testWidgets('the same post arriving again is not a swipe', (t) async {
      await openSheetOn(t, _event('e1'));
      await swipeTo(t, _event('e1'));

      // Cards publish from lifecycle callbacks that fire for reasons which
      // have nothing to do with the feed moving. Rejoining on each one would
      // throw the thread away under somebody reading it.
      expect(bloc.joinedRooms, ['room-e1']);
      expect(rooms.asked, ['e1']);
    });

    testWidgets('a room that answers after the reader has swiped on is dropped',
        (t) async {
      await openSheetOn(t, _event('e1'));
      expect(rooms.asked, ['e1']);

      // Two swipes before anything is allowed to settle.
      FeedActiveEvent.publish(_event('e2'));
      await t.pump();
      FeedActiveEvent.publish(_event('e3'));
      await settle(t);

      // Whichever lookup answers last must not win — only the post actually in
      // front may be joined.
      expect(rooms.asked, ['e1', 'e2', 'e3']);
      expect(bloc.joinedRooms.last, 'room-e3');
    });
  });

  group('a post with comments off', () {
    testWidgets('locks instead of showing the last post\'s thread', (t) async {
      await openSheetOn(t, _event('e1'));
      expect(find.byType(TextField), findsOneWidget);

      await swipeTo(
          t, _event('e2', name: 'Private Shoot', commentsEnabled: false));

      expect(find.text('Private Shoot'), findsOneWidget);
      expect(find.text('Comments are turned off'), findsOneWidget);
      // The thread and its input bar are gone, not merely covered.
      expect(find.byType(ListView), findsNothing);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('offers nothing to type into', (t) async {
      await openSheetOn(t, _event('e1', commentsEnabled: false));

      // A disabled field still reads as something to try, so the bar goes
      // rather than greys out.
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Comments are turned off'), findsOneWidget);
    });

    testWidgets('is never asked for a room', (t) async {
      await openSheetOn(t, _event('e1', commentsEnabled: false));

      // There is nothing to fetch, and asking would put a spinner on a sheet
      // that is never going to fill.
      expect(rooms.asked, isEmpty);
      expect(bloc.joinedRooms, isEmpty);
    });

    testWidgets('unlocks again on a post that allows them', (t) async {
      await openSheetOn(t, _event('e1', commentsEnabled: false));
      expect(find.text('Comments are turned off'), findsOneWidget);

      await swipeTo(t, _event('e2'));

      expect(find.text('Comments are turned off'), findsNothing);
      expect(bloc.joinedRooms, ['room-e2']);
      expect(find.byType(TextField), findsOneWidget);
    });
  });

  group('the card claims the front position', () {
    /// The feed, as both real ones build it: a vertical pager of full-bleed
    /// cards with the active index driven by onPageChanged.
    Widget feed(ValueNotifier<int> active, List<EventDiscovery> events) =>
        ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (_, __) => MaterialApp(
            theme:
                ThemeData.dark().copyWith(extensions: [AppThemeExtension.dark]),
            home: Scaffold(
              body: BlocProvider<DiscoveryBloc>(
                create: (_) => _StubDiscoveryBloc(),
                child: PageView.builder(
                  // Each card carries its own horizontal media carousel, so
                  // the feed's pager has to be named to be flung.
                  key: const Key('feed'),
                  scrollDirection: Axis.vertical,
                  itemCount: events.length,
                  onPageChanged: (i) => active.value = i,
                  itemBuilder: (_, i) => FullBleedEventCard(
                    key: ValueKey(events[i].id),
                    event: events[i],
                    cardIndex: i,
                    activeCardIndex: active,
                    onTap: () {},
                    onHide: () {},
                  ),
                ),
              ),
            ),
          ),
        );

    testWidgets(
        'the card the feed opens on, with no page change to announce it',
        (t) async {
      final active = ValueNotifier<int>(0);
      await t.pumpWidget(feed(active, [_event('e1'), _event('e2')]));
      await settle(t);

      // Nothing fires onPageChanged for the page a pager starts on, so the
      // opening card has to claim the position itself — otherwise the first
      // sheet of a session opens with nobody in front.
      expect(FeedActiveEvent.current.value?.id, 'e1');
    });

    testWidgets('and hands it over when the reader swipes', (t) async {
      final active = ValueNotifier<int>(0);
      await t.pumpWidget(feed(active, [_event('e1'), _event('e2')]));
      await settle(t);

      await t.fling(find.byKey(const Key('feed')), const Offset(0, -400), 1200);
      await settle(t);

      expect(active.value, 1);
      expect(FeedActiveEvent.current.value?.id, 'e2');
    });
  });
}
