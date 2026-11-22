# App Review — Guidelines 4.3(a), 4.3(b) and 4.2.6, spam

Received 2026-11-13. Paste the reply below into the Resolution Center. Notes at
the end are internal and must not be sent.

Apple's instruction is explicit: **do not resubmit.** Reply only. A resubmission
without a reply reads as the admission that the descriptions apply.

---

## Reply

Thank you. We believe the app meets 4.3(a), 4.3(b) and 4.2.6, so we are replying
rather than resubmitting, and answering all nine questions in order.

**1. WHAT THE APP DOES AND THE PROBLEM IT SOLVES**

At an event in Ghana — a wedding, a funeral, a graduation, a concert, a church
service — several photographers shoot thousands of frames. Today those photos
reach the people in them by being dumped into a WhatsApp group, or a Google
Drive folder whose link is posted once and lost, or they never arrive at all.
An attendee who wants the three photos they appear in has to scroll hundreds of
other people's photos, or ask the photographer to search a memory card by
memory. The photographer, meanwhile, has no way to be paid for a photo he has
already given away by posting it in a group.

jperg solves exactly that. An attendee registers their face once. When a
photographer publishes an event and uploads the photos he took, our face
recognition pipeline matches each photo against registered faces, and the
attendee is shown only the photos they personally appear in — no scrolling, no
asking. The photographer prices those photos; the attendee buys the ones they
want, in Ghanaian Cedi, and the photographer withdraws the proceeds to a
Ghanaian bank or mobile money account. Around that core, the app carries the
rest of the relationship: a feed of events and creators, 
direct messages and event chat rooms so an attendee can talk to the person who
took the photo, and a request board where someone with an event coming up posts
what they need and photographers answer with quotes, with the deposit and
balance held by us and released on completion.

**2. THE INTENDED USER**

Two sides of one marketplace, both in Ghana at launch, which is where our
company and our team are.

Attendees: adults 18+, predominantly 18-35, in Accra, Kumasi and Ghana's other
cities — the people photographed at the events above. They are smartphone-first,
they already pay for things with mobile money, and their existing experience of
event photos is a group chat.

Photographers and creatives: working event photographers in Ghana, from
one-person operations shooting weddings at weekends to small studios. For them
the app is a distribution and payment channel they currently do not have, plus
a source of new work through the request board.

**3. THE GAP IN THE MARKET**

Facial photo search exists elsewhere, and we are not claiming to have invented
it. What does not exist is any of it serving this market.

The established face-search photo platforms are built for organised Western
events — marathons, races, ticketed sports — where a single accredited
photography company shoots a numbered field, and they price and settle in USD or
EUR through card rails. None of them operate in Ghana, none take Ghanaian mobile
money, none accommodate the actual shape of a Ghanaian event, where several
independent photographers shoot the same wedding with no organiser and no
accreditation, and none of them would be found by the people we serve. The
general photo-storage apps that do reach Ghana solve the opposite problem: they
search the photos you already have, not the ones a stranger took of you.

So the gap is the whole of it: facial retrieval priced in Cedi, settled to
mobile money, built for multi-photographer unorganised events, with the
hire-a-photographer and messaging layers that this market reaches for next. We
built the recognition pipeline, the marketplace, the ranking, the chat and the
escrow ourselves to serve it.

**4. BETA TESTING**

We distributed the app through TestFlight to [N] testers between [BETA_START]
and [BETA_END] — [composition: photographers / attendees / internal], recruited
from photographers and event attendees in Accra.

Feedback from that period that is in the submitted build:

- Testers reported that the handle shown under their avatar was an internal
  recognition identifier rather than their username. It now shows the username.
- Testers in cities outside Accra found the request board empty because their
  region was not being saved from the profile editor. The region now persists
  and the board shows nearby work.
- Testers on slower connections reported photos flickering and re-drawing as
  they appeared. We changed image sizing and delivery, and the flicker is gone.
- Testers abandoned sign-up at the phone number field. It is no longer asked
  for at sign-up.



**5. STANDALONE OR PART OF A SUITE**

Standalone. jperg is the only app on our developer account, and the only one we
have ever submitted. There is no suite, so there is nothing for its scope to be
distinguished from.

**6. COULD THIS BE AN IN-APP PURCHASE OR FEATURE OF ANOTHER APP**

No, because there is no other app on our account to add it to. This is our
first and only app, and the functionality described in question 1 is the app
itself, not an addition to something else.

**7. CODE, FRAMEWORKS OR ASSETS SHARED WITH ANOTHER APP ON THE ACCOUNT**

None, for the same reason: there is no other app on the account. The binary
contains our own application code and standard third-party frameworks —
Flutter, BLoC, networking, image caching, OneSignal for push, StoreKit, and the
client SDKs of our media and payment providers. Nothing else.

