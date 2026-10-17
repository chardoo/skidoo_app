2. APP PURPOSE AND TARGET AUDIENCE

jperg is an event photography marketplace. Photographers publish an event and
upload their photos; attendees register their face once and the app
returns only the photos they appear in. Photographers price their photos and
quote on jobs posted to a request board, where requests are admin-moderated
before they appear. Audience: adults 18+ at photographed events, mostly 18-35,
and professional photographers. Launch market Ghana; not region-restricted.

3. ACCESSING THE MAIN FEATURES

Attendee demo: [DEMO_CLIENT_EMAIL] / [DEMO_CLIENT_PASSWORD]
Photographer demo: [DEMO_PHOTOGRAPHER_EMAIL] / [DEMO_PHOTOGRAPHER_PASSWORD]
Event code: [DEMO_EVENT_CODE]
Both are email-verified, two-factor off.

Core feature: the Found tab already holds matches. To search from scratch, tap
the scan icon, enter the event code, then confirm which are you.

Buying: a priced photo shows a Buy pill; checkout opens Paystack in the app.
Test card 4084 0840 8408 4081, any future expiry, CVV 408, PIN 0000, OTP
123456. Purchases: Profile > Purchased. Photos priced 0 are free.

Reporting: three-dot menu on a photo (in the viewer), an event or a job
request; long-press a comment. Reasons: inappropriate content, spam,
harassment, child safety or exploitation, copyright, other. Three
inappropriate-content reports remove an item; child-safety reports are triaged
first. To report or block a person, use the three-dot menu
on their profile, or block from a direct message.

Messaging: Chats tab; direct messages are end-to-end encrypted, events have
chat rooms. Photographers: create events, upload and price photos, quote on the
board; bookings use escrow.

Account deletion: Profile > Settings > Account & Security > Delete Account.
Immediate and permanent; it severs the face enrolment. Please use the second
demo account.

Not in this release: the app contains an advertising and campaigns feature,
switched off for every user by a server-side flag, so it does not appear during
review. We disclose it rather than leave it to be found; nothing a user does
reaches it.

4. EXTERNAL SERVICES

Face recognition is our own service; no third party receives or processes face
data. Cloudflare R2 stores new media; Cloudinary serves older media and renders
watermarks. Paystack takes payments in Ghanaian Cedi through hosted checkout in
a web view. Our own FastAPI/PostgreSQL backend handles accounts,
authentication (email and password; no social sign-in), events, photos,
payments, chat and moderation. SendGrid with a Gmail fallback sends
email, OneSignal sends push, Arkesel sends SMS. Audiomack provides licensed
music previews (see item 6). We use no third-party AI or generative AI
service.

5. REGIONAL DIFFERENCES

Features are identical in every region; payments are charged in Ghanaian Cedi.
Creators may target events and job requests by country, so the content mix
differs by their choice, not by region.

6. REGULATED SERVICES AND THIRD-PARTY MATERIAL

We are not in a licensed industry.

Biometric data: face registration is explicit and user-initiated, and faces are
enrolled against an internal identifier, never a name or email. Users can
switch face recognition off and delete stored face data at Settings > Privacy;
deleting the account severs the enrolment. Processed only by our own service.
Declared on our App Privacy card and our policy (https://jperg.com/privacy).
We are registered with Ghana's Data Protection Commission; documentation on
request.

Music: Audiomack under a commercial partnership. Preview clips only, credited
with a "Listen on Audiomack" link; we do not host, sell or allow downloads.

Photographs: uploaded by the photographers who took them, who pass government
ID verification before selling and accept terms confirming they hold the
rights. Anything can be reported, for infringement or any other reason.
https://jperg.com/terms
