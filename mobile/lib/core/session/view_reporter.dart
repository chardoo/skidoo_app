import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:jperg_app/api/dio_client_service.dart';
import 'package:jperg_app/core/di/service_locator.dart';

/// Telling the server that something was actually looked at.
///
/// `POST /views` is read by two things that want different answers out of the
/// same moment: the view counter a photographer sees on their album, and the
/// behavioural signal the feed ranking learns from. The second is why this
/// exists. An event nobody is ever told you watched is an event the ranking
/// cannot demote — its re-view penalty is keyed on a last-viewed time that was
/// always null — which is how one album ended up pinned to the top of the feed
/// through every refresh.
///
/// `/recommend/{id}/view`, which the album viewer already posts, is not this.
/// That is a weak positive kept for model training; this is the record of
/// having seen something, and the ranking reads only this one.
///
/// Fire-and-forget over a 202: whether a view was counted is not the screen's
/// business, and a report that failed must never disturb the feed it came from.
class ViewReporter {
  ViewReporter._();

  /// One id per launch.
  ///
  /// The server uses it to tell a re-render from a second look — swiping back
  /// to a card seconds later is not a new view — and then throws it away.
  /// Nothing in it identifies the device, and it does not survive the app
  /// being closed.
  static final String sessionId =
      '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}'
      '-${Random().nextInt(0x3FFFFFFF).toRadixString(36)}';

  static void report({
    required String entityType,
    required String entityId,
    int? dwellSeconds,
  }) {
    if (entityId.isEmpty) return;
    // Everything here is inside the try, not just the request: the reporter is
    // reached from dispose() and from page callbacks, where a throw would take
    // the screen with it — and there is no client under test or on a torn-down
    // locator that should lose its feed over a telemetry call.
    try {
      sl<Api>().dio.post('/views', data: {
        'entityType': entityType,
        'entityId': entityId,
        'sessionId': sessionId,
        // Absent means nobody measured, which the server reads differently
        // from a measured zero.
        if (dwellSeconds != null) 'dwellSeconds': dwellSeconds,
      }).then((_) {}).catchError((Object e) {
        debugPrint('[ViewReporter] $entityType $entityId not reported: $e');
      });
    } catch (e) {
      debugPrint('[ViewReporter] $entityType $entityId not reported: $e');
    }
  }
}

/// How a watched card is reported. [ViewReporter.report] in the app; something
/// that records the call in tests.
typedef ViewReport = void Function({
  required String entityType,
  required String entityId,
  int? dwellSeconds,
});

/// What is on screen, and for how long.
///
/// A feed holds one of these and keeps telling it what the reader is looking
/// at; the report goes out when they move on, because that is the first moment
/// the dwell is known. Give it to whatever owns the page controller — the two
/// vertical feeds each own one.
class ViewWatch {
  ViewWatch({
    this.entityType = 'event',
    ViewReport? report,
    DateTime Function()? now,
  })  : _report = report ?? ViewReporter.report,
        _now = now ?? DateTime.now;

  final String entityType;

  /// Where the report goes, and what the clock says. Both are injectable for
  /// tests only: dwell is the thing worth pinning here, and pinning it against
  /// the real clock would mean a test that sleeps.
  final ViewReport _report;
  final DateTime Function() _now;

  /// Below this the page was passed through rather than looked at. Flicking
  /// down a feed must not mark forty albums as seen — that would demote them
  /// all out of the next ranking on the strength of a thumbnail going past.
  ///
  /// Above it, the server decides what the number means: tracking scores under
  /// five seconds as a skip and over thirty as real attention. Both are worth
  /// sending, which is why the floor is this low rather than at five.
  static const Duration _minimumDwell = Duration(seconds: 1);

  /// A phone put down on a card is not ten hours of attention. The view still
  /// counts; only the dwell is capped.
  static const Duration _maximumDwell = Duration(minutes: 10);

  String? _entityId;
  DateTime? _since;

  /// The thing the reader is looking at now, or null for anything that is not
  /// one — an ad slot, a suggestions card, an empty list.
  ///
  /// The same id twice running is the same look continuing, so it is
  /// deliberately a no-op: callers are free to say this on every rebuild
  /// without restarting the clock.
  void showing(String? entityId) {
    if (entityId == _entityId) return;
    hidden();
    if (entityId == null || entityId.isEmpty) return;
    _entityId = entityId;
    _since = _now();
  }

  /// Nothing is being watched any more: the page moved on, the feed was
  /// disposed, the reader went back to the top. Reports what was open.
  void hidden() {
    final id = _entityId;
    final since = _since;
    _entityId = null;
    _since = null;
    if (id == null || since == null) return;

    var dwell = _now().difference(since);
    if (dwell < _minimumDwell) return;
    if (dwell > _maximumDwell) dwell = _maximumDwell;

    _report(
      entityType: entityType,
      entityId: id,
      dwellSeconds: dwell.inSeconds,
    );
  }
}
