# Frontend: Reset Password Flow

Three-step flow, same shape for both `client` and `photographer` — the
endpoints just differ by prefix. Both are actually **role-agnostic** under
the hood (see note at the bottom), so it doesn't functionally matter which
prefix you call, but use whichever matches the screen the user is on.

## Step 1 — Request a reset code

```
POST /api/client/confirm-email          (or /api/photographer/confirm-email)
{ "email": "user@example.com" }
```

- Generates a fresh 6-digit code, overwrites `User.code`, and sends it via **email + SMS**.
- **Always regenerates the code on every call** — no cooldown here, since this is an explicit user action (unlike the login-retry auto-regeneration, which does have a cooldown).
- Response: `{"message": "email confirmed code sent to this email"}`
- Error: `400 { "error": { "code": "BAD_REQUEST", "message": "Account does not exist" } }` if the email isn't registered.

## Step 2 — Verify the code (optional)

Lets you validate the code before showing the "set new password" screen,
without consuming it.

```
POST /api/client/verify-code
{ "email": "user@example.com", "code": "123456" }
```

- Just checks `email` + `code` match a row — doesn't consume or change anything.
- Response: `{"message": "code verified"}`
- Error: `400 "Account does not exist"` if email+code don't match (same message whether the email or the code is wrong — don't rely on it to distinguish which).
- Skippable: you can go straight from step 1 to step 3 and let `change-password`'s own email+code check be the validation.

## Step 3 — Set the new password

```
POST /api/client/change-password
{ "email": "user@example.com", "code": "123456", "password": "NewPass123!" }
```

- Re-checks `email` + `code`, hashes the new password, clears the code (`code = NULL` — **one-time use**, can't be replayed), and fires a "password changed" confirmation email/SMS.
- Response: `{"message": "password reset"}`
- Error: `400 "Password was not reset"` if email+code don't match at this point (e.g. code already consumed, or wrong).

## Validation rules to enforce client-side too

| Field | Rule |
|---|---|
| `email` | Standard format check, max 254 chars |
| `code` | Digits only, 4–10 chars (in practice always 6 digits) |
| `password` (step 3 only) | 8–128 chars, must include a lowercase letter, an uppercase letter, a digit, **and** a symbol — all four required, not just length |

## Things worth knowing that aren't obvious from the endpoints alone

- **No code expiry.** There's no timer — a code stays valid until it's consumed (step 3 succeeds) or replaced (user hits step 1 again). Don't build a countdown UI that implies a hard expiry unless you want to fake one client-side.
- **Both prefixes work regardless of actual role** — `/client/confirm-email` and `/photographer/confirm-email` do the exact same lookup with no `role` filter, so either one works for any account (a photographer's email works through the client endpoint and vice versa).
