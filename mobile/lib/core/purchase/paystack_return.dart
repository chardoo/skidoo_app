/// How the app knows Paystack has finished with somebody.
///
/// The checkout is a WebView over Paystack's own pages, so "the payment is
/// done" has to be read off a URL. There were two copies of that reading — the
/// photo checkout and the ads checkout — and they did not agree: the ads one
/// knew about `paystack.co/close` and the photo one did not. A photo purchase
/// that ended on the close page therefore sat on screen until the buyer pressed
/// back, which is the whole of the "payment succeeded and nothing happened"
/// report.
///
/// So the reading lives here once, and both checkouts ask it.
class PaystackReturn {
  const PaystackReturn._();

  /// Paystack is handing the customer back, however it chose to do it.
  ///
  /// Four shapes, and all four happen:
  ///
  ///  * **`trxref=` / `reference=`** — appended to the callback URL on every
  ///    post-payment redirect. The query is what is worth matching rather than
  ///    the URL it hangs off: the callback URL is account-wide configuration
  ///    shared with the ads service, and when it pointed at a POST-only webhook
  ///    this WebView loaded the 405 and showed `{"detail":"Method Not
  ///    Allowed"}` as the last thing anyone saw of their purchase.
  ///  * **`/close`** — `standard.paystack.co/close`, which is where the
  ///    standard checkout goes when there is no callback URL to send anybody
  ///    to, and where the inline modal goes when it is dismissed.
  ///    `PAYSTACK_CALLBACK_URL` is unset on this deployment (see
  ///    `main/app/config.py`), so Paystack falls back to the dashboard's — and
  ///    when that is empty too, this is the end of every payment.
  ///  * **the two legacy patterns** — a callback URL still set to one of them
  ///    keeps working.
  ///
  /// Deliberately not a test for *success*: a close page says the session is
  /// over, not that the money cleared. Only the server can say that, and
  /// `/client/payments/complete-images` does — it verifies the reference with
  /// Paystack before it settles anything. So this answers "stop showing the
  /// WebView" and the server answers "did they pay".
  static bool isFinished(String url) {
    final u = url.toLowerCase();
    return u.contains('trxref=') ||
        u.contains('reference=') ||
        u.contains('paystack.co/close') ||
        u.contains('/payment/success') ||
        u.contains('https://example.com/richcode/');
  }

  /// Whether the URL carries a transaction reference, which only a real
  /// post-payment redirect does.
  ///
  /// Separated from [isFinished] because the two answer different questions and
  /// one of them decides whether to speak. A redirect carrying `trxref` is
  /// somebody who went through with it, so a settlement that then fails is
  /// worth an error on screen. A bare close page is far more often somebody who
  /// changed their mind, and telling them "payment failed" for a payment they
  /// never made is the app inventing a problem.
  static bool carriesReference(String url) {
    final u = url.toLowerCase();
    return u.contains('trxref=') || u.contains('reference=');
  }
}
