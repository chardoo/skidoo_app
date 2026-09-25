import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

/// The app icon is a pile of PNGs, and two of their properties are
/// load-bearing.
///
/// The first is the obvious one: every slot in the asset catalogue has to hold
/// an image of exactly the size it claims, or iOS falls back to whatever it can
/// find and the icon looks different depending on where it is drawn.
///
/// The second only shows up at the worst moment. App Store Connect rejects a
/// marketing icon with an alpha channel — the upload fails after the archive,
/// with a message about the *build* rather than the file — and nothing on a
/// developer's machine notices, because an icon with transparency renders fine
/// everywhere in the simulator. `tool/generate_app_icon.py` writes RGB for this
/// reason; this is what catches the icon that gets dropped in by hand later.
///
/// Read as bytes rather than decoded: a PNG's IHDR carries the dimensions and
/// the colour type in its first 26 bytes, which is all either question needs,
/// and the suite has no image decoder.

const _iosDir = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';

/// What the five Android buckets are, in pixels. No adaptive icon in this
/// project — these legacy mipmaps are the whole set.
const _androidIcons = {
  'android/app/src/main/res/mipmap-mdpi/ic_launcher.png': 48,
  'android/app/src/main/res/mipmap-hdpi/ic_launcher.png': 72,
  'android/app/src/main/res/mipmap-xhdpi/ic_launcher.png': 96,
  'android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png': 144,
  'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png': 192,
};

/// PNG colour types that carry transparency: 4 is grey+alpha, 6 is RGBA.
const _alphaColourTypes = {4, 6};

({int width, int height, int colourType}) readHeader(Uint8List bytes) {
  const signature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
  for (var i = 0; i < signature.length; i++) {
    if (bytes[i] != signature[i]) fail('not a PNG');
  }
  final view = ByteData.sublistView(bytes);
  // 8 signature + 4 length + 4 type "IHDR", then width, height, depth, colour.
  return (
    width: view.getUint32(16),
    height: view.getUint32(20),
    colourType: bytes[25],
  );
}

/// A palette image (colour type 3) can still be transparent, through a tRNS
/// chunk rather than through its colour type.
bool hasTransparencyChunk(Uint8List bytes) {
  const needle = [0x74, 0x52, 0x4E, 0x53]; // "tRNS"
  for (var i = 0; i <= bytes.length - needle.length; i++) {
    var hit = true;
    for (var j = 0; j < needle.length; j++) {
      if (bytes[i + j] != needle[j]) {
        hit = false;
        break;
      }
    }
    if (hit) return true;
  }
  return false;
}

void main() {
  /// Every iOS slot, as {filename: pixel size} — read from the catalogue
  /// itself rather than listed here, so a slot added in Xcode is covered
  /// without anyone remembering to add it.
  late Map<String, int> iosIcons;

  setUpAll(() {
    final contents = jsonDecode(
      File('$_iosDir/Contents.json').readAsStringSync(),
    ) as Map<String, dynamic>;

    iosIcons = {
      for (final image in contents['images'] as List<dynamic>)
        if ((image as Map<String, dynamic>)['filename'] != null)
          image['filename'] as String: (double.parse(
                    (image['size'] as String).split('x').first,
                  ) *
                  double.parse(
                    (image['scale'] as String).replaceAll('x', ''),
                  ))
              .round(),
    };
  });

  test('the catalogue still describes a full icon set', () {
    // 15 files across iPhone, iPad and the store listing. A short set means
    // slots were dropped, which iOS fills by scaling a neighbour.
    expect(iosIcons, hasLength(15));
    expect(iosIcons, containsPair('Icon-App-1024x1024@1x.png', 1024));
  });

  test('every iOS icon is exactly the size its slot claims', () {
    iosIcons.forEach((name, size) {
      final file = File('$_iosDir/$name');
      expect(file.existsSync(), isTrue, reason: '$name is missing');

      final header = readHeader(file.readAsBytesSync());
      expect(
        [header.width, header.height],
        [size, size],
        reason: '$name is ${header.width}x${header.height}, and its slot in '
            'Contents.json asks for ${size}x$size — re-run '
            'tool/generate_app_icon.py',
      );
    });
  });

  test('no iOS icon carries an alpha channel', () {
    iosIcons.forEach((name, _) {
      final bytes = File('$_iosDir/$name').readAsBytesSync();
      final header = readHeader(bytes);

      expect(
        _alphaColourTypes.contains(header.colourType),
        isFalse,
        reason: '$name has transparency (PNG colour type '
            '${header.colourType}). The store refuses the upload for this, '
            'and only for the 1024 — flatten it onto the field colour.',
      );
      expect(hasTransparencyChunk(bytes), isFalse,
          reason: '$name carries a tRNS chunk, which is transparency by '
              'another route');
    });
  });

  test('every Android bucket has its launcher icon, at its own size', () {
    _androidIcons.forEach((path, size) {
      final file = File(path);
      expect(file.existsSync(), isTrue, reason: '$path is missing');

      final header = readHeader(file.readAsBytesSync());
      expect([header.width, header.height], [size, size],
          reason: '$path is ${header.width}x${header.height}, not ${size}x$size');
    });
  });

  test('the icon is generated from the mark, not pasted in beside it', () {
    // The vector every size is rendered from. If it goes, the script cannot
    // regenerate anything and the icons quietly become unreproducible files.
    expect(File('assets/logo/jperg_icon_white.svg').existsSync(), isTrue);
    expect(File('tool/generate_app_icon.py').existsSync(), isTrue);
  });
}
