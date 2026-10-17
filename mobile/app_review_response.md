# App Review reply — "additional information needed"

Answers for items 2–6 of the review letter, written to be pasted into the
App Store Connect reply and into App Review Information → Notes so the
next submission inherits them. Item 1 (the screen recording) is being captured
separately; there is a shot list at the end so the recording does not miss a
flow Apple named.

Everything below was checked against the code on 13 October 2026 (app
version 1.0.1+63, bundle `com.example.jperg`, API
`https://api.piccotechnologies.com`). Text inside ``` fences is the copy to
send; text outside the fences is for us.

---

## ⚠ Read before you send this

Three things to know before you paste anything. Two came out of the letter;
the third is ours to declare. None of them is covered up below — it is cheaper
to fix or disclose them than to argue them.

1. ~~Photos and comments cannot be reported in the app.~~ **Wired on 17
October 2026 — this gap is closed.** Apple's item 1 asks the recording to show
"any user-generated content, including the required content reporting and
blocking mechanisms" (Guideline 1.2). Where every kind of content is reported
now:

| Content | Report in app? | Where |
|---|---|---|
| Event / album | ✅ | event ⋯ → "Report event" (`event_more_options_sheet.dart`) |
| Ad campaign | ✅ | feed card ⋯ → "Report ad" (`feed_item_card.dart:1418`) — not reachable this release, see item 3 § 12 |
| Job request | ✅ | feed card ⋯ → "Report request" (same sheet) |
| Individual photo | ✅ | photo viewer ⋯ → "Report photo" (`photo_more_options_sheet.dart`) |
| Comment / reply | ✅ | long-press a comment → "Report comment" (`comment_dialogs.dart`) |
| An account | ✅ | profile ⋯ → "Report account" (`profile_more_options_sheet.dart`) |
| Abusive user | ✅ | profile ⋯ → Block, and chat room ⋯ → Block |

Two things changed beyond the wiring, both worth knowing before the recording
is shot:

- **Blocking is no longer only inside a DM.** It is on the ⋯ menu of both
  profile screens, which is where a reviewer looks for it. The chat room's own
  Block is unchanged.
- **"Child safety or exploitation" is now its own report reason**, separate
  from "inappropriate content", and the moderation queue sorts those reports
  ahead of everything else. That is the in-app route the published CSAE
  standards describe, and it is what Google Play's Child Safety Standards
  policy requires as well.

Server side: `POST /client/{id}/report` takes `assetType` of `picture`,
`event`, `request`, `campaign`, `comment`, `user`, and `reason` of
`inappropriate_content`, `spam`, `harassment`, `copyright`, `child_safety`,
`other` (`main/app/routers/client/report.py`). Three inappropriate-content
reports still take an item out of circulation automatically; an account report
resolves to a suspension from the admin console. **Needs `alembic upgrade head`
on the main service** — the two new values are Postgres enum values
(migration `rep01`).

2. Photo purchases go through Paystack, not In-App Purchase. Checkout opens
Paystack's hosted page in an in-app WebView (`checkout_page.dart`,
`cart_bloc.dart:100`). The thing being bought is a digital download consumed
inside the app, which is what Guideline 3.1.1 reserves for IAP — and the letter
raises 3.1.1 unprompted. The answer to item 4 below states the processor
plainly rather than hiding it. Decide deliberately which way to go: adopt IAP
for photo purchases, or move buying out of the app entirely. Expect this to be
asked either way.

3. Advertising is built but switched off, and that has to be *said*. The ads
and campaigns feature is hidden for every user by the server-side `ads_enabled`
flag while it is finished, so a reviewer will not see it. Apple's October 2026
guideline revision moved hidden, dormant and undocumented features out of 2.3.1
into their own guideline, **2.5.19**, which means a feature that exists in the
binary and cannot be reached is now a named reason for rejection unless it is
disclosed. Item 3 § 12 discloses it in the terms that guideline asks for: what
it is, that it is off, how it is switched off, and that no gesture or account
state reaches it. Do not quietly drop the code instead — a disclosed dormant
feature is accepted, an undisclosed one found later is a Developer Code of
Conduct problem.

Two things below are unconfirmed and must be settled before replying: the
database's region (item 4 carries a bracket), and whether `ads_enabled` is
genuinely off in the production config the reviewed build will talk to. Check
the admin panel's Config screen for the second — the flag is live state, not
something the build decides, so it can be true right now and the disclosure
would then be wrong.

---

## 2. Purpose and target audience

```
jperg is an event photography marketplace. It solves one specific problem: at
weddings, graduations, concerts, parties and conferences, professional
photographers take hundreds of photos, and the people in those photos almost
never see them. The photos sit on a memory card or in a folder nobody is given
a link to, and finding yourself means scrolling through hundreds of strangers'
shots or asking the photographer to search by memory.

