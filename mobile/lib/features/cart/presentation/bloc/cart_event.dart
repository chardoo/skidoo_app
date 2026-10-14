part of 'cart_bloc.dart';

abstract class CartEvent extends Equatable {
  const CartEvent();
  @override
  List<Object?> get props => [];
}

class CartItemAdded extends CartEvent {
  final Photo photo;
  const CartItemAdded(this.photo);
  @override
  List<Object?> get props => [photo.id];
}

class CartItemRemoved extends CartEvent {
  final Photo photo;
  const CartItemRemoved(this.photo);
  @override
  List<Object?> get props => [photo.id];
}

/// Replace the whole basket in one go.
///
/// For the Found album, whose selection is scoped to one event: the bar there
/// describes what is on screen ("12 free photos saved automatically"), so what
/// it checks out has to be exactly this album's kept photos and nothing left
/// over from a previous one. Clearing and re-adding one by one would emit a
/// state per photo and leave a window where the total is wrong.
class CartItemsReplaced extends CartEvent {
  final List<Photo> photos;
  const CartItemsReplaced(this.photos);
  @override
  List<Object?> get props => [photos.map((p) => p.id).toList()];
}

class CartPaymentInitiated extends CartEvent {
  const CartPaymentInitiated();
}

/// Settle the basket against the reference the checkout was opened with.
///
/// Dispatched when Paystack hands the buyer back *and* when the buyer closes
/// the checkout themselves, because the two are not distinguishable from the
/// outside: on this deployment Paystack's last page frequently has no redirect
/// left in it, so "they pressed back" and "they paid and were never sent
/// anywhere" look identical. `/client/payments/complete-images` verifies the
/// reference with Paystack and is idempotent, so asking about a payment that
/// never happened is free and not asking about one that did costs somebody
/// their photos.
class CartPaymentCompleted extends CartEvent {
  const CartPaymentCompleted({this.quiet = false});

  /// Suppresses the failure message, leaving the success path untouched.
  ///
  /// True when the buyer simply closed the checkout: the likeliest reason the
  /// settlement is refused there is that they changed their mind, and
  /// "Payment failed. Please try again." for a payment nobody made is the app
  /// inventing a problem. A refusal after a redirect that carried a reference
  /// still speaks.
  final bool quiet;

  @override
  List<Object?> get props => [quiet];
}

class CartImageDownloaded extends CartEvent {
  final String url;
  const CartImageDownloaded(this.url);
  @override
  List<Object?> get props => [url];
}

class CartCleared extends CartEvent {
  const CartCleared();
}

class CartMessageDismissed extends CartEvent {
  const CartMessageDismissed();
}
