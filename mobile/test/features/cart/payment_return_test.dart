import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/purchase/paystack_return.dart';

/// How the app decides Paystack is done, and whether it should speak about it.
///
/// The report: "the payment is successful but then the screen stays there
/// forever and the user has to navigate back". The checkout watched one
/// channel (`onNavigationRequest`) for one pattern (`trxref=`), and this
/// deployment configures no `PAYSTACK_CALLBACK_URL` — so Paystack's standard
/// checkout ends on `standard.paystack.co/close`, which matched nothing. The
/// WebView stayed up, and pressing back told the cart nothing, so the basket
/// was never settled either.
void main() {
  group('Paystack has finished', () {
    test('a callback redirect carrying the reference', () {
      expect(
          PaystackReturn.isFinished(
              'https://api.piccotechnologies.com/api/paystack/webhook'
              '?trxref=T123456&reference=T123456'),
          isTrue);
    });

    test('the close page, which is where a payment ends with no callback URL',
        () {
      expect(PaystackReturn.isFinished('https://standard.paystack.co/close'),
          isTrue);
    });

    test('and the two legacy callback patterns still work', () {
      expect(PaystackReturn.isFinished('https://example.com/richCode/abc'),
          isTrue);
      expect(PaystackReturn.isFinished('https://jperg.com/payment/success'),
          isTrue);
    });

    test('case does not matter — the host may arrive capitalised', () {
      expect(PaystackReturn.isFinished('https://Standard.Paystack.CO/Close'),
          isTrue);
      expect(PaystackReturn.isFinished('https://x.test/cb?TRXREF=T1'), isTrue);
    });

    test('but the checkout itself is not a return', () {
      expect(PaystackReturn.isFinished('https://checkout.paystack.com/abc123'),
          isFalse);
      // The card form, 3-D Secure, the bank's own page: all mid-payment.
      expect(PaystackReturn.isFinished('https://checkout.paystack.com/v2/card'),
          isFalse);
      expect(PaystackReturn.isFinished('https://3ds.bank.test/challenge'),
          isFalse);
    });
  });

  group('whether a refusal is worth reporting', () {
    test('a reference came back — they went through with it, so speak up', () {
      expect(PaystackReturn.carriesReference('https://x.test/cb?trxref=T1'),
          isTrue);
      expect(PaystackReturn.carriesReference('https://x.test/cb?reference=T1'),
          isTrue);
    });

    test('a bare close page is usually a change of mind, so stay quiet', () {
      // Still *finished* — the screen must close either way. It just must not
      // announce a failed payment to somebody who never made one.
      const close = 'https://standard.paystack.co/close';
      expect(PaystackReturn.isFinished(close), isTrue);
      expect(PaystackReturn.carriesReference(close), isFalse);
    });
  });
}
