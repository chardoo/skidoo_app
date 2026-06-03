import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Mirrors lib/app.dart's _SelectionOverlay: SelectionArea backed by a local
// Overlay. Guards against a regression where wrapping the whole app for
// copyable text suppresses the semantics tree — buttons, static text and
// labeled icons must still be exposed (for accessibility + e2e role/label
// queries). See the investigation in the chat history: the wrapper was
// verified to produce an identical semantics tree to the unwrapped app.
class _SelectionOverlay extends StatelessWidget {
  const _SelectionOverlay({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Overlay(
      initialEntries: [
        OverlayEntry(
          maintainState: true,
          builder: (_) => SelectionArea(child: child),
        ),
      ],
    );
  }
}

Widget _probe() => Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () {},
        ),
      ),
      body: Column(
        children: [
          const Text('Hello heading'),
          ElevatedButton(onPressed: () {}, child: const Text('Log in')),
          const Icon(Icons.star, semanticLabel: 'Star icon'),
        ],
      ),
    );

void main() {
  testWidgets('wrapper preserves the same semantics as the plain app',
      (tester) async {
    final handle = tester.ensureSemantics();

    // Plain (no wrapper) — baseline.
    await tester.pumpWidget(MaterialApp(home: _probe()));
    await tester.pumpAndSettle();
    final plain = {
      'btn': find.bySemanticsLabel('Log in').evaluate().length,
      'text': find.bySemanticsLabel('Hello heading').evaluate().length,
      'icon': find.bySemanticsLabel('Star icon').evaluate().length,
    };

    // Wrapped exactly like lib/app.dart.
    await tester.pumpWidget(MaterialApp(
      builder: (_, child) => _SelectionOverlay(child: child!),
      home: _probe(),
    ));
    await tester.pumpAndSettle();
    final wrapped = {
      'btn': find.bySemanticsLabel('Log in').evaluate().length,
      'text': find.bySemanticsLabel('Hello heading').evaluate().length,
      'icon': find.bySemanticsLabel('Star icon').evaluate().length,
    };

    // The wrapper must not drop any of these nodes.
    expect(wrapped['btn'], greaterThanOrEqualTo(1));
    expect(wrapped['text'], greaterThanOrEqualTo(1));
    expect(wrapped['icon'], greaterThanOrEqualTo(1));
    // And it must match the plain tree exactly.
    expect(wrapped, equals(plain));

    handle.dispose();
  });
}
