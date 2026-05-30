import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:skidoo_app/core/validators/media_validator.dart';

XFile _fileOfSize(int bytes, {String name = 'media.bin'}) {
  return XFile.fromData(Uint8List(bytes), name: name, length: bytes);
}

void main() {
  group('MediaValidator.validate', () {
    test('accepts a normal-sized image', () async {
      final file = _fileOfSize(1024, name: 'photo.jpg');
      expect(await MediaValidator.validate(file, isVideo: false), isNull);
    });

    test('rejects an empty file', () async {
      final file = _fileOfSize(0, name: 'empty.jpg');
      final result = await MediaValidator.validate(file, isVideo: false);
      expect(result, isNotNull);
      expect(result, contains('empty'));
    });

    test('rejects an image over the limit', () async {
      final file = _fileOfSize(MediaValidator.maxImageBytes + 1, name: 'big.png');
      final result = await MediaValidator.validate(file, isVideo: false);
      expect(result, isNotNull);
      expect(result, contains('too large'));
      expect(result, contains('Image'));
      expect(result, contains('50 MB'));
    });

    test('rejects a video over the limit with the video label', () async {
      final file = _fileOfSize(MediaValidator.maxVideoBytes + 1, name: 'clip.mp4');
      final result = await MediaValidator.validate(file, isVideo: true);
      expect(result, isNotNull);
      expect(result, contains('Video'));
      expect(result, contains('too large'));
    });

    test('accepts a file exactly at the limit', () async {
      final file = _fileOfSize(MediaValidator.maxImageBytes, name: 'edge.jpg');
      expect(await MediaValidator.validate(file, isVideo: false), isNull);
    });
  });
}
