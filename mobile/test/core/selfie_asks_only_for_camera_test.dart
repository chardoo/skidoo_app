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

  test('the iOS microphone string does not claim the app records audio', () {
    // The key itself has to stay. `camera_avfoundation` links
    // AVCaptureDevice's audio APIs to support video recording, and App Store
    // validation rejects a build whose frameworks reference those APIs with
    // no purpose string — whether or not the app calls them. Deleting it,
    // which an earlier version of this test demanded, would fail submission.
    //
    // What must not come back is the *wording*. It used to read "for video
    // recording", describing a feature the app does not have; the string is
    // the only thing App Review sees, so it should say the opposite.
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    final at = plist.indexOf('NSMicrophoneUsageDescription');
    if (at == -1) return; // gone entirely is also fine — nothing uses it

    final value = plist.substring(at, plist.indexOf('</string>', at));
    expect(
      value.toLowerCase(),
      isNot(contains('for video recording')),
      reason: 'the app records no audio — the string should say so, since '
          'App Review is its only audience',
    );
  });
}
