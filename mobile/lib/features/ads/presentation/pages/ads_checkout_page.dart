import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/common/widgets/app_button.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/utils/snackbar_utils.dart';
import 'package:jperg_app/features/admin/data/models/exchange_rates.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:jperg_app/core/utils/web_wrap.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';

class AdsCheckoutPage extends StatefulWidget {
  const AdsCheckoutPage({
    super.key,
    required this.authorizationUrl,
    required this.onSuccess,
    this.reference = '',
    this.amountGhs = 0,
    this.originalAmount = 0,
    this.originalCurrency = '',
  });

  final String authorizationUrl;
  final String reference;

  /// Called when Paystack redirects back indicating a successful payment.
  final VoidCallback onSuccess;

  /// Exact GHS amount returned by the server's pay endpoint.
  final double amountGhs;

  /// Original amount in the advertiser's chosen currency.
  final double originalAmount;

  /// ISO-4217 currency code of the original amount (e.g. "USD").
  final String originalCurrency;

  @override
  State<AdsCheckoutPage> createState() => _AdsCheckoutPageState();
}

class _AdsCheckoutPageState extends State<AdsCheckoutPage> {
  WebViewController? _controller;
  bool _loading = true;

  static bool _isSuccess(String url) => url.contains('trxref=');
  static bool _isClose(String url) =>
      url.contains('standard.paystack.co/close') ||
      url.contains('paystack.co/close');

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      // Launch payment URL in a new browser tab immediately.
      WidgetsBinding.instance.addPostFrameCallback((_) => _launchWebPayment());
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
            AppSnackBar.error(
                context, 'Payment page error: ${error.description}');
          }
        },
        onNavigationRequest: (request) {
          final url = request.url;
          if (_isClose(url)) {
            if (mounted) Navigator.of(context).pop();
            return NavigationDecision.prevent;
          }
          if (_isSuccess(url)) {
            widget.onSuccess();
            if (mounted) Navigator.of(context).pop();
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ))
      ..loadRequest(Uri.parse(widget.authorizationUrl));
  }

  Future<void> _launchWebPayment() async {
    await launchUrl(
      Uri.parse(widget.authorizationUrl),
      mode: LaunchMode.externalApplication,
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    // ── Web: browser-tab payment flow ─────────────────────────────────────────
    if (kIsWeb) {
      final page = Scaffold(
        backgroundColor: ext.homeBackground,
        appBar: AppBar(
          backgroundColor: ext.homeBackground,
          elevation: 0,
          leading: kIsWeb
              ? null
              : IconButton(
                  tooltip: 'Close',
                  icon: Icon(Icons.close_rounded,
                      color: ext.greetingColor, size: 22.sp),
                  onPressed: () => Navigator.of(context).pop(),
                ),
          title: Text(
            'Complete Payment',
            style: TextStyle(
                color: ext.greetingColor,
                fontSize: 17.sp,
                fontWeight: FontWeight.w700),
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 28.w),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.open_in_new_rounded,
                    size: 52.sp, color: ext.accentGold),
                SizedBox(height: AppSpacing.xl.h),
                Text(
                  'Payment opened in a new tab',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: ext.greetingColor,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 10.h),
                Text(
                  'Complete your payment in the browser tab that just opened, then tap the button below.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: ext.searchHintColor, fontSize: 14.sp, height: 1.5),
                ),
                SizedBox(height: AppSpacing.xxxl.h),
                AppButton(
                  fullWidth: true,
                  label: 'Payment complete',
                  onPressed: () {
                    widget.onSuccess();
                    Navigator.of(context).pop();
                  },
                ),
                SizedBox(height: AppSpacing.md.h),
                TextButton(
                  onPressed: _launchWebPayment,
                  child: Text(
                    'Reopen payment page',
                    style:
                        TextStyle(color: ext.searchHintColor, fontSize: 13.sp),
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
    final mobilePage = Scaffold(
      backgroundColor: ext.homeBackground,
      appBar: AppBar(
        backgroundColor: ext.homeBackground,
        elevation: 0,
        leading: kIsWeb
            ? null
            : IconButton(
                tooltip: 'Close',
                icon: Icon(Icons.close_rounded,
                    color: ext.greetingColor, size: 22.sp),
                onPressed: () => Navigator.of(context).pop(),
              ),
        title: Text(
          'Complete Payment',
          style: TextStyle(
              color: ext.greetingColor,
              fontSize: 17.sp,
              fontWeight: FontWeight.w700),
        ),
        centerTitle: false,
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller!),
          if (_loading)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: ext.accentGold),
                  if (widget.amountGhs > 0) ...[
                    SizedBox(height: AppSpacing.xl.h),
                    _PaymentInfoCard(
                      amountGhs: widget.amountGhs,
                      originalAmount: widget.originalAmount,
                      originalCurrency: widget.originalCurrency,
                      ext: ext,
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
    return webWrap(mobilePage, backgroundColor: ext.homeBackground);
  }
}

// ── Payment amount info card shown while WebView loads ────────────────────────

class _PaymentInfoCard extends StatelessWidget {
  const _PaymentInfoCard({
    required this.amountGhs,
    required this.originalAmount,
    required this.originalCurrency,
    required this.ext,
  });

  final double amountGhs;
  final double originalAmount;
  final String originalCurrency;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    final ghsFormatted = ExchangeRates.formatGhs(amountGhs);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.xxxl.w),
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.xl.w, vertical: AppSpacing.lg.h),
        decoration: BoxDecoration(
          color: ext.cardSurface,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
            color: ext.accentGold.withValues(alpha: 0.3),
            width: 0.8,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (originalCurrency.isNotEmpty &&
                originalCurrency != 'GHS' &&
                originalAmount > 0)
              Text(
                '${originalAmount.toStringAsFixed(2)} $originalCurrency'
                ' ≈ $ghsFormatted',
                style: TextStyle(
                  color: ext.greetingColor,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              )
            else
              Text(
                ghsFormatted,
                style: TextStyle(
                  color: ext.greetingColor,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
            SizedBox(height: 6.h),
            Text(
              'You will be charged in GHS via Paystack',
              style: TextStyle(
                color: ext.searchHintColor,
                fontSize: 12.sp,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
