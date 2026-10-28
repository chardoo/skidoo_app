import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

/// Buying photos through the App Store.
///
/// Apple requires anything consumed inside the app to be sold through In-App
/// Purchase, and IAP sells *pre-registered products* rather than arbitrary
/// amounts. A photo's price belongs to the photographer who set it, so the two
/// do not line up on their own — the server resolves that by quoting each
/// basket against a ladder of price points and telling this file which product
/// to buy. See `main/app/services/ios_iap.py`.
///
/// What this file is responsible for, and nothing else:
///
///   * asking StoreKit for the one product the server named,
///   * buying it with the server's order token attached,
///   * handing the signed transaction back for verification,
///   * completing the transaction once the server says the photos are granted.
///
/// **It never decides whether a purchase succeeded.** The receipt is signed by
/// Apple and verified on the server; this process is the one an attacker
/// controls, so anything it concludes about its own purchases is worthless.
/// The only question answered here is "did StoreKit hand us a transaction",
/// and the server decides what that transaction is worth.
///
/// Android deliberately does nothing. Photo purchases there go through
/// Paystack, which is the existing flow and is not Apple's business.
class IosStore {
  IosStore._();

  static final IosStore instance = IosStore._();

  /// Resolved on first use, never in the field initialiser.
  ///
  /// `InAppPurchase.instance` builds the platform plugin the moment it is
  /// touched — on Android that opens a billing client and a platform channel.
  /// As a field initialiser it ran merely from reading [isSupported], which is
  /// the one thing every caller does *before* deciding whether any of this
  /// applies: on Android it started billing for a path that does not exist,
  /// and in a widget test it threw for want of a binding.
  InAppPurchase? _iapOrNull;
  InAppPurchase get _iap => _iapOrNull ??= InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  /// Purchases waiting on a result, by the order token they were started with.
  ///
  /// The token is Apple's `applicationUserName`, which comes back on the
  /// transaction — it is the only thread tying an anonymous "the GHS 67
  /// product" back to a particular basket of photographs.
  final Map<String, Completer<PurchaseDetails>> _pending = {};

  /// Only ever true on iOS. Android has its own rail.
  bool get isSupported => !kIsWeb && Platform.isIOS;

  /// Start listening for purchase updates.
  ///
  /// Called once at startup, not when a purchase begins. StoreKit replays
  /// transactions that were never finished — a purchase whose app was killed
  /// between paying and settling arrives on this stream on the *next* launch,
  /// and if nothing is listening then, the buyer has paid for photos they will
  /// never receive.
  Future<void> start({required PurchaseResolver resolver}) async {
    if (!isSupported || _subscription != null) return;
    _resolver = resolver;
    _subscription = _iap.purchaseStream.listen(
      _onUpdates,
      onError: (Object e) => debugPrint('[IAP] purchase stream error: $e'),
    );
  }

  PurchaseResolver? _resolver;

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  /// Whether the App Store is available to this device at all.
  ///
  /// False on a device with purchasing restricted by Screen Time, and in some
  /// sandbox states. Worth asking before showing a Buy button that cannot work.
  Future<bool> available() async {
    if (!isSupported) return false;
    try {
      return await _iap.isAvailable();
    } catch (e) {
      debugPrint('[IAP] isAvailable failed: $e');
      return false;
    }
  }

