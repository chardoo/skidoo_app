import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/security/web_navigation.dart';

/// Where an in-app WebView may go.
///
/// Two of the three WebViews in this app are payment screens with no address
/// bar and JavaScript enabled, so "which URLs render in there" is the whole of
/// an in-app phishing surface. These tests are the rule.
void main() {
  group('renders', () {
    test('https — the payment page itself', () {
      expect(decideWebNavigation('https://checkout.paystack.com/abc123'),
          WebNavigation.render);
    });

    test('https on a bank we have never heard of', () {
      // 3-D Secure sends the payer to the *issuer*, not to Paystack. A host
      // allowlist would have declined this and broken card payments, which is
      // why the rule is about the scheme and the host is shown instead.
      expect(decideWebNavigation('https://acs.some-bank.com.gh/3ds/challenge'),
          WebNavigation.render);
    });

    test('about:blank, which a WebView navigates to by itself', () {
      expect(decideWebNavigation('about:blank'), WebNavigation.render);
    });
  });

  group('handed to the operating system', () {
    test('a wallet or banking app answering its own scheme', () {
      for (final url in [
        'mtnmomo://pay?token=abc',
        'bankapp://authorise/9f2',
        'intent://pay#Intent;scheme=upi;end',
        'tel:*170%23',
        'itms-apps://apps.apple.com/app/id123',
      ]) {
        expect(decideWebNavigation(url), WebNavigation.handOff,
            reason: '$url should leave the app, not render inside it');
      }
    });
  });

  group('refused outright', () {
    test('the local-content schemes an injected page would reach for', () {
      for (final url in [
        'file:///etc/passwd',
        'file:///data/data/com.example.jperg/shared_prefs/x.xml',
        'data:text/html;base64,PHNjcmlwdD5hbGVydCgxKTwvc2NyaXB0Pg==',
        'javascript:alert(document.cookie)',
        'blob:https://evil.example/abc',
        'content://com.android.providers.media/external',
        'filesystem:https://evil.example/temporary/x',
      ]) {
        expect(decideWebNavigation(url), WebNavigation.refuse,
            reason: '$url must never be rendered or handed on');
      }
    });

    test('about: anything other than blank', () {
      expect(decideWebNavigation('about:srcdoc'), WebNavigation.refuse);
      expect(decideWebNavigation('about:config'), WebNavigation.refuse);
    });

    test('our own deep-link scheme — a page must not drive the router', () {
      expect(decideWebNavigation('jperg://request/abc'), WebNavigation.refuse);
    });

    test('cleartext http, which the platforms forbid anyway', () {
      expect(decideWebNavigation('http://checkout.paystack.com/abc'),
          WebNavigation.refuse);
    });

    test('nothing, and nonsense', () {
      expect(decideWebNavigation(''), WebNavigation.refuse);
      expect(decideWebNavigation('   '), WebNavigation.refuse);
      expect(decideWebNavigation('not a url at all'), WebNavigation.refuse);
    });

    test('case and whitespace do not get a scheme past the rule', () {
      expect(decideWebNavigation('JavaScript:alert(1)'), WebNavigation.refuse);
      expect(decideWebNavigation('  FILE:///etc/hosts  '), WebNavigation.refuse);
      expect(decideWebNavigation('  HTTPS://paystack.com/x  '),
          WebNavigation.render);
    });
  });

  group('the host shown to the payer', () {
    test('is the host, without the www', () {
      expect(webViewHost('https://www.paystack.com/pay/x'), 'paystack.com');
      expect(webViewHost('https://checkout.paystack.com/x'),
          'checkout.paystack.com');
    });

    test('is null when there is nothing to show', () {
      expect(webViewHost(null), isNull);
      expect(webViewHost('about:blank'), isNull);
      expect(webViewHost(''), isNull);
    });
  });
}