jperg closes that gap from both ends:

For attendees (most of our users). You register your face once at signup. When
you attend an event, you scan the event's code or search it, and the app
returns only the photos you personally appear in — matched by face recognition
rather than by browsing. You can save the free ones, buy the ones that are
priced, follow the photographers whose work you like, message them, and comment
on individual photos.

For photographers and creators. You publish an event, upload the photos you
took, set a price per photo, and the people who were actually there find
themselves and pay you for their own shots. You keep a profile with sample
work, take direct messages, and answer public job requests with a quote when
somebody is looking to hire.

There is also a request board: a user posts what they need shot (event type,
location, budget) and photographers send quotes. Posting is free. Requests pass
through admin moderation before they appear on the board.

Target audience. Adults who attend photographed social events — our primary
group is 18-35 — plus professional and semi-professional photographers who
shoot those events for a living. Accounts are for people aged 18 and over, as
stated in our terms. The initial market is Ghana, where the payment processor
and SMS provider operate; the app itself is not restricted by region (see
item 5).

Value provided. Attendees get photos of themselves they would otherwise never
see. Photographers get paid for work that currently goes undelivered, and reach
the specific people who were in their frames instead of posting an album and
hoping.
```

## 3. Setting up and accessing the main features

Fill in the three bracketed values before sending. The demo account must
already satisfy the checklist under the fence or the reviewer will be stopped
on the first screen.

```
DEMO ACCOUNT (attendee / client)
  Email:    [DEMO_CLIENT_EMAIL]
  Password: [DEMO_CLIENT_PASSWORD]

DEMO ACCOUNT (photographer / creator)
  Email:    [DEMO_PHOTOGRAPHER_EMAIL]
  Password: [DEMO_PHOTOGRAPHER_PASSWORD]

Both accounts are email-verified and have two-factor authentication switched
off, so they log in with the password alone.

EVENT CODE for face search: [DEMO_EVENT_CODE]

--- Attendee walkthrough -------------------------------------------------

1. Launch the app. Tap "Sign in" and use the attendee credentials above. (To
   see registration instead, tap "Create account": email + password, then a
   6-digit code sent to that address, then a 4-step wizard — add your face,
   tell us what describes you, pick interests, pick creators to follow. Every
   step after the face can be skipped.)

2. Home feed. Events and photos from creators, scored by interest and
   location. Scroll, like, tap a card to open the event. The ⋯ menu on a card
   is where content is reported.

3. FINDING YOUR PHOTOS — the core feature. Open the "Found" tab. The demo
   account already has matches, so photos of the registered face appear
   grouped by event. Tap one to open the viewer and swipe.
   To run a search from scratch: tap the scan icon, enter the event code
   above, and the app searches that event for your face. Matches arrive as
   "pending" and you confirm or deselect which ones are you.

4. BUYING A PHOTO (paid content). A photo with a price shows a "Buy" pill.
   Select one or more, tap the purchase bar, and checkout opens Paystack's
   secure payment page inside the app. Use Paystack's test card:
   4084 0840 8408 4081, any future expiry, CVV 408, PIN 0000, OTP 123456.
   Purchased
   photos appear under Profile > Purchased and can be downloaded at full
   quality.
   Photos priced at 0 are free and are saved without any payment step.

