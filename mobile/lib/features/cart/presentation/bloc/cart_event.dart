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
