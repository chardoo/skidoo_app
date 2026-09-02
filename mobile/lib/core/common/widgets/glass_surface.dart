import 'dart:io' show Platform;
import 'dart:ui';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';

/// Chrome that floats over content: the nav bars, the icon buttons, the pills
/// on a photo.
///
/// **One widget because the platforms disagree, and both are right.** iOS
/// chrome is frosted glass — you see the content moving under it, and that is
/// how the system's own bars behave. Material 3 does not do that: its nav bar
/// is an opaque tonal surface, and a blurred bar on Android reads as an app
/// imitating a different OS. So this branches once, here, rather than at forty
/// call sites that would drift apart.
///
/// The blur is also not free. It is a render pass over everything behind the
/// widget, every frame, and the nav bar is on screen for the whole session —
/// so on Android, where cheap hardware is the common case, it is paid
/// constantly for a look that platform does not even want.
///
/// Web takes the Android path: `BackdropFilter` on CanvasKit is a real cost
/// and the app's web build is a desktop-shaped portal, not a phone.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    required this.borderRadius,
    this.blurSigma = 14,
    this.bordered = true,
    this.padding,
    this.onDark,
    this.tonalOpacity = 1,
  });

  final Widget child;
  final BorderRadius borderRadius;

  /// How soft the frost is.
  ///
  /// Low on purpose, and this is the setting that decides whether the glass
  /// reads as glass. A wide blur smears everything behind it into one flat
  /// tone, so the chrome looks like a painted panel however transparent the
  /// tint is — you can see *a colour* through it, not *the content*. Keeping
  /// the radius short leaves the shapes behind recognisable, which is the
  /// entire effect. It is cheaper, too: blur cost rises with radius.
  final double blurSigma;

  /// The hairline that gives the glass an edge. Off for surfaces that already
  /// have one from their own shape.
  final bool bordered;

  final EdgeInsetsGeometry? padding;

  /// How solid the tonal fallback is, where this build does not frost.
  ///
  /// Opaque by default, and that default is right for chrome that has to stay
  /// legible over anything: a translucent fill with nothing blurred behind it
  /// is a washed-out box with the content showing through, which is worse than
  /// either treatment done properly. The nav bar is the case that argument was
  /// written for.
  ///
  /// It is wrong for a surface whose whole job is to sit *on* a picture. A pill
  /// in the middle of a photo has to let the photo through — an opaque one
  /// punches a hole in the image it is drawn over — and there, a plain dark
  /// scrim is the honest fallback when a blur is not on offer. Set it low
  /// enough to read the text against and no lower.
  ///
  /// Ignored on the frosted path, where the tint is deliberately barely there
  /// and the blur is doing the work.
  final double tonalOpacity;

  /// Force the dark treatment regardless of the app's theme.
  ///
  /// Some surfaces sit on ground that is dark whatever the theme is — the feed
  /// is a deliberate dark island, and a photo viewer is black. Chrome there
  /// has to match what is *behind* it, which is not what `Theme.of` knows.
  final bool? onDark;

  /// Forces a treatment in tests. Null follows the platform.
  ///
  /// Needed because the suite runs on macOS, which is neither of the two
  /// platforms this ships to — so without an override every widget test would
  /// silently exercise whichever branch the *host* implies rather than the one
  /// being asserted.
  @visibleForTesting
  static bool? debugFrostedOverride;

  /// Whether this build frosts or falls back to a tonal surface.
  ///
  /// Exposed so a caller can size or colour something differently under each
  /// treatment without re-deriving the rule.
  ///
  /// iOS only. Android gets Material 3's tonal surface by choice, and web
  /// because a blur on CanvasKit is a real cost for a build that is a
  /// desktop-shaped portal rather than a phone. macOS is not a target, so it
  /// takes the same path as the test host it usually is.
  static bool get isFrosted {
    if (debugFrostedOverride != null) return debugFrostedOverride!;
    if (kIsWeb) return false;
    return Platform.isIOS;
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final dark = onDark ?? Theme.of(context).brightness == Brightness.dark;

    final content = padding == null
        ? child
        : Padding(padding: padding!, child: child);

    final border = bordered
        ? Border.all(color: ext.glassBorder, width: 0.5)
        : null;

    if (!isFrosted) {
      // Material 3's own nav surface: opaque by default, lifted by tone rather
      // than by transparency — see [tonalOpacity] for when that default is
      // wrong and why it is not simply flipped for everyone.
      return Container(
        decoration: BoxDecoration(
          color: (dark ? const Color(0xFF1B1B1A) : ext.cardSurface)
              .withValues(alpha: tonalOpacity),
          borderRadius: borderRadius,
          border: border,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: dark ? 0.32 : 0.10),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: content,
      );
    }

    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: DecoratedBox(
          decoration: BoxDecoration(
            // Tuned for having a blur behind it. The old glassFill values were
            // set when nothing was blurred and the tint was doing the whole
            // job alone; over real frost they read as fog. See
            // [_frostedFill].
            color: _frostedFill(ext, dark: dark),
            borderRadius: borderRadius,
            border: border,
          ),
          child: content,
        ),
      ),
    );
  }

  /// The tint laid over the blur.
  ///
  /// Barely there. Two rounds of this were too heavy — 35 % black read as an
  /// opaque slab over a dark photo, and 18 % still hid what was behind it. The
  /// tint is not what makes the chrome legible; the blur is. Its only job is
  /// to keep the surface from disappearing entirely against a mid-grey photo.
  ///
  /// Paired with a short [blurSigma]: a light tint over a wide blur still
  /// looks flat, because the blur has already thrown away everything that
  /// would tell you there is content back there.
  static Color _frostedFill(AppThemeExtension ext, {required bool dark}) =>
      dark
          ? const Color(0x14121211) // near-black, 8 %
          : const Color(0x33FFFFFF); // white, 20 %
}
