import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';

/// The verified tick. One widget, so there is one of it.
///
/// It was drawn at six call sites in **three different colours** — `infoBlue`
/// on the creator profile, the public profile and the chat room tile,
/// `accentGold` in search, the portfolio editor and the verification form —
/// which meant the same claim about the same account changed colour depending
/// on which screen you reached it from. A badge that is not consistent is not
/// a badge; it reads as two unrelated marks.
///
/// Green, because that is the brand accent (`accentGold` is #1D9E75 — the
/// token kept its name through the rebrand) and because blue is the tick every
/// other platform uses for something they verify differently from us. The
/// shade follows the ground it sits on: see [AppThemeExtension.accentOnGround],
/// since the lighter green does not carry enough contrast on a light page.
///
/// Nothing is drawn when [isVerified] is false, so callers can hand it the
/// flag rather than wrapping it in an `if` each time.
class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({
    super.key,
    this.isVerified = true,
    this.size,
    this.semanticLabel = 'Verified',
  });

  /// Whether to draw anything at all.
  final bool isVerified;

  /// Overrides the default glyph size. Call sites vary from a 14sp tick beside
  /// a chat name to an 18sp one in a page title; the default suits a name on a
  /// profile.
  final double? size;

  /// What a screen reader says. Worth overriding where the tick means
  /// something more specific than "verified" — an official account, say.
  final String semanticLabel;

  /// The default glyph size, in sp. Matches the name line it usually sits on.
  static const double defaultSize = 16;

  @override
  Widget build(BuildContext context) {
    if (!isVerified) return const SizedBox.shrink();
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    return Semantics(
      label: semanticLabel,
      child: Icon(
        Icons.verified_rounded,
        size: (size ?? defaultSize).sp,
        color: ext.accentOnGround,
      ),
    );
  }
}
