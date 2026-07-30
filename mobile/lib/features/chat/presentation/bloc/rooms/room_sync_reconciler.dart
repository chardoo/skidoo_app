/// Decides when a locally-known chat room should be treated as gone.
///
/// Removals used to rely solely on a live WebSocket signal
/// (`ChatBackgroundService.roomRemovedStream`). Delete a room from another
/// device while this one is closed or offline and that signal is missed: the
/// server stops listing the room, but the rooms list preserved every
/// locally-known room unconditionally, so it stayed on screen indefinitely and
/// only revealed itself on tap as "you are not a member".
///
/// Simply trusting the server's list instead would erase a room the user just
/// created or joined, because that room is written to the local cache
/// immediately and "list my rooms" can be a beat behind the write. So a room
/// gets a grace sync, and is dropped once the server has omitted it
/// [missesBeforeDrop] times in a row.
class RoomSyncReconciler {
  RoomSyncReconciler({this.missesBeforeDrop = 2})
      : assert(missesBeforeDrop >= 1, 'zero would erase just-created rooms');

  /// Consecutive syncs a room may be absent before being dropped. Two means
  /// one beat of grace — enough for the create/join race, and a deleted room
  /// is gone by the second refresh.
  final int missesBeforeDrop;

  final Map<String, int> _misses = {};

  /// Records one successful sync and returns the ids to forget.
  ///
  /// [freshIds] must be **every** id the server returned, across all buckets:
  /// callers that split the list into active rooms and pending invites would
  /// otherwise see a room moving between buckets as a miss.
  Set<String> onSync(Set<String> freshIds, Iterable<String> knownIds) {
    for (final id in freshIds) {
      _misses.remove(id);
    }

    final stale = <String>{};
    for (final id in knownIds) {
      if (freshIds.contains(id)) continue;
      final misses = (_misses[id] ?? 0) + 1;
      if (misses >= missesBeforeDrop) {
        _misses.remove(id);
        stale.add(id);
      } else {
        _misses[id] = misses;
      }
    }
    return stale;
  }

  /// Drops any pending miss count for [roomId] — it has been removed by another
  /// path (a live signal, or the user leaving), so the tally is moot.
  void forget(String roomId) => _misses.remove(roomId);

  /// Visible for tests.
  int missesFor(String roomId) => _misses[roomId] ?? 0;
}