5. USER-GENERATED CONTENT. Photos and events are uploaded by photographers;
   comments and job requests are written by users. Everything a user can post
   can be reported from the ⋯ menu on it — a photo (⋯ in the photo viewer), an
   event or a job request (⋯ on the card), or a comment (long-press it). Choose
   a reason: inappropriate content, spam, harassment, child safety or
   exploitation, copyright, other. Three inappropriate-content reports take an
   item out of circulation automatically, and child-safety reports are triaged
   ahead of all other moderation.
   To report or block the person rather than the post: open their profile and
   use ⋯ > "Report account" or ⋯ > Block. Block is also on the ⋯ menu of a
   direct message. A block stops messages in both directions.

6. MESSAGING. Chats tab. Direct messages are end-to-end encrypted; events have
   their own chat rooms. Attachments are images, video, audio and files.

7. HIRING. "Requests" > create a request (event type, location, date, budget).
   Note for review: a new request goes to admin moderation and does NOT appear
   on the public board immediately. The demo account already has one approved
   request so the quote flow can be seen end to end.

8. ACCOUNT DELETION. Profile > Settings > Account & Security > "Delete
   Account", then confirm in the dialog. This is immediate and permanent:
   personal data is erased, the
   face enrolment is severed so matches do not carry to a future account, and
   every signed-in session is terminated. Purchase records are retained without
   personal data, for photographer payout integrity only. Please use the
   secondary demo account if you want to exercise this, so the primary one
   survives for the rest of the review.

--- Photographer walkthrough ---------------------------------------------

9.  Sign in with the photographer credentials. Dashboard shows events,
    earnings and payouts.
10. Create an event: name, date, location, cover image, optional soundtrack,
    then upload photos and set a price. Uploaded photos are scanned for faces
    in the background, which is what lets attendees find themselves.
11. Request board: browse jobs, send a quote. Bookings run on escrow — quote,
    deposit, balance, release.

--- Not available in this release -----------------------------------------

12. ADVERTISING / CAMPAIGNS. The app contains an advertising feature —
    sponsored cards in the feed and a "My Campaigns" area for buying them. It
    is NOT part of this release and is switched off for every user by a
    server-side configuration flag (`ads_enabled`), so no advertisement and no
    campaign screen will appear anywhere during review. It is disclosed here
    rather than left for you to find: the feature is still being completed and
    we did not want to ship a half-finished surface. There is no way for a user
    to switch it on, it is not reachable by any gesture, code or account state,
    and no advertising is sold or served to users today. When it is finished we
    will submit the release that turns it on and will describe it in full then.
```

Demo account checklist — verify each before replying:

- [ ] `email_verified` is true on both accounts. All three login routes refuse
      an unverified account (`EmailNotVerifiedError`), so an unverified demo
      account is an instant "unable to review".
- [ ] Two-factor is off (`POST /client/login/verify-2fa` exists; a demo
      account behind it cannot be logged into).
- [ ] The attendee account has a face enrolled and confirmed matches in
      at least one event, so the Found tab is populated on first open. A
      reviewer cannot test face search from an empty tab.
- [ ] `[DEMO_EVENT_CODE]` names a live event that contains photos of that same
      registered face.
- [ ] At least one photo in that event is priced (paid flow) and at least
      one is free.
- [ ] The attendee account has one approved request on the board.
- [ ] Paystack is in a mode where the test card above actually completes. If
      the live key is in use, the test card will fail and that reads as a bug —
      either switch the demo to test keys or give the reviewer a real low-value
      photo and say so.
- [ ] Neither demo account is one of the two QA emails that
      `scripts/delete_test_users.py` hard-deletes.

## 4. External services, tools and platforms

```
Core functionality

