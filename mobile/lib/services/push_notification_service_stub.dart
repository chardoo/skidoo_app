/// Web (and analyzer-default) implementation: does nothing.
///
/// onesignal_flutter has no web support, and its Dart entry point imports
/// `dart:io` — so it cannot even be compiled into the web bundle, let alone
/// called. A `kIsWeb` guard at the call site would not have been enough;
/// the import itself is what breaks the build, which is why this goes through
/// a conditional import rather than a runtime check.
library;

Future<void> initPush() async {}

Future<bool> requestPushPermission() async => false;

Future<void> pushLogin(String userId) async {}

Future<void> pushLogout() async {}
