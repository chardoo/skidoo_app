import 'package:flutter_test/flutter_test.dart';
import 'package:skidoo_app/features/chat/presentation/bloc/rooms/room_sync_reconciler.dart';

/// The bug these lock down: a room deleted from another device while this one
/// was closed never received the live `roomRemovedStream` signal, and the rooms
/// list preserved every locally-known room unconditionally — so it sat there
/// forever, only revealing itself on tap as "you are not a member".
void main() {
  late RoomSyncReconciler r;

  setUp(() => r = RoomSyncReconciler());

  test('a room the server still lists is never stale', () {
    expect(r.onSync({'a', 'b'}, ['a', 'b']), isEmpty);
    expect(r.onSync({'a', 'b'}, ['a', 'b']), isEmpty);
    expect(r.onSync({'a', 'b'}, ['a', 'b']), isEmpty);
  });

  test('a room the server has dropped survives one sync, then goes', () {
    // Grace: the create/join race writes to the cache before the server lists it.
    expect(r.onSync({'a'}, ['a', 'b']), isEmpty, reason: 'b gets one grace sync');
    expect(r.missesFor('b'), 1);
    // Second consecutive omission — now it is genuinely gone.
    expect(r.onSync({'a'}, ['a', 'b']), {'b'});
  });

  test('the tally resets if the server lists the room again', () {
    r.onSync({'a'}, ['a', 'b']); // b missed once
    expect(r.missesFor('b'), 1);
    r.onSync({'a', 'b'}, ['a', 'b']); // b is back
    expect(r.missesFor('b'), 0);
    // So it starts over rather than being dropped on the next single miss.
    expect(r.onSync({'a'}, ['a', 'b']), isEmpty);
  });

  test('a room moving between buckets is not a miss', () {
    // The caller splits ONE server list into active rooms and pending invites.
    // Both buckets are passed together, so a room moving from pending to active
    // is still "present" and must not be counted against.
    const freshIds = {'a', 'b'};
    expect(r.onSync(freshIds, ['a', 'b']), isEmpty);
    expect(r.missesFor('b'), 0);
  });

  test('a room dropped by the live signal stops being tallied', () {
    r.onSync({'a'}, ['a', 'b']); // b missed once
    expect(r.missesFor('b'), 1);
    r.forget('b'); // removed via roomRemovedStream / user left
    expect(r.missesFor('b'), 0);
  });

  test('several dropped rooms are reported together', () {
    r.onSync({'a'}, ['a', 'b', 'c']);
    expect(r.onSync({'a'}, ['a', 'b', 'c']), {'b', 'c'});
  });

  test('an unknown room is not reported as stale', () {
    // Only rooms this device knows about can go stale; ids the server omits
    // that were never local are irrelevant.
    expect(r.onSync({'a'}, ['a']), isEmpty);
  });

  test('missesBeforeDrop: 1 drops immediately, and zero is rejected', () {
    final strict = RoomSyncReconciler(missesBeforeDrop: 1);
    expect(strict.onSync({'a'}, ['a', 'b']), {'b'});
    // Zero would erase a just-created room before the server ever lists it.
    expect(() => RoomSyncReconciler(missesBeforeDrop: 0), throwsA(isA<AssertionError>()));
  });
}
