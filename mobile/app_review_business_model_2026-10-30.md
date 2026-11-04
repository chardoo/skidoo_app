# App Review — business model, the five questions (re-asked)

Received 2026-10-30, after our Guideline 3.1.1 letter explaining the boost
In-App Purchase. These are the same five questions answered on 2026-10-27 in
[`app_review_2_1b.md`](app_review_2_1b.md), and **several answers have
changed** since then — the Paid Applications Agreement completed, boosts went
to StoreKit, and the request board was switched on. Where an earlier answer no
longer holds, the reply says so in its own words rather than leaving Apple to
notice.

Paste the reply below into App Store Connect. Notes at the end are internal.

---

## Reply

Thank you. The five answers below follow the letter we sent about Guideline
3.1.1, and where our earlier reply of 27 October no longer describes the app,
we say so plainly.

**1. WHO ARE THE USERS THAT WILL USE THE PAID FEATURES IN THE APP?**

Two kinds of people pay in Picco, and they pay for different things.

*Attendees of an event* — ordinary consumers, 18+, mostly 18-35, in Ghana. They
buy individual photographs of themselves, typically GHS 5 to GHS 50, as one-off
purchases with nothing recurring. Some of them also hire a photographer for an
event of their own, which is answered under question 5.

*Photographers* — the sellers on the marketplace. They pay no listing fee, no
upload fee and no subscription, and they receive the proceeds of their photo
sales, withdrawn to a Ghanaian bank or mobile money account. The one thing a
photographer buys is a boost: placing their own job request higher on our
in-app request board. That is the In-App Purchase described in our last letter.

Any registered account can do any of this. There is no paid account type, no
business plan and no eligibility step. Our premium creator badge is free and
cannot be bought — it is earned by delivering work on time and is removed
automatically when someone stops.

**2. WHERE CAN USERS PURCHASE THE FEATURES THAT CAN BE ACCESSED IN THE APP?**

Inside the app, by three routes:

- *A boost* — Apple In-App Purchase, through StoreKit, against three fixed
  consumable products. This is new since our last reply.
- *A photograph* — our payment provider's hosted checkout (Paystack, in
  Ghanaian Cedi) in a web view inside the app, returning to the app when it
  completes.
- *A booking deposit or balance* — the same Paystack checkout, for hiring a
  photographer for a real event. See question 5.

We must correct one thing we told you on 27 October. We said then that nothing
could be bought on our website by anyone. That is no longer true, and we would
rather say so than have it found: jperg.com is a desktop studio that only
photographers can sign into, for work the phone is bad at — uploading the
hundreds of photographs from a shoot, pricing them, and reading their earnings
— and a photographer managing their business there can also buy a boost for
their own job request, through Paystack.

It is their own business tooling and it sells nothing to the people who buy
photographs. The iOS app does not send anyone there to buy: the two links it
carries open the bulk uploader and the creator dashboard, and there is no
button, price, message or hint in the app pointing at a purchase anywhere
outside it. A boost bought on iOS is bought with In-App Purchase.

We sell no credits, gift cards, vouchers, codes or bundles, through any
channel.

**3. WHAT SPECIFIC TYPES OF PREVIOUSLY PURCHASED FEATURES CAN A USER ACCESS IN
THE APP?**

Three, all of them things the same person bought earlier:

- *Photographs bought in the app on an earlier occasion.* They are listed under
  Profile > Purchased and survive reinstalling and signing in again, shown and
  saved at full quality without our preview watermark. (Our 27 October reply
  said the app had no save function. It has one now — for a photograph that
  person owns, and only for that.)
- *An active boost.* It appears on the request it was bought for, with the days
  remaining. If a photographer bought it in the web studio described above, it
  is already active when they open the app.
- *A booking already paid into.* The deposit, the balance and the state of the
  job are shown so both sides can follow it.

Nothing a user buys anywhere unlocks a feature of the app. There is no
entitlement, no tier and no subscription to restore.

**4. WHAT PAID CONTENT, SUBSCRIPTIONS, OR FEATURES ARE UNLOCKED WITHIN THE APP
THAT DO NOT USE IN-APP PURCHASE?**

Two, and we would rather set them out than have them found.

*An individual event photograph*, bought through Paystack. Our last letter
explained at length why this one cannot be a StoreKit product — the item does
not exist until a photographer uploads it, the price is set by that
photographer in cedis, a single event can add several thousand of them in an
afternoon, and the photographer, not us, is the seller. We built and removed
the fixed-price-ladder workaround because it charges the buyer a price nobody
set, records the sale as a price point rather than as a photograph, and makes
Apple the merchant of record for goods we do not own.

