/// Converts a [DateTime] to a human-readable relative label.
///
/// Examples: "Just now", "5m", "2h", "3d", "15/4"
class TimeFormatter {
  TimeFormatter._();

  static String relative(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inSeconds < 60) return 'Just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    if (d.inHours < 24) return '${d.inHours}h';
    if (d.inDays < 7) return '${d.inDays}d';
    return '${dt.day}/${dt.month}';
  }
}
