# App Review — Guideline 4, design

Received 2026-11-17. Two complaints in one paragraph:

> the app includes controls that are difficult to use due to size or placement
> and is not optimized to support all screen sizes or resolutions

with a pointed note about iPad. They are two symptoms of the same cause, and
it is worth stating the cause before the fixes, because it will come back
otherwise.

## The cause

Every size in this app goes through `flutter_screenutil` against a **390×844**
design (`app.dart`), so a number written in the source is not a number of
points. `46.h` means 46 × (screen height ÷ 844), and `46.w` means
46 × (screen width ÷ 390).

That is correct for *spacing* — gaps should get smaller on a smaller phone —
and wrong for anything a finger has to land on, in two directions at once:

| Device | `.w` factor | `.h` factor | A `46.h` button |
|---|---|---|---|
| iPhone 14 (design) | 1.00 | 1.00 | 46pt |
| **iPhone SE 3** | 0.96 | **0.79** | **36pt** |
| iPad Pro 13″ portrait | 2.10 | 1.40 | 64pt |
| **iPad Pro 13″ landscape** | **3.03** | 0.97 | 45pt, 3× too wide |

Both halves of Apple's sentence fall out of that table. Controls were under the
44pt minimum on small phones; the layout came apart on iPad, where widths grew
3× while `.sp` text stayed phone-sized.

## What shipped in this fix

### 1. Controls are floored at 44pt — `core/utils/responsive.dart`

`kMinTapTarget = 44.0`, and a `TapTargetSize` extension giving `.tapH` / `.tapW`
— `.h` and `.w` that can never return less than 44. The floor only ever lifts,
so large phones are drawn exactly as before.

Applied to **61 controls** across 40 files, plus four shared primitives that
cover most of the app by themselves:

- `AppButton` — floors the caller's height too, not just its own default, so a
  call site asking for a compact button gets a compact drawing and not a 32pt
  target. Was 39.5pt on an SE at its default.
- `AppFilterChip` — the row is floored at 44 and the pill is **centred inside
  it at its original height**. The chip looks exactly as drawn, and the tap
  lands on the 44pt band around it. A secondary chip was a 25pt target.
- `MediaRailAction` — floors `tapTargetSize`. The album download asked for
  `32.r`, which is 25pt on an SE.
- `ProfilePillButton`, `AppCodeField`, the chat send and media buttons, the
  fullscreen close button, the cart button.

Spacers, dividers, scrims, thumbnails and avatars were deliberately left on
`.h`/`.w` — shrinking those on a smaller screen is the right behaviour.

Guarded by `test/core/tap_target_size_test.dart`, which pumps the shared
controls **at iPhone SE size**. That matters: the same assertions at 390×844
pass on the broken code, which is exactly why the defect survived.

### 2. The app is iPhone-only — `ios/Runner.xcodeproj/project.pbxproj`

`TARGETED_DEVICE_FAMILY = 1` on every build configuration. The Runner target
was already set; the project-level default and the notification service
extension still said `"1,2"` — and an extension whose device family is not a
subset of its host app's is an upload-validation failure waiting to happen.

`UISupportedInterfaceOrientations~ipad` is gone from `Info.plist` along with
it. That key was doing active harm: a multitasking iPad **ignores**
`setPreferredOrientations`, so the portrait lock in `main.dart` did not hold
there, and the app was free to rotate into a 1366pt-wide landscape that a
390-wide design has no answer for.

The iPhone orientation list still names both landscapes. **Do not tidy them
out** — `setPreferredOrientations` can only ever be granted an orientation the
plist declares, and the fullscreen video player asks for landscape back.

Note that Xcode rewrites `Info.plist` and strips XML comments from it on every
build, so the reasoning lives in `main.dart` beside the orientation call.

### Before submitting

- [ ] If App Store Connect holds **iPad screenshots**, remove them. An
      iPhone-only app does not offer them and a stale set contradicts the
      binary.
- [ ] Archive and test on a physical iPhone SE or a 13 mini if one is to hand —
      that is the device the tap-target work is for.

---

## Not done yet: making the app work *on* iPad

Deferred deliberately. iPhone-only is a legitimate answer to this rejection —
the app still downloads onto an iPad and the OS runs it in a correctly scaled
iPhone window — and it is the answer that can ship today. Real iPad support is
a project, not a patch, and these are the pieces in the order they have to
happen.

**Phase 1 — stop the scaling running away.** The 3× horizontal blow-up is the
whole problem and it is fixable in one place. Either cap screenutil's
effective width by handing `ScreenUtilInit` a `MediaQuery` whose size is
clamped on large screens, or render the app inside a centred, phone-width
canvas with the app ground painted around it. The second is less code, is
honest about what the app is, and is what several well-regarded phone-first
apps do on iPad. Neither touches the 3,100 `.w`/`.sp` call sites, which is the
point — rewriting those is not on the table.

**Phase 2 — the screens that are already wide-aware.** Settings, auth and chat
carry `maxWidth` constraints (480/540/680/720/900) from an earlier pass. The
feed, discovery, gallery, profile and the request board do not. They need the
same treatment before anything is shown to a reviewer on an iPad.

**Phase 3 — landscape.** Re-declare the iPad orientations, set
`UIRequiresFullScreen` if the orientation lock needs to hold, and decide per
screen whether landscape is a wider column or a genuinely different layout.
The fullscreen video player is the only screen that handles rotation today.

**Phase 4 — grids.** `isTablet()` and `responsiveColumnCount()` already exist
in `core/utils/responsive.dart` and are used by three files. `MediaGrid` is
the right chokepoint for the rest.

Budget several days and test on an iPad mini, an iPad Pro 13″ and Split View —
not just the simulator's default.
