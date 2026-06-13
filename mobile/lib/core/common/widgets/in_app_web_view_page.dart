import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/core/utils/snackbar_utils.dart';
import 'package:skidoo_app/core/utils/web_wrap.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

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
    if (kIsWeb) {
      // No in-app WebView on web — open in a new browser tab instead.
      WidgetsBinding.instance.addPostFrameCallback((_) => _launchExternally());
      return;
    }
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

  Future<void> _launchExternally() async {
    final ok = await launchUrl(
      Uri.parse(widget.url),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && mounted) {
      AppSnackBar.error(context, 'Could not open ${widget.url}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    final appBar = AppBar(
      backgroundColor: ext.homeBackground,
      elevation: 0,
      leading: IconButton(
        tooltip: 'Close',
        icon: Icon(Icons.close_rounded, color: ext.greetingColor, size: 22.sp),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      title: Text(
        widget.title,
        style: TextStyle(
            color: ext.greetingColor, fontSize: 17.sp, fontWeight: FontWeight.w700),
      ),
      centerTitle: false,
    );

    // ── Web: the content opened in a browser tab ──────────────────────────────
    if (kIsWeb) {
      final page = Scaffold(
        backgroundColor: ext.homeBackground,
        appBar: appBar,
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 28.w),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.open_in_new_rounded,
                    size: 52.sp, color: ext.accentGold),
                SizedBox(height: 20.h),
                Text(
                  '${widget.title} opened in a new tab',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: ext.greetingColor,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 10.h),
                Text(
                  'If it didn\'t open, tap the button below.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: ext.searchHintColor, fontSize: 14.sp, height: 1.5),
                ),
                SizedBox(height: 28.h),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ext.accentGold,
                      foregroundColor: Colors.black,
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r)),
                    ),
                    onPressed: _launchExternally,
                    child: Text('Open ${widget.title}',
                        style: TextStyle(
                            fontSize: 15.sp, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      return webWrap(page, backgroundColor: ext.homeBackground);
    }

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
