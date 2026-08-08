import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The resolver's swap logic: replace *this* route, wherever it sits.
class _Resolver extends StatefulWidget {
  const _Resolver({required this.delay});
  final Duration delay;
  @override
  State<_Resolver> createState() => _ResolverState();
}

class _ResolverState extends State<_Resolver> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future<void>.delayed(widget.delay); // the fetch
      if (!mounted) return;
      _swapSelfFor(MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('album'))));
    });
  }

  void _swapSelfFor(Route<void> destination) {
    final route = ModalRoute.of(context);
    final navigator = Navigator.of(context);
    if (route == null) {
      navigator.push(destination);
      return;
    }
    if (route.isCurrent) {
      navigator.pushReplacement(destination);
      return;
    }
    navigator.removeRoute(route);
    navigator.push(destination);
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Opening…')));
}

void main() {
  testWidgets('resolver removes itself even when something lands on top first',
      (t) async {
    final nav = GlobalKey<NavigatorState>();
    await t.pumpWidget(MaterialApp(
      navigatorKey: nav,
      home: const Scaffold(body: Text('home')),
    ));

    nav.currentState!.push(MaterialPageRoute<void>(
        builder: (_) => const _Resolver(delay: Duration(milliseconds: 100))));
    await t.pump();

    // Something arrives while the fetch is still in flight — a notification
    // route, a second link, anything. The resolver is no longer on top.
    nav.currentState!.push(MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('interloper'))));
    await t.pumpAndSettle();

    // Fetch completes. The link the person tapped must WIN — the album has to
    // end up on top, not buried under whatever overtook it.
    await t.pump(const Duration(milliseconds: 200));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.text('album'), findsOneWidget,
        reason: 'the destination must be visible, not one route down');
    expect(find.text('interloper'), findsNothing);
    expect(find.text('Opening…'), findsNothing,
        reason: 'the resolver must never be left in the stack');

    // Back goes to the interloper, then home — the resolver is gone for good.
    nav.currentState!.pop();
    await t.pumpAndSettle();
    expect(find.text('interloper'), findsOneWidget);
    nav.currentState!.pop();
    await t.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
  });
}
