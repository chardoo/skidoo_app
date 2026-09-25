import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

/// The splash artwork is a file, and two of its properties are load-bearing.
///
/// `SplashPage` holds for the length of the animation, as a number typed into
/// the source, and it relies on the animation stopping at its last frame. Both
/// facts live in the gif's bytes, where nothing in the app can check them and a
/// re-export can change them without anyone editing a line of Dart. That is how
/// the file arrived the first time: exported looping forever, so a start slower
/// than the animation wiped the finished wordmark and drew it on again while
/// the person waited.
///
/// So the bytes are read here instead. These are the only tests in the suite
/// that assert about an asset rather than about a widget, and they are worth it
/// — the failure they catch is invisible on a fast phone with a warm cache, and
/// obvious on the slow first launch nobody tests on.

const _asset = 'assets/splash/Splash_reducedg.gif';

/// Must match `_kMinDisplay` in `splash_page.dart` — which is the point.
///
/// 1800, not the 3600 it was: the cut was re-timed to play at twice the speed
/// (54 frames at 30 fps rather than 108) because every launch was waiting out
/// the full 3.6 s of it. Change the file and this fails until the page's floor
/// is moved with it — the failure message says by how much.
const _animationLength = Duration(milliseconds: 1800);

/// Walks the gif's block structure, adding up the per-frame delays.
///
/// A gif does not carry its own duration: it is the sum of the delay on each
/// frame's Graphic Control Extension, in hundredths of a second. This file
/// mixes 30 ms and 40 ms frames, which is why multiplying a frame count by one
/// delay — how the constant was first arrived at — got the wrong answer.
({int frames, Duration length}) readTiming(Uint8List d) {
  var i = 13; // header (6) + logical screen descriptor (7)
  final flags = d[10];
  if (flags & 0x80 != 0) i += 3 * (2 << (flags & 7)); // global colour table

  var frames = 0;
  var centiseconds = 0;

  while (i < d.length) {
    switch (d[i]) {
      case 0x21: // extension
        final label = d[i + 1];
        i += 2;
        if (label == 0xF9) {
          // Graphic Control Extension: [size][packed][delay lo][delay hi]…
          centiseconds += d[i + 2] | (d[i + 3] << 8);
        }
        while (d[i] != 0) {
          i += d[i] + 1; // skip each sub-block by its length byte
        }
        i += 1;
      case 0x2C: // image descriptor — one frame
        frames += 1;
        i += 9;
        final local = d[i];
        i += 1;
        if (local & 0x80 != 0) i += 3 * (2 << (local & 7)); // local palette
        i += 1; // LZW minimum code size
        while (d[i] != 0) {
          i += d[i] + 1;
        }
        i += 1;
      case 0x3B: // trailer
        return (frames: frames, length: Duration(milliseconds: centiseconds * 10));
      default:
        fail('unreadable gif: unexpected block 0x${d[i].toRadixString(16)} '
            'at byte $i');
    }
  }
  return (frames: frames, length: Duration(milliseconds: centiseconds * 10));
}

void main() {
  late Uint8List bytes;

  setUpAll(() {
    final file = File(_asset);
    expect(file.existsSync(), isTrue,
        reason: '$_asset is missing — the splash has no artwork');
    bytes = file.readAsBytesSync();
  });

  test('plays once and holds its last frame', () {
    // Flutter honours the gif's own loop count. The NETSCAPE2.0 application
    // extension is what carries it, and a count of 0 in that block means
    // *forever* — so the presence of the block at all is the thing to catch.
    // Without it the decoder stops after one pass and the finished wordmark
    // stays on screen, which is what the waiting state is drawn on top of.
    expect(
      bytes.indexOfSublist('NETSCAPE2.0'.codeUnits),
      -1,
      reason: 'the artwork loops: it will redraw the wordmark from scratch '
          'every 3.6 s on any start slow enough to still be waiting. Strip the '
          'NETSCAPE2.0 application extension from the gif.',
    );
  });

  test('is as long as the page holds for', () {
    final timing = readTiming(bytes);

    expect(timing.frames, greaterThan(0), reason: 'no frames decoded');
    // Longer would cut the mark off before it finishes drawing; shorter would
    // hold a still image for no reason. They are meant to be the same number.
    expect(
      timing.length,
      _animationLength,
      reason: 'the animation is now ${timing.length.inMilliseconds} ms over '
          '${timing.frames} frames — update _kMinDisplay in splash_page.dart '
          'to match, or the page leaves mid-draw',
    );
  });
}

extension on Uint8List {
  /// Index of [needle] in these bytes, or -1. No package for it, and the file
  /// is 75 KB.
  int indexOfSublist(List<int> needle) {
    for (var i = 0; i <= length - needle.length; i++) {
      var hit = true;
      for (var j = 0; j < needle.length; j++) {
        if (this[i + j] != needle[j]) {
          hit = false;
          break;
        }
      }
      if (hit) return i;
    }
    return -1;
  }
}
