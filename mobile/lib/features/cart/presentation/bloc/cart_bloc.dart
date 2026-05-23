import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:skidoo_app/core/di/service_locator.dart';
import 'package:skidoo_app/core/error/exceptions.dart';
import 'package:skidoo_app/features/cart/domain/usecases/complete_payment_usecase.dart';
import 'package:skidoo_app/features/cart/domain/usecases/download_image_usecase.dart';
import 'package:skidoo_app/features/cart/domain/usecases/pay_for_images_usecase.dart';
import 'package:skidoo_app/models/photos/Photo.dart';
import 'package:skidoo_app/services/auth_service.dart';

part 'cart_event.dart';
part 'cart_state.dart';

class CartBloc extends Bloc<CartEvent, CartState> {
  final PayForImagesUseCase _payForImagesUseCase;
  final CompletePaymentUseCase _completePaymentUseCase;
  final DownloadImageUseCase _downloadImageUseCase;
  final AuthService _authService;

  CartBloc({
    required PayForImagesUseCase payForImagesUseCase,
    required CompletePaymentUseCase completePaymentUseCase,
    required DownloadImageUseCase downloadImageUseCase,
  })  : _payForImagesUseCase = payForImagesUseCase,
        _completePaymentUseCase = completePaymentUseCase,
        _downloadImageUseCase = downloadImageUseCase,
        _authService = sl<AuthService>(),
        super(const CartState()) {
    on<CartItemAdded>(_onItemAdded);
    on<CartItemRemoved>(_onItemRemoved);
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
    final updated =
        state.items.where((i) => i.id != event.photo.id).toList();
    emit(state.copyWith(
      items: updated,
      totalAmount: _calculateTotal(updated),
      successMessage: 'Image removed.',
    ));
  }

  Future<void> _onPaymentInitiated(
      CartPaymentInitiated event, Emitter<CartState> emit) async {
    if (state.items.isEmpty) {
      emit(state.copyWith(errorMessage: 'Cart is empty.'));
      return;
    }
    emit(state.copyWith(
        status: CartStatus.paymentLoading, clearMessages: true));
    try {
      final email = await _authService.getEmail();
      final response = await _payForImagesUseCase(
        PayForImagesParams(
            email: email, amount: state.totalAmount.toString()),
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
      final paidImages = state.items
          .map((item) => {
                'pictureId': item.id,
                'clientId': clientId,
                'userId': item.userId,
              })
          .toList();
      final payload = {
        'amount': state.totalAmount,
        'referenceId': state.referenceId,
        'clientId': clientId,
        'PaidImage': paidImages,
      };
      final response =
          await _completePaymentUseCase(CompletePaymentParams(payload));
      if (response['paidImages'] != null &&
          response['paidImages']['count'] != null &&
          (response['paidImages']['count'] as int) > 0) {
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
    emit(state.copyWith(
        status: CartStatus.idle, clearMessages: true));
  }
}
