import 'package:image_picker/image_picker.dart';

/// Opens the gallery for at most [limit] images.
///
/// Wraps a trap in `pickMultiImage`: its `limit` throws
/// `ArgumentError: cannot be lower than 2`, so any screen that computes the
/// limit from remaining capacity crashes on the pick that would have filled the
/// last slot — the one case a capped picker is most likely to be used for. This
/// falls back to the single-image picker there, and returns an empty list
/// rather than opening a picker that can't accept anything when there is no
/// room left at all.
Future<List<XFile>> pickImagesUpTo(
  ImagePicker picker, {
  required int limit,
  int imageQuality = 85,
}) async {
  if (limit <= 0) return const [];

  if (limit == 1) {
    final single = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: imageQuality,
    );
    return single == null ? const [] : [single];
  }

  return picker.pickMultiImage(imageQuality: imageQuality, limit: limit);
}
