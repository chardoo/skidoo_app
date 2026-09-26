import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jperg_app/features/admin/data/models/app_config.dart';
import 'package:jperg_app/features/admin/data/repositories/app_config_repository.dart';
import 'package:jperg_app/features/feedback/data/feedback_api.dart';
import 'package:jperg_app/features/feedback/feedback_prompt.dart';

/// When the app asks somebody what they think of it.
///
/// Almost every test here is about *not* asking, which is the right shape for
/// this feature: a prompt that appears too early asks about a sign-up screen,
/// and one that appears too often gets the app rated badly for asking. The
/// gate has four conditions and any one of them says no on its own.
class _FakeApi implements FeedbackApi {
  _FakeApi({this.last});

  DateTime? last;
  int asked = 0;

  @override
  Future<DateTime?> lastSubmitted(FeedbackKind kind) async {
    asked++;
    return last;
  }

  @override
  Future<bool> submit({
    required FeedbackKind kind,
    int? rating,
    String? message,
    String? appVersion,
    String? platform,
  }) async =>
      true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const config = AppConfig(
    feedbackEnabled: true,
    feedbackPromptAfterSessions: 3,
    feedbackPromptAfterDays: 2,
    feedbackPromptRepeatDays: 90,
  );

  /// A device that has launched [sessions] times, first seen [daysAgo] ago.
  Future<void> device({
    int sessions = 3,
    int daysAgo = 2,
    int? lastAskedDaysAgo,
    bool answered = false,
  }) async {
    final now = DateTime.now();
    SharedPreferences.setMockInitialValues({
      'feedback.sessions': sessions,
      'feedback.firstSeen':
          now.subtract(Duration(days: daysAgo)).millisecondsSinceEpoch,
      if (lastAskedDaysAgo != null)
        'feedback.lastAsked': now
            .subtract(Duration(days: lastAskedDaysAgo))
            .millisecondsSinceEpoch,
      if (answered) 'feedback.answered': true,
    });
  }

  setUp(() => AppConfigRepository.notifier.value = config);

  group('when it asks', () {
    test('a device that has been around long enough', () async {
      await device();

      expect(await FeedbackPrompt(api: _FakeApi()).shouldAsk(), isTrue);
    });

    test('again, once the repeat window has passed', () async {
      await device(lastAskedDaysAgo: 91);

      expect(await FeedbackPrompt(api: _FakeApi()).shouldAsk(), isTrue);
    });
  });

  group('when it does not', () {
    test('the admin switched it off', () async {
      await device();
      AppConfigRepository.notifier.value =
          const AppConfig(feedbackEnabled: false);

      expect(await FeedbackPrompt(api: _FakeApi()).shouldAsk(), isFalse);
    });

    test('too few launches', () async {
      await device(sessions: 2);

      expect(await FeedbackPrompt(api: _FakeApi()).shouldAsk(), isFalse);
    });

    test('enough launches, but all of them today', () async {
      // Five launches in one evening is somebody trying the app out, not
      // somebody with an opinion of it. Both conditions, not either.
      await device(sessions: 9, daysAgo: 0);

      expect(await FeedbackPrompt(api: _FakeApi()).shouldAsk(), isFalse);
    });

    test('they said not now, recently', () async {
      await device(lastAskedDaysAgo: 30);

      expect(await FeedbackPrompt(api: _FakeApi()).shouldAsk(), isFalse);
    });

    test('they already answered on this device', () async {
      await device(answered: true);

      expect(await FeedbackPrompt(api: _FakeApi()).shouldAsk(), isFalse);
    });

    test('they already rated it on another device', () async {
      // The one question the device cannot answer for itself. Somebody who
      // rated the app on their old phone should not be asked on their new one.
      await device();
      final api = _FakeApi(last: DateTime.now().subtract(const Duration(days: 3)));

      expect(await FeedbackPrompt(api: api).shouldAsk(), isFalse);
    });

    test('a rating older than the repeat window does not hold it back',
        () async {
      await device();
      final api =
          _FakeApi(last: DateTime.now().subtract(const Duration(days: 200)));

      expect(await FeedbackPrompt(api: api).shouldAsk(), isTrue);
    });
  });

  group('what it costs', () {
    test('an ordinary launch never reaches the network', () async {
      // Every launch before the third, and every launch after somebody has
      // answered, has to cost nothing but a preferences read.
      await device(sessions: 1);
      final api = _FakeApi();

      await FeedbackPrompt(api: api).shouldAsk();

      expect(api.asked, 0);
    });

    test('an answered device never reaches the network either', () async {
      await device(answered: true);
      final api = _FakeApi();

      await FeedbackPrompt(api: api).shouldAsk();

      expect(api.asked, 0);
    });
  });

  group('remembering', () {
    test('answering stops it coming back', () async {
      await device();
      await FeedbackPrompt.noteAnswered();

      expect(await FeedbackPrompt(api: _FakeApi()).shouldAsk(), isFalse);
    });

    test('dismissing starts the repeat window', () async {
      await device();
      await FeedbackPrompt.noteDismissed();

      expect(await FeedbackPrompt(api: _FakeApi()).shouldAsk(), isFalse);
    });

    test('a launch is counted, and the first one is dated', () async {
      SharedPreferences.setMockInitialValues({});

      await FeedbackPrompt.noteLaunch();
      await FeedbackPrompt.noteLaunch();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('feedback.sessions'), 2);
      expect(prefs.getInt('feedback.firstSeen'), isNotNull);
    });

    test('the first-seen date is not moved by later launches', () async {
      // It is what "installed two days ago" is measured from; re-stamping it
      // every launch would mean the prompt could never come due.
      SharedPreferences.setMockInitialValues({});
      await FeedbackPrompt.noteLaunch();
      final prefs = await SharedPreferences.getInstance();
      final first = prefs.getInt('feedback.firstSeen');

      await FeedbackPrompt.noteLaunch();

      expect(prefs.getInt('feedback.firstSeen'), first);
    });
  });
}
