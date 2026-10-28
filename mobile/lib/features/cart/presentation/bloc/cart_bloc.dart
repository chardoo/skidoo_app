import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/core/error/exceptions.dart';
import 'package:jperg_app/core/purchase/ios_photo_purchase.dart';
import 'package:jperg_app/core/purchase/ios_store.dart';
import 'package:jperg_app/features/cart/data/datasources/cart_remote_data_source.dart';
import 'package:jperg_app/core/utils/gallery_refresh_signal.dart';
import 'package:jperg_app/features/gallery/data/purchased_photos.dart';
import 'package:jperg_app/features/cart/domain/repositories/cart_repository.dart';
import 'package:jperg_app/features/cart/domain/usecases/download_image_usecase.dart';
import 'package:jperg_app/models/photos/Photo.dart';
import 'package:jperg_app/services/auth_service.dart';

part 'cart_event.dart';
part 'cart_state.dart';

class CartBloc extends Bloc<CartEvent, CartState> {
  /// Both halves of a purchase go through the repository's *-images calls:
  /// the basket is a list of picture ids and the server prices it. See
  /// [_onPaymentInitiated].
  final CartRepository _repository;

  /// Built on first use rather than in the constructor.
  ///
  /// Two reasons, and the second is the one that bit. It reaches into the
  /// service locator, so constructing it eagerly makes every test that builds
  /// a CartBloc register a CartRemoteDataSource it has no use for. And on
  /// Android it is never touched at all — photo purchases there go through
  /// Paystack — so building it there is work for a path that does not exist.
  IosPhotoPurchase? _iosPurchaseOrNull;
  IosPhotoPurchase get _iosPurchase =>
      _iosPurchaseOrNull ??= IosPhotoPurchase(sl<CartRemoteDataSource>());
  final DownloadImageUseCase _downloadImageUseCase;
  final AuthService _authService;

  CartBloc({
    required CartRepository repository,
    required DownloadImageUseCase downloadImageUseCase,
  })  : _repository = repository,
        _downloadImageUseCase = downloadImageUseCase,
        _authService = sl<AuthService>(),
        super(const CartState()) {
    on<CartItemAdded>(_onItemAdded);
    on<CartItemRemoved>(_onItemRemoved);
    on<CartItemsReplaced>(_onItemsReplaced);
    on<CartPaymentInitiated>(_onPaymentInitiated);
    on<CartIosQuoteUpdated>(_onIosQuoteUpdated);
    on<CartPaymentCompleted>(_onPaymentCompleted);
    on<CartImageDownloaded>(_onImageDownloaded);
    on<CartCleared>(_onCartCleared);
    on<CartMessageDismissed>(_onMessageDismissed);
  }

  double _calculateTotal(List<Photo> items) =>
      items.fold(0.0, (sum, item) => sum + item.price);

  void _onItemAdded(CartItemAdded event, Emitter<CartState> emit) {
    if (state.items.any((i) => i.id == event.photo.id)) {
      emit(state.copyWith(successMessage: 'Already in cart.'));
      return;
    }
    final updated = List<Photo>.from(state.items)..add(event.photo);
    emit(state.copyWith(
      items: updated,
      totalAmount: _calculateTotal(updated),
      // The old figure is for the old basket.
      clearIosQuote: true,
      successMessage: 'Image added to cart.',
    ));

    _refreshIosQuote(emit);
  }

  void _onItemRemoved(CartItemRemoved event, Emitter<CartState> emit) {
    final updated = state.items.where((i) => i.id != event.photo.id).toList();
    emit(state.copyWith(
      items: updated,
      totalAmount: _calculateTotal(updated),
      // The old figure is for the old basket.
      clearIosQuote: true,
      successMessage: 'Image removed.',
    ));

    _refreshIosQuote(emit);
  }

  void _onItemsReplaced(CartItemsReplaced event, Emitter<CartState> emit) {
    final updated = List<Photo>.from(event.photos);
    emit(state.copyWith(
      items: updated,
      totalAmount: _calculateTotal(updated),
      // The old figure is for the old basket.
      clearIosQuote: true,
      // No success message: this is a screen setting up its own basket before
      // checking out, not a person adding something. "Image added to cart."
      // for each of nine photos would be nine snackbars nobody asked for.
      clearMessages: true,
    ));

    _refreshIosQuote(emit);
  }

