import 'package:flutter/material.dart';

const _kSplashBg = Color(0xFF111110);

/// Branded splash — plays `assets/splash/splash.gif` full-bleed, then hands
/// off to [nextRoute]. Shown on every cold start (mobile only), including
/// for already-logged-in users, who previously skipped straight to Home with
/// no branded moment at all.
class SplashPage extends StatefulWidget {
  static const routeName = '/splash';

  const SplashPage({super.key, required this.nextRoute});

  /// Route to replace this page with once the splash beat is done.
  final String nextRoute;

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  static const _kMinDisplay = Duration(milliseconds: 1800);

  @override
  void initState() {
    super.initState();
    Future.delayed(_kMinDisplay, () {
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(widget.nextRoute);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kSplashBg,
      body: SizedBox.expand(
        child: Image.asset(
          'assets/splash/splash.gif',
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
