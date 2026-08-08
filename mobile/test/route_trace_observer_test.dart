import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/navigation/route_trace_observer.dart';

class AlbumPage extends StatelessWidget {
  const AlbumPage({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(body: Text('album'));
}

class GuestFeedPage extends StatelessWidget {
  const GuestFeedPage({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(body: Text('guest'));
}

void main() {
  testWidgets('names the widget behind an unnamed route', (t) async {
    final logs = <String>[];
    final original = debugPrint;
    debugPrint = (String? m, {int? wrapWidth}) => logs.add(m ?? '');

    final nav = GlobalKey<NavigatorState>();
    await t.pumpWidget(MaterialApp(
      navigatorKey: nav,
      navigatorObservers: [RouteTraceObserver.instance],
      home: const AlbumPage(),
    ));

    // Exactly the interloper's shape: untyped, unnamed.
    nav.currentState!.push(MaterialPageRoute(builder: (_) => const GuestFeedPage()));
    await t.pumpAndSettle();
    debugPrint = original; // must be restored before the test ends

    final identified = logs.where((l) => l.contains('renders:')).join('\n');
    expect(identified, contains('GuestFeedPage'),
        reason: 'the diagnostic must name the screen. logs:\n${logs.join("\n")}');
  });
}
