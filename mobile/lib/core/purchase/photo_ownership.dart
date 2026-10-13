import 'package:flutter/widgets.dart';
import 'package:jperg_app/features/gallery/data/purchased_photos.dart';
import 'package:jperg_app/models/photos/Photo.dart';

/// "Does this person own this picture?", asked in one place.
///
/// The photo's own `isPurchased` is not the answer on its own, and that is the
/// whole reason this exists. Only two endpoints put the flag on a picture —
/// `/client/my-photos` and the discovery feed — so a photo reached any other
/// way arrives saying false whether or not it was bought. Worse, the flag is
/// fixed at *fetch* time: the list a viewer is paging through was fetched
/// before the purchase, so every photo in it still says "not bought" the
/// moment the payment clears. That is what put the Buy pill back on a photo
/// somebody had just paid for.
///
/// [PurchasedPhotos] is the app's own record, fed by checkout the instant a
/// payment completes, so it knows what the payload cannot. Either saying yes
/// is enough: the payload is right about photos fetched since the purchase,
/// and the id set is right about the ones fetched before it.
///
/// Wrap anything drawn off this in a [PurchaseAware] so it repaints when the
/// set changes — the answer moves while the screen is up, which is the case
/// that was broken.
bool pictureIsBought(String pictureId, {bool isPurchased = false}) =>
    isPurchased ||
    (pictureId.isNotEmpty &&
        (purchasedPhotosOrNull()?.isPurchased(pictureId) ?? false));

/// [pictureIsBought] for a [Photo].
bool photoIsBought(Photo photo) =>
    pictureIsBought(photo.id, isPurchased: photo.isPurchased);

/// Rebuilds its child whenever what the viewer owns changes.
///
/// The purchase that changes the answer happens on another route entirely — a
/// Paystack page pushed over this one — and the screen underneath has no other
/// reason to rebuild when it pops. Without this the price pill, the watermark
/// and the locked action rail all stayed as they were drawn.
///
/// Also loads the set if nothing has yet: it is fetched once a session and
/// shared, so asking here costs no request.
class PurchaseAware extends StatefulWidget {
  const PurchaseAware({super.key, required this.builder});

  final WidgetBuilder builder;

  @override
  State<PurchaseAware> createState() => _PurchaseAwareState();
}

class _PurchaseAwareState extends State<PurchaseAware> {
  final PurchasedPhotos? _purchased = purchasedPhotosOrNull();

  @override
  void initState() {
    super.initState();
    _purchased?.ensureLoaded();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
        valueListenable: _purchased?.revision ?? kNoPurchasedPhotos,
        builder: (context, _, __) => widget.builder(context),
      );
}
