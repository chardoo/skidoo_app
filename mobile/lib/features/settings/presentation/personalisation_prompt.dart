import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether to offer to personalise somebody's feed, and when.
///
/// `share_usage_data` is what lets the recommender rank a feed from what a
/// person actually watches. It defaults to off — deliberately, and the privacy
/// policy commits to that — and the only way to turn it on was a switch in
/// Settings › Privacy called "Share Usage Data", under a heading that said
/// "Diagnostic analytics".
///
/// In production that produced **1 opt-in out of 228 accounts**. The pipeline
/// behind it is healthy end to end (see `scripts/diagnose_tracking.py`): dwell
/// is recorded, events arrive, scores compute. It is starved of input because
/// nobody was ever asked in terms that meant anything to them.
///
/// So: ask once, in the feed, after they have used it enough to have a taste
/// worth learning — and take no for an answer.
///
/// ## The rules, and why each one
///
/// Modelled on [FeedbackPrompt], which solves the same problem for app
/// ratings. Any one of these says no on its own:
///
///   * **Not before [_minSessions] launches.** Asking on first run is asking
///     somebody who has seen nothing to describe what they like.
///   * **Not before [_minFeedViews] events watched.** Launches alone can be
///     somebody opening the app and leaving; this is the signal that there is
///     something to personalise *from*.
///   * **Never twice.** Declining is an answer. A prompt that returns is a nag,
///     and the setting is still in Privacy for anyone who changes their mind.
///   * **Not if they already said yes** — including from Settings directly.
///
/// The counting is device-local on purpose: a launch is a fact about a phone.
/// Whether they have consented is a fact about the account and comes from the
/// server.
class PersonalisationPrompt {
  PersonalisationPrompt._();

  static const _kSessions = 'personalise.sessions';
  static const _kViews = 'personalise.feedViews';
  static const _kAnswered = 'personalise.answered';

  /// Launches before the question is worth asking.
  static const _minSessions = 3;

  /// Events watched before it is worth asking. Low enough to reach in a couple
  /// of sittings, high enough that the recommender has something to work with
  /// the moment they say yes.
  static const _minFeedViews = 12;

  /// Note that the app has been opened. Called once per launch.
  ///
  /// Never throws: SharedPreferences failing is not a reason for the app not
  /// to start, and a prompt is the least important thing happening at launch.
  static Future<void> noteLaunch() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kSessions, (prefs.getInt(_kSessions) ?? 0) + 1);
    } catch (e) {
      debugPrint('[Personalise] noteLaunch failed: $e');
    }
  }

  /// Note that one more event has been watched in the feed.
  ///
  /// Called from the same place that reports a view for tracking, so the two
  /// cannot drift: if the feed stops being watched, this stops counting.
  static Future<void> noteFeedView() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_kAnswered) ?? false) return;
      await prefs.setInt(_kViews, (prefs.getInt(_kViews) ?? 0) + 1);
    } catch (e) {
      debugPrint('[Personalise] noteFeedView failed: $e');
    }
  }

  /// Whether to open the prompt now.
  ///
  /// [alreadyOn] is the account's current `share_usage_data`, which the caller
  /// has and this cannot read. False on any error — failing to ask is a far
  /// smaller problem than asking somebody who has already answered.
  static Future<bool> shouldAsk({required bool alreadyOn}) async {
    if (alreadyOn) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_kAnswered) ?? false) return false;
      if ((prefs.getInt(_kSessions) ?? 0) < _minSessions) return false;
      if ((prefs.getInt(_kViews) ?? 0) < _minFeedViews) return false;
      return true;
    } catch (e) {
      debugPrint('[Personalise] shouldAsk failed: $e');
      return false;
    }
  }

  /// Remember that they answered, whichever way they answered.
  ///
  /// Recorded for "no" as much as for "yes": the point of asking once is that
  /// declining is respected.
  static Future<void> markAnswered() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kAnswered, true);
    } catch (e) {
      debugPrint('[Personalise] markAnswered failed: $e');
    }
  }

  /// Test seam — forget everything this device has recorded.
  @visibleForTesting
  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kSessions);
    await prefs.remove(_kViews);
    await prefs.remove(_kAnswered);
  }
}
