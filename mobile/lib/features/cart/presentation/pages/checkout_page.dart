import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:jperg_app/core/utils/snackbar_utils.dart';
import 'package:jperg_app/features/cart/presentation/bloc/cart_bloc.dart';
import 'package:jperg_app/l10n/app_localizations.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:jperg_app/core/common/widgets/app_back_button.dart';

class CheckoutPage extends StatefulWidget {
  final String url;
  const CheckoutPage({super.key, required this.url});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  WebViewController? _controller;

  /// Paystack is done with this person and is sending them back.
  ///
  /// `trxref` is on every post-payment redirect whatever the callback URL is,
  /// which is the part worth matching: the URL itself is account-wide config
  /// shared with the ads service, and when it pointed at a POST-only webhook
  /// this WebView loaded the 405 and showed `{"detail":"Method Not Allowed"}`
  /// as the last thing anyone saw of their purchase. The older two patterns
  /// stay — a callback URL still set to one of them keeps working.
  static bool _isReturn(String url) =>
      url.contains('trxref=') ||
      url.contains('https://example.com/richCode/') ||
      url.contains('/payment/success');

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(NavigationDelegate(
        onWebResourceError: (error) {
          if (mounted) {
            AppSnackBar.error(
                context,
                AppLocalizations.of(context)!
                    .checkoutWebError(error.description));
          }
        },
        onNavigationRequest: (request) {
          if (_isReturn(request.url)) {
            if (mounted) {
              context.read<CartBloc>().add(const CartPaymentCompleted());
              Navigator.of(context).pop();
            }
            // Prevented rather than followed: whatever is at the callback URL,
            // the purchase is finished and the app has somewhere better to be.
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ))
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    final page = Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.checkoutTitle),
        leading: const AppBackButton(),
      ),
      body: WebViewWidget(controller: _controller!),
    );
    return page;
  }
}
