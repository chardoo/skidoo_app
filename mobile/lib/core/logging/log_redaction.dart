import 'package:flutter/foundation.dart';

/// What the app is allowed to write to the device log.
///
/// Every `debugPrint` in the app passes through [redactForLog], installed once
/// in `main()`. It is one filter at the exit rather than a rule at ~90 call
/// sites, because the call sites are the problem: a repository that logs
/// `status=200 body=$body` is logging whatever the server sent, which on a
/// profile or a payment response is an email address, a phone number, and on
/// an auth response the session token itself.
///
/// **`debugPrint` is not stripped from a release build.** It keeps printing to
/// `os_log` on iOS and logcat on Android, where it reaches anyone with the
/// device and a trusted computer, and is collected wholesale into a
/// sysdiagnose or a bug report that somebody may then email to support. No
/// other app can read it on either platform, so this is a privacy exposure
/// rather than a remote hole — which is why the answer is to stop logging
/// secrets rather than to stop logging.
///
/// Silencing release logging outright was the other option and would have been
/// worse: the diagnostics that actually get used — the startup build marker,
/// the purchase recovery sweep, which HTTP stack the images are on — are read
/// from exactly those builds, and losing them costs more than it saves.
///
/// Two rules, in this order:
///
///   * credentials and personal detail are replaced, in every build. A token
///     in a debug log is still a token, and the laptop it lands on is usually
///     not the only place it stays.
///   * long lines are cut, in release only. A dumped response body is the
///     bulk of what leaks, and a developer at a connected device wants the
///     whole thing.
String redactForLog(String? message, {bool release = kReleaseMode}) {
  if (message == null || message.isEmpty) return '';

  var out = message;
  for (final rule in _rules) {
    out = out.replaceAllMapped(rule.pattern, rule.replace);
  }

  if (release && out.length > _releaseLineLimit) {
    final cut = out.length - _releaseLineLimit;
    out = '${out.substring(0, _releaseLineLimit)}… «$cut more chars»';
  }
  return out;
}

/// Where a release log line stops. Long enough for a status line, a URL and a
/// short error; far short of a serialised list of people.
const int _releaseLineLimit = 400;

class _Rule {
  const _Rule(this.pattern, this.replace);
  final RegExp pattern;
  final String Function(Match) replace;
}

String _keep1(Match m) => '${m[1]}«redacted»';

final List<_Rule> _rules = [
  // A JWT, wherever it appears and whether or not it is labelled. Ours start
  // `eyJ` because that is a base64url'd `{"` — matching the shape rather than
  // a prefix like "Bearer" catches the ones that were interpolated bare.
  _Rule(
    RegExp(r'eyJ[A-Za-z0-9_-]{6,}\.[A-Za-z0-9_-]{6,}\.[A-Za-z0-9_-]{4,}'),
    (_) => '«jwt»',
  ),
  // `Authorization: Bearer …`, and the same value in a printed header map.
  _Rule(
    RegExp(r'(Bearer\s+)[A-Za-z0-9._\-]{8,}', caseSensitive: false),
    _keep1,
  ),
  // Anything calling itself a secret, in a query string, a JSON body or a
  // Dart map: token=…, "password": "…", 'secret' : …, apiKey=…
  //
  // `Bearer` is part of the kept prefix rather than part of the value, so a
  // header the rule above has already dealt with reads `Bearer «redacted»`
  // instead of being redacted a second time. The negative lookahead makes the
  // whole filter idempotent: a line that has been through it once does not
  // change if it goes through again.
  _Rule(
    RegExp(
      r'''(["']?(?:token|access_token|refresh_token|password|secret|api[_-]?key|authorization|signedTransaction|verificationData)["']?\s*[:=]\s*["']?(?:Bearer\s+)?)'''
      // Neither an already-redacted value nor the scheme word itself: without
      // the second guard the optional `Bearer` above backtracks to empty and
      // the word "Bearer" is read as the secret.
      r'''(?!«)(?!Bearer\b)[^\s,;&"'}\]]{4,}''',
      caseSensitive: false,
    ),
    _keep1,
  ),
  // Email addresses. Ordinary content in a profile or a payment response, and
  // the single most identifying field the API returns.
  _Rule(
    RegExp(r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'),
    (_) => '«email»',
  ),
  // A phone number in the shapes this app handles. Three alternatives rather
  // than one loose pattern, because "a long run of digits" is also a
  // timestamp, a byte count and a cache size — redacting those would cost the
  // diagnostics this filter exists to keep.
  //
  //   +233244123456 / +1 (555) 123-4567   — anything starting with +
  //   0244123456                          — a local number, leading zero
  //   024 412 3456 / 024-412-3456         — separated groups
  _Rule(
    RegExp(
      r'(?<![\w.-])(?:'
      r'\+\d[\d\s().-]{6,16}\d'
      r'|0\d{8,13}'
      r'|\d{2,4}[\s().-]\d{2,4}[\s().-]\d{2,6}'
      r')(?![\w.-])',
    ),
    (_) => '«phone»',
  ),
];

/// Install the filter. Call once, before anything logs.
///
/// Wraps whatever `debugPrint` currently is rather than replacing it, so the
/// platform's own throttling — which is what keeps a burst of logging from
/// being dropped by the OS — still happens underneath.
void installLogRedaction() {
  final inner = debugPrint;
  debugPrint = (String? message, {int? wrapWidth}) {
    inner(redactForLog(message), wrapWidth: wrapWidth);
  };
}
