# "Photos of me" — filters + event grouping

Backend for the **Found photos** screen and its **Filters** sheet.

| | |
|---|---|
| `GET /api/client/my-photos` | the grid, grouped by event |
| `GET /api/client/my-photos/filters` | options for the Filters sheet + the "Show N photos" count |

Both require the client's `Authorization: Bearer <token>` and only ever return
pictures where *that* user was matched by face recognition. A client who has
never enrolled a face gets an empty result, never an error.

## Filters (identical query params on both endpoints)

| Param | Values | Notes |
|---|---|---|
| `dateRange` | `all` · `this_month` · `last_3_months` · `custom` | `custom` requires `startDate` and/or `endDate` |
| `startDate`, `endDate` | `YYYY-MM-DD` | inclusive; usable on their own without `dateRange` |
| `visibility` | `all` (default) · `public` · `private` | `private` = the photographer has not made the photo public |
| `photographerId` | id, repeatable | `?photographerId=a&photographerId=b` or `?photographerId=a,b` |
| `eventId` | id, repeatable | same two forms — use it for the "see all" drill-down |

The date filter matches the photo's **shoot date** (`Picture.eventDate`, falling
back to the event's date, then upload date) — not when the face was recognised.

Invalid values return `400` in the standard envelope
(`{"success": false, "error": {"code": "BAD_REQUEST", ...}}`): unknown
`dateRange`/`visibility`, `dateRange=custom` with no dates, `startDate` after
`endDate`.

## `GET /api/client/my-photos`

Extra params: `groupBy` (`event` default · `none`), `previewLimit` (default `6`,
max 100), `page`, `limit` (default 25, max 100).

**`groupBy=event`** — pages over **events**; `pagination.total` counts events,
`totals` carries the headline numbers ("48 found").

```jsonc
{
  "data": [
    {
      "event": {
        "id": "…", "eventName": "Praise Reloaded 2026", "description": "",
        "content_tags": [], "eventDate": "2026-07-12",
        "photographer": { "id": "…", "name": "Kofi Mensah", "profile_url": "…" }
      },
      "photoCount": 21,          // all matches in this event
      "photos": [ /* newest `previewLimit`, full photo objects */ ],
      "moreCount": 15,           // what the "+15" tile stands for
      "lastIdentifiedAt": "2026-07-28T19:04:11+00:00"
    }
  ],
  "pagination": { "page": 1, "limit": 25, "total": 4, "totalPages": 1,
                  "hasNext": false, "hasPrev": false },
  "totals": { "photos": 48, "events": 4 }
}
```

Groups are ordered by most recent match; photos within a group likewise.
Tapping "+15" → re-request with `?eventId=<id>&groupBy=none` and page through.

**`groupBy=none`** — flat photo list (the previous shape), `pagination.total`
counts photos. Each photo:

```jsonc
{
  "id": "…", "url": "…", "imageId": "…", "price": 25.0, "public": false,
  "facesCount": 3, "mediaType": "image", "likeCount": 0, "commentCount": 0,
  "comments_enabled": true, "width": 4000, "height": 6000, "durationSeconds": null,
  "isPurchased": false,                       // by *this* client
  "identifiedAt": "2026-07-28T19:04:11+00:00",
  "photoDate": "2026-07-12",                  // what dateRange filters on
  "event": { /* same event object as above */ }
}
```

## `GET /api/client/my-photos/filters`

Send the sheet's current selection; render the chips from the response and put
`matchingCount` on the button ("Show 12 photos").

```jsonc
{
  "matchingCount": 12,     // current selection
  "totalCount": 48,        // ignoring all filters
  "dateRanges":  [ { "value": "all", "count": 48 },
                   { "value": "this_month", "count": 12 },
                   { "value": "last_3_months", "count": 31 } ],
  "visibility":  [ { "value": "all", "count": 48 },
                   { "value": "public", "count": 30 },
                   { "value": "private", "count": 18 } ],
  "photographers": [ { "id": "…", "name": "Daniella Daniels",
                       "profile_url": "…", "count": 19 } ],
  "events":        [ { "id": "…", "eventName": "Praise Reloaded 2026",
                       "eventDate": "2026-07-12", "count": 21 } ]
}
```

The `photographers` and `events` lists honour the date + visibility selection
but ignore each other's selection, so toggling one chip never empties the other
list. `dateRanges` / `visibility` counts are always over the unfiltered set, so
those chips stay stable while the user experiments.