  /// Re-price the basket for the App Store after it changes.
  ///
  /// Fire-and-forget, and iOS-only. A failed preview leaves the button showing
  /// the subtotal it already had rather than blanking it: a price that is a
  /// little optimistic beats a basket that looks broken, and Apple's own sheet
  /// states the real figure before anybody is charged either way.
  void _refreshIosQuote(Emitter<CartState> emit) {
    if (!IosStore.instance.isSupported) return;
    final ids = state.items.map((i) => i.id).toList();
    if (ids.isEmpty) return;
    unawaited(_iosPurchase.preview(pictureIds: ids).then((quote) {
      if (quote != null && !isClosed) add(CartIosQuoteUpdated(quote));
    }));
  }

  void _onIosQuoteUpdated(
      CartIosQuoteUpdated event, Emitter<CartState> emit) {
    // Ignored if the basket moved on while the preview was in flight — the
    // figure would be for a basket that no longer exists.
    if (state.items.isEmpty) return;
    emit(state.copyWith(iosQuote: event.quote));
  }

  Future<void> _onPaymentInitiated(
      CartPaymentInitiated event, Emitter<CartState> emit) async {
    if (state.items.isEmpty) {
      emit(state.copyWith(errorMessage: 'Cart is empty.'));
      return;
    }
    emit(
        state.copyWith(status: CartStatus.paymentLoading, clearMessages: true));
    try {
      final email = await _authService.getEmail();
      final clientId = await _authService.getUserId();

      // On an iPhone, photos are sold through the App Store. Apple requires
      // anything consumed inside the app to go through In-App Purchase, and
      // routing a card payment around it is what the 3.1.1 rejection was
      // about. Everywhere else keeps Paystack, which is the flow below.
      //
      // Bookings are deliberately untouched by this: hiring a photographer is
      // a real-world service under guideline 3.1.3(e) and stays on Paystack on
      // every platform.
      if (IosStore.instance.isSupported) {
        await _payWithAppStore(clientId, emit);
        return;
      }
      // The server prices the basket from the picture ids. This used to send
      // `totalAmount.toString()` to /payments/initialize, which is a Dart
      // double — "60.0" — and the endpoint parsed it with int(), so every
      // checkout answered 500 before Paystack was reached. Sending the ids
      // instead removes the amount from the client altogether: the price of a
      // photo is the server's to know, and the total is now checked against
      // it again at completion.
      final response = await _repository.initializeImages(
        email: email,
        clientId: clientId,
        pictureIds: state.items.map((i) => i.id).toList(),
      );
      final authUrl = response['authorization_url'] as String?;
      final referenceId = response['reference'] as String?;
      if (authUrl == null || referenceId == null) {
        emit(state.copyWith(
            status: CartStatus.paymentFailure,
            errorMessage: 'Invalid payment response.'));
        return;
      }
      emit(state.copyWith(
        status: CartStatus.paymentInitiated,
        paymentUrl: authUrl,
        referenceId: referenceId,
      ));
    } on NetworkException catch (e) {
      emit(state.copyWith(
          status: CartStatus.paymentFailure, errorMessage: e.message));
    } on ServerException catch (e) {
      emit(state.copyWith(
          status: CartStatus.paymentFailure, errorMessage: e.message));
    } catch (e) {
      emit(state.copyWith(
          status: CartStatus.paymentFailure,
          errorMessage: 'Payment failed. Please try again.'));
    }
  }

  /// Buy the basket through the App Store, and settle it with the server.
  ///
  /// Ends in exactly the same state as the card path — the photos land in the
  /// gallery and the basket empties — so everything downstream of a successful
  /// checkout is shared rather than written twice.
  Future<void> _payWithAppStore(
      String clientId, Emitter<CartState> emit) async {
    final ids = state.items.map((i) => i.id).toList();
    try {
      final quote = await _iosPurchase.quote(
        clientId: clientId,
        pictureIds: ids,
      );
      final granted = await _iosPurchase.buy(clientId: clientId, quote: quote);
      if (granted <= 0) {
        emit(state.copyWith(
            status: CartStatus.paymentFailure,
            errorMessage: 'Payment went through but the photos did not arrive. '
                'They will appear shortly — check your Gallery.'));
        return;
      }

      GalleryRefreshSignal.bump();
      purchasedPhotosOrNull()?.add(ids);
      emit(state.copyWith(
        status: CartStatus.paymentSuccess,
        items: [],
        totalAmount: 0,
        referenceId: '',
        successMessage: 'Payment successful! Check your Gallery.',
      ));
    } on PurchaseCancelled {
      // Backing out of the App Store sheet is an ordinary thing to do, not a
      // failure worth an error message. `paymentAbandoned` is the state that
      // already means exactly this for a closed Paystack page: the basket is
      // kept so the next tap on Buy does not start from nothing, and nothing
      // is said out loud.
      emit(state.copyWith(status: CartStatus.paymentAbandoned));
    } on StoreUnavailable catch (e) {
      emit(state.copyWith(
          status: CartStatus.paymentFailure, errorMessage: e.message));
    } on NetworkException catch (e) {
      emit(state.copyWith(
          status: CartStatus.paymentFailure, errorMessage: e.message));
    } on ServerException catch (e) {
      emit(state.copyWith(
          status: CartStatus.paymentFailure, errorMessage: e.message));
    } catch (e) {
      emit(state.copyWith(
          status: CartStatus.paymentFailure,
          errorMessage: 'Payment failed. Please try again.'));
    }
  }

