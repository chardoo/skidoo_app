import 'package:flutter/foundation.dart';
import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/features/user_profile/data/repositories/profile_overview_repository.dart';
import 'package:jperg_app/services/auth_service.dart';

/// The app's [PurchasedPhotos], or null when the service locator has not been
/// set up.
///
/// Null only in a widget test that pumps one control on its own; the controls
/// treat that as "nothing is known to be bought" rather than throwing. See
/// [savedPhotosOrNull], which this mirrors.
PurchasedPhotos? purchasedPhotosOrNull() =>
    sl.isRegistered<PurchasedPhotos>() ? sl<PurchasedPhotos>() : null;

/// A notifier that never fires, for controls that found no [PurchasedPhotos].
final ValueNotifier<int> kNoPurchasedPhotos = ValueNotifier<int>(0);

/// The one call [PurchasedPhotos] makes. An interface rather than the
/// repository itself so a rail can be pumped in a widget test without an HTTP
/// client, a token, or a signed-in user behind it.
abstract class PurchasedPhotoStore {
  Future<List<String>> purchasedIds();
}

/// [PurchasedPhotoStore] over the real endpoint.
///
/// Pages `/client/dashboard`, which is the only thing that knows. There is no
/// ids-only endpoint for purchases the way there is for bookmarks, so this
/// pulls full rows and keeps the ids — wasteful in bytes and bounded in
/// practice: the page size is the endpoint's maximum, and nobody has bought a
/// thousand photos. If that stops being true, the fix is a
/// `/client/purchased-ids` on the server rather than more pages here.
class ApiPurchasedPhotoStore implements PurchasedPhotoStore {
  ApiPurchasedPhotoStore(this._repo, this._auth);

  final ProfileOverviewRepository _repo;
  final AuthService _auth;

  /// The endpoint's own ceiling.
  static const _pageSize = 100;

  /// Stops a server that ignores `page` from being asked forever. Ten pages is
  /// a thousand purchases; past that the button is worth less than the
  /// requests.
  static const _maxPages = 10;

  @override
  Future<List<String>> purchasedIds() async {
    final userId = await _auth.getUserId();
    if (userId.isEmpty) return const [];

    final ids = <String>[];
    for (var page = 1; page <= _maxPages; page++) {
      final result = await _repo.getPurchasedPhotos(
        userId,
        page: page,
        limit: _pageSize,
      );
      final before = ids.length;
      for (final photo in result.photos) {
        if (photo.id.isNotEmpty) ids.add(photo.id);
      }
      // A page that brought nothing new is the end, whatever it claimed — the
      // same guard the profile grids use for the same reason.
      if (!result.hasMore || ids.length == before) break;
    }
    return ids;
  }
}

/// Which photos the signed-in user has bought.
///
/// Exists because "did I buy this one" is asked by the viewer on every photo it
/// draws, and the answer is not in the photo. Only two endpoints return
/// `isPurchased` on a picture — the Found list and the discovery feed — so a
/// photo reached any other way arrives not knowing, and the download button
/// that depends on it could not appear. The Saved grid is exactly that case:
/// bookmarking a photo tells the server nothing about whether you own it, and
/// a photo you bought *and* bookmarked came back looking like one you had
/// merely bookmarked.
///
/// So the id set is fetched once per session and every rail reads it locally,
/// the way [SavedPhotos] already does for bookmarks. The [ValueListenable] is
/// what lets a purchase made in one viewer light up the download in another.
///
/// Read-only, unlike [SavedPhotos]: buying happens through checkout, which
/// calls [add] with what it bought rather than making this refetch.
class PurchasedPhotos {
  PurchasedPhotos(this._store);

  final PurchasedPhotoStore _store;

  /// Bumped on every change so listeners rebuild.
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  final Set<String> _purchased = {};
  Future<void>? _loading;
  bool _loaded = false;

  bool isPurchased(String pictureId) => _purchased.contains(pictureId);

  /// Whether the set has been fetched. Until it has, [isPurchased] answers
  /// false for everything — no download button is the right thing to show
  /// while the answer is unknown, and it corrects itself when [ensureLoaded]
  /// completes.
  bool get isLoaded => _loaded;

  /// Fetches the set once. Safe to call from every rail's initState:
  /// concurrent callers share the one request, and later calls are free.
  Future<void> ensureLoaded() {
    if (_loaded) return Future<void>.value();
    return _loading ??= _load();
  }

  Future<void> _load() async {
    try {
      final ids = await _store.purchasedIds();
      _purchased
        ..clear()
        ..addAll(ids);
      _loaded = true;
      revision.value++;
    } catch (_) {
      // Left unloaded so the next rail retries. A failed load must not become
      // a permanent "you own nothing", which would hide the download on photos
      // somebody paid for.
    } finally {
      _loading = null;
    }
  }

  /// Records a purchase that just completed, without a refetch.
  ///
  /// Checkout knows exactly what it bought, and the download has to appear on
  /// the photo still on screen rather than the next time the app is opened.
  void add(Iterable<String> pictureIds) {
    final added = pictureIds.where((id) => id.isNotEmpty).toSet();
    if (added.isEmpty) return;
    _purchased.addAll(added);
    revision.value++;
  }

  /// Drops everything — call on sign-out, or the next account on this phone
  /// inherits a download button for photos it does not own.
  void clear() {
    _purchased.clear();
    _loaded = false;
    _loading = null;
    revision.value++;
  }
}
