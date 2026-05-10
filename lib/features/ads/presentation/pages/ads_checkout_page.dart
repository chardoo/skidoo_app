import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/core/utils/snackbar_utils.dart';
import 'package:webview_flutter/webview_flutter.dart';

class AdsCheckoutPage extends StatefulWidget {
  const AdsCheckoutPage({
    super.key,
    required this.authorizationUrl,
    required this.onSuccess,
  });

  final String authorizationUrl;
  /// Called when Paystack redirects back indicating a successful payment.
  final VoidCallback onSuccess;

  @override
  State<AdsCheckoutPage> createState() => _AdsCheckoutPageState();
}

class _AdsCheckoutPageState extends State<AdsCheckoutPage> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    debugPrint('[AdsCheckoutPage] initState — loading URL: ${widget.authorizationUrl}');
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            debugPrint('[AdsCheckoutPage] onPageStarted: $url');
            if (mounted) setState(() => _loading = true);
          },
          onPageFinished: (url) {
            debugPrint('[AdsCheckoutPage] onPageFinished: $url');
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (error) {
            debugPrint('[AdsCheckoutPage] onWebResourceError: ${error.errorCode} ${error.description}');
            if (mounted) {
              AppSnackBar.error(context,
                  'Payment page error: ${error.description}');
            }
          },
          onNavigationRequest: (request) {
            debugPrint('[AdsCheckoutPage] onNavigationRequest: ${request.url}');
            if (request.url.contains('/payment/success') ||
                request.url.contains('payment_complete') ||
                request.url.contains('trxref=')) {
              debugPrint('[AdsCheckoutPage] payment success detected — url=${request.url}');
              widget.onSuccess();
              if (mounted) Navigator.of(context).pop();
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.authorizationUrl));
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return Scaffold(
      backgroundColor: ext.homeBackground,
      appBar: AppBar(
        backgroundColor: ext.homeBackground,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close_rounded,
              color: ext.greetingColor, size: 22.sp),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Complete Payment',
          style: TextStyle(
            color: ext.greetingColor,
            fontSize: 17.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: false,
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
