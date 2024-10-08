import 'package:flutter/material.dart';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:skidoo_app/controller/cart_controller.dart';
// import 'package:skiddoapp/controller/cart_controller.dart';
// import 'package:photoapp_mobile/contollers/cart_controller.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

class CheckoutComponent extends StatefulWidget {
  String url;
  CheckoutComponent({super.key, required this.url});
  @override
  State<CheckoutComponent> createState() => _checkoutComponent();
}

class _checkoutComponent extends State<CheckoutComponent> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }
    CartController cartController = Get.find();
    WebViewController controller =
        WebViewController.fromPlatformCreationParams(params);
    // #enddocregion platform_features

    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            // Update loading bar.
          },
          onPageStarted: (String url) {},
          onPageFinished: (String url) {
            print("fjjdfjfjdfjfjjdf");
          },
          onWebResourceError: (WebResourceError error) {
            print("we resource");
          },
          onNavigationRequest: (NavigationRequest request) async {
      
            if (request.url.contains('https://example.com/richCode/')) {
              await cartController.completePayment("");
              return NavigationDecision.prevent;
            }
            await cartController.completePayment("");
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
    _controller = controller;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pay for your images')),
      body: WebViewWidget(
        controller: _controller,
      ),
    );
  }
}