  /// Buy [productId], tagging the purchase with [orderToken].
  ///
  /// Completes with the transaction StoreKit produced. It is **not** proof of
  /// anything — see the note on this class — and the caller must hand it to the
  /// server before giving anybody a photograph.
  ///
  /// Throws [StoreUnavailable] when the product is not purchasable, and
  /// [PurchaseCancelled] when the buyer backs out, which is an ordinary thing
  /// somebody does and not an error to report as a failure.
  Future<PurchaseDetails> buy({
    required String productId,
    required String orderToken,
  }) async {
    if (!isSupported) {
      throw const StoreUnavailable('In-app purchase is only available on iOS');
    }
    if (!await available()) {
      throw const StoreUnavailable(
          'The App Store is not available on this device');
    }

    final response = await _iap.queryProductDetails({productId});
    if (response.notFoundIDs.contains(productId) ||
        response.productDetails.isEmpty) {
      // The ladder and App Store Connect have drifted: the server quoted a rung
      // whose product does not exist. Nothing the buyer can do, so say so
      // plainly rather than letting StoreKit fail obscurely.
      throw StoreUnavailable(
          'This price is not available in the App Store ($productId)');
    }

    final completer = Completer<PurchaseDetails>();
    _pending[orderToken] = completer;

    final param = PurchaseParam(
      productDetails: response.productDetails.first,
      // Apple carries this through to the transaction, where the server reads
      // it to find out which basket was paid for. Without it a consumable
      // purchase is anonymous and cannot be matched to anything.
      applicationUserName: orderToken,
    );

    // `buyConsumable`, not `buyNonConsumable`: each basket is its own purchase,
    // and somebody buying a second GHS 67 basket must be able to pay again.
    // `autoConsume` is left on so StoreKit releases the product for re-purchase
    // once the transaction is finished.
    final started = await _iap.buyConsumable(purchaseParam: param);
    if (!started) {
      _pending.remove(orderToken);
      throw const StoreUnavailable('The App Store refused to start this purchase');
    }

    return completer.future;
  }

  /// Tell StoreKit a transaction is settled and may stop being replayed.
  ///
  /// **Only after the server has granted the photos.** Finishing earlier is the
  /// one irreversible mistake in this flow: StoreKit forgets the transaction,
  /// the buyer has paid, and there is no longer a receipt to prove it.
  Future<void> finish(PurchaseDetails purchase) async {
    if (purchase.pendingCompletePurchase) {
      await _iap.completePurchase(purchase);
    }
  }

  void _onUpdates(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          // Ask-to-buy, or a card being checked. Nothing to do but wait.
          break;

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          _settle(purchase);

        case PurchaseStatus.error:
          _fail(purchase,
              StoreUnavailable(purchase.error?.message ?? 'Purchase failed'));

        case PurchaseStatus.canceled:
          _fail(purchase, const PurchaseCancelled());
      }
    }
  }

  void _settle(PurchaseDetails purchase) {
    final token = purchase.purchaseID;
    final waiting = _claim(purchase);
    if (waiting != null) {
      waiting.complete(purchase);
      return;
    }

    // Nobody is waiting: this is a transaction StoreKit kept because the app
    // died before it was finished, now replayed on a later launch. The buyer
    // paid and never got the photos, so it is settled here rather than
    // discarded — this is the whole reason the stream is listened to at
    // startup and not only during a purchase.
    debugPrint('[IAP] replaying an unfinished purchase: $token');
    _resolver?.call(purchase);
  }

  void _fail(PurchaseDetails purchase, Object error) {
    final waiting = _claim(purchase);
    waiting?.completeError(error);
    // A failed purchase still has to be finished, or StoreKit replays it
    // forever.
    unawaited(finish(purchase));
  }

  /// The completer waiting on this transaction, if the app started it.
  Completer<PurchaseDetails>? _claim(PurchaseDetails purchase) {
    // `applicationUserName` is not readable back off a PurchaseDetails on all
    // platforms, so the pending map is keyed on what we sent and matched by
    // the only pending entry when there is exactly one. A second concurrent
    // purchase is not possible from the UI — the checkout screen blocks — and
    // the server rejects a transaction whose token does not match its order
    // anyway, so a wrong guess here fails safely rather than granting.
    if (_pending.length == 1) {
      return _pending.remove(_pending.keys.first);
    }
    return null;
  }
}

/// Given a replayed transaction, settle it with the server.
typedef PurchaseResolver = Future<void> Function(PurchaseDetails purchase);

/// The App Store cannot sell this, for a reason the buyer cannot fix.
class StoreUnavailable implements Exception {
  const StoreUnavailable(this.message);
  final String message;
  @override
  String toString() => message;
}

/// The buyer backed out. An ordinary thing to do, not a failure.
class PurchaseCancelled implements Exception {
  const PurchaseCancelled();
  @override
  String toString() => 'Purchase cancelled';
}
