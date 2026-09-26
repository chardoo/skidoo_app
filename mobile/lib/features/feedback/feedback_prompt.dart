import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jperg_app/features/admin/data/repositories/app_config_repository.dart';
import 'package:jperg_app/features/feedback/data/feedback_api.dart';

/// Whether to ask somebody what they think of the app, and when.
///
/// The whole feature turns on this being conservative. A prompt that appears
/// too early asks about a sign-up screen; one that appears too often is a nag
/// and gets the app rated badly *for asking*. So four things have to be true
/// before it opens, and any one of them says no on its own:
///
///   * the admin has it switched on at all;
///   * this device has been launched [AppConfig.feedbackPromptAfterSessions]
///     times, and the app was installed at least
///     [AppConfig.feedbackPromptAfterDays] days ago — both, because five
///     launches in one evening is somebody trying the app out rather than
///     somebody with an opinion of it;
///   * nobody has said "not now" within the last
///     [AppConfig.feedbackPromptRepeatDays];
///   * this *person* has not already rated the app, which is the one question
///     the device cannot answer for itself — see [FeedbackApi.lastSubmitted].
///
/// The counting lives on the device and the answer lives on the server, and
/// that split is deliberate: a launch is a fact about a phone, an opinion is a
/// fact about a person.
class FeedbackPrompt {
  FeedbackPrompt({FeedbackApi? api}) : _api = api ?? FeedbackApi();

  final FeedbackApi _api;

  static const _kSessions = 'feedback.sessions';
  static const _kFirstSeen = 'feedback.firstSeen';
  static const _kLastAsked = 'feedback.lastAsked';
  static const _kAnswered = 'feedback.answered';

  /// Note that the app has been opened.
  ///
  /// Called once per launch, before anything decides whether to prompt. Cheap
  /// and side-effect-free beyond the counter — it must never be the reason a
  /// launch is slow, and it must never throw: SharedPreferences failing is not
  /// a reason for the app not to start.
  static Future<void> noteLaunch() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final count = (prefs.getInt(_kSessions) ?? 0) + 1;
      await prefs.setInt(_kSessions, count);
      // Stamped on the first launch rather than taken from the install date,
      // which no platform agrees on and neither reports reliably.
      if (!prefs.containsKey(_kFirstSeen)) {
        await prefs.setInt(
            _kFirstSeen, DateTime.now().millisecondsSinceEpoch);
      }
    } catch (e) {
      debugPrint('[Feedback] noteLaunch failed: $e');
    }
  }

  /// Whether to open the prompt now.
  ///
  /// Asks the server only once the local conditions are met, so the ordinary
  /// launch — which is every launch before the third, and every launch after
  /// somebody has answered — costs nothing but a preferences read.
  Future<bool> shouldAsk() async {
    final config = AppConfigRepository.current;
    if (!config.feedbackEnabled) return false;

    try {
      final prefs = await SharedPreferences.getInstance();

      // Already answered on this device. Checked first and locally: it is the
      // commonest reason not to ask, and it should not cost a round trip.
      if (prefs.getBool(_kAnswered) == true) return false;

      final sessions = prefs.getInt(_kSessions) ?? 0;
      if (sessions < config.feedbackPromptAfterSessions) return false;

      final firstSeen = prefs.getInt(_kFirstSeen);
      if (firstSeen == null) return false;
      final daysKnown = DateTime.now()
          .difference(DateTime.fromMillisecondsSinceEpoch(firstSeen))
          .inDays;
      if (daysKnown < config.feedbackPromptAfterDays) return false;

      final lastAsked = prefs.getInt(_kLastAsked);
      if (lastAsked != null) {
        final since = DateTime.now()
            .difference(DateTime.fromMillisecondsSinceEpoch(lastAsked))
            .inDays;
        if (since < config.feedbackPromptRepeatDays) return false;
      }

      // The person, not the device. Last, because it is the only check that
      // costs a request.
      final already = await _api.lastSubmitted(FeedbackKind.rating);
      if (already != null) {
        final since = DateTime.now().difference(already).inDays;
        if (since < config.feedbackPromptRepeatDays) {
          // Remembered locally so the next launch does not ask again.
          await prefs.setBool(_kAnswered, true);
          return false;
        }
      }

      return true;
    } catch (e) {
      debugPrint('[Feedback] shouldAsk failed: $e');
      // Silence rather than a prompt: a bug in this gate should cost a piece
      // of feedback, never show somebody a dialog they have already dismissed.
      return false;
    }
  }

  /// They answered. Do not ask again.
  static Future<void> noteAnswered() => _stamp(answered: true);

  /// They closed it without answering. Ask again after the repeat window.
  static Future<void> noteDismissed() => _stamp(answered: false);

  static Future<void> _stamp({required bool answered}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kLastAsked, DateTime.now().millisecondsSinceEpoch);
      if (answered) await prefs.setBool(_kAnswered, true);
    } catch (e) {
      debugPrint('[Feedback] stamp failed: $e');
    }
  }

  /// For tests and for the "reset" an admin build might want.
  @visibleForTesting
  static Future<void> forget() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in [_kSessions, _kFirstSeen, _kLastAsked, _kAnswered]) {
      await prefs.remove(key);
    }
  }
}
