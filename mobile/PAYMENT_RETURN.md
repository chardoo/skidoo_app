# Getting out of the checkout

> The payment is successful but then the screen stays there forever and the
> user has to navigate back. Which should not be the case.

Both halves of that are bugs, and the second is the expensive one: pressing
back told the app nothing, so a payment that had cleared was never settled —
money taken, no photos handed over, and no record on the device that anything
was owed.

---

## Why the screen stayed

The checkout is a WebView over Paystack's own pages, so "the payment is done"
has to be read off a URL. The photo checkout read it in one place, one way:

```dart
static bool _isReturn(String url) =>
    url.contains('trxref=') ||
    url.contains('https://example.com/richCode/') ||
    url.contains('/payment/success');

onNavigationRequest: (request) {
  if (_isReturn(request.url)) { … }
}
```

Three separate things wrong with that.

### 1. The pattern missed how payments actually end here

`PAYSTACK_CALLBACK_URL` is **unset on this deployment** — the default is `""`
(`main/app/config.py`), nothing sets it in `render.yaml`, and
`paystack_service.initialize_payment` only sends `callback_url` when it is
non-empty. So Paystack falls back to the account-wide dashboard URL, and when
that is empty too the standard checkout ends on:

```
https://standard.paystack.co/close
```

which matched none of the three patterns. The WebView sat on it.

The ads checkout had already learned this and tested for `paystack.co/close`;
the photo checkout never did. Two copies of one reading, drifted apart — which
is why it is now one copy: `lib/core/purchase/paystack_return.dart`.

### 2. One channel is not enough

`onNavigationRequest` fires for a navigation the WebView is *about to perform*.
It does **not** fire for a redirect driven from script — `window.location.replace`
on the success page, which is how the standard checkout leaves — and on iOS it
is skipped for some server-side redirects as well.

Both checkouts now watch three channels — `onNavigationRequest`, `onUrlChange`
and `onPageStarted` — and guard with a `_finished` flag, because more than one
fires for the same redirect and the duplicate used to pop the screen
*underneath* the checkout as well.

### 3. "Finished" is not "paid"

A close page says the session is over, not that the money cleared. Only the
server can say that, so `PaystackReturn` deliberately answers *stop showing the
WebView* and leaves *did they pay* to `/client/payments/complete-images`, which
verifies the reference with Paystack before it settles anything.

---

## Why backing out lost the payment

Closing the checkout by hand — the back arrow, the system gesture — did a bare
`Navigator.pop()`. The cart was never told, so `complete-images` was never
called, so the `PaidImage` rows were never written. The buyer had paid and owned
nothing.

That is not a rare path. Given fault 1, the close page *is* where a successful
payment ends, so "they paid and were never sent back" and "they changed their
mind" look identical from inside the app.

**So the basket is now settled either way, and the server decides.** This is
safe because `complete-images`:

* verifies the reference with Paystack and refuses anything that did not
  succeed, and
* is idempotent — an already-settled reference returns the existing
  `PaidImage` count rather than charging or duplicating.

Asking it about a payment that never happened costs nothing. Not asking it about
one that did costs somebody their photos.

### Quiet about refusals, loud about failures

Settling on close would otherwise shout at everyone who changed their mind.
`CartPaymentCompleted` takes a `quiet` flag, set from whether the return URL
carried a reference:

| how it ended | settle? | on refusal |
|---|---|---|
| redirect with `trxref=` / `reference=` | yes | `paymentFailure` — says so |
| close page, back arrow, system gesture | yes | `paymentAbandoned` — silent, basket kept |

`paymentAbandoned` is a new `CartStatus`, separate from `paymentFailure` so the
listener can ignore it. The basket survives it, so pressing Buy again does not
start from nothing. `SearchResultsPage` carries the same distinction through
`AdsCheckoutPage.onAbandoned`, so it no longer tells a buyer who backed out to
"contact support".

---

## Two smaller faults found while fixing this

* **A back-press trap.** `PopScope(canPop: false)` plus a `_finished` guard
  meant that if the pop ever failed to happen, every later back press was
  swallowed and the payment screen could not be left at all. `canPop` is now
  driven from state: false until the screen has settled, true afterwards, so
  the system can always take over. A checkout you cannot leave is worse than
  the bug this started as.
* **The Purchased tab never moved.** `openPaidGallery` writes
  `UserProfilePage.tabRequest` *before* Home switches tabs, and the profile
  lives in an `IndexedStack` under a `TickerMode` that is disabled while another
  tab is showing — so `_tabs.animateTo(...)` was driven by a muted ticker and
  stalled part-way. It assigns `_tabs.index` instead, which is what was wanted
  anyway: arriving on a fresh screen, the Purchased grid should simply already
  be the one on show.

---

## The deployment-side fix, which is not in this change

The app is now robust whatever Paystack does, but the underlying cause is
configuration: **`PAYSTACK_CALLBACK_URL` is empty.** Setting it to a URL that
answers `GET` would make Paystack redirect properly, carrying `trxref` — the
clean path, with a real reference every time and no reliance on the close page.

It is deliberately not set here. The value depends on the deployment, a wrong
one breaks every payment, and `render.yaml` marks secrets `sync: false` for
entry by hand. Worth doing, separately and with a value someone has checked.

Note it is account-wide if left to the dashboard, and shared with the ads
service — which is the trap that produced the comment already in `config.py`:
it was once pointed at a POST-only webhook, so every payment ended on a 405
rendered inside the WebView.

---

## Verifying

```bash
cd mobile
flutter test test/features/cart/
```

`payment_return_test.dart` pins the reading: a callback redirect, the close
page, the two legacy patterns, mixed case — and that the checkout, the card
form and a 3-D Secure challenge are *not* returns, so the screen cannot close
mid-payment. Plus the reference/no-reference split that decides whether the app
speaks.

`settles_on_close_test.dart` pins the settlement: a payment that cleared is
settled even though nobody was redirected (and the Buy tag comes off the photo
behind the checkout); a buyer who changed their mind is told nothing and keeps
their basket; a refusal after a real redirect does report; and settling twice is
harmless.

Suite: 13 failures, all pre-existing and unrelated, byte-identical to the
baseline before this change.

Related: [AFTER_PAYMENT.md](AFTER_PAYMENT.md), which covers where a settled
purchase *goes* — the Buy tag coming off and the trip to Profile ▸ Purchased.
This document covers getting out of Paystack in the first place, which has to
happen before any of that can.