*A booking* — hiring a photographer to attend and shoot an event in the
physical world. The client pays a 20% deposit to confirm, then the balance; we
hold it and release it to the photographer after the work is delivered, with a
dispute window. We treat this as what Guideline 3.1.3(e) describes: a
real-world service performed in person, paid for with a payment method other
than In-App Purchase. We take a platform fee on these bookings and none on
photo sales.

Our 27 October reply said this hiring feature was switched off and unreachable.
It is live now, on the same request board the boost In-App Purchase sits on. We
said then that we would raise it with you rather than enable it silently, and
this answer is us doing that.

There is nothing else: no subscription, no virtual currency, no ad-removal
purchase, no paid tier, no unlockable app functionality. Our advertising and
campaigns feature remains switched off for every user by a server-side flag and
does not appear in this build; we disclose it rather than leave it to be found.

**5. CAN USERS PURCHASE PHYSICAL GOODS OR SERVICES TOGETHER WITH DIGITAL
CONTENT IN YOUR APP? IF SO, PLEASE DESCRIBE HOW THE PHYSICAL AND DIGITAL
CONTENT ARE CONNECTED AND WHY YOU BUNDLE THEM TOGETHER IN A SINGLE PURCHASE.**

A real-world service is sold — a photography booking — and it is never bundled
with digital content in a single purchase.

A client posts the job, photographers quote, the client picks one and pays a
deposit and then a balance. What that money buys is a person travelling to a
place at a time and photographing it: a wedding, a graduation, a naming
ceremony. The photographs the photographer hands over afterwards are the work
product of that service, in the way a plumber's invoice is not a purchase of
the fitted pipe. They are not listed, priced or sold as digital items, and the
client is not charged for them a second time.

The marketplace photographs in question 4 are a separate transaction entirely:
a different photographer, a different event, bought one at a time by whoever
happens to appear in them. Nothing in the app sells a service and a digital
item together, and there is no bundle, basket or combined price anywhere in it.

Kind regards,
The Picco Team

---

## Notes (internal)

### What changed since the 27 October reply, and why each correction is in

Three statements in `app_review_2_1b.md` no longer describe the app. All three
are corrected in the reply above, in its own voice, because App Review keeps
prior correspondence on the case and an uncorrected contradiction is read as
concealment rather than drift.

| Said on 27 Oct | True on 30 Oct | Where corrected |
| --- | --- | --- |
| "nothing can be bought [on jperg.com], by anyone" | the creator studio sells boosts via Paystack (`picco-v2` `BoostRequestDialog.vue`) | answer 2 |
| "the app has no download, export or save-to-camera-roll function" | `saver_gallery` ships; a bought photo saves at full quality | answer 3 |
| the hiring feature "and an unreleased advertising and campaigns feature. Both are switched off" | `requests_enabled: true` — bookings and the board are live. Only `ads_enabled` is still false | answer 4 |

### Verified before sending, on production rather than from memory

`GET https://api.piccotechnologies.com/api/config`, 2026-10-30:

```
ads_enabled: false          campaigns genuinely off, as claimed
requests_enabled: true      board, boosts and bookings live
booking_deposit_percent: 20 the "20% deposit" in answer 4
platform_fee_percent: 15    the fee in answer 4 — bookings only
booking_release_days: 7     the release window
```

| Claim | Where |
| --- | --- |
| Boost is StoreKit, 3 consumables, verified server-side | `core/purchase/ios_store.dart`; `/ads/requests/{id}/ios/boost-intent` |
| Photos and bookings are Paystack hosted checkout in a WebView | `ads_checkout_page.dart`; `/ads/requests/{id}/booking/checkout` |
| Premium is free and joined, not bought | `premium_service.dart` — `join(termsVersion)`, no payment path |
| No photo-sale commission; fee is bookings only | `main/app/services/earnings.py`, `_SALE_AMOUNT` |
| The web portal is creator-only | `picco-v2/src/views` — everything authenticated is `photographer/*` |
| The app's only outbound links are uploader and dashboard | `creator_mode_menu.dart`, `creator_ready_page.dart` |

### Watch for

- **Answer 2 is the risky one.** Disclosing that a boost is also buyable on the
  web invites an anti-steering question. The defence is in the same paragraph
  and must stay there: the app carries no link, price or hint pointing at it,
  and the iOS purchase is IAP. Do not trim that sentence for length.
- **Do not describe booking photographs as "free".** They are paid for, inside
  the service. Calling them free invites the reading that a digital item is
  being given away to dodge 3.1.1.
- **If bookings are ever charged per delivered photo**, answer 5 stops being
  true and becomes a bundle. It is a single service fee today.
