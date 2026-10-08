/// Taking a selfie asks for the camera, and for nothing else.
///
/// `CameraController` has `enableAudio: true` by default, so initialising it
/// requests the **microphone** as well. On a screen called "Take a Selfie"
/// that is an unanswerable question — and declining it, which is the sensible
/// answer, failed the whole `initialize()`: camera granted, mic refused, and
/// the preview never arrived. The screen then span forever, because its only
/// non-preview state is a progress indicator.
///
/// Asserted against the source rather than by driving the camera: there is no
/// camera in a test, and the thing worth pinning is the argument, which no
/// widget test would reach anyway.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  /// Every `CameraController(` in the app, with the arguments up to its
  /// closing paren.
  List<({String path, String args})> controllers() {
    final found = <({String path, String args})>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      var at = source.indexOf('CameraController(');
      while (at != -1) {
        final close = source.indexOf(');', at);
        if (close == -1) break;
        found.add((path: entity.path, args: source.substring(at, close)));
        at = source.indexOf('CameraController(', close);
      }
    }
    return found;
  }

  test('no camera is opened with audio enabled', () {
    final offenders = [
      for (final c in controllers())
        if (!c.args.contains('enableAudio: false')) c.path,
    ];

    expect(
      offenders,
      isEmpty,
      reason: 'these open the camera with audio on, which asks for the '
          'microphone: $offenders — nothing in this app records sound, and a '
          'refused mic fails the camera too',
    );
  });

  test('there is a camera to check, so the test cannot pass vacuously', () {
    // If the controllers are ever constructed some other way, the check above
    // would quietly find nothing and go green.
    expect(controllers(), isNotEmpty);
  });

  test('iOS does not declare a microphone it never uses', () {
    // The usage string said "for video recording", which the app does not do:
    // every pickVideo is ImageSource.gallery, and just_audio only plays. A
    // declared purpose string is what App Review reads as an intention to
    // use the hardware.
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    expect(
      plist.contains('NSMicrophoneUsageDescription'),
      isFalse,
      reason: 'nothing in the app records audio — if something starts to, add '
          'the key back with a string that says what it is actually for',
    );
  });
}
