import 'package:flutter/foundation.dart';
import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/features/discovery/data/datasources/client_saved_data_source.dart';

/// The app's [SavedPhotos], or null when the service locator has not been set
/// up.
///
/// In the running app this is never null — `setupServiceLocator()` completes
/// before the first frame. It is null in a widget test that pumps one control
/// on its own, and the controls treat that as "no bookmark to offer" rather
/// than throwing: an action row is worth rendering without its bookmark, and a
/// test of the row's chrome should not have to stand up the whole locator.
SavedPhotos? savedPhotosOrNull() =>
    sl.isRegistered<SavedPhotos>() ? sl<SavedPhotos>() : null;

/// A notifier that never fires, for controls that found no [SavedPhotos] and
/// so have no bookmark state to rebuild for.
final ValueNotifier<int> kNoSavedPhotos = ValueNotifier<int>(0);

/// The three calls [SavedPhotos] makes. An interface rather than the data
/// source itself so a rail can be pumped in a widget test without an HTTP
/// client, a token, or a logged-in user behind it.
abstract class SavedPhotoStore {
  Future<List<String>> savedIds();
  Future<void> save(String pictureId);
  Future<void> unsave(String pictureId);
}

/// [SavedPhotoStore] over the real endpoints.
class ApiSavedPhotoStore implements SavedPhotoStore {
  ApiSavedPhotoStore(this._source);

  final ClientSavedDataSource _source;

  static const _assetType = 'picture';

  @override
  Future<List<String>> savedIds() =>
      _source.listSavedIds(assetType: _assetType);

  @override
  Future<void> save(String pictureId) =>
      _source.saveItem(assetType: _assetType, assetId: pictureId);

  @override
  Future<void> unsave(String pictureId) =>
      _source.unsaveByAsset(assetType: _assetType, assetId: pictureId);
}

/// Which photos the signed-in user has bookmarked, and the toggle that changes
/// it.
///
/// Exists because "is this photo saved" is asked by every photo the user looks
/// at, and answering it per photo over the network would be one request per
/// tile. The full id set is small — ids only, see
/// [ClientSavedDataSource.listSavedIds] — so it is fetched once and held for
/// the session, and every rail reads the answer locally.
///
/// The [ValueListenable] is what keeps two rails showing the same photo in
/// step: the Found viewer and the fullscreen viewer both listen, so saving in
/// one fills the bookmark in the other without either knowing the other exists.
///
/// Note this is a bookmark, not a download. The two were the same action for a
/// while — the bookmark glyph on a photo rail wrote the file to the device and
/// nothing was ever saved — which is why the filled state had nowhere to come
/// from and no photo could be un-saved.
class SavedPhotos {
  SavedPhotos(this._store);

  final SavedPhotoStore _store;

  /// Bumped on every change so listeners rebuild. The set itself is mutable and
  /// held by identity, so the notifier carries a counter rather than the set.
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  final Set<String> _saved = {};
  Future<void>? _loading;
  bool _loaded = false;

  /// In-flight toggles, so a double tap cannot fire two writes for one photo.
  final Set<String> _busy = {};

  bool isSaved(String pictureId) => _saved.contains(pictureId);

  bool isBusy(String pictureId) => _busy.contains(pictureId);

  /// Whether the set has been fetched. Until it has, [isSaved] answers false
  /// for everything — an unfilled bookmark is the right thing to show while the
  /// answer is unknown, and it corrects itself when [ensureLoaded] completes.
  bool get isLoaded => _loaded;

  /// Fetches the set once. Safe to call from every rail's initState: concurrent
  /// callers share the one request, and later calls are free.
  Future<void> ensureLoaded() {
    if (_loaded) return Future<void>.value();
    return _loading ??= _load();
  }

  Future<void> _load() async {
    try {
      final ids = await _store.savedIds();
      _saved
        ..clear()
        ..addAll(ids);
      _loaded = true;
      revision.value++;
    } catch (_) {
      // Leave _loaded false so the next rail retries. A failed load must not
      // become a permanent "nothing is saved", which would let an un-save look
      // like a save and write a duplicate.
    } finally {
      _loading = null;
    }
  }

  /// Saves or un-saves [pictureId], returning the state it ended in.
  ///
  /// Optimistic: the glyph flips before the request, and flips back if it
  /// fails. Rethrows so the caller can say why.
  Future<bool> toggle(String pictureId) async {
    if (pictureId.isEmpty || _busy.contains(pictureId)) {
      return isSaved(pictureId);
    }

    final wasSaved = _saved.contains(pictureId);
    _busy.add(pictureId);
    _apply(pictureId, saved: !wasSaved);

    try {
      if (wasSaved) {
        await _store.unsave(pictureId);
      } else {
        await _store.save(pictureId);
      }
      return !wasSaved;
    } catch (_) {
      _apply(pictureId, saved: wasSaved);
      rethrow;
    } finally {
      _busy.remove(pictureId);
      revision.value++;
    }
  }

  void _apply(String pictureId, {required bool saved}) {
    if (saved) {
      _saved.add(pictureId);
    } else {
      _saved.remove(pictureId);
    }
    revision.value++;
  }

  /// Drops everything — call on sign-out, or the next account inherits these.
  void clear() {
    _saved.clear();
    _busy.clear();
    _loaded = false;
    _loading = null;
    revision.value++;
  }
}
