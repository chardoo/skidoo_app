2. APP PURPOSE AND TARGET AUDIENCE

jperg is an event photography marketplace. Photographers publish an event and
upload their photos; attendees register their face once and the app returns
only the photos they appear in. Photographers price photos and quote on jobs
posted to a request board (requests are admin-moderated). Audience: adults 18+
at photographed events (mostly 18-35) and professional photographers.

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
harassment, child safety or exploitation, copyright, other. Three such reports
remove an item; child-safety reports are triaged first. To report or block a
person, use the three-dot menu on their profile.

Messaging: Chats tab; direct messages are end-to-end encrypted. Photographers
create events, upload and price photos, and quote on the board.

Account deletion: Profile > Settings > Account & Security > Delete Account.
Immediate and permanent; it severs the face enrolment.

Not in this release: the app contains an advertising and campaigns feature,
switched off for every user by a server-side flag, so it does not appear in
review. We disclose it rather than leave it to be found; nothing a user does
reaches it.

4. EXTERNAL SERVICES

Face recognition is our own service; no third party receives or processes face
data. Cloudflare R2 stores new media; Cloudinary serves older media and watermarks. Paystack takes payments in Ghanaian Cedi through hosted checkout in
a web view. Our own FastAPI/PostgreSQL backend handles accounts, authentication
(email and password; no social sign-in), payments, chat and moderation. SendGrid sends email, OneSignal push, Arkesel SMS. Audiomack
provides licensed music previews (item 6). No third-party or generative AI is
used.

5. REGIONAL DIFFERENCES

Features are identical in every region; payments are in Ghanaian Cedi.
Creators may target events and job requests by country, so the content mix
differs by their choice, not by ours.

6. REGULATED SERVICES AND THIRD-PARTY MATERIAL

We are not a licensed or regulated business.

Biometric data. Users opt in: registering a face is a deliberate step, and
saving it for future events is off by default. A face is stored against an
internal identifier, never a name or email, and only our own service processes
it. Users can switch recognition off and delete their face data in Settings >
Privacy, and deleting the account removes the enrolment. Declared on our App
Privacy card; policy at https://jperg.com/privacy. We are registered with
Ghana's Data Protection Commission; documentation on request.

Music. Audiomack supplies event soundtracks under a commercial partnership:
short previews only, each credited with a "Listen on Audiomack" link. We do not
host, sell or allow downloads.

Photographs. Every photo is uploaded by the photographer who took it; our terms
require them to hold the rights to what they sell. Our verification is a badge,
not a licence: a photographer may submit a government ID for admin review,
which marks the account verified for buyers, but selling is not restricted to
verified accounts. Photos can be reported for copyright infringement, as in
item 3. Terms: https://jperg.com/terms
