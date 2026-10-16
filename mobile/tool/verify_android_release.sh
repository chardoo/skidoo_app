#!/usr/bin/env bash
#
# Check an Android artifact against the things Play rejects it for.
#
# Usage:
#   tool/verify_android_release.sh build/app/outputs/bundle/release/app-release.aab
#   tool/verify_android_release.sh build/app/outputs/flutter-apk/*.apk
#
# Four checks, each one a Play Console error somebody has already hit:
#
#   1. 16 KB page sizes, part one — every LOAD segment of every .so aligned to
#      a multiple of 16384. "Your app does not support 16 KB memory page
#      sizes." A single prebuilt inside a dependency is enough to fail it; see
#      the RootBeer substitution in android/build.gradle.kts.
#   2. 16 KB page sizes, part two (APK only) — the uncompressed .so entries
#      aligned to 16 KB *inside the zip*. Native libs load straight from the
#      APK, so the zip offsets are page offsets. An AAB is exempt: Play builds
#      the APKs and does this itself.
#   3. An engine for every ABI shipped. `--target-platform` narrows which
#      engine slices are built but NOT which plugin .so are packaged, so an
#      APK can end up advertising an ABI it cannot run — Play offers it to
#      those devices and the app dies on launch with a missing libflutter.so.
#   4. The version code, printed, because shadowing is a version-code mistake
#      and the arithmetic is not obvious. See RELEASING.md.
#
# Exit status is non-zero if any check fails, so CI can gate on it.

set -uo pipefail

ARTIFACT="${1:-}"
if [[ -z "$ARTIFACT" || ! -f "$ARTIFACT" ]]; then
  echo "usage: $0 <path-to.apk|path-to.aab>" >&2
  exit 2
fi

# ── Tools ────────────────────────────────────────────────────────────────────
SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}}"
READELF="$(ls -1 "$SDK"/ndk/*/toolchains/llvm/prebuilt/*/bin/llvm-readelf 2>/dev/null | sort -V | tail -1)"
ZIPALIGN="$(ls -1 "$SDK"/build-tools/*/zipalign 2>/dev/null | sort -V | tail -1)"

if [[ -z "$READELF" ]]; then
  echo "✗ no llvm-readelf found under $SDK/ndk — install an NDK" >&2
  exit 2
fi

PAGE=16384
FAILED=0
note() { printf '  %s\n' "$*"; }
fail() { printf '  ✗ %s\n' "$*"; FAILED=1; }
pass() { printf '  ✓ %s\n' "$*"; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

case "$ARTIFACT" in
  *.aab) KIND=aab; LIBROOT="base/lib" ;;
  *.apk) KIND=apk; LIBROOT="lib" ;;
  *) echo "not an .apk or .aab: $ARTIFACT" >&2; exit 2 ;;
esac

echo "── $(basename "$ARTIFACT")  (${KIND})"

unzip -q -o "$ARTIFACT" "$LIBROOT/*" -d "$WORK" 2>/dev/null
LIBDIR="$WORK/$LIBROOT"
if [[ ! -d "$LIBDIR" ]]; then
  fail "no native libraries found under $LIBROOT/"
  exit 1
fi

# ── 1. ELF segment alignment ────────────────────────────────────────────────
echo
echo "1. ELF 16 KB alignment"
misaligned=0
while IFS= read -r so; do
  rel="${so#"$LIBDIR"/}"
  while IFS= read -r a; do
    [[ -z "$a" ]] && continue
    dec=$(( a ))
    if (( dec % PAGE != 0 )); then
      fail "$rel — LOAD align $a ($dec), needs a multiple of $PAGE"
      misaligned=1
    fi
  done < <("$READELF" --program-headers "$so" 2>/dev/null | awk '$1=="LOAD"{print $NF}' | sort -u)
done < <(find "$LIBDIR" -name '*.so' | sort)
(( misaligned == 0 )) && pass "every LOAD segment is a multiple of $PAGE"

# ── 2. Zip alignment (APK only) ─────────────────────────────────────────────
echo
echo "2. 16 KB zip alignment"
if [[ "$KIND" == "aab" ]]; then
  note "— skipped: Play builds the APKs from a bundle and aligns them itself"
elif [[ -z "$ZIPALIGN" ]]; then
  fail "no zipalign found under $SDK/build-tools"
else
  # The trailing 4 is zipalign's required <align> positional — the ordinary
  # 4-byte entry alignment. `-P 16` is the separate, additional rule for
  # uncompressed .so. Omitting the positional makes zipalign print its usage
  # and exit 0, which reads as a pass and checks nothing.
  if "$ZIPALIGN" -c -P 16 4 "$ARTIFACT" >/dev/null 2>&1; then
    pass "uncompressed .so entries sit on 16 KB boundaries"
  else
    fail "not 16 KB zip-aligned — rebuild with AGP 8.5.1+, or zipalign -P 16"
    "$ZIPALIGN" -c -P 16 -v 4 "$ARTIFACT" 2>&1 | grep -E '\.so.*BAD' | sed 's/^/      /'
  fi
fi

# ── 3. An engine for every ABI shipped ──────────────────────────────────────
echo
echo "3. Flutter engine present for every ABI"
for abi in $(ls "$LIBDIR"); do
  libs="$(ls "$LIBDIR/$abi")"
  if grep -q '^libflutter\.so$' <<<"$libs" && grep -q '^libapp\.so$' <<<"$libs"; then
    pass "$abi"
  else
    missing=""
    grep -q '^libflutter\.so$' <<<"$libs" || missing="libflutter.so"
    grep -q '^libapp\.so$' <<<"$libs" || missing="${missing:+$missing, }libapp.so"
    fail "$abi ships plugin libraries but no $missing — Play will offer this"
    fail "   build to $abi devices and it will crash on launch."
    fail "   Cause: --target-platform narrows the engine, not the plugin .so."
  fi
done

# ── 4. Version code ─────────────────────────────────────────────────────────
echo
echo "4. Version code"
MANIFEST="$WORK/AndroidManifest.xml"
if [[ "$KIND" == "apk" ]]; then
  AAPT="$(ls -1 "$SDK"/build-tools/*/aapt2 2>/dev/null | sort -V | tail -1)"
  if [[ -n "$AAPT" ]]; then
    code="$("$AAPT" dump badging "$ARTIFACT" 2>/dev/null | sed -n "s/.*versionCode='\([0-9]*\)'.*/\1/p")"
    name="$("$AAPT" dump badging "$ARTIFACT" 2>/dev/null | sed -n "s/.*versionName='\([^']*\)'.*/\1/p")"
    abis="$(ls "$LIBDIR" | tr '\n' ' ')"
    note "versionCode $code  versionName $name  abis: $abis"
    note "a split APK's code is abi*1000 + base (arm32=1, arm64=2, x86_64=4),"
    note "so a universal APK always has the LOWEST code and is shadowed by"
    note "every split. Never upload both — see RELEASING.md."
  else
    note "— aapt2 not found; skipping"
  fi
else
  note "— read from app/build.gradle.kts; Play derives the splits itself"
fi

echo
if (( FAILED )); then
  echo "✗ $(basename "$ARTIFACT") would be rejected."
  exit 1
fi
echo "✓ $(basename "$ARTIFACT") passes every check."
