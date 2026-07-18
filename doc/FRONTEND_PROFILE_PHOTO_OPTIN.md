# Frontend: Profile Photo Opt-In (Breaking Change)

**Breaking change as of 2026-07-17.** Selfies uploaded for face recognition
are no longer automatically used as the profile photo. If your signup or
add-face screens assumed `profile_url` would be populated right after
uploading selfies, that will now be `null` unless you explicitly opt in.

## What changed

| Before | Now |
|---|---|
| Every selfie uploaded for face training was silently also uploaded to Cloudinary and set as the account's `profile_url`. | Selfies are used **only** for face training by default. Nothing is uploaded to Cloudinary or stored as a profile photo unless the user explicitly agrees. |

## What you need to add

Both endpoints below now accept a new **optional** multipart form field:

```
use_as_profile: "true" | "false"   (default: "false" if omitted)
```

Send it as a normal multipart form field (string `"true"`/`"false"`, not a
JSON boolean) alongside the existing fields — same as any other `Form(...)`
field on these endpoints.

**Recommended UX:** when the user is about to upload selfies (at signup or
on an "add face" screen), show a checkbox/toggle like *"Use this photo as my
profile picture too"*. Only send `use_as_profile=true` if it's checked.
Don't default it to checked — the whole point of this change is that it's
the user's explicit choice.

### 1. `POST /common/create` (signup)

Existing multipart fields: `name`, `email`, `password`, `contact`,
`account_type` (`"user"` | `"photographer"`, default `"user"`), `files`
(selfies, optional), `country_code`, `locale`, `preferred_language`,
`timezone`, `interest_tags` (JSON array string).

**Add:** `use_as_profile` (optional, default `false`).

- If omitted/`false` and `files` are provided: selfies are used for face
  training only. Response's `account.profile_url` will be `null`.
- If `true` and at least one file is provided: the **first** file in `files`
  is uploaded and becomes `account.profile_url` in the response.

Response shape (unchanged):
```json
{
  "account": {
    "id": "...", "email": "...", "name": "...", "contact": "...",
    "role": "user", "profile_url": null, "email_verified": false
  },
  "verification_required": true
}
```

### 2. `POST /client/train-model` (add/retrain faces later)

Existing multipart fields: `email`, `files` (selfies).

**Add:** `use_as_profile` (optional, default `false`). Same semantics as
above — first file becomes the profile photo only if opted in. Response is
unchanged (`{"message": "success"}`) — if you want to show the user their
new `profile_url` after this call, fetch it via `GET /client/profile` /
`GET /photographer/profile` afterward, since this endpoint doesn't return
the account object.

### 3. `DELETE /client/face-data`

No request change. Behavior change: this now only clears face-recognition
enrollment (`has_added_faces` → `false`) and **no longer clears the profile
photo**. If your UI previously assumed removing face data also cleared the
avatar, it won't anymore — the two are independent now. To remove the
profile photo itself, that has to go through a dedicated profile-update
flow (not currently a "clear" endpoint — only replace via upload).

## Setting/changing the profile photo directly (unaffected by this change)

These already existed and still work exactly as before — use them for a
"change profile picture" screen that's independent of face enrollment:

- `POST /client/photo` — client profile photo upload (single file, sets `profile_url` directly)
- `POST /photographer/photo` — photographer equivalent

## Migration checklist for the frontend

- [ ] Signup screen: add the opt-in checkbox before the selfie upload step; wire it to `use_as_profile`.
- [ ] Add-face / retrain screen: same checkbox, same field, on `/client/train-model`.
- [ ] Anywhere you read `profile_url` immediately after signup or after `/client/train-model` and assumed it would be set: handle `null` gracefully (show a placeholder avatar / prompt to upload one).
- [ ] `DELETE /client/face-data` flows: stop assuming the avatar disappears — if you want that, you'll need to separately prompt the user or call a profile-photo-clearing flow (raise with backend if you need one, it doesn't exist yet).
