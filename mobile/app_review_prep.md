# App Review prep — notes, checklist, shot list

Everything here is for us. The reply itself is `app_review_response.md`, which
is kept clean so the whole file can be pasted into App Store Connect without
editing anything out.

## Settle these before replying

1. **Fill in the five bracketed values** in item 3: both demo accounts and the
   event code. A reviewer stopped on the sign-in screen is an automatic round
   trip.

2. ~~Confirm advertising is actually off.~~ **Verified 17 October 2026:**
   `GET https://api.piccotechnologies.com/api/config` answers
   `"ads_enabled": false`, so item 3 § 12 is true of the production config the
   reviewed build talks to. Worth re-checking if any time passes before the
   reply goes out — the flag is live admin state, it defaults to **true**, and
   a superAdmin can flip it from the panel's Config screen without touching a
   build. The same call is the fastest way to check: no auth, one line.

3. **Decide what item 4 says about where data lives.** The reply deliberately
   says "cloud infrastructure we control" and names no region, because the
   answer is not settled: the API box is AWS `af-south-1`, while
   `docs/API_LATENCY_AUDIT.md` records the database as an
   `…oregon-postgres.render.com` host and `render.yaml` pins every service to
   Oregon. If a reviewer asks, answer from fact. Never volunteer a region
   nobody has verified — item 6 is a biometric-data answer, and a wrong
   data-location claim is the worst kind to be caught on.

## Known exposure: Guideline 3.1.1

Photo purchases go through Paystack's hosted page in an in-app WebView
(`checkout_page.dart`, `cart_bloc.dart`). What is being bought is a digital
download consumed inside the app, which is what 3.1.1 reserves for In-App
Purchase, and the review letter raised 3.1.1 unprompted. Item 4 of the reply
states the processor plainly rather than hiding it.

Apple's October 2026 guideline revision does **not** help here: folding Music
Streaming Services Entitlements into the StoreKit External Purchase Link
Entitlement is an entitlement programme — application, commission, required
disclosure sheets — not permission for a WebView checkout. Decide deliberately:
adopt IAP for photo purchases, apply for the entitlement, or move buying out of
the app. Expect to be asked either way.

## Why advertising is disclosed rather than hidden

That same revision moved hidden, dormant and undocumented features out of
Guideline 2.3.1 into their own guideline, **2.5.19**. A feature that ships in
the binary and cannot be reached is now a named rejection reason unless it is
declared. Item 3 § 12 declares it in the terms that guideline asks for: what it
is, that it is off, how it is switched off, and that no gesture, code or
account state reaches it. Do not quietly delete the code instead — a disclosed
dormant feature is accepted; an undisclosed one found later is a Developer Code
of Conduct problem, which the revision also sharpened.

## Content reporting, as built

Guideline 1.2 asks for reporting and blocking on user-generated content. As of
17 October 2026:

| Content | Where it is reported |
|---|---|
| Photo | photo viewer ⋯ → "Report photo" (`photo_more_options_sheet.dart`) |
| Comment / reply | long-press → "Report comment" (`comment_dialogs.dart`) |
| Event / album | event ⋯ → "Report event" (`event_more_options_sheet.dart`) |
| Job request | feed card ⋯ → "Report request" (`feed_item_card.dart`) |
| Ad campaign | same sheet — not reachable this release, see item 3 § 12 |
| An account | profile ⋯ → "Report account" (`profile_more_options_sheet.dart`) |
| Blocking | profile ⋯ → Block, and chat room ⋯ → Block |

Reasons are inappropriate content, spam, harassment, child safety or
exploitation, copyright, other. Three inappropriate-content reports take an
item out of circulation; child-safety reports sort ahead of everything else in
the moderation queue. The account type and the child-safety reason are
Postgres enum values added by migration `rep01` — deployed 17 October 2026.

## Demo account checklist

- [ ] `email_verified` is true on both accounts. All three login routes refuse
      an unverified account, so an unverified demo account is an instant
      "unable to review".
- [ ] Two-factor is off on both.
- [ ] The attendee account has a face enrolled and confirmed matches in at
      least one event, so the Found tab is populated on first open. Face search
      cannot be demonstrated from an empty tab.
- [ ] The event code names a live event containing photos of that same
      registered face.
- [ ] At least one photo in that event is priced and at least one is free.
- [ ] The attendee account has one approved request on the board.
- [ ] Paystack is in a mode where the test card in item 3 actually completes.
      If the live key is in use, the test card fails and reads as a bug —
      either switch the demo to test keys, or give the reviewer a real
      low-value photo and say so.
- [ ] Neither demo account is one of the two QA emails that
      `scripts/delete_test_users.py` hard-deletes.

## Shot list for the item 1 screen recording

Physical device, latest iOS, one take, starting from the app icon on the home
screen. Apple names three things explicitly; a missing one is another round
trip.

1. Launch — tap the icon, let the splash finish, land on the feed.
2. Registration — create an account: email, password, the verification code,
   the face step, and at least one wizard screen after it. Then sign out and
   sign in with the demo account.
3. The core feature — Found tab with existing matches, then a live search:
   enter the event code, show the scan running, show the result, open a photo,
   swipe.
4. Paid content — select a priced photo, open checkout, complete the Paystack
   test payment, show the photo under Profile → Purchased and download it.
5. User-generated content and moderation — show photos and a comment being
   posted, then report **a photo** specifically (viewer → ⋯ → Report photo →
   pick a reason → confirm the success state); photos are the primary
   user-generated content and that is the one Apple will look for. Then
   long-press a comment → Report comment, and block someone from their
   **profile** (⋯ → Block), on the profile rather than inside a DM so the
   control is where a reviewer looks for it. Let the reason list stay on screen
   long enough to read "Child safety or exploitation".
6. Account deletion — Settings → Account & Security → Delete account → confirm
   → show that it signs out. Use the second account.

Keep it under about five minutes, no cuts, and do not narrate over a flow that
is not on screen.

## Related

- `app_store_listing.md` — listing copy, keywords, and the pre-submission
  checklist (App Privacy face-data declaration, export compliance for the
  encrypted chat, the request-moderation note).
- `ENCRYPTION.md` — what to answer on the build's export-compliance question.
- `../../docs/DATA_PROTECTION_REGISTRATION.md` — what we declared to the Data
  Protection Commission, checked against the code.
