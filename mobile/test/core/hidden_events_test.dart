import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/cache/hidden_events.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Hiding is one decision, not one per screen.
///
/// "Hide event" promises "You won't see this event again". The discover feed
/// kept that promise; the Following feed called `removeWhere` on its own list
/// and nothing else, so the card went until the next fetch handed it straight
/// back. Two lists each owning the same decision is the bug, and this is the
/// one place that owns it now.
void main() {
  const key = 'discovery_hidden_event_ids';

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    HiddenEvents.resetForTest();
  });

  group('the stored set', () {
    test('starts empty', () async {
      expect(await HiddenEvents.load(), isEmpty);
    });

    test('reads what a previous session wrote', () async {
      SharedPreferences.setMockInitialValues({
        key: ['a', 'b'],
      });

      expect(await HiddenEvents.load(), {'a', 'b'});
    });

    test('uses the key DiscoveryBloc already wrote, so old hides survive', () async {
      // The key is the migration. Renaming it would silently unhide everything
      // every existing user has hidden, on the update that "fixed" hiding.
      SharedPreferences.setMockInitialValues({
        key: ['hidden-before-this-class-existed'],
      });

      expect(HiddenEvents.isHidden('hidden-before-this-class-existed'), isFalse,
          reason: 'not until it has been loaded');
      await HiddenEvents.load();
      expect(HiddenEvents.isHidden('hidden-before-this-class-existed'), isTrue);
    });

    test('hiding persists', () async {
      await HiddenEvents.load();
      await HiddenEvents.hide('e1');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList(key), contains('e1'));
    });

    test('hiding twice is one entry', () async {
      await HiddenEvents.hide('e1');
      await HiddenEvents.hide('e1');

      expect(HiddenEvents.ids, {'e1'});
    });

    test('unhide takes it back out', () async {
      await HiddenEvents.hide('e1');
      await HiddenEvents.unhide('e1');

      expect(HiddenEvents.isHidden('e1'), isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList(key), isNot(contains('e1')));
    });

    test('an empty id is not hidden', () async {
      await HiddenEvents.hide('');
      expect(HiddenEvents.ids, isEmpty);
    });

    test('replace swaps the whole set', () async {
      await HiddenEvents.hide('old');
      await HiddenEvents.replace({'new1', 'new2'});

      expect(HiddenEvents.ids, {'new1', 'new2'});
    });
  });

  group('filter', () {
    test('drops hidden items and keeps the order of the rest', () {
      HiddenEvents.resetForTest({'b', 'd'});

      expect(
        HiddenEvents.filter(['a', 'b', 'c', 'd'], (s) => s),
        ['a', 'c'],
      );
    });

    test('drops a hidden item the server sends again', () {
      // The Following feed's actual failure: the server does not know what this
      // reader hid, so every page it sends can carry one back.
      HiddenEvents.resetForTest({'hidden-one'});

      expect(
        HiddenEvents.filter(['c', 'hidden-one', 'e'], (s) => s),
        ['c', 'e'],
      );
    });

    test('nothing hidden returns the same list untouched', () {
      HiddenEvents.resetForTest(<String>{});
      final items = ['a', 'b'];

      expect(HiddenEvents.filter(items, (s) => s), same(items));
    });

    test('an unloaded set filters nothing rather than emptying the feed', () {
      // Wrong in the safe direction: showing a hidden card once more beats
      // blanking a feed because the set had not been read yet.
      HiddenEvents.resetForTest();

      expect(HiddenEvents.filter(['a', 'b'], (s) => s), ['a', 'b']);
    });
  });
}
