import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The two inherited signals `FullBleedEventCard._wantsMusic` leans on to
/// decide whether it may make noise, exercised directly.
///
/// The card itself is expensive to mount — a bloc, a theme extension, screen
/// metrics and network images — and none of that is what could plausibly
/// break. What could is the mechanism: that `TickerMode` really does flip for
/// a tab hidden inside an `IndexedStack`, that it composes when Home nests one
/// inside another, and that `ModalRoute.isCurrent` really does go false when a
/// page is pushed over the feed but not when a sheet slides up.
///
/// [_Probe] reads them exactly as the card does. The source guard at the
/// bottom is what keeps the two from drifting apart.
class _Probe extends StatelessWidget {
  const _Probe({required this.onDecide});

  final void Function(bool tabVisible, bool routeIsCurrent) onDecide;

  @override
  Widget build(BuildContext context) {
    final tabVisible = TickerMode.valuesOf(context).enabled;
    final route = ModalRoute.of(context);
    final routeIsCurrent = route == null || route.isCurrent;
    onDecide(tabVisible, routeIsCurrent);
    return const SizedBox.shrink();
  }
}

void main() {
  group('tab visibility (TickerMode)', () {
    testWidgets('a tab hidden in an IndexedStack reports itself off screen',
        (t) async {
      final decisions = <bool>[];

      Widget build(int index) => MaterialApp(
            home: IndexedStack(
              index: index,
              children: [
                const SizedBox.shrink(),
                // How HomeNavigationPage gates its Found/Feed/Following tabs,
                // and now how HomePage gates its bottom-nav tabs.
                TickerMode(
                  enabled: index == 1,
                  child: _Probe(onDecide: (tab, _) => decisions.add(tab)),
                ),
              ],
            ),
          );

      await t.pumpWidget(build(1));
      expect(decisions.last, isTrue, reason: 'the feed tab is showing');

      // Switch to another tab. The feed stays mounted — that is the whole
      // point of IndexedStack, and the reason music would otherwise play on
      // over someone reading their messages.
      await t.pumpWidget(build(0));
      expect(decisions.last, isFalse);

      await t.pumpWidget(build(1));
      expect(decisions.last, isTrue,
          reason: 'coming back must resume, not stay silent');
    });

    testWidgets('nested TickerModes compose — either one hides the card',
        (t) async {
      // The real shape: HomePage gates its bottom-nav tab, and
      // HomeNavigationPage gates its pill tab inside it. A card is audible
      // only when both say yes.
      final decisions = <bool>[];

      Widget build({required bool bottomNav, required bool pill}) =>
          MaterialApp(
            home: TickerMode(
              enabled: bottomNav,
              child: TickerMode(
                enabled: pill,
                child: _Probe(onDecide: (tab, _) => decisions.add(tab)),
              ),
            ),
          );

      await t.pumpWidget(build(bottomNav: true, pill: true));
      expect(decisions.last, isTrue);

      await t.pumpWidget(build(bottomNav: true, pill: false));
      expect(decisions.last, isFalse, reason: 'on Found, not the Feed tab');

      await t.pumpWidget(build(bottomNav: false, pill: true));
      expect(decisions.last, isFalse, reason: 'on Chats, not on Home');
    });
  });

  group('route focus (ModalRoute)', () {
    testWidgets('a page pushed over the feed takes its sound', (t) async {
      final decisions = <bool>[];
      final nav = GlobalKey<NavigatorState>();

      await t.pumpWidget(MaterialApp(
        navigatorKey: nav,
        home: _Probe(onDecide: (_, route) => decisions.add(route)),
      ));
      expect(decisions.last, isTrue);

      // Opening an event's pictures, a photographer profile, a deep link.
      nav.currentState!.push(MaterialPageRoute<void>(
        builder: (_) => const SizedBox.shrink(),
      ));
      await t.pumpAndSettle();
      expect(decisions.last, isFalse);

      nav.currentState!.pop();
      await t.pumpAndSettle();
      expect(decisions.last, isTrue, reason: 'coming back resumes the card');
    });

    testWidgets('a modal sheet counts too — comments pause the music',
        (t) async {
      // Worth pinning because it is easy to assume otherwise: a sheet is a
      // route, and `isCurrent` does not distinguish it from a page. So opening
      // comments pauses, and closing them resumes. Telling the two apart would
      // need a RouteObserver<PageRoute>; if that is ever wanted, this test is
      // where the change announces itself.
      final decisions = <bool>[];
      final nav = GlobalKey<NavigatorState>();

      await t.pumpWidget(MaterialApp(
        navigatorKey: nav,
        home: _Probe(onDecide: (_, route) => decisions.add(route)),
      ));

      showModalBottomSheet<void>(
        context: nav.currentContext!,
        builder: (_) => const SizedBox(height: 200),
      );
      await t.pumpAndSettle();
      expect(decisions.last, isFalse);

      nav.currentState!.pop();
      await t.pumpAndSettle();
      expect(decisions.last, isTrue, reason: 'closing comments resumes it');
    });
  });

  test('the card still decides from those two signals', () {
    // [_Probe] mirrors the card rather than being it. This is what notices if
    // the card stops reading either signal — swapping one for a plain bool
    // field would compile, pass every other test, and leave music playing over
    // a hidden tab or under a full-screen page.
    final source = File(
      'lib/features/discovery/presentation/widgets/full_bleed_event_card.dart',
    );
    expect(source.existsSync(), isTrue, reason: 'the card has moved');
    final code = source.readAsStringSync();

    expect(code, contains('TickerMode.valuesOf(context).enabled'),
        reason: 'tab visibility must come from TickerMode, which composes '
            'across HomePage and HomeNavigationPage and reverses itself');
    expect(code, contains('ModalRoute.of(context)'),
        reason: 'route focus must come from the route, so a page pushed over '
            'the feed silences it');
    expect(code, contains('_activeMediaIsVideo'),
        reason: 'a video slide brings its own audio and must win');
  });
}
