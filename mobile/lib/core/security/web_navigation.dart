import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// What a WebView inside this app is allowed to load.
///
/// Three screens embed a WebView — the two payment checkouts and the legal
/// pages — and all three run JavaScript unrestricted, which they have to: a
/// Paystack checkout is an application, not a document.
///
/// What they did not have was any rule about *where* they may go. The
/// navigation delegate returned "navigate" for everything that was not the
/// payment return URL, so any redirect inside the checkout could take the
/// WebView to any address, with scripting on, inside the app's own chrome with
/// no URL bar — in the one context where being asked for card details is
/// exactly what the payer expects. That is the shape of every in-app-browser
/// phishing finding, and the fix is not to trust the first URL to stay put.
///
/// The rule, in one place rather than once per screen:
///
///   * **https renders.** Payment pages, bank 3-D Secure pages, our own
///     content — all https, which is why this does not break them. A card
///     payment redirected to the issuing bank's own domain is normal and
///     still works; the host is shown rather than blocked.
///   * **`about:blank` renders**, because WebViews navigate there themselves
///     between documents and refusing it breaks the view rather than
///     protecting it.
///   * **http is refused.** The platforms already forbid cleartext — Android
///     `usesCleartextTraffic="false"`, iOS ATS — so this only turns an opaque
///     load failure into a line that says why.
///   * **anything else is never rendered here.** Some of it is a legitimate
///     handoff: a bank or mobile-money app answering a scheme of its own, the
///     store, the dialer for a USSD string. Those are handed to the operating
///     system, which is where they belong and where the user can see what is
///     being opened. The rest — `file:`, `data:`, `javascript:`, `blob:`,
///     `content:` — are the primitives an injected page would use to read
///     local files or run script in our origin, and they are dropped.
///
/// `jperg:` is dropped too. It is our own deep-link scheme, and a web page
/// that can steer the app's router from inside a WebView is a page that can
/// navigate somebody somewhere they did not ask to go.
enum WebNavigation {
  /// Load it in the WebView.
  render,

  /// Not a web page. Hand it to the OS and keep the WebView where it is.
  handOff,

  /// Drop it.
  refuse,
}

/// Schemes that must never leave this app, by handoff or otherwise.
///
/// A denylist rather than an allowlist, deliberately and only here: the set of
/// schemes a bank, a wallet or a mobile-money app might answer is open-ended
/// and differs per country, so enumerating what is *allowed* would mean
/// breaking a payment method in a market nobody tested. What has to be
/// enumerated instead is what is dangerous, and that list is short, known, and
/// does not grow with the number of banks.
const Set<String> _neverHandOff = {
  'file', 'data', 'javascript', 'blob', 'content', 'about', 'filesystem',
  'jperg', // our own router — see the class note
};

/// What to do with a navigation to [url] from inside a WebView.
///
/// Pure, so it can be tested without a platform WebView — which is the only
/// way a rule about schemes gets exercised at all.
WebNavigation decideWebNavigation(String url) {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return WebNavigation.refuse;

  // `about:blank` only, never `about:` anything else.
  if (trimmed == 'about:blank') return WebNavigation.render;

  final uri = Uri.tryParse(trimmed);
  if (uri == null || !uri.hasScheme) return WebNavigation.refuse;

  final scheme = uri.scheme.toLowerCase();
  if (scheme == 'https') return WebNavigation.render;
  if (scheme == 'http') return WebNavigation.refuse;
  if (_neverHandOff.contains(scheme)) return WebNavigation.refuse;
  return WebNavigation.handOff;
}

/// Act on [decideWebNavigation], and say in the log what was done.
///
/// [where] names the screen, so a refused navigation can be told apart from a
/// failed one when somebody reports "the payment page went blank".
Future<void> handOffWebNavigation(String url, {required String where}) async {
  final uri = Uri.tryParse(url.trim());
  if (uri == null) return;
  debugPrint('[WebView:$where] handing ${uri.scheme}: to the system');
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (e) {
    debugPrint('[WebView:$where] the system would not open ${uri.scheme}: $e');
  }
}

/// The host a payer is actually looking at, for the title bar.
///
/// A checkout that may legitimately redirect to a bank needs to say where it
/// has got to, since the WebView has no address bar of its own. `www.` is
/// dropped because it is noise in a space this small.
String? webViewHost(String? url) {
  final host = Uri.tryParse(url ?? '')?.host;
  if (host == null || host.isEmpty) return null;
  return host.startsWith('www.') ? host.substring(4) : host;
}
