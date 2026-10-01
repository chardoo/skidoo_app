/// Disposing a dialog's controller on the line after the `await`.
///
/// Reported from a running build as three exceptions after closing the group
/// rename dialog:
///
///   A TextEditingController was used after being disposed.
///   A RenderFlex overflowed by 99746 pixels on the bottom.
///   'framework.dart': Failed assertion: '_dependents.isEmpty': is not true.
///
/// One fault. `showDialog`'s future completes when the route is popped, while
/// the dialog's widgets stay mounted for the exit transition — so a
/// `controller.dispose()` after the `await` runs with a live `TextField` still
/// painting from it.
///
/// The absurd overflow is the giveaway that it is not a layout bug: a disposed
/// controller leaves the editable without usable text metrics and the intrinsic
/// height comes back as nonsense.
///
/// The first test fails on the old pattern and passes on the new one, which is
/// the only reason this file is worth having. The second pins the behaviour the
/// fix must not cost: the value still comes back.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/widgets/text_prompt_dialog.dart';

/// Pumps past the exit transition — which is exactly the window the old code
/// got wrong. `pumpAndSettle` alone would also do it; this says why.
Future<void> settleTheDialogOut(WidgetTester tester) async {
  await tester.pump();                                   // start the reverse
  await tester.pump(const Duration(milliseconds: 400));  // past the fade
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the field survives the closing animation', (tester) async {
    String? answer;

    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () async {
              answer = await showTextPromptDialog<String>(
                context: context,
                initialText: 'Bridal party',
                builder: (dialogContext, controller) => AlertDialog(
                  content: TextField(controller: controller, autofocus: true),
                  actions: [
                    TextButton(
                      onPressed: () =>
                          Navigator.of(dialogContext).pop(controller.text),
                      child: const Text('Save'),
                    ),
                  ],
                ),
              );
            },
            child: const Text('Rename'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();
    expect(find.text('Bridal party'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Bridal party 2026');
    await tester.tap(find.text('Save'));
    await settleTheDialogOut(tester);

    // The assertion that matters is the absence of an exception during those
    // frames; `takeException` returns null only if nothing was thrown.
    expect(tester.takeException(), isNull);
    expect(answer, 'Bridal party 2026');
  });

  testWidgets('cancelling is still a null, not an empty string', (tester) async {
    // Three of the five call sites branch on `name == null` to mean "they
    // changed their mind" and treat '' as a separate case. A host that
    // swallowed the distinction would make Cancel save a blank name.
    String? answer = 'untouched';

    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () async {
              answer = await showTextPromptDialog<String>(
                context: context,
                initialText: 'Bridal party',
                builder: (dialogContext, controller) => AlertDialog(
                  content: TextField(controller: controller),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              );
            },
            child: const Text('Rename'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await settleTheDialogOut(tester);

    expect(tester.takeException(), isNull);
    expect(answer, isNull);
  });

  testWidgets('a second open starts from the initial text again',
      (tester) async {
    // The controller is per-route, so reopening must not show what was typed
    // last time. A host that cached one controller across opens would.
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () => showTextPromptDialog<String>(
              context: context,
              initialText: 'Bridal party',
              builder: (dialogContext, controller) => AlertDialog(
                content: TextField(controller: controller),
                actions: [
                  TextButton(
                    onPressed: () =>
                        Navigator.of(dialogContext).pop(controller.text),
                    child: const Text('Save'),
                  ),
                ],
              ),
            ),
            child: const Text('Rename'),
          ),
        ),
      ),
    ));

    for (var i = 0; i < 2; i++) {
      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();
      expect(find.text('Bridal party'), findsOneWidget,
          reason: 'open #${i + 1} should start from the initial text');
      await tester.enterText(find.byType(TextField), 'scribble');
      await tester.tap(find.text('Save'));
      await settleTheDialogOut(tester);
    }

    expect(tester.takeException(), isNull);
  });
}
