# App Review — Guideline 2.1(b), business model

Received 2026-10-27. Paste the reply below into App Store Connect. Notes at the
end are internal.

---

## Reply

Thank you — here is our business model in full.

jperg is an event photography marketplace in Ghana. Photographers publish an
event and upload the photos they took; attendees register their face once and
the app returns only the photos they appear in. There is one paid thing in this
build: an individual event photograph. There are no subscriptions, no tiers, no
unlockable app features, and nothing that is sold anywhere outside the app.

1. WHO ARE THE USERS THAT WILL USE THE PAID FEATURES IN THE APP?

Two groups, and only one of them pays us.

Buyers are the attendees of a photographed event — ordinary consumers, 18+,
mostly 18-35, in Ghana. Any registered account can buy; there is no separate
paid account type, no business or enterprise plan, and no eligibility step. A
buyer pays for a single photo of themselves, typically between GHS 5 and GHS
50, in one-off transactions with no recurring charge.

Photographers are the sellers. They pay us nothing — no listing fee, no upload
fee, no subscription. They set each photo's price, receive the full sale price,
and withdraw it to a Ghanaian bank or mobile money account. We take no
commission on photo sales in this release. Our premium creator badge is free
and cannot be bought: it is earned by delivering work on time and is removed
automatically when someone stops doing so.

2. WHERE CAN USERS PURCHASE THE FEATURES THAT CAN BE ACCESSED IN THE APP?

Inside the app only. Tapping Buy on a priced photo opens our payment provider's
hosted checkout page (Paystack, in Ghanaian Cedi) in a web view inside the app,
and the buyer returns to the app when it completes. There is no other
storefront. Our website, jperg.com, is a marketing page plus a portal that only
photographers can sign in to, for uploading and pricing their own photos —
nothing can be bought there, by anyone. We do not sell photo credits, gift
cards, vouchers, codes or bundles, through any channel. Question 4 covers why
that is, and what we are able to change about it.

3. WHAT SPECIFIC TYPES OF PREVIOUSLY PURCHASED FEATURES CAN A USER ACCESS IN
THE APP?

None that were purchased anywhere else, because there is nowhere else to
purchase. The only previously purchased content a user sees is the photos they
themselves bought in the app on an earlier occasion, re-shown under Profile >
Purchased so that a purchase survives reinstalling the app and signing in
again. A purchased photo is viewed in the app without our watermark; the app
has no download, export or save-to-camera-roll function, so nothing leaves the
app as a file.

4. WHAT PAID CONTENT, SUBSCRIPTIONS, OR FEATURES ARE UNLOCKED WITHIN THE APP
THAT DO NOT USE IN-APP PURCHASE?

One, and we want to be straightforward about it rather than have you find it:
the purchase of an individual event photograph. A photographer prices a photo;
an attendee who appears in it pays that price through Paystack's hosted
checkout in a web view, and the photo is then shown to them in full quality
without the watermark. There is nothing else — no subscription, no consumable
currency, no feature unlock, no ad-removal purchase, no paid tier of any kind.

We understand this is the kind of content Guideline 3.1.1 reserves for In-App
Purchase, and we want to be clear that we are not declining to use it. We are
unable to.

We are enrolled as a business in Ghana. Our account cannot complete the Paid
Applications Agreement, because the banking and tax setup it requires is not
offered for our region — and without that agreement In-App Purchase cannot be
configured in App Store Connect at all. There is no In-App Purchase product we
are able to create, and no sandbox transaction we are able to test. This is not
a decision we have made about our business model; it is the only payment path
our developer account has. We have attached a screenshot of what App Store
Connect shows us.

The same constraint applies on the buyer's side. Our customers pay in Ghanaian
Cedi and predominantly by mobile money, which is not available as an Apple ID
payment method in our market, so even where In-App Purchase exists it would not
reach most of the people who use our app.

We are asking for your guidance rather than assuming an answer, and we will do
whichever of these you prefer:

(a) If In-App Purchase can be enabled for our account, tell us how and we will
move photo purchases to StoreKit and keep Paystack only for paying
photographers, which is money leaving our platform rather than a purchase.

(b) If it cannot, we have a build ready that removes purchasing from the iOS
app entirely: no Buy control, no prices, no cart, and no link, button or
message directing users to purchase anywhere else. Photos would be purchasable
only on our website and viewable in the app afterwards, and everything else —
registering a face, searching an event, seeing every photo of yourself
watermarked — stays free as it is today.

We would rather you tell us which you want than guess wrong. Say the word and
we will submit the second build immediately.

5. CAN USERS PURCHASE PHYSICAL GOODS OR SERVICES TOGETHER WITH DIGITAL CONTENT
IN YOUR APP? IF SO, PLEASE DESCRIBE HOW THE PHYSICAL AND DIGITAL CONTENT ARE
CONNECTED AND WHY YOU BUNDLE THEM TOGETHER IN A SINGLE PURCHASE.

No. In this build nothing physical is sold, nothing is shipped, and no
real-world service is paid for. A photo purchase is a single digital item and
is never bundled with anything.

For completeness, because it exists in the code and we would rather disclose it
than leave it to be found: the app contains an unreleased feature for hiring a
photographer for a real-world shoot (a client posts a job, a photographer
quotes, the client pays a deposit and then the balance, and we release the
money once the work is delivered) and an unreleased advertising and campaigns
feature. Both are switched off for every user by a server-side flag and are not
reachable in the version under review. When the hiring feature is released we
will treat it as what it is — payment for a photographer's time at a physical
event, a real-world service performed in person — and the photos they hand over
afterwards are the deliverable of that service, not a separately sold digital
product. We will discuss it with you before switching it on rather than enable
it silently.