**8. CODEBASE, SDK OR CONTENT LIBRARY SHARED WITH A THIRD-PARTY APP**

No. The app is not derived from, and does not share a codebase with, any other
app, by us or anyone else. Beyond the standard frameworks listed above, we
consume four third-party services over their public APIs, none of which supplies
an app or a template: a face recognition API, two media storage and delivery
providers, a payment provider's hosted checkout, and Audiomack for licensed
music previews. The product around them — the matching pipeline, the
marketplace, the request board and escrow, the feed ranking, the end-to-end
 chat, and the six backend services behind all of it — is written by
us and runs on infrastructure we operate in AWS.

**9. CREATED FOR A CLIENT, PARTNER OR THIRD PARTY**

No. jperg is our own product. The concept, the brand, the content model and
every line of the app and its backend are ours, and the account it is submitted
under is the account of the company that owns them. No client, partner or third
party supplied the content, concept or branding, and the app was not built from
a commercial template or an app generation service — there is no template or
service provider in the picture to submit it instead of us.

We are glad to walk a reviewer through any of this, or to supply a build
walkthrough, on request.

---

## Internal notes — do not send

### Fill before sending

1. **Item 4 is the only part not provable from the repo.** There is no
   TestFlight record anywhere in this repository. Fill `[N]`, the two dates and
   the composition from App Store Connect's TestFlight tab — Apple can see that
   page, so the numbers have to match it. If the external testing was smaller or
   shorter than the answer implies, say the smaller number: a tester count Apple
   can contradict in one click is worse than a modest one.

2. **The four feedback lines must each be a real report.** They are written from
   commits that shipped in 1.0.1 (63) and are true as *changes* —
   `6c5e90f` (username under the avatar), `581cdfb`/`bd1ec72` (region saves, board
   not empty), `f44dd52`/`6cb9987`/`7d89b95` (image sizing, flicker),
   `b24a63b` (no phone at sign-up). What this file cannot know is whether a
   tester asked for them. Keep the ones a tester actually raised; cut the rest.
   Apple asked for "examples of user feedback provided in beta that was applied
   to the production build" — four honest ones beat eight invented ones.

3. **Length — 6,707 characters as written** (placeholders still in). Recount
   after filling item 4:

       python3 -c "import re,sys; t=open('mobile/app_review_4_3.md').read(); t=t.split('## Reply',1)[1].split('## Internal notes',1)[0].strip(); print(len(t))"

   The Resolution Center reply field is more generous than the 4000-character
   App Review Information notes field, but if it refuses the paste, cut from
   items 7 and 8 (the framework lists) and the second paragraph of item 2.
   Never cut items 1, 3 or 9 — those are the three Apple is actually weighing.

### Why this rejection probably arrived

4.3 rejections of a genuinely original app usually trace to something in the
submission that *looks* generated. Two candidates here, both worth fixing before
the next cycle even though neither belongs in the reply:

1. **The bundle identifier is `com.example.jperg`.** `com.example.*` is the
   placeholder Flutter and Android Studio write into a brand-new project. To a
   reviewer scanning for template-generated submissions it is close to a
   signature, and we are carrying it in production. It is a real registered
   identifier (changing it means a new App Store Connect record and a new app,
   which is not a mid-review move), so leave it for now — but it is the single
   most likely reason 4.2.6 appeared in a letter about an app no template could
   produce. Do not raise it in the reply; do not "fix" it this week either.

2. **The store listing reads like category copy.** The description is a feature
   list that could sit over several apps, and the keyword field is ten generic
   terms. Neither is wrong, but neither communicates the Ghana-specific product
   that item 3 above describes. If this comes back, the listing — not the
   binary — is the thing to change.

### Claims in this reply that the repo does support

Worth knowing which sentences we can defend, since the last round caught us
overstating creator verification:

- Six backend services, ours: `main`, `chat`, `recommender`, `ads`, `tracking`,
  `gateway`.
- End-to-end encrypted DMs: `mobile/ENCRYPTION.md`, Signal Protocol in the chat
  service.
- Feed ranking ours: `recommender/` (SVD scoring, boost, cold start).
- Escrow: quote → deposit → balance → release, with disputes and auto-release.
- Request board moderation: a posted request is admin-reviewed before it appears.
- Payments in GHS to Ghanaian bank or mobile money: Paystack.

Face recognition is a third-party API (Luxand) that we call; the pipeline around
it — enrolment, matching, the pending-identification model, the visibility rules
— is ours. Item 8 says "a face recognition API" for exactly that reason. The
earlier letter's phrasing that the recognition *service* is "built and run by
us" is stronger than this file is willing to be; do not escalate it here.

Advertising and campaigns remain off by server flag, as disclosed in
`app_review_response.md` item 3. Nothing in this reply contradicts that
disclosure, and item 1 deliberately does not list ads among the features.
