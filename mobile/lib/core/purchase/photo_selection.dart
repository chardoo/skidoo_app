import 'package:flutter/foundation.dart';
import 'package:jperg_app/models/photos/Photo.dart';

/// What the viewer claims as theirs, for one event.
///
/// Two modes, because the design has two screens and they are the mirror image
/// of each other:
///
///  * **Browsing** an album from the Found tab ([reviewMode] false) — nothing
///    is selected, and tapping a photo or its Buy pill adds it. The person
///    came to look, and being pre-committed to buying everything they scroll
///    past would be a trap.
///  * **Reviewing** what a scan just turned up ([reviewMode] true) — everything
///    arrives selected and the screen asks them to *remove* the ones that
///    aren't them ("Tap to deselect photos that aren't you"). Recognition has
///    already made the claim; the person is confirming it.
///
/// Either way the exceptions are what is stored — [_toggled] holds the ids
/// that differ from the mode's default. That keeps the set small, and keeps it
/// correct when more photos page in: a photo nobody has touched takes the
/// default, whenever it arrives.
///
/// Scoped to a single album and thrown away when the page is popped. The
/// counts on the bottom bar describe this event — "12 free photos saved
/// automatically" is a statement about what is on screen — so a basket that
/// accumulated across albums could not be described that way.
///
/// A ChangeNotifier rather than a bloc: there is no async work and no event
/// log worth keeping, just a set of ids and three totals derived from it.
class PhotoSelection extends ChangeNotifier {
  PhotoSelection({List<Photo> photos = const [], this.reviewMode = false})
      : _photos = List.of(photos);

  /// Whether a photo nobody has touched counts as selected.
  final bool reviewMode;

  List<Photo> _photos;

  /// Ids whose state differs from [reviewMode]'s default.
  final Set<String> _toggled = <String>{};

  /// Photos already owned are never part of this. They cannot be re-bought,
  /// they must not swell the total, and showing them as "selected" would imply
  /// the CTA is about to charge for them again.
  bool _isSelectable(Photo p) => !p.isPurchased;

  bool isSelected(String id) =>
      _toggled.contains(id) ? !reviewMode : reviewMode;

  /// The photos this selection is drawn from. Replaced wholesale as more pages
  /// load; the deselected set survives, because the person's "not me" decisions
  /// must not be undone by scrolling.
  void updatePhotos(List<Photo> photos) {
    if (listEquals(_photos, photos)) return;
    _photos = List.of(photos);
    notifyListeners();
  }

  void toggle(String id) {
    if (!_toggled.remove(id)) _toggled.add(id);
    notifyListeners();
  }

  /// Back to how the screen opened.
  ///
  /// Which is not the same thing in both modes, and that is the point: on the
  /// browsing screen "Clear" empties the selection, on the review screen it
  /// restores every match. Both are "undo what I have done here", which is
  /// what the word means to the person reading it.
  void clear() {
    if (_toggled.isEmpty) return;
    _toggled.clear();
    notifyListeners();
  }

  Iterable<Photo> get _live => _photos.where(_isSelectable);

  Iterable<Photo> get _kept => _live.where((p) => isSelected(p.id));

  /// Selected photos that cost money — what the CTA buys.
  List<Photo> get paid => _kept.where((p) => p.price > 0).toList();

  /// Selected photos that cost nothing — saved alongside, without payment.
  List<Photo> get free => _kept.where((p) => p.price <= 0).toList();

  int get paidCount => paid.length;
  int get freeCount => free.length;

  double get total => paid.fold(0.0, (sum, p) => sum + p.price);

  /// Whether there is anything to pay for. The bar hides otherwise: an album of
  /// free photos has nothing to check out, and a CTA reading "Get 0 photos"
  /// would be a button that does nothing.
  bool get hasPurchase => paidCount > 0;

  /// Whether the CTA has any work at all — paid or free.
  bool get hasAnything => paidCount > 0 || freeCount > 0;
}
