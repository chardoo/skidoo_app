import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_2_wrappers.dart';

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

  /// What the App Store charges for each of [productIds], already localised.
  ///
  /// Apple's own strings — "GH₵ 55.00", "₦ 4,500", "€ 3,49" — in whatever
  /// storefront the buyer is in, with the symbol and grouping their region
  /// uses. That is the whole reason prices are not quoted by the server: this
  /// is correct everywhere without a rate anybody has to maintain.
  ///
  /// An empty map off iOS, and on any failure. A sheet that cannot reach
  /// StoreKit shows the configured price rather than nothing.
  Future<Map<String, String>> pricesFor(Set<String> productIds) async {
    if (!isSupported || productIds.isEmpty) return const {};
    try {
      if (!await available()) return const {};
      final response = await _iap.queryProductDetails(productIds);
      return {
        for (final p in response.productDetails) p.id: p.price,
      };
    } catch (e) {
      debugPrint('[IAP] could not read prices: $e');
      return const {};
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
    final bool started;
    try {
      started = await _iap.buyConsumable(purchaseParam: param);
    } on PlatformException catch (e) {
      _pending.remove(orderToken);
      // StoreKit scans its unfinished transactions before it will start a new
      // one and refuses outright if any of them is for this same product. It
      // refuses *before* the payment sheet, so the symptom is a Buy button
      // that produces nothing at all — no sheet, no cancellation, no error
      // anybody outside this file could name.
      //
      // Every receipt the server could not settle is one of those, which makes
      // this the second failure of a first failure: one purchase that could not
      // be verified blocks that tier until its transaction is cleared. See
      // [drainUnfinished], which is how it gets cleared.
      if (e.code == 'storekit_duplicate_product_object') {
        throw const PurchaseStillSettling();
      }
      throw StoreUnavailable(e.message ?? 'The App Store refused this purchase');
    }
    if (!started) {
      _pending.remove(orderToken);
      throw const StoreUnavailable('The App Store refused to start this purchase');
    }

    return completer.future;
  }

  /// Settle everything StoreKit is still holding, and finish what it can.
  ///
  /// This is the recovery path for purchases whose receipt never reached the
  /// server, or reached it at a time when it could not be checked. StoreKit
  /// keeps them forever — which is the behaviour we want, since the buyer has
  /// paid — but it also refuses to sell the same product again until they are
  /// finished, so an unsettled receipt silently takes the tier off sale for
  /// whoever owns the phone.
  ///
  /// Reads `Transaction.unfinished` directly rather than waiting for the
  /// purchase stream. The stream is the right place for a purchase made while
  /// the app is running; it is not a reliable way to re-offer one from a
  /// previous launch, and "reliable" is the whole requirement here.
  ///
  /// Scoped to [productPrefix] so this only ever touches what it understands.
  /// A receipt from a flow that no longer exists is left exactly where it is:
  /// it blocks nothing we still sell, and finishing it would throw away the
  /// only evidence that somebody paid.
  ///
  /// Returns how many were finished. Never throws — a recovery sweep that
  /// fails must not take the purchase the buyer is attempting down with it.
  Future<int> drainUnfinished({
    required Future<bool> Function(String orderToken, String signedTransaction)
        settle,
    String productPrefix = 'boost_',
  }) async {
    if (!isSupported) return 0;
    var finished = 0;
    try {
      final held = await SK2Transaction.unfinishedTransactions();
      for (final txn in held) {
        if (!txn.productId.startsWith(productPrefix)) continue;
        // Per transaction, so one receipt the server refuses does not end the
        // sweep and leave the rest of them held.
        try {
          final token = txn.appAccountToken;
          final receipt = txn.receiptData;
          if (token == null ||
              token.isEmpty ||
              receipt == null ||
              receipt.isEmpty) {
            // Nothing to match it to, and nothing to prove it with. Finishing
            // is the only move that does not block the product forever.
            debugPrint('[IAP] finishing an unidentifiable transaction ${txn.id}');
            await _finishById(txn.id);
            finished++;
            continue;
          }
          if (await settle(token, receipt)) {
            await _finishById(txn.id);
            finished++;
          }
        } catch (e) {
          debugPrint('[IAP] held transaction ${txn.id} not settled: $e');
        }
      }
    } catch (e) {
      debugPrint('[IAP] could not drain unfinished transactions: $e');
    }
    if (finished > 0) {
      debugPrint('[IAP] cleared $finished unfinished transaction(s)');
    }
    return finished;
  }

  Future<void> _finishById(String id) async {
    final numeric = int.tryParse(id);
    if (numeric == null) return;
    await SK2Transaction.finish(numeric);
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
  ///
  /// Matched on the order token the transaction actually carries. The map used
  /// to be read by position instead — "the only pending entry, when there is
  /// exactly one" — on the grounds that the server refuses a token that does
  /// not match its order. It does refuse it, and that is the problem: the
  /// refusal lands on the purchase the buyer just made.
  ///
  /// StoreKit replays every transaction that was never finished, including one
  /// from a build whose receipts the server could not yet check, and it replays
  /// them onto this stream *while a new purchase is in flight*. Read by
  /// position, that stale transaction completed the new purchase's future, the
  /// app settled the new order with the old receipt, and the server correctly
  /// answered "that purchase was made for another order" — so Apple had taken
  /// the money and no boost was applied. Matched by token, the stale one falls
  /// through to [_settle]'s replay branch, which settles the order it really
  /// belongs to, and the new purchase keeps waiting for its own transaction.
  ///
  /// Case-insensitively, because the token does not come back as it was sent:
  /// StoreKit round-trips it through `UUID`, and Apple's `uuidString` is
  /// uppercase. The server folds case for the same reason.
  ///
  /// A transaction carrying no token at all still falls back to the single
  /// pending entry: a cancellation or an error arrives as an update with no
  /// transaction behind it, and that update is the only thing that will ever
  /// release the future the buyer is waiting on.
  Completer<PurchaseDetails>? _claim(PurchaseDetails purchase) {
    final token = OrderToken.of(purchase)?.toLowerCase();
    if (token != null) {
      for (final started in _pending.keys) {
        if (started.toLowerCase() == token) return _pending.remove(started);
      }
      return null;
    }
    if (_pending.length == 1) {
      return _pending.remove(_pending.keys.first);
    }
    return null;
  }
}

/// The order token a transaction was bought with.
///
/// Set as `applicationUserName` when the purchase started, and read back under
/// two different names depending on which StoreKit the plugin used:
/// `appAccountToken` on StoreKit 2, and the payment's `applicationUsername`
/// on the StoreKit 1 path. Both are checked because which one a device takes
/// is the plugin's decision, not this app's.
///
/// Null for a transaction carrying neither — a purchase made by a build that
/// predates this flow. The caller finishes those rather than retrying them
/// forever; there is nothing to match them to.
extension OrderToken on IosStore {
  static String? of(PurchaseDetails purchase) {
    if (purchase is SK2PurchaseDetails) {
      final token = purchase.appAccountToken;
      if (token != null && token.isNotEmpty) return token;
    }
    if (purchase is AppStorePurchaseDetails) {
      final name = purchase.skPaymentTransaction.payment.applicationUsername;
      if (name != null && name.isNotEmpty) return name;
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

/// StoreKit will not sell this product while an earlier purchase of it is
/// unfinished.
///
/// Its own type because it is the one failure that is *recoverable from here*:
/// settle what is being held and the same tap works. See
/// [IosStore.drainUnfinished].
class PurchaseStillSettling implements Exception {
  const PurchaseStillSettling();
  @override
  String toString() =>
      'An earlier purchase of this product has not been settled yet';
}
