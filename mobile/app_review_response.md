# App Review reply — Guideline 2.1, Information Needed

Everything below is the reply. Copy it as it stands, after filling in the five
bracketed values in item 3. Working notes, the demo-account checklist and the
screen-recording shot list have moved to app_review_prep.md.

---

## 2. App Purpose and Target Audience

jperg is an event photography marketplace. It solves one specific problem: at
weddings, graduations, concerts, parties and conferences, professional
photographers take hundreds of photos, and the people in those photos almost
never see them. The photos sit on a memory card or in a folder nobody is given
a link to, and finding yourself means scrolling through hundreds of strangers'
shots or asking the photographer to search by memory.

jperg closes that gap from both ends.

For attendees, who are most of our users: you register your face once at
signup. When you attend an event, you scan the event's code or search it, and
the app returns only the photos you personally appear in, matched by face
recognition rather than by browsing. You can save the free ones, buy the ones
that are priced, follow the photographers whose work you like, message them,
and comment on individual photos.

For photographers and creators: you publish an event, upload the photos you
took, set a price per photo, and the people who were actually there find
themselves and pay you for their own shots. You keep a profile with sample
work, take direct messages, and answer public job requests with a quote when
somebody is looking to hire.

There is also a request board: a user posts what they need shot — event type,
location, budget — and photographers send quotes. Posting is free. Requests
pass through admin moderation before they appear on the board.

Target audience. Adults who attend photographed social events, our primary
group being 18 to 35, plus professional and semi-professional photographers who
shoot those events for a living. Accounts are for people aged 18 and over, as
stated in our terms. The initial market is Ghana, where our payment processor
and SMS provider operate; the app itself is not restricted by region, as
described in item 5.

Value provided. Attendees get photos of themselves they would otherwise never
see. Photographers get paid for work that currently goes undelivered, and they
reach the specific people who were in their frames instead of posting an album
and hoping.

---

## 3. Accessing the Main Features

DEMO ACCOUNT (attendee)
  Email: [DEMO_CLIENT_EMAIL]
  Password: [DEMO_CLIENT_PASSWORD]

DEMO ACCOUNT (photographer)
  Email: [DEMO_PHOTOGRAPHER_EMAIL]
  Password: [DEMO_PHOTOGRAPHER_PASSWORD]

Both accounts are email-verified and have two-factor authentication switched
off, so they sign in with the password alone.

EVENT CODE for face search: [DEMO_EVENT_CODE]

Attendee walkthrough

1. Launch the app and tap "Sign in" with the attendee credentials above. To see
registration instead, tap "Create account": email and password, then a 6-digit
code sent to that address, then a short wizard — add your face, tell us what
describes you, pick interests, pick creators to follow. Every step after the
face can be skipped.

2. Home feed. Events and photos from creators, ordered by interest and
location. Scroll, like, and tap a card to open the event.

3. Finding your photos, the core feature. Open the "Found" tab. The demo
account already has matches, so photos of the registered face appear grouped by
event; tap one to open the viewer and swipe. To run a search from scratch, tap
the scan icon and enter the event code above, and the app searches that event
for your face. Matches arrive as pending and you confirm or deselect which ones
are you.

4. Buying a photo. A photo with a price shows a "Buy" pill. Select one or more,
tap the purchase bar, and checkout opens Paystack's secure payment page inside
the app. Use Paystack's test card 4084 0840 8408 4081, any future expiry, CVV
408, PIN 0000, OTP 123456. Purchased photos appear under Profile > Purchased
and can be downloaded at full quality. Photos priced at 0 are free and are
saved without any payment step.

5. User-generated content and moderation. Photos and events are uploaded by
photographers; comments and job requests are written by users. Everything a
user can post can be reported from the three-dot menu on it: a photo from the
three-dot menu in the photo viewer, an event or a job request from the
three-dot menu on its card, and a comment by long-pressing it. The reasons
offered are inappropriate content, spam, harassment, child safety or
exploitation, copyright, and other. Three inappropriate-content reports take an
item out of circulation automatically, and child-safety reports are triaged
ahead of all other moderation. To report or block the person rather than the
post, open their profile and use the three-dot menu: "Report account" or
"Block". Blocking is also available from the three-dot menu of a direct
message, and a block stops messages in both directions.

6. Messaging. The Chats tab. Direct messages are end-to-end encrypted, and
events have their own chat rooms. Attachments are images, video, audio and
files.

7. Hiring. "Requests", then create a request with event type, location, date
and budget. Please note that a new request goes to admin moderation and does
not appear on the public board immediately. The demo account already has one
approved request so the quote flow can be seen end to end.

8. Account deletion. Profile > Settings > Account & Security > "Delete
Account", then confirm in the dialog. This is immediate and permanent: personal
data is erased, the face enrolment is severed so matches do not carry to a
future account, and every signed-in session is terminated. Purchase records are
retained without personal data, for photographer payout integrity only. Please
use the second demo account if you wish to exercise this, so the first one
survives for the rest of the review.

Photographer walkthrough

9. Sign in with the photographer credentials. The dashboard shows events,
earnings and payouts.

10. Create an event: name, date, location, cover image, optional soundtrack,
then upload photos and set a price. Uploaded photos are scanned for faces in
the background, which is what lets attendees find themselves.

11. Request board: browse jobs and send a quote. Bookings run on escrow —
quote, deposit, balance, release.

Not available in this release

