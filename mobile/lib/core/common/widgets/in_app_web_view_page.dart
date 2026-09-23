import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/theme/app_typography.dart';
import 'package:jperg_app/core/utils/snackbar_utils.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:jperg_app/core/theme/app_icons.dart';

/// A lightweight in-app browser used to show remote, always-up-to-date content
/// (privacy policy, terms, etc.) without bundling it in the app.
///
/// * Mobile (iOS/Android): renders the page inside an in-app [WebViewWidget].
/// * Web: `webview_flutter` has no web implementation, so the URL is opened in
///   a new browser tab and a small fallback screen is shown.
///
/// Open it with [InAppWebViewPage.open] from anywhere:
/// ```dart
/// InAppWebViewPage.open(context,
///     url: 'https://example.com/privacy', title: 'Privacy Policy');
/// ```
class InAppWebViewPage extends StatefulWidget {
  const InAppWebViewPage({
    super.key,
    required this.url,
    required this.title,
  });

  final String url;
  final String title;

  /// Pushes the page (mobile) or opens the URL in a new tab (web).
  static Future<void> open(
    BuildContext context, {
    required String url,
    required String title,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InAppWebViewPage(url: url, title: title),
      ),
    );
  }

  @override
  State<InAppWebViewPage> createState() => _InAppWebViewPageState();
}

class _InAppWebViewPageState extends State<InAppWebViewPage> {
  WebViewController? _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) {
          if (mounted) setState(() => _loading = true);
        },
        onPageFinished: (_) {
          if (mounted) setState(() => _loading = false);
        },
        onWebResourceError: (error) {
          if (mounted) {
            setState(() => _loading = false);
            AppSnackBar.error(
                context, 'Could not load page: ${error.description}');
          }
        },
      ))
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    final appBar = AppBar(
      backgroundColor: ext.homeBackground,
      elevation: 0,
      leading: IconButton(
        tooltip: 'Close',
        icon: AppSvgIcon(AppIcons.closeMd, color: ext.greetingColor, size: 22.sp),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      title: Text(
        widget.title,
        style: TextStyle(
            color: ext.greetingColor,
            fontFamily: AppTypography.displayFontFamily,
            fontSize: 17.sp,
            fontWeight: FontWeight.w700),
      ),
      centerTitle: false,
    );

    // ── Web: the content opened in a browser tab ──────────────────────────────

    // ── Mobile: in-app WebView ────────────────────────────────────────────────
    return Scaffold(
      backgroundColor: ext.homeBackground,
      appBar: appBar,
      body: Stack(
        children: [
          WebViewWidget(controller: _controller!),
          if (_loading)
            Center(child: CircularProgressIndicator(color: ext.accentGold)),
        ],
      ),
    );
  }
}
