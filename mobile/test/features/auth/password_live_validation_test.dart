import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skidoo_app/core/validators/validators.dart';

/// The password rules are strict — lower, upper, digit, symbol, min length —
/// and the validator reports them one at a time. Surfacing that only on submit
/// turns setting a password into a guessing game, so the forms now validate on
/// user interaction. These pin the rule order the user walks through.
void main() {
  test('reports the first unmet rule, in escalating order', () {
    expect(Validators.signupPasswordValidator(''), '*Password is required');
    expect(Validators.signupPasswordValidator('a'),
        contains('Minimum'));
    // Long enough, but still missing character classes.
    expect(Validators.signupPasswordValidator('abcdefghij'),
        '*Add an uppercase letter');
    expect(Validators.signupPasswordValidator('Abcdefghij'), '*Add a number');
    expect(Validators.signupPasswordValidator('Abcdefghij1'),
        startsWith('*Add a symbol'));
  });

  test('accepts a password meeting every rule', () {
    expect(Validators.signupPasswordValidator('Abcdefgh1!'), isNull);
  });

  testWidgets('onUserInteraction stays quiet until the user types',
      (t) async {
    final key = GlobalKey<FormState>();
    final controller = TextEditingController();

    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Form(
          key: key,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: TextFormField(
            controller: controller,
            validator: Validators.signupPasswordValidator,
          ),
        ),
      ),
    ));

    // Pristine: no scolding before anything is typed.
    expect(find.textContaining('*'), findsNothing);

    // A weak entry is flagged immediately — no submit needed.
    await t.enterText(find.byType(TextFormField), 'abc');
    await t.pump();
    expect(find.textContaining('Minimum'), findsOneWidget);

    // ...and the message tracks each rule as it is satisfied.
    await t.enterText(find.byType(TextFormField), 'abcdefghij');
    await t.pump();
    expect(find.text('*Add an uppercase letter'), findsOneWidget);

    // Fully valid → the error clears without submitting.
    await t.enterText(find.byType(TextFormField), 'Abcdefgh1!');
    await t.pump();
    expect(find.textContaining('*'), findsNothing);
  });
}
