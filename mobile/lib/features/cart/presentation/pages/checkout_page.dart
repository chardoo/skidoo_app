import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/common/widgets/app_button.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/utils/snackbar_utils.dart';
import 'package:jperg_app/features/cart/presentation/bloc/cart_bloc.dart';
import 'package:jperg_app/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:jperg_app/core/utils/web_wrap.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/common/widgets/app_back_button.dart';

class CheckoutPage extends StatefulWidget {
  final String url;
  const CheckoutPage({super.key, required this.url});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  WebViewController? _controller;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _launchUrl());
      return;
    }
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(NavigationDelegate(
        onWebResourceError: (error) {
          if (mounted) {
            AppSnackBar.error(context, AppLocalizations.of(context)!.checkoutWebError(error.description));
          }
        },
        onNavigationRequest: (request) {
          if (request.url.contains('https://example.com/richCode/') ||
              request.url.contains('/payment/success')) {
            if (mounted) {
              context.read<CartBloc>().add(const CartPaymentCompleted());
              Navigator.of(context).pop();
            }
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ))
      ..loadRequest(Uri.parse(widget.url));
  }

  Future<void> _launchUrl() async {
    await launchUrl(Uri.parse(widget.url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      final ext = Theme.of(context).extension<AppThemeExtension>()!;
      final page = Scaffold(
        backgroundColor: ext.homeBackground,
        appBar: AppBar(
          backgroundColor: ext.homeBackground,
          elevation: 0,
          title: Text(AppLocalizations.of(context)!.checkoutTitle,
              style: TextStyle(color: ext.greetingColor, fontSize: 17.sp, fontWeight: FontWeight.w700)),
          leading: kIsWeb
              ? null
              : AppBackButton(onPressed: () => Navigator.of(context).pop()),
        ),
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 28.w),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.open_in_new_rounded, size: 52.sp, color: ext.accentGold),
                SizedBox(height: AppSpacing.xl.h),
                Text(
                  'Payment opened in a new tab',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: ext.greetingColor, fontSize: 18.sp, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 10.h),
                Text(
                  'Complete your payment in the browser tab that just opened, then tap the button below.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: ext.searchHintColor, fontSize: 14.sp, height: 1.5),
                ),
                SizedBox(height: AppSpacing.xxxl.h),
                AppButton(
                  fullWidth: true,
                  label: 'Payment complete',
                  onPressed: () {
                    context.read<CartBloc>().add(const CartPaymentCompleted());
                    Navigator.of(context).pop();
                  },
                ),
                SizedBox(height: AppSpacing.md.h),
                TextButton(
                  onPressed: _launchUrl,
                  child: Text('Reopen payment page',
                      style: TextStyle(color: ext.searchHintColor, fontSize: 13.sp)),
                ),
              ],
            ),
          ),
        ),
      );
      return webWrap(page, backgroundColor: ext.homeBackground);
    }

    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final page = Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.checkoutTitle),
        leading: kIsWeb
            ? null
            : AppBackButton(onPressed: () => Navigator.of(context).pop()),
      ),
      body: WebViewWidget(controller: _controller!),
    );
    return webWrap(page, backgroundColor: ext.homeBackground);
  }

}