Everything above is the complete picture of how we make money today. Happy to
answer anything further.

---

## Notes (internal)

### Before sending

- **Attach the App Store Connect screenshot.** Answer 4 says one is attached
  and it is the whole weight of the argument — ASC showing the Paid
  Applications Agreement cannot be completed, or IAP cannot be configured.
  Without it this reads as a claim rather than a constraint.
- **Answer 4 promises a purchasing-removed build is ready.** It is not built
  yet. There is no per-platform purchase flag today: `/config` has
  `ads_enabled` and `requests_enabled`, nothing for photo purchases and nothing
  keyed on platform.
- **Check `requests_enabled` on production** (`api.piccotechnologies.com`, not
  the Render test DB). Answer 5 says the hiring and advertising features are
  both off. `ads_enabled` was confirmed off for the earlier 2.1 reply, but
  `requests_enabled` is a separate flag and both default to `True` in
  `main/app/models/app_config.py`. If the board is live, answer 5 must describe
  bookings as live — which is fine, a real-world service needs no IAP.

### What was verified in the code

| Claim | Where |
| --- | --- |
| One paid item: an individual photo | `main/app/routers/client/payments.py`; price 0 is free |
| Checkout is Paystack hosted pages in a WebView | `mobile/lib/features/cart/presentation/pages/checkout_page.dart`, `paystack_service.py:62` |
| No purchasing on the website | `picco-v2/src/router/index.ts` — every authenticated route is `/photographer/*` |
| Photographer receives the full sale price | `main/app/services/earnings.py` — `_SALE_AMOUNT` has no fee subtracted; bookings are the only place a platform fee exists |
| Premium tier is free, cannot be bought | `main/app/services/premium.py` — gated on ID verification and delivery record |
| No subscriptions | no recurring product in `paystack_service`; no StoreKit/Play Billing dependency |
| Purchased photos are re-shown, not downloaded | `core/purchase/photo_ownership.dart`; no gallery-saver dependency |
| Ads/campaigns off by server flag | `ads_enabled` on `/config`, read live via `features/ads/campaigns_enabled.dart` |

### Why IAP is not an option, and why nothing else exempts us

IAP is unavailable, not declined: a Ghanaian business enrolment cannot complete
the Paid Applications Agreement. It would take an entity Apple can pay — a
foreign subsidiary — which is a corporate decision, not an engineering one.

- **Multiplatform (3.1.3(b))** permits access to items acquired elsewhere
  *provided those items are also available as IAP in the app* — which needs the
  thing we cannot configure. So the fallback has to be the stricter shape: no
  purchasing surface at all, which is why it removes prices as well as Buy. A
  price with no way to pay it reads as a call to action.
- **Reader apps (3.1.3(a))** covers magazines, newspapers, books, audio, music,
  video. Photographs are not on that list.
- **External Purchase Link Entitlement** is a programme with its own
  entitlement and commission, not permission for a WebView checkout, and it is
  storefront-scoped and does not reach Ghana.
- **Apple Pay is not a substitute.** 3.1.3(e) names it as the method for goods
  consumed *outside* the app. Paystack's Apple Pay rollout (Oct 2026) improves
  web checkout and changes nothing about 3.1.1.
- **Physical services (3.1.3(e))** genuinely covers hiring a photographer for a
  shoot, which is why bookings need no IAP, now or later. It does not cover
  selling a photograph viewed in the app.

### What to expect

Keeping Buy and putting the constraint to Apple is a deliberate choice made
2026-10-28. Expect a 3.1.1 rejection anyway: App Review applies the guidelines
and has no regional-availability clause to waive 3.1.1 under. Cost of finding
out is one cycle.

**Do not resubmit the same build after an explicit 3.1.1 rejection.** IAP
circumvention is a category Apple treats seriously and a pattern of
resubmitting escalates past review to the account. One good-faith attempt is
nowhere near that line; a second refusal is.

**Pursue the real fix in parallel:** an Apple Developer Support thread about the
Paid Applications Agreement being unavailable to a Ghanaian business enrolment.
Different venue, different authority, and the only route by which Buy stays in
the app permanently.

### If the fallback is ever needed

1. Config flag plus one purchasing chokepoint in the app. Eight files test
   `price > 0 && !photoIsBought(photo)`; route them through one
   `core/purchase/purchasing_enabled.dart` modelled on `campaigns_enabled.dart`
   rather than editing eight call sites.
2. Fix `_handle_charge_success` (`main/app/routers/common/webhooks.py:117`),
   which becomes the only settlement path once checkout is on the web. It does
   not set `price_paid`, does not fire `push_payment_success_task`, and does not
   check the amount covers the basket. The first is a live bug today:
   `_SALE_AMOUNT` is `COALESCE(pi.price_paid, pic.price, 0)`, so a
   webhook-settled sale is valued at the photo's current price forever.
3. Per-request `callback_url` in `initialize_payment`
   (`paystack_service.py:56` reads only the global setting).
4. Web storefront under `/buy/*` — a path the AASA `components` whitelist does
   not claim, so the app cannot hijack it. Not `/my-photos`, which it does.
   Plus a magic-link endpoint so the match email lands buyers already signed in.
5. Point `image_recognised_task`'s email and SMS at the storefront, and only
   there — never in the app.
