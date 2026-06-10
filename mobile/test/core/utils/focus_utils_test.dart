import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skidoo_app/core/utils/focus_utils.dart';

void main() {
  group('isTextInputFocused', () {
    testWidgets('false when no text field is focused', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Text('hi'))));
      expect(isTextInputFocused(), isFalse);
    });

    testWidgets('true while a TextField has focus', (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: TextField(focusNode: node)),
      ));
      node.requestFocus();
      await tester.pump();

      expect(isTextInputFocused(), isTrue,
          reason: 'comment/search typing must be detected so feed shortcuts '
              '(space/j/k) do not hijack the keystroke');
    });

    testWidgets('naive primaryFocus widget check is NOT an EditableText',
        (tester) async {
      // Regression note: documents WHY the old guard failed.
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: TextField(focusNode: node)),
      ));
      node.requestFocus();
      await tester.pump();

      final widget = FocusManager.instance.primaryFocus?.context?.widget;
      expect(widget is EditableText, isFalse,
          reason: 'the focused node belongs to EditableText-internal Focus, '
              'so the old `is EditableText` guard never matched');
    });
  });
}
