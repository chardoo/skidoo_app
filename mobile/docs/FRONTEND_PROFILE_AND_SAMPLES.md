# Frontend: Profile Fields Update + Photographer Sample Images

Two things for the frontend: the new profile fields added 2026-07-18, and the
existing (already-built, previously undocumented) photographer sample-images
endpoints.

## 1. New profile fields

Five new fields on the `User` record. None of them are set at signup —
all go through the existing update-profile endpoints or new ones below.

| Field | Type | Who has it | Set via |
|---|---|---|---|
| `bio` | `string`, max 1000 chars | any account | `PATCH /client/profile/{clientId}` or `PATCH /photographer/profile/{userId}` |
| `specialties` | `string[]` | photographer | `PATCH /photographer/profile/{userId}` |
| `studio_name` | `string`, max 150 chars | photographer | `PATCH /photographer/profile/{userId}` |
| `studio_image_url` | `string` (Cloudinary URL) | photographer | `POST /photographer/profile/{userId}/studio-image` (new) |
| `verified_by_admin` | `boolean` | any account | admin-only, see below — **cannot** be set through any client/photographer endpoint |

**Important: `specialties` vs `interest_tags` are not interchangeable.**
`interest_tags` is what an account uses to personalize *its own* feed
(unchanged, existing field). `specialties` is what a photographer offers,
shown to *other* users, and is what the "suggested photographers" matching
now uses instead of `interest_tags` — so a photographer's personal feed
preferences no longer leak into how others discover them. If your UI reused
one tag input for both concepts, split it into two.

### Setting bio (either role)

`PATCH /client/profile/{clientId}` (JSON body) or
`PATCH /photographer/profile/{userId}` (multipart form, like the rest of
that endpoint's fields) — just add `bio` to whatever you already send.
Both endpoints return `bio` in the response.

### Setting specialties / studio_name (photographer only)

Same `PATCH /photographer/profile/{userId}` multipart endpoint. Send:
- `specialties` — a JSON array string, e.g. `'["wedding","portrait"]'`, or a plain comma-separated string (`"wedding,portrait"`) — both are accepted, same as the existing `interest_tags` field on this endpoint.
- `studio_name` — plain string.

### Studio image (photographer only)

```
POST /photographer/profile/{userId}/studio-image
Content-Type: multipart/form-data
file: <image>
```
Single image only (not a gallery) — each call replaces the previous one.
Response: `{"id": "...", "studio_image_url": "https://..."}`. This is
separate from the personal avatar (`profile_url` / `POST /photographer/profile/{userId}/photo`) — a photographer profile screen now has two independent images.

### verified_by_admin (read-only for clients/photographers)

Shows up in `GET /client/profile/{clientId}`, `GET /photographer/profile/{userId}`,
and everywhere else `profile_url` already appears (photographer listing,
search, suggested, unified search, admin panel). Render it as a verified
badge; there is no way for a user to set this themselves — only an admin
action changes it (`POST` / `DELETE /admin/users/{user_id}/verify`, admin app only).

## 2. Photographer sample images (already existed — documenting now)

`main/app/routers/photographer/samples.py`. Note the GET is a `POST` with a
body, not a query param — mirrors this endpoint's existing style, not a typo.

### List a photographer's samples
```
POST /photographer/samples
{ "userId": "..." }
```
Returns `[{"id": "...", "url": "...", "imageId": "..."}, ...]`

### Upload sample images (appends, doesn't replace)
```
PUT /photographer/samples
Content-Type: multipart/form-data
userId: "..."
files: <image>, <image>, ...
```
Uploads each file to Cloudinary and adds a row per file — this **adds** to
the existing set, it does not clear it first. Returns the full updated list
in the same shape as the GET above. Caller must be an actual photographer
account (checked server-side against the DB role, not just the JWT).

### Delete one sample
```
DELETE /photographer/samples
{ "sampleId": "...", "userId": "..." }
```
Returns `{"count": 0 | 1}`.

These are distinct from `studio_image_url` (one designated studio cover
photo) and from face-training selfies (used only for recognition, never
persisted — see `docs/FRONTEND_PROFILE_PHOTO_OPTIN.md`). Samples are a
photographer's own portfolio/showcase gallery with no cap currently
enforced — flag to backend if you need a max-count limit added.
