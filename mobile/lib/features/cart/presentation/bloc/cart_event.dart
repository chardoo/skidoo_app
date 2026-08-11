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

class CartPaymentCompleted extends CartEvent {
  const CartPaymentCompleted();
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
