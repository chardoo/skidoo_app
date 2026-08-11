import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/core/error/exceptions.dart';
import 'package:jperg_app/core/utils/gallery_refresh_signal.dart';
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
      successMessage: 'Image added to cart.',
    ));
  }

  void _onItemRemoved(CartItemRemoved event, Emitter<CartState> emit) {
    final updated = state.items.where((i) => i.id != event.photo.id).toList();
    emit(state.copyWith(
      items: updated,
      totalAmount: _calculateTotal(updated),
      successMessage: 'Image removed.',
    ));
  }

  void _onItemsReplaced(CartItemsReplaced event, Emitter<CartState> emit) {
    final updated = List<Photo>.from(event.photos);
    emit(state.copyWith(
      items: updated,
      totalAmount: _calculateTotal(updated),
      // No success message: this is a screen setting up its own basket before
      // checking out, not a person adding something. "Image added to cart."
      // for each of nine photos would be nine snackbars nobody asked for.
      clearMessages: true,
    ));
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
        emit(state.copyWith(
          status: CartStatus.paymentSuccess,
          items: [],
          totalAmount: 0,
          referenceId: '',
          successMessage: 'Payment successful! Check your Gallery.',
        ));
      } else {
        emit(state.copyWith(
          status: CartStatus.paymentFailure,
          items: [],
          totalAmount: 0,
          errorMessage: 'Payment unsuccessful. Please try again.',
        ));
      }
    } on NetworkException catch (e) {
      emit(state.copyWith(
          status: CartStatus.paymentFailure, errorMessage: e.message));
    } on ServerException catch (e) {
      emit(state.copyWith(
          status: CartStatus.paymentFailure, errorMessage: e.message));
    } catch (e) {
      emit(state.copyWith(
          status: CartStatus.paymentFailure,
          errorMessage: 'Payment verification failed.'));
    }
  }

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
