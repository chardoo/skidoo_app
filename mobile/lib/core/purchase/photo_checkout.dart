import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/core/purchase/photo_selection.dart';
import 'package:jperg_app/core/utils/gallery_refresh_signal.dart';
import 'package:jperg_app/core/utils/snackbar_utils.dart';
import 'package:jperg_app/features/cart/domain/usecases/save_images_free_usecase.dart';
import 'package:jperg_app/features/cart/presentation/bloc/cart_bloc.dart';
import 'package:jperg_app/features/cart/presentation/pages/checkout_page.dart';
import 'package:jperg_app/services/auth_service.dart';

/// Buying the photos a [PhotoSelection] holds.
///
/// Extracted so every grid that sells photos goes through one implementation.
/// There were already two purchase paths in this app before this — the cart's
/// and the search results page's own — and a third written for the Found album
/// would have made the rule "how do we take money" a thing you had to read
/// three files to know.
///
/// Two halves that belong together: [runPhotoCheckout] starts it, and
/// [PhotoCheckoutListener] wraps the screen so the Paystack page can be pushed
/// when the cart says it is ready.

/// The cart, if this screen has one above it — otherwise the registered
/// singleton, otherwise null.
///
/// The viewer opens from nine places now and they do not share an ancestor:
/// some sit under Home, which provides the cart, and some are pushed onto the
/// root navigator by a deep link. Rather than requiring every one of them to
/// provide it, the pieces here find it and degrade quietly when there is none
/// — which is also what lets a widget test build the viewer bare.
CartBloc? maybeCart(BuildContext context) {
  try {
    return context.read<CartBloc>();
  } on ProviderNotFoundException {
    return sl.isRegistered<CartBloc>() ? sl<CartBloc>() : null;
  }
}

/// Save what is free, then pay for what is not. Never throws.
///
/// In that order, and not in one transaction, because they are not one thing:
/// the free photos are already this person's to keep and saving them should
/// not be contingent on a card clearing. If payment then fails they keep the
/// free ones and are told about the rest — the outcome someone would expect.
/// The reverse order holds their own photos hostage to a checkout they might
/// abandon.
Future<void> runPhotoCheckout(
  BuildContext context,
  PhotoSelection selection,
) async {
  final free = selection.free;
  final paid = selection.paid;
  if (free.isEmpty && paid.isEmpty) return;

  if (free.isNotEmpty) {
    try {
      final clientId = await sl<AuthService>().getUserId();
      await sl<SaveImagesForFreeUseCase>()(free, clientId: clientId);
      GalleryRefreshSignal.bump();
    } catch (_) {
      // Worth saying, not worth stopping for — the paid photos are the part
      // with money attached and the part they are waiting on.
      if (context.mounted) {
        AppSnackBar.error(context, 'Could not save your free photos.');
      }
    }
  }

  if (!context.mounted) return;

  if (paid.isEmpty) {
    AppSnackBar.success(context, 'Saved to your gallery.');
    return;
  }

  // Hand this screen's chosen photos to the cart wholesale, then let its
  // existing pipeline take over: initialize → Paystack → complete → PaidImage
  // rows → GalleryRefreshSignal.
  final cart = maybeCart(context);
  if (cart == null) {
    AppSnackBar.error(
        context, 'Could not start the payment. Please try again.');
    return;
  }
  cart
    ..add(CartItemsReplaced(paid))
    ..add(const CartPaymentInitiated());
}

/// Pushes the Paystack page when the cart has a URL, and reports the outcome.
///
/// A widget rather than a mixin so it can wrap any screen's body without that
/// screen having to be stateful or know the cart exists beyond calling
/// [runPhotoCheckout].
class PhotoCheckoutListener extends StatelessWidget {
  const PhotoCheckoutListener({
    super.key,
    required this.child,
    this.onSuccess,
  });

  final Widget child;

  /// Called after a successful purchase — for clearing the screen's selection,
  /// which is now bought and should stop looking like it is for sale.
  final VoidCallback? onSuccess;

  @override
  Widget build(BuildContext context) {
    final cart = maybeCart(context);
    // Nothing to listen to — a screen with no cart anywhere above it, which in
    // practice means a widget test. It still draws.
    if (cart == null) return child;

    return BlocListener<CartBloc, CartState>(
      bloc: cart,
      listenWhen: (prev, next) => prev.status != next.status,
      listener: (context, state) {
        switch (state.status) {
          case CartStatus.paymentInitiated when state.paymentUrl != null:
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => BlocProvider.value(
                  // The one this listener is on, which is not always the one
                  // in the tree — a viewer opened from a deep link has no cart
                  // above it and uses the registered singleton.
                  value: cart,
                  child: CheckoutPage(url: state.paymentUrl!),
                ),
              ),
            );
          case CartStatus.paymentSuccess:
            AppSnackBar.success(
              context,
              state.successMessage ?? 'Your photos are unlocked.',
            );
            onSuccess?.call();
          case CartStatus.paymentFailure:
            AppSnackBar.error(
              context,
              state.errorMessage ?? 'Payment failed. Please try again.',
            );
          default:
            break;
        }
      },
      child: child,
    );
  }
}
