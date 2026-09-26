import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/features/gallery/data/purchased_photos.dart';
import 'package:jperg_app/features/gallery/presentation/found/models/found_photo_actions.dart';
import 'package:jperg_app/models/photos/Photo.dart';

/// The download on a photo the viewer bought, wherever they opened it.
///
/// It used to be offered on exactly one surface — Found you — on the reasoning
/// that everywhere else shows someone else's work and there is no purchase
/// behind it. That is right about discovery and a shared link, and wrong about
/// the two grids on the profile: Purchased is nothing but purchases, and Saved
/// holds whatever was bookmarked, bought or not.
///
/// The part that makes it awkward is that the photo usually does not know.
/// Only the Found list and the discovery feed return `isPurchased` on a
/// picture, so a photo opened from a profile grid, an album or a link arrives
/// saying false whether or not it was bought. [PurchasedPhotos] is the app's
/// own answer, and these cover both routes to it.

Photo photo({
  double price = 0,
  bool isPurchased = false,
  bool isPublic = true,
  String id = 'pic-1',
}) =>
    Photo.fromMap({
      'id': id,
      'url': 'https://cdn.example.com/$id.jpg',
      'price': price,
      'isPurchased': isPurchased,
      'public': isPublic,
      'comments_enabled': true,
    });

class _FakeStore implements PurchasedPhotoStore {
  _FakeStore(this.ids, {this.throws = false});

  final List<String> ids;
  final bool throws;
  int calls = 0;

  @override
  Future<List<String>> purchasedIds() async {
    calls++;
    if (throws) throw StateError('offline');
    return ids;
  }
}

void main() {
  group('what the rule offers', () {
    test('a bought photo gets the download off any screen', () {
      // The ask: Saved and Purchased both open the ordinary viewer, which
      // builds `unrestricted`.
      final offered = FoundPhotoActions.unrestricted(
        commentsEnabled: true,
        purchased: true,
      );

      expect(offered.download, isTrue);
      expect(offered.anyInBar, isTrue);
    });

    test('an unbought photo still gets nothing', () {
      // The half of the old rule worth keeping: ownership decides, not the
      // screen. Otherwise the app hands out a photographer's work for free.
      const offered = FoundPhotoActions.unrestricted(commentsEnabled: true);

      expect(offered.download, isFalse);
    });

    test('the bookmark and the reactions are untouched by it', () {
      // Only the download moved. A purchase does not change what else these
      // screens offer.
      final bought = FoundPhotoActions.unrestricted(
        commentsEnabled: true,
        purchased: true,
      );

      expect(bought.save, isTrue);
      expect(bought.like, isTrue);
      expect(bought.share, isTrue);
    });

    test('Found you accepts the same fact arriving by the other route', () {
      // A priced photo whose payload says nothing, but which the id set knows
      // was bought. It has to unlock — otherwise the gate turns it away and
      // offers not one glyph.
      final byPayload =
          FoundPhotoActions.forFoundPhoto(photo(price: 20, isPurchased: true));
      final byIdSet =
          FoundPhotoActions.forFoundPhoto(photo(price: 20), purchased: true);

      expect(byPayload.download, isTrue);
      expect(byIdSet.download, isTrue);
      expect(byIdSet.any, isTrue, reason: 'a bought photo is not locked');
    });
  });

  group('the id set', () {
    test('answers for what was bought and nothing else', () async {
      final store = _FakeStore(['a', 'b']);
      final purchased = PurchasedPhotos(store);

      await purchased.ensureLoaded();

      expect(purchased.isPurchased('a'), isTrue);
      expect(purchased.isPurchased('c'), isFalse);
      expect(purchased.isLoaded, isTrue);
    });

    test('is fetched once, however many rails ask', () async {
      // Every viewer calls ensureLoaded from initState; a swipe through twenty
      // photos must not be twenty requests.
      final store = _FakeStore(['a']);
      final purchased = PurchasedPhotos(store);

      await Future.wait([
        purchased.ensureLoaded(),
        purchased.ensureLoaded(),
        purchased.ensureLoaded(),
      ]);
      await purchased.ensureLoaded();

      expect(store.calls, 1);
    });

    test('a failed load retries rather than becoming "you own nothing"',
        () async {
      // The dangerous failure: a permanent false would hide the download on
      // photos somebody paid for, with nothing to say why.
      final store = _FakeStore(const [], throws: true);
      final purchased = PurchasedPhotos(store);

      await purchased.ensureLoaded();
      expect(purchased.isLoaded, isFalse);

      await purchased.ensureLoaded();
      expect(store.calls, 2, reason: 'the next rail has to try again');
    });

    test('a purchase lands without a refetch, and tells its listeners',
        () async {
      // Checkout knows what it bought, and the download has to appear on the
      // photo still on screen behind the payment sheet.
      final store = _FakeStore(const []);
      final purchased = PurchasedPhotos(store);
      await purchased.ensureLoaded();

      var rebuilds = 0;
      purchased.revision.addListener(() => rebuilds++);

      purchased.add(['bought-1', 'bought-2']);

      expect(purchased.isPurchased('bought-1'), isTrue);
      expect(rebuilds, 1);
      expect(store.calls, 1, reason: 'no refetch — the ids were handed over');
    });

    test('signing out forgets them', () async {
      // Or the next account on this phone gets a download button on photos it
      // does not own.
      final store = _FakeStore(['a']);
      final purchased = PurchasedPhotos(store);
      await purchased.ensureLoaded();

      purchased.clear();

      expect(purchased.isPurchased('a'), isFalse);
      expect(purchased.isLoaded, isFalse);
    });
  });
}
