# Frontend: Event Description + content_tags Everywhere

## What's new

`Event` now has a `description` field, and `content_tags` (which already
existed) is now guaranteed present in every response that returns an event —
no more checking for a missing key.

Both are plain fields on the event object:
- `description` — `string`, max 2000 chars. Never `null` — always at least `""` (empty string) if the creator hasn't set one, including all pre-existing events.
- `content_tags` — `string[]`. Never `null` — always at least `[]`.

## Setting the description (photographer only)

**At creation** — `POST /photographer/events` (multipart form): add `description` alongside the existing fields (`eventName`, `content_tags`, etc.). Optional — omit it and the event gets `""`.

**Editing afterward** — `PATCH /photographer/events/{eventId}` (JSON body): add `description` to the `UpdateEventRequest` body, same as `eventName` or `content_tags`.

`content_tags` is unchanged — same form field at creation, same JSON field on update, accepts a JSON array string or comma-separated string.

## Where you'll see them in responses

Every endpoint that returns an event now includes both fields:

| Endpoint | Shape |
|---|---|
| `POST /photographer/events` (create response) | top-level `description`, `content_tags` |
| `GET /photographer/events` (list) | same |
| `PATCH /photographer/events/{eventId}` (update response) | same |
| `POST /client/search-images` | top-level on the `event` object |
| `GET /client/random-images` | inside each group's `event` object |
| `GET /follow/feed` | inside each group's `event` object |
| `POST /client/events` (event name/photographer search) | top-level, alongside `eventName`/`eventDate` |
| `GET /client/my-photos` | inside each item's `event` object |

## Nothing else changed

No new required fields, no breaking changes to existing keys — `description` and `content_tags` are additive on every one of the endpoints above. If your event card/detail UI doesn't render a description yet, this is safe to roll out incrementally per screen.
