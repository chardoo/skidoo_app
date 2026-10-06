import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:jperg_app/core/common/widgets/in_app_web_view_page.dart';

/// Where the Terms and the Privacy Policy live, and how to open them.
///
/// One place, because these appear on six screens and a link that rots is
/// worse than no link: it is the one a store reviewer taps, and the one
/// somebody follows when they are already uneasy about a face being stored.
///
/// They used to be a lone `const _kPrivacyPolicyUrl` on the sign-up page
/// pointing at `piccotechnologies.com/privacy`, which does not resolve — every
/// path on that host fails on an SSL error. So the app's only legal link, the
/// one shown at the moment somebody agrees to the terms, went nowhere.
///
/// These are served by picco-v2 at `jperg.com`, from the same text the gateway
/// publishes (`gateway/app/routes/legal.py`). Both verified live.
class LegalLinks {
  const LegalLinks._();

  static const String privacy = 'https://jperg.com/privacy';
  static const String terms = 'https://jperg.com/terms';

  /// Opens the privacy policy in the in-app browser.
  ///
  /// In-app rather than handing off to Safari or Chrome: being thrown out of
  /// the app to read a policy and having to find your way back is how people
  /// lose a half-finished sign-up.
  static Future<void> openPrivacy(BuildContext context) =>
      InAppWebViewPage.open(context, url: privacy, title: 'Privacy Policy');

  static Future<void> openTerms(BuildContext context) =>
      InAppWebViewPage.open(context, url: terms, title: 'Terms & Conditions');
}

/// "Privacy Policy" and "Terms & Conditions" as tappable text, side by side.
///
/// The pair that belongs at the foot of a screen where somebody is agreeing to
/// something or handing over data. Both are offered together because a screen
/// that links one and not the other invites the question of where the other
/// one went.
class LegalLinksRow extends StatelessWidget {
  const LegalLinksRow({
    super.key,
    this.prefix,
    this.color,
    this.fontSize,
    this.alignment = WrapAlignment.center,
  });

  /// Leading sentence, e.g. "By continuing you agree to our". Null draws the
  /// two links alone, which is what a settings screen wants.
  final String? prefix;

  final Color? color;
  final double? fontSize;
  final WrapAlignment alignment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = fontSize ?? 12.sp;
    final muted = color ?? theme.hintColor;
    final link = theme.colorScheme.primary;

    TextStyle plain() => TextStyle(color: muted, fontSize: size);
    TextStyle tappable() => TextStyle(
          color: link,
          fontSize: size,
          // w700, not w600: DM Sans ships light/regular/medium/bold here and
          // no semibold, so w600 is a weight the renderer has to fake.
          fontWeight: FontWeight.w700,
          decoration: TextDecoration.underline,
          decorationColor: link,
        );

    Widget action(String label, Future<void> Function(BuildContext) open) =>
        Semantics(
          button: true,
          label: label,
          child: GestureDetector(
            onTap: () => open(context),
            child: Text(label, style: tappable()),
          ),
        );

    return Wrap(
      alignment: alignment,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (prefix != null) Text('$prefix ', style: plain()),
        action('Privacy Policy', LegalLinks.openPrivacy),
        Text('  ·  ', style: plain()),
        action('Terms & Conditions', LegalLinks.openTerms),
      ],
    );
  }
}
