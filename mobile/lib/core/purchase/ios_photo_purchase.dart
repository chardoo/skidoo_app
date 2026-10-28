import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';

import 'package:jperg_app/core/purchase/ios_store.dart';
import 'package:jperg_app/features/cart/data/datasources/cart_remote_data_source.dart';

/// Buying a basket of photos on an iPhone, end to end.
///
/// Three steps, and the order of the last two is the whole point:
///
///   1. **Intent.** The server prices the basket, applies the iOS markup, picks
///      the App Store product that covers it, and remembers the basket against
///      an order token.
///   2. **Buy.** StoreKit charges for that product, carrying the token.
///   3. **Verify, then finish.** The server checks Apple's signature and grants
///      the photos. *Only then* is the transaction finished.
///
/// Finishing before the server has granted is the one irreversible mistake
/// available here: StoreKit stops replaying a finished transaction, so a
/// failure in step 3 would leave somebody charged for photos they never
/// received and no receipt left to prove it. So `finish` happens after a
/// successful verify and nowhere else — and a verify that fails leaves the
/// transaction alive, to be retried on the next launch by the replay path in
/// [IosStore].
class IosPhotoPurchase {
  IosPhotoPurchase(this._remote);

  final CartRemoteDataSource _remote;

  /// Whether this build can sell photos through the App Store at all.
  bool get isSupported => IosStore.instance.isSupported;

  /// What a basket costs on iOS, before anybody commits to it.
  ///
  /// Worth calling on its own: the iOS price is not the sum of the prices on
  /// the photos — a markup covers Apple's commission, and the total is rounded
  /// up to a purchasable price point. A checkout screen that showed the raw
  /// subtotal and then charged more would be lying, however small the gap.
  Future<IosQuote> quote({
    required String clientId,
    required List<String> pictureIds,
  }) async {
    final body = await _remote.iosIntent(
      clientId: clientId,
      pictureIds: pictureIds,
    );
    return IosQuote.fromJson(body);
  }

  /// The same figure, without committing to a purchase.
  ///
  /// For labelling a Pay button. [quote] records a pending order each time it
  /// is called, which is right when somebody is buying and wrong when they are
  /// merely looking at their basket.
  ///
  /// Returns null rather than throwing: a price preview that cannot be fetched
  /// should leave the screen showing the subtotal it already had, not replace
  /// the basket with an error.
  Future<IosQuote?> preview({required List<String> pictureIds}) async {
    try {
      return IosQuote.fromJson(await _remote.iosQuote(pictureIds: pictureIds));
    } catch (e) {
      debugPrint('[IAP] could not preview the basket price: $e');
      return null;
    }
  }

  /// Buy [quote], and come back when the photos are in the buyer's library.
  ///
  /// Throws [PurchaseCancelled] if the buyer backs out — which the caller
  /// should treat as nothing having happened, not as a failure worth an error
  /// message.
  Future<int> buy({
    required String clientId,
    required IosQuote quote,
  }) async {
    final purchase = await IosStore.instance.buy(
      productId: quote.productId,
      orderToken: quote.orderToken,
    );

    final granted = await _settle(
      clientId: clientId,
      orderToken: quote.orderToken,
      purchase: purchase,
    );

    // After the grant, never before. See the note on this class.
    await IosStore.instance.finish(purchase);
    return granted;
  }

  /// Settle a transaction StoreKit replayed from an earlier launch.
  ///
  /// The app was killed between paying and settling. The order token travels
  /// on the transaction itself, so the basket is still recoverable — this is
  /// why [IosStore] listens from startup rather than only during a checkout.
  Future<void> resumeUnfinished(
    PurchaseDetails purchase, {
    required String clientId,
  }) async {
    final token = _tokenOf(purchase);
    if (token == null) {
      // Nothing ties this to a basket. Finishing it is the only option that
      // does not replay forever; the purchase is recoverable from the server's
      // pending order by support if somebody reports it.
      debugPrint('[IAP] replayed a purchase with no order token — finishing it');
      await IosStore.instance.finish(purchase);
      return;
    }
    try {
      await _settle(
        clientId: clientId,
        orderToken: token,
        purchase: purchase,
      );
      await IosStore.instance.finish(purchase);
    } catch (e) {
      // Left unfinished on purpose: StoreKit will offer it again next launch,
      // which is the behaviour that eventually delivers the photos.
      debugPrint('[IAP] could not settle a replayed purchase, will retry: $e');
    }
  }

  Future<int> _settle({
    required String clientId,
    required String orderToken,
    required PurchaseDetails purchase,
  }) async {
    final signed = purchase.verificationData.serverVerificationData;
    final body = await _remote.iosVerify(
      clientId: clientId,
      orderToken: orderToken,
      signedTransaction: signed,
    );
    final paid = body['paidImages'];
    final count = paid is Map ? paid['count'] as int? : null;
    return count ?? 0;
  }

  /// The order token a transaction was bought with.
  ///
  /// Set as `applicationUserName` when the purchase was started, and read back
  /// under two different names depending on which StoreKit the plugin used:
  /// `appAccountToken` on StoreKit 2, and the payment's `applicationUsername`
  /// on the StoreKit 1 path. Both are checked because which one a device takes
  /// is the plugin's decision, not this app's.
  ///
  /// Null for a transaction that carries neither — a purchase made by a build
  /// that predates this flow. The caller finishes those rather than retrying
  /// them forever; there is nothing to match them to.
  String? _tokenOf(PurchaseDetails purchase) {
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

/// What the server says an iOS basket costs.
@immutable
class IosQuote {
  const IosQuote({
    required this.productId,
    required this.orderToken,
    required this.subtotal,
    required this.charged,
    required this.addedForPlatform,
    required this.currency,
  });

  /// The App Store product that covers this basket.
  final String productId;

  /// What ties the purchase back to these photos.
  final String orderToken;

  /// The sum of the creators' prices — what a photographer is paid from.
  final double subtotal;

  /// What the buyer is actually charged, which is a price point at or above
  /// [subtotal] plus the markup.
  final double charged;

  /// Everything above [subtotal]: the iOS markup and the rounding together.
  /// Shown so a receipt can say where the difference went.
  final double addedForPlatform;

  final String currency;

  factory IosQuote.fromJson(Map<String, dynamic> json) => IosQuote(
        productId: json['productId'] as String? ?? '',
        orderToken: json['orderToken'] as String? ?? '',
        subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0,
        charged: (json['charged'] as num?)?.toDouble() ?? 0,
        addedForPlatform:
            (json['addedForPlatform'] as num?)?.toDouble() ?? 0,
        currency: json['currency'] as String? ?? 'GHS',
      );

  /// Whether the buyer pays more than the photos' prices add up to.
  ///
  /// False when no markup is configured and the basket landed exactly on a
  /// price point — in which case the checkout screen has nothing extra to
  /// explain and should not invent a line item saying "+0.00".
  bool get hasPlatformAddition => addedForPlatform > 0.004;
}
