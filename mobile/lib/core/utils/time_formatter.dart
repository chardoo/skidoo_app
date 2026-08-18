import 'package:intl/intl.dart';

/// Converts a [DateTime] to a human-readable relative label.
///
/// Examples: "Just now", "5m", "2h", "3d", "2w", "15/4"
class TimeFormatter {
  TimeFormatter._();

  static String relative(DateTime dt) {
    // Server times arrive as UTC. The elapsed-time branches below are safe
    // either way (a difference between two instants doesn't care about zones),
    // but the date fallback reads calendar fields and needs the phone's.
    final local = dt.toLocal();
    final d = DateTime.now().difference(dt);
    if (d.inSeconds < 60) return 'Just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    if (d.inHours < 24) return '${d.inHours}h';
    if (d.inDays < 7) return '${d.inDays}d';
    // Weeks before the date, up to a month. "3w" is read at a glance; "27/7"
    // has to be worked out against today's date to mean anything.
    if (d.inDays < 30) return '${d.inDays ~/ 7}w';
    return '${local.day}/${local.month}';
  }

  /// The whole date and time, spelled out — "15 Apr 2026 at 14:03".
  ///
  /// What the compact label above leaves out. Used where the exact moment has
  /// to be available without being in the way: a tooltip, or the screen-reader
  /// label on a notification, where "2w" tells someone nothing.
  static String absolute(DateTime dt) =>
      DateFormat("d MMM y 'at' HH:mm").format(dt.toLocal());
}
