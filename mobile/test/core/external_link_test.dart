import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/deep_links/deep_link.dart';
import 'package:jperg_app/core/navigation/external_link.dart';
import 'package:jperg_app/features/chat/presentation/widgets/mention_text.dart';

/// Links written by other people.
///
/// Two halves, and both matter in a chat: a link to something in this app
/// should open that screen rather than a browser, and anything else should say
/// where it is about to take you before it goes.
///
/// The URL matching is the part worth pinning hardest. Over-matching is not
/// cosmetic — every false positive turns a word in somebody's sentence into a
/// tap target that opens a "you're leaving the app" sheet for something that
/// was never a link.
Widget host(Widget child) => MaterialApp(
      home: Scaffold(body: child),
    );

MentionText body(String text) => MentionText(
      text: text,
      style: const TextStyle(fontSize: 14),
      mentionStyle: const TextStyle(fontWeight: FontWeight.bold),
    );

/// The runs the widget actually built, so the assertions are about what was
/// rendered rather than about the regex in isolation.
List<InlineSpan> runsOf(WidgetTester t) {
  final widget = t.widget<Text>(find.byType(Text));
  final span = widget.textSpan;
  return span is TextSpan ? (span.children ?? const []) : const [];
}

/// Which runs are tappable — the links.
List<String> linksIn(WidgetTester t) => [
      for (final s in runsOf(t))
        if (s is TextSpan && s.recognizer is TapGestureRecognizer)
          s.text ?? '',
    ];

void main() {
  group('what counts as a link', () {
    testWidgets('an explicit https address does', (t) async {
      await t.pumpWidget(host(body('look at https://jperg.com/e/abc123')));

      expect(linksIn(t), ['https://jperg.com/e/abc123']);
    });

    testWidgets('a bare host does', (t) async {
      // How people actually type them.
      await t.pumpWidget(host(body('jperg.com/e/abc123 is the one')));

      expect(linksIn(t), ['jperg.com/e/abc123']);
    });

    testWidgets('a trailing full stop is not part of the address', (t) async {
      // "have a look at jperg.com." — the stop ends the sentence, not the host.
      await t.pumpWidget(host(body('have a look at jperg.com.')));

      expect(linksIn(t), ['jperg.com']);
    });

    testWidgets('a decimal is not a link', (t) async {
      // The case over-matching gets wrong first, and the one that would turn
      // prose into tap targets.
      await t.pumpWidget(host(body('it costs 3.50 or so')));

      expect(linksIn(t), isEmpty);
    });

    testWidgets('ordinary prose is left alone', (t) async {
      await t.pumpWidget(host(body('nice shot, send me the rest')));

      // No spans at all — it falls back to a plain Text, which is the cheap
      // path every ordinary message should take.
      expect(runsOf(t), isEmpty);
      expect(find.text('nice shot, send me the rest'), findsOneWidget);
    });

    testWidgets('the text around a link survives intact', (t) async {
      await t.pumpWidget(host(body('see jperg.com/e/1 today')));

      final text = [
        for (final s in runsOf(t))
          if (s is TextSpan) s.text ?? '',
      ].join();

      expect(text, 'see jperg.com/e/1 today');
    });
  });

  group('what a link resolves to', () {
    test('an event link is one of ours, and names the event', () {
      // ExternalLink asks parseDeepLink before it offers to leave, so what that
      // returns is what decides in-app versus browser.
      final link = parseDeepLink(Uri.parse('https://jperg.com/e/evt-1'));

      expect(link, isNotNull);
      expect(link!.kind, DeepLinkKind.event);
      expect(link.id, 'evt-1');
    });

    test('a photo link is ours too', () {
      final link = parseDeepLink(Uri.parse('https://jperg.com/p/pic-1'));

      expect(link?.kind, DeepLinkKind.picture);
      expect(link?.id, 'pic-1');
    });

    test('somebody else\'s site is not', () {
      // Which is what sends it to the "you're leaving the app" sheet.
      expect(parseDeepLink(Uri.parse('https://example.com/anything')), isNull);
    });
  });

  group('a foreign site that shares our path grammar', () {
    // The paths this app claims are short and ordinary, and other sites use
    // the same ones. `parseDeepLink` reads the path only — correctly, since
    // the links it was written for come from the OS, which has already checked
    // the domain — so on a link out of a stranger's message the host has to be
    // checked separately, and [ExternalLink.isOurs] is where.
    //
    // Getting this wrong is not a near miss: the link never reaches the
    // "you're leaving the app" sheet at all. It opens a resolver, fetches an
    // id that belongs to somebody else's site, and fails.

    test('an Instagram post is not our photo link', () {
      final uri = Uri.parse('https://instagram.com/p/DHx123');

      // The path alone says "ours" — this is the trap.
      expect(parseDeepLink(uri)?.kind, DeepLinkKind.picture);
      // The host says otherwise, and the host wins.
      expect(ExternalLink.isOurs(uri), isFalse);
    });

    test('a Flickr photostream is not our my-photos link', () {
      final uri = Uri.parse('https://www.flickr.com/photos/someone/5312');

      expect(parseDeepLink(uri)?.kind, DeepLinkKind.myPhotos);
      expect(ExternalLink.isOurs(uri), isFalse);
    });

    test('a host that merely starts with ours is a stranger', () {
      expect(
        ExternalLink.isOurs(Uri.parse('https://jperg.com.example.net/e/1')),
        isFalse,
      );
    });

    test('our own domain, and its subdomains, are ours', () {
      // Subdomains so a staging build opens its own links rather than bouncing
      // the tester out to a browser.
      for (final url in [
        'https://jperg.com/e/evt-1',
        'https://www.jperg.com/e/evt-1',
        'https://staging.jperg.com/e/evt-1',
        'https://JPERG.COM/e/evt-1',
      ]) {
        expect(ExternalLink.isOurs(Uri.parse(url)), isTrue, reason: url);
      }
    });
  });
}
