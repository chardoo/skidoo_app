import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/config/app_links_config.dart';
import 'package:jperg_app/core/deep_links/deep_link.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/chat/presentation/widgets/message_bubble.dart';
import 'package:jperg_app/features/chat/presentation/widgets/shared_link_card.dart';
import 'package:jperg_app/models/chat/chat_message.dart';

/// Sharing an event into a chat used to send `event.pictures.first` and
/// nothing else. The recipient got a photograph: no album name, no count, no
/// way to reach the event it came from — and tapping it opened the full-screen
/// image viewer, which is the one place the event is not.
///
/// So a shared event travels as a picture *and* a body — the album's name on
/// one line, its link on the next — and the bubble reads that back as a card.
/// A shared photo carries no link and is still just a photo, which is what a
/// shared photo should be.
void main() {
  final eventUrl = AppLinksConfig.urlFor(
    const DeepLink(DeepLinkKind.event, id: 'evt-1'),
  );
  final photoUrl = AppLinksConfig.urlFor(
    const DeepLink(DeepLinkKind.picture, id: 'pic-1'),
  );

  group('reading a shared message', () {
    test('an album name above a link is a card', () {
      final shared = SharedLinkContent.parse('Chale Wote 2026\n$eventUrl');

      expect(shared, isNotNull);
      expect(shared!.title, 'Chale Wote 2026');
      expect(shared.link.kind, DeepLinkKind.event);
      expect(shared.link.id, 'evt-1');
      expect(shared.kindLabel, 'Event');
      expect(shared.leadingText, isNull);
    });

    test('what the sender typed is kept apart from it', () {
      final shared =
          SharedLinkContent.parse('you were here!\nChale Wote 2026\n$eventUrl');

      expect(shared!.leadingText, 'you were here!');
      expect(shared.title, 'Chale Wote 2026');
    });

    test('a photo link reads as a photo', () {
      final shared = SharedLinkContent.parse('Chale Wote 2026\n$photoUrl');

      expect(shared!.link.kind, DeepLinkKind.picture);
      expect(shared.kindLabel, 'Photo');
    });

    test('somebody else\'s site is not our card', () {
      // instagram.com/p/{id} is our photo path, and flickr.com/photos/{u} is
      // our my-photos path. On a link somebody else wrote, the path alone is
      // not evidence of anything — see [ExternalLink.open].
      expect(
        SharedLinkContent.parse('A photo\nhttps://instagram.com/p/abc'),
        isNull,
      );
    });

    test('a plain message is not a card', () {
      expect(SharedLinkContent.parse('hey'), isNull);
      expect(SharedLinkContent.parse('hey\nhow are you'), isNull);
    });

    test('a link with nothing above it is not a card', () {
      // There would be nothing to write on it.
      expect(SharedLinkContent.parse(eventUrl), isNull);
      expect(SharedLinkContent.parse('\n$eventUrl'), isNull);
    });
  });

  group('the format has one owner', () {
    // The share sheet writes this and the bubble reads it, from two different
    // features. A round trip is the only thing that keeps them honest.
    test('what a share composes is what the bubble reads', () {
      final body = SharedLinkContent.compose(
        title: 'Chale Wote 2026',
        url: eventUrl,
      );

      final shared = SharedLinkContent.parse(body!);
      expect(shared!.title, 'Chale Wote 2026');
      expect(shared.link.kind, DeepLinkKind.event);
      expect(shared.link.id, 'evt-1');
    });

    test('a share with no link composes nothing', () {
      // Which is what a shared photograph is: a picture, no body.
      expect(SharedLinkContent.compose(title: 'Anything', url: ''), isNull);
    });

    test('a title with a newline in it cannot forge the link line', () {
      // An event named "x\nhttps://evil.example" would otherwise put its own
      // last line under the real one.
      final body = SharedLinkContent.compose(
        title: 'Party\nhttps://evil.example/p/1',
        url: eventUrl,
      );

      final shared = SharedLinkContent.parse(body!);
      expect(shared!.url, eventUrl, reason: 'the real link must be the last line');
      expect(shared.link.id, 'evt-1');
    });
  });

  group('drawing it', () {
    setUp(() {
      // A real phone's worth of room. The default 800x600 surface is shorter
      // than the design height every `.h` here is scaled against, so anything
      // full-height — the sheet the tap below opens — overflows it.
      final view = TestWidgetsFlutterBinding.ensureInitialized()
          .platformDispatcher
          .views
          .first;
      view.physicalSize = const Size(390 * 3, 844 * 3);
      view.devicePixelRatio = 3;
    });

    Widget host(Widget child) => ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (_, __) => MaterialApp(
            theme: ThemeData.dark()
                .copyWith(extensions: [AppThemeExtension.dark]),
            home: Scaffold(body: SingleChildScrollView(child: child)),
          ),
        );

    ChatMessage message({
      required String content,
      String? imageUrl,
      bool paidPreview = false,
    }) =>
        ChatMessage(
          id: 'm1',
          roomId: 'r1',
          senderId: 'u1',
          senderName: 'Ama',
          senderRole: 'user',
          content: content,
          imageUrl: imageUrl,
          paidPreview: paidPreview,
          createdAt: DateTime.utc(2026, 9, 26),
        );

    testWidgets('a shared event draws a card, not a bare photo', (t) async {
      await t.pumpWidget(host(MessageBubble(
        message: message(
          content: 'Chale Wote 2026\n$eventUrl',
          imageUrl: 'https://cdn.example.com/cover.jpg',
        ),
        isMe: false,
      )));
      await t.pump();

      expect(find.byType(SharedLinkCard), findsOneWidget);
      expect(find.text('Chale Wote 2026'), findsOneWidget);
      expect(find.text('Event'), findsOneWidget);
    });

    testWidgets('the link itself is never shown as text', (t) async {
      // It is what the card *does*, not something to read.
      await t.pumpWidget(host(MessageBubble(
        message: message(
          content: 'Chale Wote 2026\n$eventUrl',
          imageUrl: 'https://cdn.example.com/cover.jpg',
        ),
        isMe: false,
      )));
      await t.pump();

      expect(find.textContaining(eventUrl), findsNothing);
    });

    testWidgets('what the sender typed is still said', (t) async {
      await t.pumpWidget(host(MessageBubble(
        message: message(
          content: 'you were here!\nChale Wote 2026\n$eventUrl',
          imageUrl: 'https://cdn.example.com/cover.jpg',
        ),
        isMe: false,
      )));
      await t.pump();

      expect(find.textContaining('you were here!'), findsOneWidget);
      expect(find.text('Chale Wote 2026'), findsOneWidget);
    });

    testWidgets('a shared photo is a preview of the photo', (t) async {
      // Shared from Found or the viewer, a photo carries its own /p/ link, so
      // it is a card too — a reference to the picture, not a copy of it
      // sitting full-height in the thread.
      await t.pumpWidget(host(MessageBubble(
        message: message(
          content: 'Chale Wote 2026\n$photoUrl',
          imageUrl: 'https://cdn.example.com/p.jpg',
        ),
        isMe: false,
      )));
      await t.pump();

      expect(find.byType(SharedLinkCard), findsOneWidget);
      expect(find.text('Photo'), findsOneWidget);
    });

    testWidgets('a photo sent with no link is unchanged', (t) async {
      // Nothing to open, so nothing to preview: the plain image message every
      // other part of chat sends.
      await t.pumpWidget(host(MessageBubble(
        message: message(content: '', imageUrl: 'https://cdn.example.com/p.jpg'),
        isMe: false,
      )));
      await t.pump();

      expect(find.byType(SharedLinkCard), findsNothing);
    });

    testWidgets('the cover is a fixed preview band, not the asset', (t) async {
      await t.pumpWidget(host(MessageBubble(
        message: message(
          content: 'Chale Wote 2026\n$eventUrl',
          imageUrl: 'https://cdn.example.com/cover.jpg',
        ),
        isMe: false,
      )));
      await t.pump();

      final band = t.widget<AspectRatio>(find.descendant(
        of: find.byType(SharedLinkCard),
        matching: find.byType(AspectRatio),
      ));
      expect(band.aspectRatio, SharedLinkCard.coverAspect);
    });

    testWidgets('tapping it goes to the link, never to the zoom viewer',
        (t) async {
      // The bubble's own image opens a full-screen zoom viewer, and nested
      // inside a card the deeper gesture wins the arena — so the card draws
      // its own cover instead of wrapping that one. If this regresses, a
      // shared event looks like an event and behaves like a photograph.
      await t.pumpWidget(host(MessageBubble(
        message: message(
          content: 'Chale Wote 2026\n$eventUrl',
          imageUrl: 'https://cdn.example.com/cover.jpg',
        ),
        isMe: false,
      )));
      await t.pump();

      await t.tap(find.byType(SharedLinkCard));
      await t.pumpAndSettle();

      // The zoom viewer is the thing that must not happen. It is the only
      // InteractiveViewer in this tree.
      expect(find.byType(InteractiveViewer), findsNothing,
          reason: 'the card opened the photo viewer instead of the link');

      // What did happen: the tap went to [ExternalLink.open]. With no
      // DeepLinkService wired up in a widget test it falls through to the
      // leaving sheet, which is proof enough that the link path ran — in the
      // app the service is there and it navigates instead.
      expect(find.text("You're leaving the app"), findsOneWidget);
    });

    testWidgets('a paid photo is still marked as a card', (t) async {
      // The card draws its own cover instead of the bubble's image, and the
      // mark lives on the image — so it had to be carried across with it. A
      // preview is a copy, and every copy of an unbought photo is marked.
      await t.pumpWidget(host(MessageBubble(
        message: message(
          content: 'Chale Wote 2026\n$photoUrl',
          imageUrl: 'https://cdn.example.com/priced.jpg',
          paidPreview: true,
        ),
        isMe: false,
      )));
      await t.pump();

      expect(
        find.descendant(
          of: find.byType(SharedLinkCard),
          matching: find.byType(SvgPicture),
        ),
        findsOneWidget,
        reason: 'the paid mark did not survive the move onto the card',
      );
    });

    testWidgets('an ordinary shared photo carries no mark', (t) async {
      await t.pumpWidget(host(MessageBubble(
        message: message(
          content: 'Chale Wote 2026\n$photoUrl',
          imageUrl: 'https://cdn.example.com/free.jpg',
        ),
        isMe: false,
      )));
      await t.pump();

      expect(find.byType(SvgPicture), findsNothing);
    });

    testWidgets('a typed link with no picture stays a typed link', (t) async {
      // MentionText already makes it tappable; it is not a card.
      await t.pumpWidget(host(MessageBubble(
        message: message(content: 'Chale Wote 2026\n$eventUrl'),
        isMe: false,
      )));
      await t.pump();

      expect(find.byType(SharedLinkCard), findsNothing);
    });
  });
}
