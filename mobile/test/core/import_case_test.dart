import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Two spellings of one path are two libraries, and two libraries are two types.
///
/// `lib/api/dio_client_service.dart` was imported as `package:jperg_app/api/…`
/// by the service locator and 33 other files, and as `package:jperg_app/API/…`
/// by the notifications service and the push service. macOS and Windows have
/// case-insensitive filesystems, so both resolved and both compiled — into two
/// distinct `Api` classes. `sl.registerSingleton<Api>` filled the first,
/// `sl<Api>()` in those two files asked for the second, and every call in them
/// threw "Object/factory with type Api is not registered inside GetIt": the
/// notifications list, the unread badge, notification preferences, and device
/// register/unregister for push.
///
/// Nothing about that failure points at the import, which is why it is worth a
/// test rather than a fix.
void main() {
  test('no file is imported under two spellings of its path', () {
    final uris = <String>{};
    final pattern = RegExp(r'''package:jperg_app/[A-Za-z0-9_/.]*\.dart''');

    for (final dir in ['lib', 'test']) {
      for (final entity in Directory(dir).listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        uris.addAll(
          pattern.allMatches(entity.readAsStringSync()).map((m) => m[0]!),
        );
      }
    }

    final byLowercase = <String, Set<String>>{};
    for (final uri in uris) {
      byLowercase.putIfAbsent(uri.toLowerCase(), () => <String>{}).add(uri);
    }

    final clashes = byLowercase.values.where((s) => s.length > 1).toList();
    expect(clashes, isEmpty,
        reason: 'these differ only by case, so each spelling compiles to its '
            'own copy of every type in the file');
  });
}