- Face recognition is our own service, which we build and operate. It enrols a
  user's face at signup, detects faces in uploaded event photos, and scores a
  candidate match against a confidence threshold before a photo is shown to
  anyone as "yours". No third party receives or processes face data. Faces are
  enrolled against an internal person identifier, not against names or email
  addresses. The service runs on our own infrastructure (hosted at Render).
- Cloudflare R2 — object storage and delivery for new photo, video and
  attachment uploads.
- Cloudinary — storage, image transformation and CDN delivery for media
  uploaded before the move to R2, which is still the majority of the library.
  It also renders the watermark overlay on unpurchased paid photos. Both
  providers are live; which one serves a given file depends on when it was
  uploaded.
- Paystack — payment processing for photo purchases. Hosted checkout, opened in
  an in-app WebView. Currency: GHS.

Accounts, messaging and notifications

- Our own API and database (FastAPI + PostgreSQL) — accounts, authentication
  (email and password, JWT), events, photos, payments, chat and moderation.
  The API runs on AWS (af-south-1, Cape Town) behind Cloudflare; the database
  is [CONFIRM: AWS af-south-1 or Render Oregon — see the note under this
  fence]. There is no third-party authentication provider and no social
  sign-in: we issue and verify our own tokens.
- SendGrid, with a Gmail SMTP fallback — transactional email (verification
  codes, password reset, receipts).
- OneSignal — push notifications.
- Arkesel — SMS (Ghana).

Content and discovery

- Audiomack — the music a photographer can score an event with. Licensed
  partner. The app plays preview clips only and every track carries a "Listen
  on Audiomack" link, where the full play is counted and the artist credited.
  See item 6.
- Open-Meteo — city and place lookup for the location field on events, ads and
  job requests. Proxied and cached by our own server; never called from the
  app.
- An IP geolocation lookup, plus the CDN's own country header — resolves the
  viewer's country for ad and request targeting when the user has not set one.

Recommendations

- The feed's ranking is our own code (collaborative filtering plus
  content-based scoring, scikit-learn, trained on our own data). We do not use
  any third-party AI service, large language model or generative AI service
  anywhere in the app.
```

Two things to settle before this goes out:

- **Where the database actually is.** The API box is `af-south-1` — that much is
  in `deploy-aws.yml`. The database is documented in `docs/API_LATENCY_AUDIT.md`
  as an `…oregon-postgres.render.com` host, and `render.yaml` pins every service
  to Oregon. If that is still the case, say Render (US) rather than South
  Africa: item 6 is a biometric-data answer, and a wrong data-location claim is
  the worst kind to be caught on. Fill the bracket in with whichever is true.
- **Advertising is off in this release** and is disclosed at the end of item 3.
  Paystack's bullet no longer mentions ad campaigns or request boosts for the
  same reason — nothing in this build can buy one. Put them back when the
  feature ships.

## 5. Regional differences

```
The app's features and content are the same in every region. Nothing is gated
by the user's country: sign-up, face registration, face search, viewing and
buying photos, messaging, commenting, reporting, blocking, the request board
and account deletion all behave identically wherever the app is opened.

Three region-dependent details, none of which changes what the app does:

1. Payments are processed in Ghanaian Cedi (GHS) through Paystack, our
   processor for the launch market. A buyer anywhere can pay with any card
   Paystack accepts; the amount is charged in GHS.
2. Some content is targeted by its creator, not by us. A photographer can
   restrict an event to, or exclude it from, chosen countries, and people
   posting job requests can target theirs. So two users in different countries
   may see a different mix of events and job requests, in the same way two
   users with different interests do. This is a creator-chosen audience
   setting, not a regional feature difference.
3. SMS notifications are sent through a Ghana gateway. Email and push
   notifications are global and are what the app relies on; SMS is
   supplementary.

Most of our current users are in Ghana because that is where we launched, not
because of any restriction in the app.
```

## 6. Regulated industry / protected third-party material

```
The app is not in a regulated industry — it is not finance, health, gambling,
or any licensed profession. Three areas where we hold or need authorisation:

