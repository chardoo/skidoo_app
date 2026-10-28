part of 'cart_bloc.dart';

enum CartStatus {
  idle,
  paymentLoading,
  paymentInitiated,
  paymentSuccess,
  paymentFailure,

  /// The checkout was closed without a payment that cleared.
  ///
  /// Apart from [paymentFailure] because the two deserve different treatment:
  /// a failure is a payment that was attempted and refused and is worth saying
  /// out loud, while this is somebody who opened Paystack and backed out. The
  /// basket is kept so the next tap on Buy does not have to be rebuilt, and
  /// nothing is said — see `CartPaymentCompleted.quiet`.
  paymentAbandoned,
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

  /// What the App Store will actually charge for this basket, on iOS.
  ///
  /// Null everywhere else, and null until the preview lands. [totalAmount] is
  /// the sum of the photographers' prices; on iOS the buyer pays a markup
  /// covering Apple's commission, rounded up to a purchasable price point — so
  /// a Pay button labelled from [totalAmount] alone would name a figure
  /// nobody is charged. See `core/purchase/ios_photo_purchase.dart`.
  final IosQuote? iosQuote;

  const CartState({
    this.items = const [],
    this.totalAmount = 0.0,
    this.referenceId = '',
    this.status = CartStatus.idle,
    this.paymentUrl,
    this.errorMessage,
    this.successMessage,
    this.iosQuote,
  });

  CartState copyWith({
    List<Photo>? items,
    double? totalAmount,
    String? referenceId,
    CartStatus? status,
    String? paymentUrl,
    String? errorMessage,
    String? successMessage,
    IosQuote? iosQuote,
    bool clearIosQuote = false,
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
      iosQuote: clearIosQuote ? null : (iosQuote ?? this.iosQuote),
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
        iosQuote,
      ];
}
