import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/config/app_links_config.dart';
import 'package:jperg_app/core/deep_links/deep_link.dart';
import 'package:jperg_app/core/deep_links/deep_link_service.dart';
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/utils/snackbar_utils.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opening a link that somebody else wrote.
///
/// Two questions, in this order:
///
/// 1. **Is it one of ours?** A link to an event, a photo, a request or a
///    profile is a screen in this app, and following it in a browser would send
///    somebody out of the app to look at something the app is already showing.
///    Two parts to the answer: our domain, and then [parseDeepLink] for what
///    the path means — reusing the parser so a route added there works here for
///    free, and checking the host separately because the parser is written for
///    links the OS has already vouched for and these are not. See [isOurs].
///
/// 2. **Otherwise, ask before leaving.** An address in a message was typed by
///    another person, and tapping a word should not hand the reader to an
///    unknown site without a word about where they are going. The sheet names
///    the host, which is the part worth reading, and puts the full address
///    underneath for anyone who wants it.
///
/// The confirmation is not a formality. Chat is exactly where a hostile link
/// arrives, and "you are about to leave" plus a legible hostname is the
/// difference between following a link and being taken somewhere.
class ExternalLink {
  const ExternalLink._();

  /// Follows [raw] — in the app when it points at one of our screens, in the
  /// browser once the reader has agreed to leave.
  ///
  /// Silently does nothing for something that is not a URL at all: the caller
  /// is a tap handler on text, and text is full of things that look like
  /// addresses and are not.
  static Future<void> open(BuildContext context, String raw) async {
    final uri = _parse(raw);
    if (uri == null) return;

    // Ours? Then it is a navigation, not a departure. The host is checked
    // before the path, because on a link somebody else wrote the path alone is
    // not evidence of anything.
    final link = isOurs(uri) ? parseDeepLink(uri) : null;
    if (link != null) {
      final service = DeepLinkService.instance;
      if (service != null) {
        await service.follow(link);
        return;
      }
      // No service to route it — fall through and open it in a browser, which
      // lands on the site's own page for the same content.
    }

    if (!context.mounted) return;
    final go = await confirmLeaving(context, uri);
    if (go != true) return;

    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      AppSnackBar.error(context, 'Could not open that link.');
    }
  }

  /// "You're leaving the app", naming where to.
  ///
  /// Public so a caller with its own URL — a campaign's call-to-action, a
  /// track's page at the provider — can ask the same question in the same
  /// words rather than inventing a second dialog.
  static Future<bool?> confirmLeaving(BuildContext context, Uri uri) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        decoration: BoxDecoration(
          color: ext.homeBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        ),
        padding: EdgeInsets.fromLTRB(
            AppSpacing.xl.w, AppSpacing.lg.h, AppSpacing.xl.w, AppSpacing.xl.h),
        // The tiles inside paint their ink on the nearest Material, and this
        // decorated Container would swallow it — see comment_dialogs.dart.
        child: Material(
          type: MaterialType.transparency,
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40.w,
                    height: 4.h,
                    margin: EdgeInsets.only(bottom: AppSpacing.lg.h),
                    decoration: BoxDecoration(
                      color: ext.searchHintColor.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                ),
                Text(
                  "You're leaving the app",
                  style: TextStyle(
                    color: ext.greetingColor,
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: AppSpacing.sm.h),
                Text(
                  'This link opens outside the app.',
                  style: TextStyle(
                    color: ext.searchHintColor,
                    fontSize: 13.sp,
                  ),
                ),
                SizedBox(height: AppSpacing.lg.h),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(AppSpacing.md.w),
                  decoration: BoxDecoration(
                    color: ext.cardSurface,
                    borderRadius: BorderRadius.circular(AppRadius.md.r),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // The host, alone and first. It is the part that answers
                      // "where am I going" — a long address with the real
                      // destination buried in the middle is how a link lies
                      // about itself.
                      Text(
                        uri.host,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: ext.greetingColor,
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        uri.toString(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: ext.searchHintColor,
                          fontSize: 12.sp,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: AppSpacing.lg.h),
                Row(
                  children: [
                    Expanded(
                      child: _SheetButton(
                        label: 'Cancel',
                        filled: false,
                        ext: ext,
                        onTap: () => Navigator.of(sheetContext).pop(false),
                      ),
                    ),
                    SizedBox(width: AppSpacing.md.w),
                    Expanded(
                      child: _SheetButton(
                        label: 'Continue',
                        filled: true,
                        ext: ext,
                        onTap: () => Navigator.of(sheetContext).pop(true),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Whether [uri] is on the domain this app's own links live on.
  ///
  /// [parseDeepLink] deliberately does not ask this, and should not start: the
  /// links it was written for arrive from the OS, which has already matched the
  /// domain against the AASA and assetlinks files before handing anything over.
  /// Checking there would only stop staging and local builds from opening their
  /// own links, which is what the test in deep_link_test.dart pins.
  ///
  /// Here nothing has checked anything — the address was typed by whoever sent
  /// the message. Our path grammar is short and ordinary, so other sites share
  /// it outright: `instagram.com/p/{id}` reads as our photo link and
  /// `flickr.com/photos/{user}` reads as our "my photos" link. Without this,
  /// tapping either one skipped the sheet entirely and pushed a resolver that
  /// went looking for an id belonging to somebody else's site — ending on
  /// "Could not open that link" while the page the reader actually wanted was
  /// never opened.
  ///
  /// Subdomains count as ours so a staging build still opens its own links.
  /// Matched on the dot so `jperg.com.example.net` — a host that merely starts
  /// with ours — is a stranger's, which is the shape this check exists for.
  static bool isOurs(Uri uri) {
    final ours = Uri.parse(AppLinksConfig.shareBaseUrl).host.toLowerCase();
    if (ours.isEmpty) return false;
    final host = uri.host.toLowerCase();
    return host == ours || host.endsWith('.$ours');
  }

  /// A URL, or null for text that only looks like one.
  ///
  /// Bare hosts — "jperg.com/e/123", as people actually type them — are given
  /// https, because a link with no scheme parses as a relative path and opens
  /// nothing at all. Anything that is not http(s) after that is refused: a
  /// `tel:`, `mailto:` or custom scheme in a stranger's message is a different
  /// question from a web page, and this sheet does not ask it.
  static Uri? _parse(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    var uri = Uri.tryParse(trimmed);
    if (uri == null) return null;
    if (!uri.hasScheme) uri = Uri.tryParse('https://$trimmed');
    if (uri == null || uri.host.isEmpty) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;
    return uri;
  }
}

class _SheetButton extends StatelessWidget {
  const _SheetButton({
    required this.label,
    required this.filled,
    required this.ext,
    required this.onTap,
  });

  final String label;
  final bool filled;
  final AppThemeExtension ext;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 48.h,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? ext.accentGold : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.pill.r),
          border: filled
              ? null
              : Border.all(color: ext.searchHintColor.withValues(alpha: 0.4)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: filled ? Colors.white : ext.greetingColor,
            fontSize: 15.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
