import 'package:jperg_app/features/chat/data/datasources/chat_rest_data_source.dart'
    show PresenceSnapshot;

/// The line under somebody's name in a one-to-one conversation.
///
/// Pulled out of the page because it makes three judgements that are easy to
/// get wrong and impossible to test inside a widget's private State:
///
///   • an account we have no answer for is *unknown*, not offline. Saying
///     "Offline" there asserts something we do not know — and it is the same
///     mistake, one layer up, as the web header that said "Connected" off its
///     own socket state;
///   • "online" outranks any last-seen we happen to hold, because the stamp is
///     written on every heartbeat and is therefore always a moment old even
///     for somebody who is there right now;
///   • the elapsed time is deliberately coarse. Presence is renewed on a
///     timer, so the underlying figure is only good to within a lease, and
///     "last seen 43 seconds ago" claims a precision it does not have.
///
/// Returns null when there is nothing worth saying, which the header draws as
/// an empty line rather than a guess.
String? presenceLabel(PresenceSnapshot? snapshot, {DateTime? now}) {
  if (snapshot == null) return null;
  if (snapshot.online) return 'Online';

  final lastSeen = snapshot.lastSeen;
  if (lastSeen == null) return null;
  return 'Last seen ${relativeTime(lastSeen, now: now)}';
}

const _monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// "just now" / "5m ago" / "3h ago" / "yesterday" / "4 Aug".
String relativeTime(DateTime when, {DateTime? now}) {
  final delta = (now ?? DateTime.now()).toUtc().difference(when.toUtc());
  // A clock that disagrees with the server's puts this in the future. "In 3
  // minutes" reads as a bug, so anything not yet past counts as just now.
  if (delta.inMinutes < 1) return 'just now';
  if (delta.inMinutes < 60) return '${delta.inMinutes}m ago';
  if (delta.inHours < 24) return '${delta.inHours}h ago';
  if (delta.inDays == 1) return 'yesterday';
  if (delta.inDays < 7) return '${delta.inDays}d ago';
  final local = when.toLocal();
  return '${local.day} ${_monthNames[local.month - 1]}';
}
