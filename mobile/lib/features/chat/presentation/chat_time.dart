/// Every clock face the chat UI draws.
///
/// Chat timestamps are UTC everywhere inside the app — see `parseServerTime`
/// for why. This is the boundary where the phone's own timezone is applied,
/// and it is the only one: a `DateTime` taken straight off a [ChatMessage] or
/// a room's last message has not been converted yet, so reading `.hour` from
/// one shows the user UTC. In Accra that happens to look right, which is
/// exactly why it went unnoticed — everywhere else, every time in the app was
/// wrong by the user's offset.
///
/// Formatting is here rather than in the widgets so there is one answer to
/// "what day is this message on", shared by the inbox row and the day
/// separator. They disagreed before: the separator split days at UTC midnight
/// while claiming "Today".
class ChatTime {
  ChatTime._();

  /// [t] on the phone's clock. Everything below goes through this first.
  static DateTime local(DateTime t) => t.toLocal();

  /// Midnight of the day [t] falls on, in the phone's timezone.
  static DateTime _dayOf(DateTime t) {
    final l = local(t);
    return DateTime(l.year, l.month, l.day);
  }

  /// Whole days between the day [t] falls on and today — 0 today, 1 yesterday.
  static int daysAgo(DateTime t) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day).difference(_dayOf(t)).inDays;
  }

  /// Whether [a] and [b] land on the same calendar day for this user.
  static bool sameDay(DateTime a, DateTime b) => _dayOf(a) == _dayOf(b);

  /// 24-hour clock — "14:03".
  static String clock(DateTime t) {
    final l = local(t);
    return '${l.hour.toString().padLeft(2, '0')}:'
        '${l.minute.toString().padLeft(2, '0')}';
  }

  /// 12-hour clock — "2:03 pm". Used in the inbox, which mixes times and day
  /// names and reads better without leading zeros.
  ///
  /// [upperPeriod] gives "2:03 PM", which is what the message bubble uses: the
  /// time sits inside the bubble at a small size, where a capitalised period
  /// stays legible against the fill.
  static String clock12(DateTime t, {bool upperPeriod = false}) {
    final l = local(t);
    final period = l.hour >= 12 ? 'pm' : 'am';
    final hour = l.hour == 0 ? 12 : (l.hour > 12 ? l.hour - 12 : l.hour);
    return '$hour:${l.minute.toString().padLeft(2, '0')} '
        '${upperPeriod ? period.toUpperCase() : period}';
  }

  /// The clock face drawn inside a message bubble — "2:03 PM". The day is
  /// already established by the separator above it, so only the time is needed.
  static String bubbleClock(DateTime t) => clock12(t, upperPeriod: true);

  static const _weekdays = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday',
    'Friday', 'Saturday', 'Sunday',
  ];

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// The name of the day [t] falls on — "Monday".
  static String weekday(DateTime t) => _weekdays[local(t).weekday - 1];

  /// "dd/mm/yyyy", for the inbox rows too old for a day name.
  static String shortDate(DateTime t) {
    final l = local(t);
    return '${l.day.toString().padLeft(2, '0')}/'
        '${l.month.toString().padLeft(2, '0')}/${l.year}';
  }

  /// "5 Apr", gaining a year once it is no longer this one. For day separators,
  /// where the date is the whole message and has room to be readable.
  static String longDate(DateTime t) {
    final l = local(t);
    final year = l.year == DateTime.now().year ? '' : ' ${l.year}';
    return '${l.day} ${_months[l.month - 1]}$year';
  }
}
