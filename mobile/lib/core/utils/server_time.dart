/// Matches an ISO-8601 zone designator: a trailing `Z`, or an offset such as
/// `+00:00`, `-0500`, `+01`.
final _zoneSuffix = RegExp(r'(?:Z|z|[+-]\d{2}(?::?\d{2})?)$');

/// Reads a timestamp the server sent, as UTC.
///
/// The API stores every timestamp in UTC and sends it that way, so this is the
/// one place that has to know it. Two things go wrong without it:
///
///  * `DateTime.parse` on a string with no zone designator returns *local*
///    time. The same message would then be an hour apart on a phone in Accra
///    and a phone in Lagos, and neither would be right.
///  * The result is left carrying whatever zone the string happened to name,
///    so downstream code comparing two timestamps is comparing apples to
///    oranges.
///
/// Everything inside the app therefore holds UTC — including the local cache,
/// whose `created_at` column is compared as text in SQL and only sorts
/// correctly if every row is written in the same zone. The phone's own
/// timezone is applied once, at the moment a time is drawn on screen, and
/// nowhere else.
DateTime parseServerTime(String raw) {
  final s = raw.trim();
  final parsed =
      _zoneSuffix.hasMatch(s) ? DateTime.parse(s) : DateTime.parse('${s}Z');
  return parsed.toUtc();
}
