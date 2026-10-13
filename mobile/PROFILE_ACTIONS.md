# Follow and Message on a profile

Two bugs, both about reaching a photographer and finding nothing to do there.

> When a user searches for event, photographer, people or tag — for the
> photographer, when the user taps through to the profile, there should be
> Message and Follow/Unfollow. Also when a user navigates from a comment
> session the user should be able to see Follow/Unfollow and Message for the
> photographer page. This has to be consistent across board.

---

## Bug 1 — the photographer's profile drew no Message

### What was happening

`CreatorProfilePage` is the photographer page, and every path reaches the same
one: search ▸ Photographers, search ▸ Events / Tags (through a photo's
attribution bar), the feed, Following, a deep link. Its action pair was written
like this:

```dart
if (_isOwner == false) ...[
  _Actions(canMessage: _canMsg?.canMessage ?? false, …),
]
```

Two faults in three lines:

* **`_isOwner` is `bool?` and starts null.** It is set by `_checkOwner()`, which
  `await`s the stored user id. Until that read came back, `_isOwner == false` was
  false and **the whole row was absent** — so on every profile, from every entry
  point, Follow and Message arrived a beat after the rest of the page. If the
  read threw, they never arrived at all.
* **Message was dropped, not disabled.** `canMessage` defaulted to `false`, and
  `_Actions` rendered the Message pill only `if (widget.canMessage)`. So the
  button was missing for the whole of the can-message round trip, and missing
  *permanently* for a photographer whose DM setting is off. Absent is
  indistinguishable from still-loading, which is exactly how it was read:
  "there is no Message button on this photographer".

Meanwhile `PublicProfilePage` — the *person* screen — answered the same two
questions differently again: Follow and Message both unconditional, no
can-message check at all (the button was live and failed on the tap), and the
whole row gated on `_loaded == true`, i.e. on the profile fetch.

So the two screens had drifted into two different answers to one question, and
neither was right.

### The fix

One widget: `lib/features/user_profile/presentation/widgets/profile_actions.dart`.
Three rules, stated once and applied on both screens.

1. **Your own profile offers nothing.** Decided from `AuthService.userId` — the
   id the session already holds — so it holds on the first frame. Waiting on a
   fetch meant either drawing Follow on your own profile and taking it away (a
   tap in that window posts a follow of yourself, which the API refuses), or
   drawing nothing on everybody's profile until the answer landed.
2. **A creator gets Follow and Message; a person gets Message alone.** Following
   is a creator relationship — it feeds the Following tab, which exists to show
   you work — so following somebody who posts nothing subscribes you to nothing.
   This half was already a deliberate decision; see *What was already decided*
   below.
3. **Message is always drawn, and dimmed when it would fail.** Never removed.
   `canMessage: null` (check in flight) reads as allowed, because yes is the
   common case and a button that starts dimmed and brightens draws the eye to
   the one state nobody needs to notice. A refusal dims it when it lands.

Nothing in it waits on a request. It uses the existing shared
`ProfilePillButton`, which had been written for exactly this and was wired into
nothing — see below.

**One deliberate exception.** The request flow mounts `CreatorProfilePage` with
a `footer` (its "Select photographer" CTA), and there the pair is suppressed: a
requester picking somebody for a job chooses them first and talks afterwards, so
Follow and Message would compete with the CTA for the same decision. `footer`
is how that mounting announces itself; nothing else passes one.

---

## Bug 2 — a comment author could not be opened

A comment thread is the one list in the app where creators and ordinary people
appear together, and both sheets got it wrong in opposite directions.

| | before | after |
|---|---|---|
| Photo comment sheet (`photo_comment_sheet.dart`) | `_toRowData` set **no `onUserTap` at all** — `CommentItemWidget` reads `onUserTap != null` to decide whether the avatar is a target, so every avatar was dead and `isMe` was hardcoded `false` | author tap wired, routed by role |
| Event comment thread (`event_comment_page.dart`, two call sites) | `onUserTap` was null unless `senderRole == rolePhotographer` — so an ordinary commenter's avatar was dead | same helper, same rule |

