# Release notes

Store "What's new" copy, newest first, with the scope each note covers. Each
entry says which store it shipped to — the two do not release in step, and a
note written for one is not copy for the other.

**Which number is the release.** The two platforms take their build number from
different places, and neither reads the other's:

| | authority | where |
| --- | --- | --- |
| Android | `versionCode` | hardcoded in [`android/app/build.gradle.kts`](android/app/build.gradle.kts), **not** derived from `pubspec.yaml` |
| iOS | `CFBundleVersion` | `$(FLUTTER_BUILD_NUMBER)` — which *is* the `+63` in `pubspec.yaml`, the part Android ignores |

So the pubspec's build number is dead weight on Android and is the whole of the
iOS build number. To scope the next Android note, find the commit that set the
previous version code and take everything after it:

```bash
git log --format="%h|%ad|%s" --date=short -L36,41:mobile/android/app/build.gradle.kts \
  | grep -E "^[0-9a-f]{7,}\||^\+ *versionCode"
```

For iOS the same question is asked of `pubspec.yaml`:

```bash
git log --format="%h|%ad|%s" --date=short -L5,5:mobile/pubspec.yaml \
  | grep -E "^[0-9a-f]{7,}\||^\+version:"
```

Play caps its field at **500 characters** per language. App Store Connect
allows **4000**, which is not a reason to use them.

---

## 1.0.1 (63) — App Store — 2026-10-29

**iOS only. There is no Play release in this cycle**, so there is no Play copy
below — the Android `versionCode` in the working tree has moved to 44 and the
note for it, when it ships, is a separate entry written against that number.
The 63 here is `pubspec.yaml`'s build number, so if the pubspec is bumped
before the archive, this heading moves with it.

Covers the seventeen commits after `a704832`. That is an Android version code,
used here only because it is the last point either store shipped from.

458 characters.

```
• Your region now saves, and the request board shows work near you.
• Becoming a creator takes effect at once — verifying your ID is optional.
• Boosts are now bought through the App Store.
• Sign-up no longer asks for a phone number.
• Choose your town from a list instead of typing it.
• Photos load faster and no longer flicker as they appear.
• The handle under your avatar is your username, not your email.
• A profile tab that cannot load now says so.
```

### What that maps to

| Commit | Change |
| --- | --- |
| `59eec36` | Edit Profile picks a town from the location search instead of taking typed text |
| `581cdfb` | The profile payload carries the stored region, so the field opens on it |
| `bd1ec72` | The region finally reaches the server, and a new creator's board is not empty |
| `ee72617` | Boosts are bought through the App Store on iOS; photos stay on Paystack |
| `2f71260` | A failed App Store purchase no longer blocks the next attempt |
| `104afba` | Photos through the App Store — superseded by `ee72617`, see below |
| `b24a63b` | Sign-up stops requiring a phone number |
| `6c5e90f` | The handle under the avatar reads `username`, not the face-recognition id |
| `afbc6ff` | A profile tab that failed to load says so instead of sitting empty |
| `f44dd52` | A photo asks for the size it will be drawn at |
| `6cb9987` | Photos are sized to the connection and fetched over HTTP/3 |
| `282d89a` | The image warmed ahead is the one the next card will ask for |
| `7d89b95` | The blur waits for the photo it stands in for |
| `5dff62c` | The photo stops dissolving up through its own blur |
| `c34c414` | A full-bleed slot shows a ring rather than a blur of the photo |
| `de5e7d9` | One flag picks which backend a build talks to — not user-visible |
| `350281b` | App Review 2.1(b) answers — not user-visible |

### Wording decisions

- **"Your region now saves" is the headline, and it is a confession.** Three
  commits make one fix: the picker (`59eec36`), the field reading it back
  (`581cdfb`), and `bd1ec72`, which found that the app had been calling
  `/api/api/location` all along — so no region had *ever* reached the server,
  for anybody. The bullet is worded as the thing working rather than as the
  thing having been broken, but it should not be softened into "improved": for
  every person on an earlier build this is the first time the field does
  anything at all.
- **The board bullet rides with it on purpose.** A creator with no region is
  ranked as unplaceable, and a newly promoted creator saw an empty board
  entirely until the backend deploy on 2026-10-29. One sentence covers both
  because to the person reading it they are the same complaint.
- **"Verifying your ID is optional" must not become "you don't need to verify".**
  The ID still earns the verified badge and an admin still awards it. What
  changed is that it no longer blocks the end of the creator wizard. The
  in-app note says the same thing in the same order — badge first, optional
  second — and the two should not drift.
- **The boost bullet is iOS-only, and does not travel.** `104afba` put photos
  through Apple's IAP and `ee72617` took them back out: photos are Paystack on
  both platforms, and only boosts are an in-app purchase, only on iOS. When
  Android next ships, that line is not copy for it — a Play note naming the App
  Store is both wrong and a listing violation. In the other direction, an iOS
  note implying *photos* are an in-app purchase is the Apple review finding
  this release exists to avoid.
- **The three feed bullets are one bullet.** `f44dd52`, `6cb9987`, `282d89a`,
  `7d89b95`, `5dff62c` and `c34c414` are six commits of loading and placeholder
  work that a reader experiences as "it stopped flickering". Listing them
  separately would spend a third of the field on it.

---

## 1.0.1 (41) — 2026-10-22

Covers the nine commits after `48f92c6`, which set version code 40.
450 characters.

```
• Verified creators now show their badge on the feed and in Following.
• Likes from comments and chat appear in your Liked tab right away.
• Photos you save arrive at full quality, with no preview watermark.
• Sign-up asks for your name instead of a username.
• Photographer profiles no longer repeat the studio name.
• Creators can now see when a post has been taken down, and why.
• Content removed by moderation clears from the app automatically.
```

### What that maps to

| Commit | Change |
| --- | --- |
| `0602899` | The verified tick sits beside the name on the feed and in Following |
| `1eee05f` | A like recorded anywhere reaches the Liked grid |
| `df4f8af` | Sign-up asks for a name, not a username |
| `5a5eb8c` | Tests holding sign-up to asking for a name — not user-visible |
| `9e19f90` | Saving a photo hands over the original, unbadged |
| `b1a54d4` | One name on a portfolio, not a name and a studio name |
| `bd0722a` | Blocked content leaves the phone on the next request |
| `48ef295` | A creator sees their blocked album, marked, with the reason |
| `3579ad4` | Subject-verb agreement in the Premium headline — too small to list |

### Wording decisions

Two bullets are worded deliberately and should not be loosened on edit:

- **The watermark bullet** says "Photos you save", not "photos". `9e19f90`
  removes the paid-preview watermark from the downloaded file only for a photo
  the person owns or has bought; the server still watermarks previews of photos
  they have not. The in-app share sheet now reads "Full quality, to your
  device", and this line matches it on purpose, so the listing cannot be read
  as a promise to strip marks from unpaid photos.
- **The two moderation bullets** describe the creator-facing notice and the
  cache cleanup. They do not describe blocking mechanics, which is not
  something to advertise in a store listing. A creator is the only person sent
  a blocked row at all — see the backend's `docs/BLOCKED_CONTENT.md`.
