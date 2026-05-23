part of 'cart_bloc.dart';

enum CartStatus {
  idle,
  paymentLoading,
  paymentInitiated,
  paymentSuccess,
  paymentFailure,
  downloading,
  downloadSuccess,
  downloadFailure,
}

class CartState extends Equatable {
  final List<Photo> items;
  final double totalAmount;
  final String referenceId;
  final CartStatus status;
  final String? paymentUrl;
  final String? errorMessage;
  final String? successMessage;

  const CartState({
    this.items = const [],
    this.totalAmount = 0.0,
    this.referenceId = '',
    this.status = CartStatus.idle,
    this.paymentUrl,
    this.errorMessage,
    this.successMessage,
  });

  CartState copyWith({
    List<Photo>? items,
    double? totalAmount,
    String? referenceId,
    CartStatus? status,
    String? paymentUrl,
    String? errorMessage,
    String? successMessage,
    bool clearMessages = false,
  }) {
    return CartState(
      items: items ?? this.items,
      totalAmount: totalAmount ?? this.totalAmount,
      referenceId: referenceId ?? this.referenceId,
      status: status ?? this.status,
      paymentUrl: paymentUrl ?? this.paymentUrl,
      errorMessage: clearMessages ? null : (errorMessage ?? this.errorMessage),
      successMessage:
          clearMessages ? null : (successMessage ?? this.successMessage),
    );
  }

  @override
  List<Object?> get props => [
        items,
        totalAmount,
        referenceId,
        status,
        paymentUrl,
        errorMessage,
        successMessage,
      ];
}
