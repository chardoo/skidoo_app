import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/features/gallery/data/saved_photos.dart';

/// A store that records what it was asked to do and can be made to fail.
class _FakeStore implements SavedPhotoStore {
  _FakeStore({List<String> initial = const []}) : _ids = [...initial];

  final List<String> _ids;
  final List<String> calls = [];

  int loads = 0;
  bool failLoads = false;
  bool failWrites = false;

  /// When set, [savedIds] waits on this so a test can hold the load open.
  Completer<void>? gate;

  @override
  Future<List<String>> savedIds() async {
    loads++;
    if (gate != null) await gate!.future;
    if (failLoads) throw StateError('offline');
    return List<String>.from(_ids);
  }

  @override
  Future<void> save(String pictureId) async {
    calls.add('save:$pictureId');
    if (failWrites) throw StateError('offline');
    _ids.add(pictureId);
  }

  @override
  Future<void> unsave(String pictureId) async {
    calls.add('unsave:$pictureId');
    if (failWrites) throw StateError('offline');
    _ids.remove(pictureId);
  }
}

void main() {
  group('SavedPhotos', () {
    test('reports what the server says is saved', () async {
      final saved = SavedPhotos(_FakeStore(initial: ['a', 'b']));
      await saved.ensureLoaded();

      expect(saved.isSaved('a'), isTrue);
      expect(saved.isSaved('c'), isFalse);
    });

    test('loads once, however many rails ask', () async {
      // Every photo on screen builds a rail; one request between them.
      final store = _FakeStore();
      final saved = SavedPhotos(store);

      await Future.wait([
        saved.ensureLoaded(),
        saved.ensureLoaded(),
        saved.ensureLoaded(),
      ]);
      await saved.ensureLoaded();

      expect(store.loads, 1);
    });

    test('concurrent callers share the one in-flight request', () async {
      final store = _FakeStore()..gate = Completer<void>();
      final saved = SavedPhotos(store);

      final first = saved.ensureLoaded();
      final second = saved.ensureLoaded();
      store.gate!.complete();
      await Future.wait([first, second]);

      expect(store.loads, 1);
    });

    test('a failed load is retried rather than cached as empty', () async {
      // Caching the failure would make every photo look unsaved, and the next
      // tap would write a duplicate instead of un-saving.
      final store = _FakeStore(initial: ['a'])..failLoads = true;
      final saved = SavedPhotos(store);

      await saved.ensureLoaded();
      expect(saved.isLoaded, isFalse);
      expect(saved.isSaved('a'), isFalse);

      store.failLoads = false;
      await saved.ensureLoaded();

      expect(saved.isLoaded, isTrue);
      expect(saved.isSaved('a'), isTrue);
      expect(store.loads, 2);
    });

    test('toggle saves, then un-saves', () async {
      final store = _FakeStore();
      final saved = SavedPhotos(store);
      await saved.ensureLoaded();

      expect(await saved.toggle('a'), isTrue);
      expect(saved.isSaved('a'), isTrue);

      expect(await saved.toggle('a'), isFalse);
      expect(saved.isSaved('a'), isFalse);

      expect(store.calls, ['save:a', 'unsave:a']);
    });

    test('the glyph flips before the request lands', () async {
      final store = _FakeStore();
      final saved = SavedPhotos(store);
      await saved.ensureLoaded();

      final pending = saved.toggle('a');
      expect(saved.isSaved('a'), isTrue, reason: 'optimistic');
      await pending;
    });

    test('a failed write rolls the glyph back and says so', () async {
      final store = _FakeStore()..failWrites = true;
      final saved = SavedPhotos(store);
      await saved.ensureLoaded();

      await expectLater(saved.toggle('a'), throwsA(isA<StateError>()));
      expect(saved.isSaved('a'), isFalse);
    });

    test('a failed un-save leaves the photo saved', () async {
      final store = _FakeStore(initial: ['a']);
      final saved = SavedPhotos(store);
      await saved.ensureLoaded();
      store.failWrites = true;

      await expectLater(saved.toggle('a'), throwsA(isA<StateError>()));
      expect(saved.isSaved('a'), isTrue);
    });

    test('a double tap is one write, not two', () async {
      final store = _FakeStore();
      final saved = SavedPhotos(store);
      await saved.ensureLoaded();

      final first = saved.toggle('a');
      final second = saved.toggle('a');
      await Future.wait([first, second]);

      expect(store.calls, ['save:a']);
    });

    test('notifies listeners so every rail on the photo agrees', () async {
      final saved = SavedPhotos(_FakeStore());
      await saved.ensureLoaded();

      var notified = 0;
      saved.revision.addListener(() => notified++);

      await saved.toggle('a');

      expect(notified, greaterThan(0));
    });

    test('an empty id is ignored', () async {
      final store = _FakeStore();
      final saved = SavedPhotos(store);
      await saved.ensureLoaded();

      expect(await saved.toggle(''), isFalse);
      expect(store.calls, isEmpty);
    });

    test('clear drops everything for the next account', () async {
      final saved = SavedPhotos(_FakeStore(initial: ['a']));
      await saved.ensureLoaded();
      expect(saved.isSaved('a'), isTrue);

      saved.clear();

      expect(saved.isSaved('a'), isFalse);
      expect(saved.isLoaded, isFalse);
    });
  });
}
