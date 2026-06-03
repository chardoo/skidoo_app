import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skidoo_app/core/widgets/animations/app_animations.dart';

void main() {
  testWidgets('Reveal renders its child and settles to opacity 1', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Reveal(child: Text('hi'))),
    ));
    // Child is present immediately (only opacity/offset animate).
    expect(find.text('hi'), findsOneWidget);
    await tester.pumpAndSettle();
    final opacity = tester.widget<Opacity>(
      find.descendant(of: find.byType(Reveal), matching: find.byType(Opacity)),
    );
    expect(opacity.opacity, 1.0);
  });

  testWidgets('Reveal honours reduce-motion (no animation, instantly visible)',
      (tester) async {
    await tester.pumpWidget(const MediaQuery(
      data: MediaQueryData(disableAnimations: true),
      child: MaterialApp(
        home: Scaffold(body: Reveal(delay: Duration(seconds: 5), child: Text('x'))),
      ),
    ));
    // No pumpAndSettle / no waiting for the 5s delay: it should already be
    // fully visible because animations are disabled.
    await tester.pump();
    final opacity = tester.widget<Opacity>(
      find.descendant(of: find.byType(Reveal), matching: find.byType(Opacity)),
    );
    expect(opacity.opacity, 1.0);
    expect(find.text('x'), findsOneWidget);
  });
}
