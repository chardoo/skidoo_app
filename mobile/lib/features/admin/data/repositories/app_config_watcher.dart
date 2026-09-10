import 'package:flutter/widgets.dart';

/// Keeps the app's copy of `/config` from going stale.
///
/// The flags are fetched once at launch, and that was the whole of it: an admin
/// switching campaigns off reached nobody who already had the app open, and
/// switching them back on reached nobody until they force-quit. Sessions here
/// last days.
///
/// Refetching when the app returns to the foreground is the cheapest answer
/// that matches how the switch is actually used — someone flips it and then
/// looks at a phone. `/config` is a small unauthenticated GET, and
/// [AppConfigRepository.notifier] does the rest: every screen watching it
/// redraws itself.
///
/// [_minInterval] keeps a run of quick app switches from turning into a run of
/// requests. It does not delay a change by that long — a resume after the
/// interval has passed fetches immediately, and the interval is short next to
/// how long a phone spends in a pocket.
class AppConfigWatcher with WidgetsBindingObserver {
  AppConfigWatcher(this._fetch);

  /// `AppConfigRepository.fetch` in the app — a function rather than the
  /// repository so this can be exercised without an HTTP client.
  final Future<void> Function() _fetch;

  static const _minInterval = Duration(seconds: 30);

  DateTime? _lastFetch;
  bool _started = false;

  /// Marks the launch fetch as already done, so the first resume does not
  /// immediately repeat it.
  void start({DateTime? now}) {
    if (_started) return;
    _started = true;
    _lastFetch = now ?? DateTime.now();
    WidgetsBinding.instance.addObserver(this);
  }

  void stop() {
    if (!_started) return;
    _started = false;
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refresh();
  }

  /// Refetches unless the last one was very recent. Returns whether it did.
  Future<bool> refresh({DateTime? now}) async {
    final at = now ?? DateTime.now();
    final last = _lastFetch;
    if (last != null && at.difference(last) < _minInterval) return false;
    _lastFetch = at;
    await _fetch();
    return true;
  }
}
