import 'package:image_picker/image_picker.dart';

/// Centralised size/type checks for picked images and videos.
///
/// Uses [XFile.length] (not `dart:io`) so the same checks run on web and
/// mobile — `dart:io`'s `File(path).length()` throws on Flutter web.
class MediaValidator {
  MediaValidator._();

  /// Default cap for a single image, in bytes.
  ///
  /// Only a default. Where the receiving service publishes its own cap, pass it
  /// via [maxBytes] instead — chat does, because its caps are admin-controlled
  /// and were far below this: a 20 MB video passed here, uploaded in full over
  /// a mobile connection, and was only then refused on arrival.
  static const int maxImageBytes = 50 * 1024 * 1024; // 50 MB

  /// Default cap for a single video, in bytes. See [maxImageBytes].
  static const int maxVideoBytes = 50 * 1024 * 1024; // 50 MB

  static String _fmt(int bytes) {
    final mb = bytes / (1024 * 1024);
    return '${mb.toStringAsFixed(mb >= 10 ? 0 : 1)} MB';
  }

  /// Returns a user-facing error message if [file] is unacceptable, or `null`
  /// when it passes. Checks for empty/unreadable files and per-type size caps.
  static Future<String?> validate(
    XFile file, {
    required bool isVideo,
    int? maxBytes,
  }) async {
    final int size;
    try {
      size = await file.length();
    } catch (_) {
      return 'Could not read the selected file. Please try another.';
    }

    if (size <= 0) {
      return 'The selected file appears to be empty or unreadable.';
    }

    final limit = maxBytes ?? (isVideo ? maxVideoBytes : maxImageBytes);
    if (size > limit) {
      final kind = isVideo ? 'Video' : 'Image';
      final name = file.name.isEmpty ? 'file' : '"${file.name}"';
      return '$kind $name is too large. Maximum size is ${_fmt(limit)}.';
    }

    return null;
  }
}
