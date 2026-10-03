import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/gallery/presentation/found/widgets/face_gate_prompt.dart';

/// The second way out of the Found tab's empty state.
///
/// Adding a face is still the primary action: done once, it works for every
/// event afterwards. Easy search is for the person who will not do that, which
/// is why it is offered underneath rather than beside — and why the line under
/// it has to say what the trade is.
void main() {
  Widget host({
    required FaceGateReason reason,
    VoidCallback? onEasySearch,
    VoidCallback? onSignIn,
  }) =>
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) => MaterialApp(
          theme: ThemeData.dark().copyWith(extensions: [AppThemeExtension.dark]),
          home: Scaffold(
            body: FaceGatePrompt(
              reason: reason,
              onPrimaryAction: () {},
              onSignIn: onSignIn,
              onEasySearch: onEasySearch,
            ),
          ),
        ),
      );

  testWidgets('it is offered to someone who is signed in without a face',
      (tester) async {
    await tester.pumpWidget(host(
      reason: FaceGateReason.noFaceAdded,
      onEasySearch: () {},
    ));

    expect(find.text('Take a selfie'), findsOneWidget);
    expect(find.text('Easy search'), findsOneWidget);
  });

  testWidgets('it says what you give up, not only what you get',
      (tester) async {
    // Without the trade stated it reads as the same thing but easier, and
    // everyone picks it.
    await tester.pumpWidget(host(
      reason: FaceGateReason.noFaceAdded,
      onEasySearch: () {},
    ));

    final line = tester.widget<Text>(find.textContaining('Search one event'));
    expect(line.data, contains('code'));
    expect(line.data, contains('never saved'));
  });

  testWidgets('a surface that cannot route there does not advertise it',
      (tester) async {
    // The signed-out gate: easy search reads who you are from the token, so
    // there is nothing to offer a guest until they have an account.
    await tester.pumpWidget(host(
      reason: FaceGateReason.signedOut,
      onSignIn: () {},
    ));

    expect(find.text('Easy search'), findsNothing);
    expect(find.textContaining('Search one event'), findsNothing);
  });

  testWidgets('tapping it calls the caller', (tester) async {
    var taps = 0;
    await tester.pumpWidget(host(
      reason: FaceGateReason.noFaceAdded,
      onEasySearch: () => taps++,
    ));

    await tester.tap(find.text('Easy search'));
    await tester.pump();

    expect(taps, 1);
  });

  testWidgets('it does not displace adding a face', (tester) async {
    // Order matters: the filled button is the recommendation, and it stays
    // above the outlined one.
    await tester.pumpWidget(host(
      reason: FaceGateReason.noFaceAdded,
      onEasySearch: () {},
    ));

    final primary = tester.getCenter(find.text('Take a selfie'));
    final secondary = tester.getCenter(find.text('Easy search'));
    expect(primary.dy, lessThan(secondary.dy));
  });
}
