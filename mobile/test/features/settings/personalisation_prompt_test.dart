import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/features/settings/presentation/personalisation_prompt.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// When to ask somebody whether their feed may learn from them.
///
/// The switch behind this has always existed, off by default, reachable only
/// through Settings › Privacy. In production that produced **1 opt-in out of
/// 228 accounts** while the pipeline behind it ran healthily on one person's
/// data. So the question is not whether to collect — it is when it is fair to
/// ask, and these are the rules that make "once, and no means no" true.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PersonalisationPrompt.reset();
  });

  Future<void> launches(int n) async {
    for (var i = 0; i < n; i++) {
      await PersonalisationPrompt.noteLaunch();
    }
  }

  Future<void> views(int n) async {
    for (var i = 0; i < n; i++) {
      await PersonalisationPrompt.noteFeedView();
    }
  }

  group('it waits until there is something to personalise', () {
    test('never on a fresh install', () async {
      expect(await PersonalisationPrompt.shouldAsk(alreadyOn: false), isFalse);
    });

    test('not on launches alone — opening the app is not watching it',
        () async {
      await launches(10);
      expect(await PersonalisationPrompt.shouldAsk(alreadyOn: false), isFalse);
    });

    test('not on views alone — one long sitting is not a habit', () async {
      await views(50);
      expect(await PersonalisationPrompt.shouldAsk(alreadyOn: false), isFalse);
    });

    test('yes once they have come back and watched a few', () async {
      await launches(3);
      await views(12);
      expect(await PersonalisationPrompt.shouldAsk(alreadyOn: false), isTrue);
    });
  });

  group('it asks once', () {
    test('not again after they said yes', () async {
      await launches(3);
      await views(12);
      await PersonalisationPrompt.markAnswered();
      expect(await PersonalisationPrompt.shouldAsk(alreadyOn: false), isFalse);
    });

    test('not again after they said no', () async {
      // The same call records both answers. Declining is a decision, not a
      // deferral — the setting stays in Privacy for anyone who changes
      // their mind.
      await launches(3);
      await views(12);
      await PersonalisationPrompt.markAnswered();
      await launches(40);
      await views(400);
      expect(await PersonalisationPrompt.shouldAsk(alreadyOn: false), isFalse);
    });

    test('never when it is already on', () async {
      // Including somebody who found the switch in Settings themselves.
      await launches(3);
      await views(12);
      expect(await PersonalisationPrompt.shouldAsk(alreadyOn: true), isFalse);
    });
  });

  test('it stops counting once answered', () async {
    // No reason to keep writing a number nothing will read again.
    await launches(3);
    await views(12);
    await PersonalisationPrompt.markAnswered();
    await views(5);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('personalise.feedViews'), 12);
  });

  test('counting survives a restart', () async {
    // Three launches means three *sessions*, so the count has to outlive each
    // one — otherwise the threshold could never be reached.
    await launches(2);
    await views(12);
    expect(await PersonalisationPrompt.shouldAsk(alreadyOn: false), isFalse);

    await PersonalisationPrompt.noteLaunch();
    expect(await PersonalisationPrompt.shouldAsk(alreadyOn: false), isTrue);
  });
}