So from a photo's comments the photographer's profile — and its Follow and
Message — simply could not be reached. From an event's comments it could, but
nobody else could.

### The fix

`lib/features/user_profile/presentation/utils/open_author_profile.dart`:

```dart
VoidCallback? openAuthorProfileTap(context, {authorId, authorName, authorRole, isMe})
```

**The role picks the screen; it does not decide whether there is one.** A
creator goes to `openPhotographerProfile`, anybody else to
`openPublicProfile`. Returns `null` only for the viewer's own comment, which is
how a row declines to offer the tap. An empty or unrecognised role is treated as
a person: far likelier, and the person screen degrades better — it carries no
portfolio, rates or reviews to render empty.

Both destinations already gate on sign-in, so a guest reading a thread is asked
to sign in and lands on the profile afterwards rather than having the tap
swallowed.

---

## What was already decided, and left alone

Two prior decisions are load-bearing here, and this change keeps both.

**Two profiles, two screens.** A person (`role='user'`) opens
`PublicProfilePage` via `/client/users/{id}/profile`; a creator opens
`CreatorProfilePage` via `/photographer/profile/{id}`. The user endpoint returns
404 for a photographer *on purpose*. The People chip in search cannot return a
photographer either — `search_users` filters `role="user"`
(`main/app/repositories/search_repository.py`) — so the split is enforced on
both sides.

**A person has no Follow button and no follower counts.** This is
`test/features/user_profile/public_profile_actions_test.dart`, added in
`73cfcd9`, which spells out why: *"Following is a creator relationship — it
feeds the Following tab, which exists to show you work — so following somebody
who posts nothing subscribes you to nothing, and the two zeroes under their name
were a scoreboard for a game they are not playing."*

Those six tests **were failing at `HEAD`**. The commit added the shared
`ProfilePillButton` and the tests describing the target design, but never
rewired `PublicProfilePage` — which still carried Follow, the two figures and a
private pill of its own. Finishing that is part of this change, so the screen
now matches the decision that was written down for it: Message alone, centred,
on the first frame, dimmed when they take no DMs.

---

## Paths checked

Every route to a photographer page, walked:

| Path | Status |
|---|---|
| search ▸ Photographers → profile | fixed (was: no Message, late Follow) |
| search ▸ People → person's profile | fixed (Message-only, first frame) |
| search ▸ Events → event → photo → attribution bar → profile | fixed |
| search ▸ Tags → event → photo → attribution bar → profile | fixed |
| photo comments → author | **fixed (was unreachable)** |
| event comments → author | fixed (was creators only) |
| feed card / Following / creator suggestions / deep link → profile | fixed |
| request flow → profile | unchanged by decision (Select photographer owns it) |

The search ▸ Events and ▸ Tags paths were verified rather than assumed: the
attribution bar is tappable only when `Photo.userId` is populated, and
`/client/events/{eventId}/photos` returns the photographer under
`event.photographer` rather than `event.userId`. `Photo.fromMap` does read that
nested shape, so the id arrives — confirmed against the real envelope before
concluding the path was sound.

---

## Verifying

```bash
cd mobile
flutter test test/features/user_profile/
```

`profile_actions_are_consistent_test.dart` pins the new rules: Follow and
Message on a creator's first frame; Message kept-but-dimmed when they take no
DMs, with Follow still live; nothing on your own profile; Message alone for a
person; and a comment author tappable whether creator, person, or a role that
never arrived — but never your own comment.

`public_profile_actions_test.dart` (8 tests) passes for the first time.

Suite: 2601 tests, 13 failures — all 13 pre-existing and unrelated
(`bookmark_is_instant`, `creator_avatar_initial`, `broadcasts_title`,
`destructive_confirm`, `legal_links`), verified identical with these changes
stashed. The 6 `public_profile_actions` failures in that baseline are gone.
