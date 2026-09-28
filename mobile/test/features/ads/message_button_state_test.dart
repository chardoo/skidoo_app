import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/ads/data/models/feed_request_model.dart';
import 'package:jperg_app/features/ads/presentation/widgets/photographer_tile.dart';

/// The Message button on somebody you chose for a job.
///
/// It used to be drawn live whatever the state of the conversation, so a
/// recipient who had blocked the caller — or who takes no new DMs — produced a
/// button that looked available and answered a tap with a red snackbar. The
/// refusal was correct; offering the tap in the first place was not.
///
/// `CanMessageUseCase` exists precisely so this can be known before drawing,
/// and the screen was not calling it.
void main() {
  RequestInterest person() => const RequestInterest(id: 'ph-1', name: 'Joe');

  Widget host({String? blocked, VoidCallback? onMessage}) => ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (context, __) => MaterialApp(
          theme: ThemeData.dark().copyWith(extensions: [AppThemeExtension.dark]),
          home: Scaffold(
            body: Builder(
              builder: (context) => PhotographerTile(
                person: person(),
                ext: Theme.of(context).extension<AppThemeExtension>()!,
                onTap: () {},
                onMessage: onMessage ?? () {},
                messageBlockedReason: blocked,
              ),
            ),
          ),
        ),
      );

  testWidgets('an open conversation offers Message', (t) async {
    await t.pumpWidget(host());
    await t.pump();

    expect(find.text('Message'), findsOneWidget);
    expect(find.text('Unavailable'), findsNothing);
  });

  testWidgets('a closed one says so instead', (t) async {
    await t.pumpWidget(host(blocked: 'You cannot message this user.'));
    await t.pump();

    expect(find.text('Unavailable'), findsOneWidget);
    expect(find.text('Message'), findsNothing);
  });

  testWidgets('and cannot be tapped into a failure', (t) async {
    // The whole point. A tap that is guaranteed to end in a red snackbar is
    // the thing this was reported for.
    var taps = 0;
    await t.pumpWidget(host(
      blocked: 'You cannot message this user.',
      onMessage: () => taps++,
    ));
    await t.pump();

    await t.tap(find.text('Unavailable'));
    await t.pump();

    expect(taps, 0);
  });

  testWidgets('an open one still opens', (t) async {
    var taps = 0;
    await t.pumpWidget(host(onMessage: () => taps++));
    await t.pump();

    await t.tap(find.text('Message'));
    await t.pump();

    expect(taps, 1);
  });

  testWidgets('the reason is reachable, not just the refusal', (t) async {
    // "Unavailable" alone says nothing about why, and why is the part
    // somebody can act on. Carried on the Tooltip — a long-press or a tap
    // shows it, and a screen reader announces it.
    await t.pumpWidget(host(blocked: 'You cannot message this user.'));
    await t.pump();

    final tooltip = t.widget<Tooltip>(find.byType(Tooltip));
    expect(tooltip.message, 'You cannot message this user.');
  });
}