  Future<void> _onPaymentCompleted(
      CartPaymentCompleted event, Emitter<CartState> emit) async {
    emit(state.copyWith(status: CartStatus.paymentLoading));
    try {
      final clientId = await _authService.getUserId();
      final response = await _repository.completeImages(
        referenceId: state.referenceId,
        clientId: clientId,
        pictures: state.items
            .map((item) => {'pictureId': item.id, 'userId': item.userId})
            .toList(),
      );
      if (response['paidImages'] != null &&
          response['paidImages']['count'] != null &&
          (response['paidImages']['count'] as int) > 0) {
        // Newly purchased photos are now in the gallery — refresh it.
        GalleryRefreshSignal.bump();
        // And the viewer still on screen behind this: the download button is
        // drawn off the purchased id set, which would otherwise not know about
        // these until the next session. Fed the ids rather than told to
        // refetch — the cart is holding exactly what it just bought.
        purchasedPhotosOrNull()?.add([for (final item in state.items) item.id]);
        emit(state.copyWith(
          status: CartStatus.paymentSuccess,
          items: [],
          totalAmount: 0,
          referenceId: '',
          successMessage: 'Payment successful! Check your Gallery.',
        ));
      } else {
        emit(_settlementRefused(
            event, 'Payment unsuccessful. Please try again.'));
      }
    } on NetworkException catch (e) {
      emit(_settlementRefused(event, e.message));
    } on ServerException catch (e) {
      emit(_settlementRefused(event, e.message));
    } catch (e) {
      emit(_settlementRefused(event, 'Payment verification failed.'));
    }
  }

  /// The settlement did not produce any photos.
  ///
  /// Which of two things that is depends on how the checkout ended, and the
  /// event carries the answer — see [CartPaymentCompleted.quiet]. A buyer who
  /// was redirected back with a reference and then refused has a problem worth
  /// reporting; a buyer who closed the page is almost always one who changed
  /// their mind, and the basket is left intact so pressing Buy again does not
  /// start from nothing.
  CartState _settlementRefused(CartPaymentCompleted event, String message) =>
      event.quiet
          ? state.copyWith(status: CartStatus.paymentAbandoned)
          : state.copyWith(
              status: CartStatus.paymentFailure,
              items: [],
              totalAmount: 0,
              referenceId: '',
              errorMessage: message,
            );

  Future<void> _onImageDownloaded(
      CartImageDownloaded event, Emitter<CartState> emit) async {
    emit(state.copyWith(status: CartStatus.downloading, clearMessages: true));
    try {
      await _downloadImageUseCase(DownloadImageParams(event.url));
      emit(state.copyWith(
        status: CartStatus.downloadSuccess,
        successMessage: 'Image downloaded successfully.',
      ));
    } on NetworkException catch (e) {
      emit(state.copyWith(
          status: CartStatus.downloadFailure, errorMessage: e.message));
    } on ServerException catch (e) {
      emit(state.copyWith(
          status: CartStatus.downloadFailure, errorMessage: e.message));
    } catch (e) {
      emit(state.copyWith(
          status: CartStatus.downloadFailure,
          errorMessage: 'Download failed.'));
    }
  }

  void _onCartCleared(CartCleared event, Emitter<CartState> emit) {
    emit(const CartState());
  }

  void _onMessageDismissed(
      CartMessageDismissed event, Emitter<CartState> emit) {
    emit(state.copyWith(status: CartStatus.idle, clearMessages: true));
  }
}
