/// What the App Store charges for a basket, as the app understands it.
///
/// The iOS price is not the sum of the prices on the photos: a markup covers
/// Apple's commission, and the total is then rounded up to a purchasable price
/// point. A checkout screen that showed the subtotal and charged the rung
/// would be lying to somebody about money, however small the gap — so the
/// quote carries all three numbers and the screen is expected to show them.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/purchase/ios_photo_purchase.dart';

Map<String, dynamic> body({
  String productId = 'photos_0067',
  String orderToken = 'b4f1c0de-0000-4000-8000-000000000001',
  num subtotal = 50,
  num charged = 67,
  num added = 17,
  String currency = 'GHS',
}) =>
    {
      'productId': productId,
      'orderToken': orderToken,
      'subtotal': subtotal,
      'charged': charged,
      'addedForPlatform': added,
      'currency': currency,
    };

void main() {
  group('reading a quote', () {
    test('carries the product, the token and all three amounts', () {
      final quote = IosQuote.fromJson(body());

      expect(quote.productId, 'photos_0067');
      expect(quote.orderToken, 'b4f1c0de-0000-4000-8000-000000000001');
      expect(quote.subtotal, 50);
      expect(quote.charged, 67);
      expect(quote.addedForPlatform, 17);
      expect(quote.currency, 'GHS');
    });

    test('an integer amount is read as a number, not dropped', () {
      // The server sends JSON numbers, which arrive as int when they have no
      // fractional part. Reading them as double? would silently give null and
      // a checkout screen showing 0.00.
      final quote = IosQuote.fromJson(body(subtotal: 50, charged: 67));
      expect(quote.subtotal, 50.0);
      expect(quote.charged, 67.0);
    });

    test('a fractional amount keeps its pesewas', () {
      final quote = IosQuote.fromJson(body(subtotal: 22.89, charged: 29.76));
      expect(quote.subtotal, closeTo(22.89, 0.0001));
      expect(quote.charged, closeTo(29.76, 0.0001));
    });

    test('a response missing everything does not throw', () {
      // A failed call is handled by the data source; this is the shape that
      // arrives when the server answers with something unexpected, and
      // crashing the checkout screen is the worst available response to it.
      final quote = IosQuote.fromJson(const {});
      expect(quote.productId, isEmpty);
      expect(quote.charged, 0);
    });
  });

  group('whether to explain the extra', () {
    test('says so when the buyer pays more than the photos cost', () {
      expect(IosQuote.fromJson(body(added: 17)).hasPlatformAddition, isTrue);
    });

    test('stays quiet when there is nothing extra to explain', () {
      // No markup configured and the basket landed exactly on a price point.
      // A line reading "+0.00" is noise that invites the question it answers.
      final quote = IosQuote.fromJson(
        body(subtotal: 53, charged: 53, added: 0),
      );
      expect(quote.hasPlatformAddition, isFalse);
    });

    test('stays quiet for a rounding artefact below a pesewa', () {
      // Floating point through JSON turns 0 into 0.000001 often enough that
      // comparing to zero exactly would show the line at random.
      expect(
        IosQuote.fromJson(body(added: 0.0001)).hasPlatformAddition,
        isFalse,
      );
    });

    test('speaks up for a genuine one-pesewa difference', () {
      expect(IosQuote.fromJson(body(added: 0.01)).hasPlatformAddition, isTrue);
    });
  });

  group('what the charge is allowed to be', () {
    test('the buyer is never charged less than the photos are priced at', () {
      // Rounding is always *up* on the server — down would mean the platform
      // paying the difference on every sale. Pinned here too because this is
      // the number the app puts in front of somebody.
      final quote = IosQuote.fromJson(body(subtotal: 50, charged: 67));
      expect(quote.charged, greaterThanOrEqualTo(quote.subtotal));
    });

    test('the extra is exactly the gap between the two', () {
      final quote = IosQuote.fromJson(
        body(subtotal: 50, charged: 67, added: 17),
      );
      expect(quote.charged - quote.subtotal, closeTo(quote.addedForPlatform, 0.0001));
    });
  });
}
