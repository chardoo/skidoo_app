# Creating an event and giving someone ownership

Two different roles on an event, easy to confuse:

| | who | can |
|---|---|---|
| **Creator** | the photographer who made the event (`userId` on every event payload) | everything — edit, upload, delete, add and remove owners |
| **Owner** | anyone whose email is in `owners` | add another owner. **Nothing else.** |

The creator is always an owner: their email goes into `owners` automatically when
the event is created. Ownership is by **email**, not account, so a photographer
can name the couple before either of them has signed up — the flag lights up on
their first request once they do.

---

## Step 1 — Create the event

```
POST /api/photographer/events
Authorization: Bearer <token>
Content-Type: multipart/form-data
```

| Field | Required | Notes |
|---|---|---|
| `userId` | ✅ | the photographer's id. The role is checked against the database, not the token |
| `eventName` | ✅ | |
| `files` | ✅ in practice — see below | the cover image; first file becomes the cover |
| `description` | | max 2000 chars |
| `owners` | | **owner emails**, JSON array string, e.g. `'["bride@example.com","groom@example.com"]'`. A comma-separated string also works. The creator is added automatically — you never need to include their own address |
| `content_tags` | | JSON array string, e.g. `'["wedding","outdoor"]'`. A comma-separated string also works |
| `target_countries` / `blocked_countries` | | same JSON-array-string format |
| `language` | | e.g. `en` |
| `sensitivity_level` | | `general` (default) · `mature` · `restricted` |
| `publish_timezone` | | IANA name, e.g. `Africa/Accra` |
| `comments_enabled` | | defaults to `true` |

**The cover file is effectively required.** If you post no file, the endpoint
still answers `201` but *creates nothing* — it just returns the photographer's
existing events. Treat "no file" as a client-side validation error; don't rely
on the status code to tell you it worked.

**The response is the photographer's whole event list**, not the one event you
just made. It's an array of event objects, newest state of everything:

```jsonc
[
  {
    "id": "9f1c…", "eventName": "Richard Wedding", "description": "",
    "url": "https://res.cloudinary.com/…", "imageId": "newImages/abc",
    "eventDate": "2026-07-30", "userId": "6b2e…",
    "accessCode": "VOYAGE-35",
    "owner": true,                       // you are an owner
    "owners": ["kofi@example.com", "bride@example.com"],   // creator first, then whoever you named
    "content_tags": [], "target_countries": [], "blocked_countries": [],
    "language": null, "region_relevance": {}, "sensitivity_level": "general",
    "publish_timezone": null, "likes": 0, "dislikes": 0,
    "commentCount": 0, "comments_enabled": true
  }
]
```

To get the id of the event you just created, take the entry whose `eventName`
matches — or refetch `GET /api/photographer/events?userId=…`, which returns the
same shape paginated.

Owner emails are validated, lower-cased and de-duplicated. A malformed one
fails the whole request with `400` **before** anything is uploaded, so a typo
costs nothing.

---

## Step 2 — Add an owner later

Only needed for owners named *after* creation — the couple adding each other, or
a photographer who forgot someone. One email per call; anyone already on the
list can do this, as can the creator.

```
POST /api/common/events/{eventId}/owners
Authorization: Bearer <token>
Content-Type: application/json

{ "email": "bride@example.com" }
```

```jsonc
{
  "id": "9f1c…",
  "owners": ["kofi@example.com", "bride@example.com"],
  "owner": true,        // is the caller an owner
  "creator": true       // is the caller the creator
}
```

- Emails are stored lower-case; matching is case-insensitive, so `Bride@Example.com` and `bride@example.com` are the same person.
- Adding someone twice is a no-op, not an error or a duplicate — safe to retry.
- The email does **not** need to belong to an existing account.

## Removing an owner — creator only

```
DELETE /api/common/events/{eventId}/owners/{email}
Authorization: Bearer <token>
```

Same response body. An owner who is not the creator gets `403` — owners can add
but never remove, including removing themselves. Only the creator can undo a
mistyped address.

---

## Showing "you own this" in the UI

Every event payload carries **`owner`** — a boolean for the *requesting* user —
and the **`owners`** list. No extra call, no client-side email comparison:

| Endpoint | `owner` | `owners` |
|---|---|---|
| `POST /photographer/events` | ✅ | ✅ |
| `GET /photographer/events` | ✅ | ✅ |
| `PATCH /photographer/events/{id}` | ✅ | ✅ |
| `GET /photographer/events/{id}/images` (under `event`) | ✅ | ✅ |
| `GET /client/my-photos` (under `event`) | ✅ | ✅ |
| `POST /client/events` (search) | ✅ | ✅ |
| `POST /client/search-images` (under `event`) | ✅ | ✅ |
| `GET /client/{id}/saved` (under the event asset) | ✅ | ✅ |
| `GET /client/random-images` (under `event`) | ✅ | ❌ omitted |

`owner` is `false` for anyone signed out, since ownership is decided from the
bearer token's email.

⚠️ In `/client/random-images` each **picture** also has an `owner` key, which
means something different — "your face is in this photo". The event-level
`owner` is the ownership flag. Same word, different nesting level.

---

## Errors

All errors use the standard envelope:
`{"success": false, "error": {"code": "...", "message": "...", "statusCode": ...}}`

| Status | When |
|---|---|
| `400` | removing the creator from `owners` — their rights don't come from the list, so the flag would go false while they kept full access |
| `401` | missing or expired token |
| `403` | `add`: caller is neither creator nor owner · `remove`: caller is not the creator |
| `404` | no such event, or the email you're removing isn't on the list |
| `422` | malformed email (`'email': Please provide a valid email address`) |

---

## Typical flow

1. Photographer fills the create form — name, cover image, and an "owners" field
   where they type one or more emails.
2. `POST /photographer/events` with the cover file and `owners` as a JSON array
   string. One request; the event exists with its owners already set.
3. Pick the new event out of the returned array by `eventName`, keep its `id`.
4. Render the chips from `owners`, with a remove control shown only when the
   viewer is the creator.
5. Later additions — `POST /common/events/{id}/owners`, one email per call.

Step 5 is the one action an owner has, and it is how a couple adds each other
without going back to the photographer.
