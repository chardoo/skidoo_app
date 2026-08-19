import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The rule the Chats app bar uses to decide whether to draw a back arrow.
///
/// Chats is a bottom-nav destination inside Home's `IndexedStack`, so it has no
/// route of its own — it shares Home's. An arrow belongs there only if Home
/// itself was pushed onto something.
Widget leadingFor(BuildContext context) =>
    (ModalRoute.of(context)?.canPop ?? false)
        ? const BackButton()
        : const SizedBox.shrink();

/// A stand-in for Home: a tab page that shares the route it is drawn in.
class _TabPage extends StatelessWidget {
  const _TabPage();

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: leadingFor(context),
          title: const Text('Chats'),
        ),
        body: Builder(
          builder: (c) => Text('canPop=${Navigator.of(c).canPop()}'),
        ),
      );
}

void main() {
  group('the Chats back arrow', () {
    testWidgets('stays away when a route is pushed above Home', (t) async {
      // Exactly the deep-link launch: `/home` is the first route, and the
      // link's resolver is pushed on top of it while Home is still building.
      final nav = GlobalKey<NavigatorState>();
      await t.pumpWidget(MaterialApp(
        navigatorKey: nav,
        home: const _TabPage(),
      ));

      nav.currentState!.push(MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('deeplink/resolver')),
      ));
      await t.pumpAndSettle();

      // Home is offstage under the resolver but still built — which is the
      // whole trouble: it keeps whatever its app bar decided.
      //
      // The stack-wide question now answers yes, and that is what used to put
      // the arrow on the Chats tab; pressing it popped Home itself off an
      // otherwise empty navigator, which is the black screen.
      expect(find.text('canPop=true', skipOffstage: false), findsOneWidget);
      // The route-scoped question is the one that is actually about this page.
      expect(find.byType(BackButton, skipOffstage: false), findsNothing);
    });

    testWidgets('appears when the page itself was pushed', (t) async {
      final nav = GlobalKey<NavigatorState>();
      await t.pumpWidget(MaterialApp(
        navigatorKey: nav,
        home: const Scaffold(body: Text('home')),
      ));

      nav.currentState!.push(MaterialPageRoute<void>(
        builder: (_) => const _TabPage(),
      ));
      await t.pumpAndSettle();

      expect(find.byType(BackButton), findsOneWidget);
    });

    testWidgets('goes away again once the route above Home is popped',
        (t) async {
      // The arrow was read once and cached: it survived the resolver it came
      // from. Reading it from the route rebuilds when the answer changes.
      final nav = GlobalKey<NavigatorState>();
      await t.pumpWidget(MaterialApp(
        navigatorKey: nav,
        home: const _TabPage(),
      ));

      nav.currentState!.push(MaterialPageRoute<void>(
        builder: (_) => const _TabPage(),
      ));
      await t.pumpAndSettle();
      expect(find.byType(BackButton), findsOneWidget);

      nav.currentState!.pop();
      await t.pumpAndSettle();
      expect(find.byType(BackButton), findsNothing);
    });
  });

  test("Home's tabs never ask the navigator whether it can pop", () {
    // These four are drawn inside HomePage's IndexedStack, sharing its route.
    // `Navigator.of(context).canPop()` reports on the whole stack, so any route
    // above Home makes it say yes; it also registers no dependency, so the
    // answer it gives is the one from whenever the tab happened to build.
    const tabs = [
      'lib/features/chat/presentation/pages/chat_rooms_page.dart',
      'lib/features/notifications/presentation/pages/notifications_page.dart',
      'lib/features/user_profile/presentation/pages/user_profile_page.dart',
      'lib/features/home/presentation/pages/home_navigation_page.dart',
    ];

    for (final path in tabs) {
      final file = File(path);
      expect(file.existsSync(), isTrue, reason: '$path has moved');
      // Comments stripped: the fix in chat_rooms_page.dart explains itself by
      // naming the call it stopped making.
      final code = file
          .readAsLinesSync()
          .where((l) => !l.trimLeft().startsWith('//'))
          .join('\n');
      expect(
        code,
        isNot(contains('canPop()')),
        reason: '$path is a tab of Home, not a route — ask '
            'ModalRoute.of(context)?.canPop instead, and pop with '
            'AppBackButton/maybePop so the last route cannot be popped away.',
      );
    }
  });
}
