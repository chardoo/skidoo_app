/// Where the app's requests go, and that they all go to the same place.
///
/// The host was written out three times — the Dio client, the chat REST
/// client and the chat socket — all pointing at
/// `photoapp-backend-ka5m.onrender.com`, which is the deployment the app was
/// built against and not the one its users are meant to reach. Three copies of
/// a value that must agree is three chances for them not to, and a build that
/// moved two of them would talk to two different backends without failing.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/config/api_config.dart';
import 'package:jperg_app/core/config/chat_config.dart';

void main() {
  group('the host', () {
    test('is production unless a build says otherwise', () {
      // The default, and the one that matters: a release built with
      // `--dart-define=USE_TEST_API` forgotten must point at production. The
      // other way round ships a store build talking to a test backend with
      // nothing in the running app to say so.
      //
      // `flutter test` passes no defines, so this is the unflagged build.
      expect(ApiConfig.useTestApi, isFalse);
      expect(ApiConfig.host, ApiConfig.production);
      expect(ApiConfig.environmentName, 'production');
    });

    test('is always one of the two deployments', () {
      expect(ApiConfig.host, anyOf(ApiConfig.production, ApiConfig.test));
    });

    test('the two deployments are different places', () {
      // A copy-paste that left both pointing at production would make the
      // switch silently do nothing, which is worse than it not existing.
      expect(ApiConfig.test, isNot(ApiConfig.production));
    });

    test('carries no path and no trailing slash', () {
      // Everything below appends to it. A trailing slash makes `//api`, and a
      // path makes `/api/api`. Asserted for both, since either can be built.
      for (final h in [ApiConfig.production, ApiConfig.test]) {
        expect(h, isNot(endsWith('/')), reason: h);
        expect(Uri.parse(h).path, isEmpty, reason: h);
      }
    });

    test('is https, so the socket can be wss', () {
      for (final h in [ApiConfig.production, ApiConfig.test]) {
        expect(h, startsWith('https://'), reason: h);
      }
    });
  });

  group('what is derived from it', () {
    test("main's routes sit under /api", () {
      expect(ApiConfig.apiBaseUrl, '${ApiConfig.host}/api');
    });

    test('the socket scheme follows the host, rather than being written again', () {
      // An https host whose socket was left as `ws` fails the upgrade, and the
      // two being separate strings is exactly how that happens.
      expect(ApiConfig.wsHost, 'wss://api.piccotechnologies.com');
      expect(ApiConfig.wsHost, isNot(contains('https')));
    });

    test('chat is the same gateway, not a host of its own', () {
      // `/chat` and `/chat/ws` are proxied to the chat service by the gateway.
      expect(ChatConfig.restBaseUrl, ApiConfig.host);
      expect(ChatConfig.wsBaseUrl, ApiConfig.host);
    });
  });

  group('nothing still points at a build server', () {
    final dartFiles = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));

    test('no backend URL is hardcoded outside ApiConfig', () {
      final offenders = <String>[];
      for (final file in dartFiles) {
        if (file.path.endsWith('core/config/api_config.dart')) continue;
        final code = file
            .readAsLinesSync()
            .where((l) => !l.trimLeft().startsWith('//'))
            .join('\n');
        // The portal lives on its own host and is a separate decision — see
        // AppLinksConfig, whose comment records why it points where it does.
        if (file.path.endsWith('core/config/app_links_config.dart')) continue;
        if (code.contains('onrender.com')) offenders.add(file.path);
      }
      expect(offenders, isEmpty,
          reason: 'these would talk to a different backend than the rest');
    });

    test('the Dio clients take the base from ApiConfig', () {
      for (final path in [
        'lib/API/dio_client_service.dart',
        'lib/API/DioClietService.dart',
      ]) {
        final source = File(path).readAsStringSync();
        expect(source, contains('ApiConfig.apiBaseUrl'), reason: path);
      }
    });
  });
}
