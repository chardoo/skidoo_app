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
    test('is production', () {
      expect(ApiConfig.host, 'https://api.piccotechnologies.com');
    });

    test('carries no path and no trailing slash', () {
      // Everything below appends to it. A trailing slash makes `//api`, and a
      // path makes `/api/api`.
      expect(ApiConfig.host, isNot(endsWith('/')));
      expect(Uri.parse(ApiConfig.host).path, isEmpty);
    });

    test('is https, so the socket can be wss', () {
      expect(ApiConfig.host, startsWith('https://'));
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
