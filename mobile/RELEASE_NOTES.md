# Release notes

Play Console "What's new" copy, newest first, with the scope each note covers.

The Android version code is the authority on what a release contains. It is
hardcoded in [`android/app/build.gradle.kts`](android/app/build.gradle.kts)
(`defaultConfig.versionCode`) and is **not** derived from `pubspec.yaml` — the
`+63` in the pubspec version is unused on Android. To scope the next note, find
the commit that set the previous version code and take everything after it:

```bash
git log --format="%h|%ad|%s" --date=short -L36,41:mobile/android/app/build.gradle.kts \
  | grep -E "^[0-9a-f]{7,}\||^\+ *versionCode"
```

Play caps the field at **500 characters** per language.

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
