# After payment

What the app does the moment a photo purchase clears, and why.

The report this answers (QA item 6):

> After payment is made the user comes back to the picture with the buy tag
> again. This is not supposed to be so, it has to even route the user to the
> gallery for the user to see the paid pictures.

Two separate faults, fixed separately.

---

## 1. The buy tag stayed on a photo that had been paid for

### What was happening

Every priced surface asked one question — "has this been bought?" — and every
one of them answered it from `Photo.isPurchased`, the flag on the record the
screen was built from. That flag is wrong twice over:

* **Only two endpoints send it.** `GET /client/my-photos` and the discovery
  feed set `isPurchased`; see `main/app/repositories/my_photos_repository.py`
  and `feed_repository.py`. A photo opened from a profile grid, a search
  result, an album or a `/p/{id}` link arrives saying `false` whether or not it
  was bought.
* **It is fixed at fetch time.** The list behind the viewer was fetched *before*
  the payment, so after the payment every photo in it still said "not bought".

The payment itself runs on a route pushed over the viewer (`CheckoutPage`, the
Paystack WebView). When it pops, the screen underneath has no reason to rebuild
and nothing new to rebuild from — so the Buy pill, the price badge, the
watermark and the locked action rail were all exactly as they had been drawn.

`PurchasedPhotos` already knew better: `CartBloc._onPaymentCompleted` feeds it
the ids it just bought. Only the download button ever consulted it.

### The fix

One question, asked in one place: `lib/core/purchase/photo_ownership.dart`.

```dart
bool photoIsBought(Photo photo);                 // the payload's flag OR the id set
bool pictureIsBought(String id, {bool isPurchased});
class PurchaseAware extends StatefulWidget { … } // rebuilds when the set changes
```

`photoIsBought` says yes if *either* source says yes — the payload is right
about photos fetched since the purchase, the id set is right about the ones
fetched before it. `PurchaseAware` wraps anything drawn off it so the answer
moving while the screen is up repaints that screen, which is the case that was
broken.

Surfaces switched over to it:

| File | What stops showing |
|---|---|
| `found/widgets/found_photo_stage.dart` | the "GHS 20 \| Buy" pill, the watermark |
| `found/widgets/found_photo_filmstrip.dart` | the thumbnail's amount and watermark |
| `found/widgets/found_photo_tile.dart` | the grid tile's amount, watermark and tick |
| `found/widgets/found_action_rail.dart` | `actionsFor` unlocks the rail a paid photo has nothing on |
| `found/widgets/found_photo_quick_actions.dart` | now defers to the shared helper |
| `core/purchase/photo_selection.dart` | an owned photo leaves the selection and the total |
| `search/widgets/search_photo_grid.dart` | the tile's amount, tick and watermark |
| `home/pages/search_results_page.dart` | the card's price treatment |
| `gallery/pages/gallery_fullscreen_page.dart` | the full-screen watermark |

### Two further things that were wrong underneath it

* **`PurchasedPhotos._load` replaced the set instead of merging into it.** A
  purchase completing while the first fetch was in flight was overwritten by a
  response written before it happened — the Buy pill came back for the rest of
  the session. It merges now; `clear()` (sign-out) is still what empties the
  set, so nothing goes stale.
* **The search-results checkout never told the app it had bought anything.** It
  completes payment directly through `CartRepository` rather than through
  `CartBloc`, and so skipped both `GalleryRefreshSignal.bump()` and
  `PurchasedPhotos.add()`. It does both now, like the cart's own path.

---

## 2. Payment ended on the photo instead of in the gallery

### What was happening

`CheckoutPage` pops itself when Paystack redirects, and that was the end of the
journey: the buyer was back on the photo they had been looking at. Even with the
Buy pill gone, being returned to the same photo is not an answer to "did that
work?".

### The fix

`lib/core/purchase/paid_gallery_route.dart`:

```dart
void openPaidGallery(BuildContext context);
```

It sends the buyer to the gallery of what they have paid for — the **Purchased**
grid on the profile (`POST /client/dashboard`, ordered
`PaidImage.createdAt desc`), so the photos from this purchase are the ones at
the top of it. Three steps, in this order:

1. `UserProfilePage.tabRequest = purchasedTab` — the profile is told which tab
   to show before it is revealed, so the Liked grid is never seen first.
2. `HomePage.tabRequest = profileTab` — the bottom nav switches, which also
   makes the profile reload (`HomePage._changeTab` nudges it, and checkout has
   already bumped `GalleryRefreshSignal`).
3. `popUntil(/home)` — the album, the viewer and the payment page come off, so
   the gallery is what the buyer is looking at.

With no Home underneath — a deep link that opened the viewer on its own, a
session that started at the guest feed — there is nothing to pop back to, so
Home is pushed instead. `HomePage.isLive` is the test rather than the route
stack: a second Home would discard the live one and refetch everything under it.

Called from both checkout paths:

* `core/purchase/photo_checkout.dart` — the shared `PhotoCheckoutListener`,
  which is what the Found album and the Found viewer use.
* `home/pages/search_results_page.dart` — its own older flow. This used to land
  on Home's **Found** pill, which is the right neighbourhood and the wrong
  screen: Found is what recognition matched, paid for or not, so the photos just
  bought were somewhere in a grid among photos still for sale.

The success snackbar is raised *before* the navigation on purpose. It belongs to
the app's one root `ScaffoldMessenger`, so it survives the routes closing under
it and is read on the gallery.

### Deliberately unchanged

* **A free save does not navigate.** Saving the free photos in an album is not
  a payment and the person is still browsing; they get "Saved to your gallery."
  and stay where they are.
* **A failed payment does not navigate.** It reports and leaves the buyer on the
  photo, which is where retrying from makes sense.

---

## Verifying

```bash
cd mobile && flutter test test/features/gallery/purchase_clears_the_buy_tag_test.dart
```

Covers: the tag is there while the photo is unowned; it goes the moment
`PurchasedPhotos.add` lands with the viewer still on screen; it is never drawn
on a photo already owned; the selection's total drops to zero and notifies; and
a finished purchase leaves for the gallery with both tab requests set.

By hand, the path the report took: Found → an album with a priced photo → Buy →
pay → you land on Profile ▸ Purchased with the photo at the top of the grid, and
going back to the album shows it with no amount, no mark, and a live action rail.

Pre-existing, unrelated to this work: the four failures in
`test/features/gallery/bookmark_is_instant_test.dart` (the rail still passes
`SavedPhotos.isBusy` as `busy`, which the test forbids) fail identically at
`HEAD`.
