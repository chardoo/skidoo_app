import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/purchase/paystack_return.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/theme/app_typography.dart';
import 'package:jperg_app/core/utils/snackbar_utils.dart';
import 'package:jperg_app/features/admin/data/models/exchange_rates.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_icons.dart';

class AdsCheckoutPage extends StatefulWidget {
  const AdsCheckoutPage({
    super.key,
    required this.authorizationUrl,
    required this.onSuccess,
    this.onAbandoned,
    this.reference = '',
    this.amountGhs = 0,
    this.originalAmount = 0,
    this.originalCurrency = '',
  });

  final String authorizationUrl;
  final String reference;

  /// Called when Paystack hands the payer back carrying a reference — somebody
  /// who went through with it.
  final VoidCallback onSuccess;

  /// Called when the checkout ends with no reference: the close page, the back
  /// button, the system gesture.
  ///
  /// Null for the campaign and boost flows, which settle from Paystack's
  /// webhook and have nothing to do here. The photo purchase in
  /// SearchResultsPage passes one, because there the app is what settles the
  /// basket — and a payment that cleared on a page with no redirect left in it
  /// would otherwise be money taken with nothing delivered. It must stay quiet
  /// about refusals: the likeliest reason this fires is somebody changing their
  /// mind.
  final VoidCallback? onAbandoned;

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

  /// This screen has done its job. More than one channel reports the same
  /// return — see [initState] — and without this the payer was settled twice
  /// and `pop` was called twice, the second taking the screen underneath.
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (url) {
          if (mounted) setState(() => _loading = true);
          // A second channel for the return, because `onNavigationRequest`
          // does not fire for a redirect driven from script — which is how
          // Paystack's success page leaves — nor, on iOS, for some server
          // redirects. Missing it left this screen up on a finished payment.
          if (PaystackReturn.isFinished(url)) _finish(url);
        },
        onPageFinished: (_) {
          if (mounted) setState(() => _loading = false);
        },
        onUrlChange: (change) {
          final url = change.url;
          if (url != null && PaystackReturn.isFinished(url)) _finish(url);
        },
        onWebResourceError: (error) {
          if (mounted) {
            AppSnackBar.error(
                context, 'Payment page error: ${error.description}');
          }
        },
        onNavigationRequest: (request) {
          if (PaystackReturn.isFinished(request.url)) {
            _finish(request.url);
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ))
      ..loadRequest(Uri.parse(widget.authorizationUrl));
  }

  /// Report the outcome once and close.
  ///
  /// [url] is null when the payer closed the screen themselves. Either way the
  /// flow ends here; which callback runs depends only on whether a reference
  /// came back with them — see [AdsCheckoutPage.onAbandoned].
  void _finish(String? url) {
    if (_finished || !mounted) return;
    // In state so it also releases [PopScope]: if the pop below ever fails,
    // the next back press is handled natively rather than swallowed.
    setState(() => _finished = true);

    if (url != null && PaystackReturn.carriesReference(url)) {
      widget.onSuccess();
    } else {
      widget.onAbandoned?.call();
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    // In-app WebView payment flow.
    final mobilePage = Scaffold(
      backgroundColor: ext.homeBackground,
      appBar: AppBar(
        backgroundColor: ext.homeBackground,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Close',
          icon:
              AppSvgIcon(AppIcons.closeMd, color: ext.greetingColor, size: 22.sp),
          // Not a bare pop: leaving is not evidence that nothing was paid, and
          // the flows that settle in the app have to be told either way.
          onPressed: () => _finish(null),
        ),
        title: Text(
          'Complete Payment',
          style: TextStyle(
              color: ext.greetingColor,
              fontFamily: AppTypography.displayFontFamily,
              fontSize: 16.sp,
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
    return PopScope(
      // False until settled, so the first back press reports the outcome. True
      // afterwards — see [_finish].
      canPop: _finished,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _finish(null);
      },
      child: mobilePage,
    );
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
