import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:jperg_app/core/purchase/paystack_return.dart';
import 'package:jperg_app/core/utils/snackbar_utils.dart';
import 'package:jperg_app/features/cart/presentation/bloc/cart_bloc.dart';
import 'package:jperg_app/l10n/app_localizations.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:jperg_app/core/common/widgets/app_back_button.dart';
import 'package:jperg_app/core/security/web_navigation.dart';

/// Paystack's own pages, in a WebView, for one photo purchase.
///
/// The screen's whole job is to notice when Paystack is done and get out of the
/// way — see [PaystackReturn] for how "done" is read, and
/// [_finish] for why leaving is never silent.
class CheckoutPage extends StatefulWidget {
  final String url;
  const CheckoutPage({super.key, required this.url});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  WebViewController? _controller;

  /// The host the buyer is on, shown under the title.
  ///
  /// This view has no address bar, and a card payment legitimately moves to
  /// the issuing bank's domain partway through 3-D Secure. Naming the host is
  /// what tells those two cases apart for the person being asked for card
  /// details. See [webViewHost].
  String? _host;

  /// Set the moment this screen has done its one job, so it is done once.
  ///
  /// Three channels report the return now (see [initState]) and more than one
  /// fires for the same redirect. Without this the cart was asked to settle
  /// twice and `Navigator.pop` was called twice — the second one taking the
  /// screen *underneath* the checkout with it.
  bool _finished = false;

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
        // Watched on three channels, because a Paystack redirect does not
        // reliably arrive on any one of them.
        //
        // `onNavigationRequest` sees a navigation the WebView is about to
        // perform, and that is what this screen used to rely on alone. It does
        // not fire for a redirect driven from script — `window.location.replace`
        // on the success page, which is how the standard checkout leaves — and
        // on iOS it is skipped for some server redirects as well. So the
        // payment went through, the page changed, and nothing here noticed:
        // the WebView sat on Paystack's success screen until the buyer pressed
        // back, and pressing back told the cart nothing at all.
        //
        // `onUrlChange` catches the script-driven ones and `onPageStarted` the
        // rest. [_finished] makes the duplicates harmless.
        onNavigationRequest: (request) {
          if (PaystackReturn.isFinished(request.url)) {
            _finish(request.url);
            // Prevented rather than followed: whatever is at the callback URL,
            // the purchase is over and the app has somewhere better to be.
            return NavigationDecision.prevent;
          }
          // The same rule the boost checkout applies, from the same place:
          // https renders — including a bank's 3-D Secure page — a bank or
          // wallet scheme goes to the system, and nothing else is rendered on
          // a screen that has no address bar. See [decideWebNavigation].
          switch (decideWebNavigation(request.url)) {
            case WebNavigation.render:
              return NavigationDecision.navigate;
            case WebNavigation.handOff:
              handOffWebNavigation(request.url, where: 'cart-checkout');
              return NavigationDecision.prevent;
            case WebNavigation.refuse:
              debugPrint('[WebView:cart-checkout] refused ${request.url}');
              return NavigationDecision.prevent;
          }
        },
        onUrlChange: (change) {
          final url = change.url;
          if (url != null && PaystackReturn.isFinished(url)) _finish(url);
        },
        onPageStarted: (url) {
          final host = webViewHost(url);
          if (mounted && host != null && host != _host) {
            setState(() => _host = host);
          }
          if (PaystackReturn.isFinished(url)) _finish(url);
        },
      ))
      ..loadRequest(Uri.parse(widget.url));
  }

  /// Hand the outcome to the cart and close.
  ///
  /// [url] is null when the buyer closed the screen themselves rather than
  /// Paystack sending them back, and that difference decides one thing only:
  /// whether a failed settlement is worth saying out loud. The settlement is
  /// attempted either way, and that is the point — `complete-images` verifies
  /// the reference with Paystack before it settles, and is idempotent, so
  /// asking it about a payment that never happened costs nothing while *not*
  /// asking it about one that did loses somebody their photos. Closing the
  /// screen by hand used to do exactly that: money taken, nothing delivered,
  /// no record on the device that anything was owed.
  void _finish(String? url) {
    if (_finished || !mounted) return;
    // Recorded in state, not just a field: it also releases [PopScope], so if
    // the pop below ever fails to happen the next back press is handled by the
    // system instead of being swallowed. A payment screen that cannot be left
    // is a worse bug than the one this method exists to fix.
    setState(() => _finished = true);

    // A bare close page is usually somebody who changed their mind, so a
    // refusal there is expected and stays quiet. A redirect carrying a
    // reference is somebody who went through with it, and a refusal there is
    // worth reporting.
    final quiet = url == null || !PaystackReturn.carriesReference(url);
    context.read<CartBloc>().add(CartPaymentCompleted(quiet: quiet));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    // Back, and the system gesture, go through [_finish] as well — the buyer
    // leaving is not evidence that they did not pay, and on this deployment
    // Paystack's last page is often one with no redirect left in it.
    return PopScope(
      // False until this screen has settled, so the first back press runs
      // [_finish] rather than dropping the buyer out with the cart none the
      // wiser. True afterwards — see the note in [_finish].
      canPop: _finished,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _finish(null);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(AppLocalizations.of(context)!.checkoutTitle),
              if (_host != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_outline, size: 11),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        _host!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          leading: AppBackButton(onPressed: () => _finish(null)),
        ),
        body: WebViewWidget(controller: _controller!),
      ),
    );
  }
}
