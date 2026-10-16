# Releasing to Play

Two Play Console errors prompted this document. Both are about *which artifact
you upload*, not about the code:

> This APK will not be served to any users because it is completely shadowed by
> one or more APKs with higher version codes.

> Your app does not support 16 KB memory page sizes.

---

## Short version

```bash
cd mobile
flutter build appbundle --release
tool/verify_android_release.sh build/app/outputs/bundle/release/app-release.aab
```

Upload **the one `.aab`**. Nothing else. That is what the CI lane does
(`fastlane/Fastfile`, `android deploy`), and it is the only path with no way to
get either error.

---

## Why an APK gets "completely shadowed"

A release may hold several APKs, and Play picks one per device: the **highest
version code** whose targeting matches. An APK that can never win that
comparison on any device is dead weight, and Play says so.

Flutter gives each per-ABI split its own version code, because Play refuses two
APKs with the same one. The arithmetic is `abi * 1000 + versionCode`
(`FlutterPluginConstants.ABI_VERSION`):

| artifact | ABIs served | version code at `versionCode = 39` |
|---|---|---|
| `app-release.apk` (universal) | all three | **39** |
| `app-armeabi-v7a-release.apk` | armeabi-v7a | 1039 |
| `app-arm64-v8a-release.apk` | arm64-v8a | 2039 |
| `app-x86_64-release.apk` | x86_64 | 4039 |

So the universal APK always has the **lowest** code while covering **every**
device the splits cover. Upload it alongside them and it is shadowed by
definition — there is no device it could be chosen for. That is the error,
word for word.

**So: the splits, or the universal, never both.** And never a leftover APK from
an earlier build sitting in the release — it is both shadowed and, as below,
very likely the one failing the 16 KB check.

---

## Why "does not support 16 KB memory page sizes"

Android 15 devices can boot with 16 KB memory pages, and Play now requires apps
to work on them. There are **two** separate requirements and both must hold:

1. **ELF alignment.** Every `LOAD` segment of every bundled `.so` must sit on a
   multiple of 16384. A single prebuilt inside a dependency fails the whole
   app — which is exactly what happened in `8abebcf`: RootBeer's
   `libtoolChecker.so` came in at 4096 through `flutter_jailbreak_detection`,
   and no amount of raising `ndkVersion` touched it because nothing in this
   build compiles it. The fix was substituting the coordinate; see the
   `dependencySubstitution` block in `android/build.gradle.kts`.
2. **Zip alignment (APKs only).** Native libraries load straight out of the
   APK, so their *offsets inside the zip* are page offsets: the uncompressed
   `.so` entries must start on 16 KB boundaries. AGP 8.5.1+ does this; this
   project is on 8.11.1. A bundle is exempt — Play builds the APKs itself.

**Current source satisfies both.** Verified on a fresh build: every `LOAD`
segment across all four ABIs is a multiple of 16384, and `zipalign -c -P 16`
reports success on the APK.

That is worth stating plainly, because it means **an artifact failing this
check today was built before `8abebcf` (12 Oct)**. Rebuilding is the fix. Do not
go looking for a new misalignment first — check the artifact's date.

---

## Before every upload

```bash
tool/verify_android_release.sh <path to .aab or .apk>
```

Four checks, each one an error somebody has already hit:

1. ELF 16 KB alignment of every `.so`
2. 16 KB zip alignment (APK only)
3. **an engine for every ABI shipped** — see the trap below
4. the version code, printed, with the shadowing arithmetic

It exits non-zero on failure, so CI can gate on it.

### The `--target-platform` trap

Do not use `--target-platform` to drop an ABI from a store build.

It narrows which **engine** slices are compiled and nothing else. The Flutter
Gradle plugin still sets `ndk.abiFilters` to all three supported ABIs
(`configureAbiWithoutSplits` in `FlutterPlugin.kt`), so every *plugin's*
prebuilt `.so` is packaged for every ABI regardless. You get an APK holding
`lib/x86_64/libdartjni.so` with no `libflutter.so` beside it — Play reads the
folder, concludes the app supports x86_64, offers it to those devices, and the
app dies on launch with a missing engine.

Check 3 catches it. For reference, building with `--target-platform android-arm64`
and running the script produces:

```
3. Flutter engine present for every ABI
  ✓ arm64-v8a
  ✗ armeabi-v7a ships plugin libraries but no libflutter.so, libapp.so …
  ✗ x86_64 ships plugin libraries but no libflutter.so, libapp.so …
```

To genuinely ship fewer architectures, use `--split-per-abi` and upload only
the splits you want — each one carries its own engine.

---

## Bumping the version

`versionCode` lives in `android/app/build.gradle.kts` and must increase on every
upload. Remember the splits multiply it: if you have ever uploaded splits at
`versionCode = 39`, the highest code Play has seen is **4039**, and a later
*universal* APK at 40 is below all of them. Mixing the two forms across releases
is how a release ends up with nothing servable. Pick one form and keep to it —
or, better, upload the bundle and let Play do the splitting.
