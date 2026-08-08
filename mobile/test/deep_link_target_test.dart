import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The shape of DeepLinkTarget's event case: navigates from _resolve() with no
/// `await` before the navigation, so it runs synchronously if called directly
/// from initState — inside the push of this very route.
class _Target extends StatefulWidget {
  const _Target();
  @override
  State<_Target> createState() => _TargetState();
}

class _TargetState extends State<_Target> {
  @override
  void initState() {
    super.initState();
    // The fix: defer past the frame so the navigator is no longer locked.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _resolve();
    });
  }

  Future<void> _resolve() async {
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('album'))),
    );
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

void main() {
  testWidgets('a deep-link target resolves without locking the navigator',
      (t) async {
    final nav = GlobalKey<NavigatorState>();
    await t.pumpWidget(MaterialApp(
      navigatorKey: nav,
      home: const Scaffold(body: Text('home')),
    ));

    nav.currentState!.push(MaterialPageRoute<void>(builder: (_) => const _Target()));
    await t.pumpAndSettle();

    expect(t.takeException(), isNull, reason: 'must not throw while locked');
    expect(find.text('album'), findsOneWidget, reason: 'link opened');

    // The reported symptom was that nothing could navigate afterwards.
    await nav.currentState!.maybePop();
    await t.pumpAndSettle();
    expect(t.takeException(), isNull, reason: 'navigator must not be stuck');
    expect(find.text('home'), findsOneWidget);
  });
}