1. BIOMETRIC DATA (face recognition). The app registers a user's face in order
   to find them in event photos. This is the sensitive part of the product and
   is treated as such:
   - Face registration is explicit and user-initiated. At signup it is a step
     the user performs knowingly; when searching an event, saving the face for
     future events is a checkbox that is OFF by default, and the screen's
     privacy wording changes with it.
   - Faces are enrolled against an internal person identifier, never against a
     name or email address.
   - Face recognition can be switched off entirely at any time, and the stored
     face data deleted, from Settings > Privacy ("Allow Face Recognition" and
     "Manage Face Data"). Deleting the account severs the enrolment too, so
     matches never carry over to a future account.
   - Face data is processed by our own recognition service, which we build and
     operate. No third party receives, stores or processes it.
   - This is declared on our App Privacy card (Sensitive Info / biometric data)
     and in our privacy policy at https://jperg.com/privacy.
   - We are registered with Ghana's Data Protection Commission as a data
     controller for this processing. Registration documentation can be
     supplied on request.

2. MUSIC. Photographers can add a soundtrack to an event. Tracks come from
   Audiomack under a commercial partnership: the app plays preview clips only,
   each track displays its title, artist and artwork, and every track carries a
   "Listen on Audiomack" link where the full play is counted and the artist
   credited. We do not host, store or sell audio, and there is no download. The
   partnership agreement can be supplied on request.

3. PHOTOGRAPHS. All photos are uploaded by the photographers who took them,
   who hold the rights and who set their own prices. Creator accounts complete
   identity verification — a government ID document reviewed by our team —
   before they can publish and sell, and they accept terms confirming they own
   or are licensed to sell what they upload. Anyone can report a photo, album,
   comment, ad, job request or account for copyright infringement or for any
   other reason, and three inappropriate-content reports remove an item from
   circulation pending review. Our terms are at https://jperg.com/terms.

Supporting documents — Data Protection Commission registration, the Audiomack
agreement, and our creator terms — are available on request; tell us where to
send them.
```

---

## Appendix — shot list for the item 1 recording

Physical device, latest iOS, one take, starting from the app icon on the home
screen. Apple names three things explicitly; a missing one is another round
trip.

1. Launch — tap the icon, let the splash finish, land on the feed.
2. Registration — create an account: email, password, the verification
   code, the face step, and at least one wizard screen after it. Then sign out
   and sign in with the demo account.
3. The core feature — Found tab with existing matches, then a live search:
   scan/enter the event code, show the scan running, show the result, open a
   photo, swipe.
4. Paid content — select a priced photo, open checkout, complete the
   Paystack test payment, show the photo under Profile → Purchased and download
   it.
5. User-generated content + moderation — show photos and a comment being
   posted, then show reporting and blocking. Report **a photo** specifically
   (photo viewer → ⋯ → Report photo → pick a reason → confirm the success
   state): photos are the app's primary user-generated content and that is the
   one Apple will look for. Then long-press a comment → Report comment, and
   block someone from their **profile** (⋯ → Block → show the confirmation) —
   on the profile rather than inside a DM, so the control is where a reviewer
   looks for it. Let the reason list stay on screen long enough to read "Child
   safety or exploitation".
6. Account deletion — Settings → Account & Security → Delete account →
   confirm → show that it signs out. Use the secondary account.

Keep it under about 5 minutes, no cuts, and do not narrate over a flow that is
not on screen.

---

## Related

- `app_store_listing.md` — the listing copy, keywords, and the pre-submission
  checklist (App Privacy face-data declaration, export compliance for the
  encrypted chat, the request-moderation note).
- `ENCRYPTION.md` — what to answer on the build's export-compliance question.
- `../../docs/DATA_PROTECTION_REGISTRATION.md` — what we declared to the Data
  Protection Commission, checked against the code.