12. Advertising and campaigns. The app contains an advertising feature —
sponsored cards in the feed and a "My Campaigns" area for buying them. It is
not part of this release and is switched off for every user by a server-side
configuration flag, so no advertisement and no campaign screen will appear
anywhere during review. We are disclosing it rather than leaving it to be
found: the feature is still being completed and we did not want to ship a
half-finished surface. There is no way for a user to switch it on, it is not
reachable by any gesture, code or account state, and no advertising is sold or
served to users today. When it is finished we will submit the release that
turns it on and will describe it in full then.

---

## 4. External Services, Tools and Platforms

Core functionality

Face recognition is our own service, which we build and operate. It enrols a
user's face at signup, detects faces in uploaded event photos, and scores a
candidate match against a confidence threshold before a photo is shown to
anyone as theirs. No third party receives or processes face data. Faces are
enrolled against an internal person identifier, not against names or email
addresses.

Cloudflare R2 provides object storage and delivery for new photo, video and
attachment uploads. Cloudinary provides storage, image transformation and CDN
delivery for media uploaded before our move to R2, which is still the majority
of the library, and it renders the watermark overlay on unpurchased paid
photos. Both are in use; which one serves a given file depends on when it was
uploaded.

Paystack handles payment processing for photo purchases, through its hosted
checkout opened in an in-app web view. Transactions are in Ghanaian Cedi.

Accounts, messaging and notifications

Our own API and database, built on FastAPI and PostgreSQL and hosted on cloud
infrastructure we control behind Cloudflare, handle accounts, authentication by
email and password with our own JSON Web Tokens, events, photos, payments, chat
and moderation. There is no third-party authentication provider and no social
sign-in: we issue and verify our own tokens.

SendGrid, with a Gmail SMTP fallback, sends transactional email — verification
codes, password resets and receipts. OneSignal sends push notifications.
Arkesel sends SMS in Ghana.

Content and discovery

Audiomack supplies the music a photographer can score an event with, under a
commercial partnership. The app plays preview clips only and every track
carries a "Listen on Audiomack" link, where the full play is counted and the
artist credited. This is described further in item 6.

Open-Meteo provides city and place lookup for the location field on events and
job requests. It is proxied and cached by our own server and is never called
from the app. An IP geolocation lookup, together with our CDN's country header,
resolves the viewer's country for content targeting when the user has not set
one.

Recommendations

The feed's ranking is our own code: collaborative filtering combined with
content-based scoring, using scikit-learn and trained on our own data. We do
not use any third-party AI service, large language model or generative AI
service anywhere in the app.

---

## 5. Regional Differences

The app's features and content are the same in every region. Nothing is gated
by the user's country: sign-up, face registration, face search, viewing and
buying photos, messaging, commenting, reporting, blocking, the request board
and account deletion all behave identically wherever the app is opened.

There are three region-dependent details, none of which changes what the app
does.

First, payments are processed in Ghanaian Cedi through Paystack, our processor
for the launch market. A buyer anywhere can pay with any card Paystack accepts;
the amount is charged in Ghanaian Cedi.

Second, some content is targeted by its creator rather than by us. A
photographer can restrict an event to, or exclude it from, chosen countries,
and people posting job requests can target theirs. Two users in different
countries may therefore see a different mix of events and job requests, in the
same way two users with different interests do. This is a creator-chosen
audience setting, not a regional feature difference.

Third, SMS notifications are sent through a Ghana gateway. Email and push
notifications are global and are what the app relies on; SMS is supplementary.

Most of our current users are in Ghana because that is where we launched, not
because of any restriction in the app.

---

## 6. Regulated Services and Third-Party Material

The app is not in a regulated industry: it is not finance, health, gambling, or
any licensed profession. There are three areas where we hold or need
authorisation.

Biometric data (face recognition). The app registers a user's face in order to
find them in event photos. This is the sensitive part of the product and is
treated as such.

Face registration is explicit and user-initiated. At signup it is a step the
user performs knowingly, and when searching an event, saving the face for
future events is a checkbox that is off by default, with the screen's privacy
wording changing with it. Faces are enrolled against an internal person
identifier, never against a name or email address. Face recognition can be
switched off entirely at any time, and the stored face data deleted, from
Settings > Privacy, using "Allow Face Recognition" and "Manage Face Data".
Deleting the account severs the enrolment as well, so matches never carry over
to a future account. Face data is processed by our own recognition service,
which we build and operate; no third party receives, stores or processes it.
This is declared on our App Privacy card as sensitive information, and in our
privacy policy at https://jperg.com/privacy. We are registered with Ghana's
Data Protection Commission as a data controller for this processing, and
registration documentation can be supplied on request.

Music. Photographers can add a soundtrack to an event. Tracks come from
Audiomack under a commercial partnership: the app plays preview clips only,
each track displays its title, artist and artwork, and every track carries a
"Listen on Audiomack" link where the full play is counted and the artist
credited. We do not host, store or sell audio, and there is no download. The
partnership agreement can be supplied on request.

Photographs. All photos are uploaded by the photographers who took them, who
hold the rights and who set their own prices. Creator accounts complete
identity verification — a government ID document reviewed by our team — before
they can publish and sell, and they accept terms confirming they own or are
licensed to sell what they upload. Anyone can report a photo, album, comment,
job request or account for copyright infringement or for any other reason, and
three inappropriate-content reports remove an item from circulation pending
review. Our terms are at https://jperg.com/terms.

Supporting documents — our Data Protection Commission registration, the
Audiomack agreement, and our creator terms — are available on request; please
tell us where to send them.
