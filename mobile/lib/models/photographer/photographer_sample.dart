import 'package:jperg_app/core/utils/cloudinary_transform.dart';

class PhotographerSample {
  final String id;
  final String url;
  final String imageId;
  final String mediaType;

  /// Server-side pixel dimensions. Null for legacy records.
  final int? width;
  final int? height;

  double? get aspectRatio =>
      (width != null && height != null && height! > 0) ? width! / height! : null;

  /// Same fallback as `Photo.isVideo`: the url settles it when the record
  /// carries no `media_type`.
  bool get isVideo =>
      mediaType == 'video' || CloudinaryTransform.isVideoUrl(url);

  const PhotographerSample({
    required this.id,
    required this.url,
    this.imageId = '',
    this.mediaType = 'image',
    this.width,
    this.height,
  });

  factory PhotographerSample.fromJson(Map<String, dynamic> json) {
    return PhotographerSample(
      id: json['id']?.toString() ?? '',
      url: json['url']?.toString() ?? json['imageUrl']?.toString() ?? '',
      imageId: json['imageId']?.toString() ?? '',
      mediaType: json['media_type']?.toString() ?? json['mediaType']?.toString() ?? 'image',
      width: (json['width'] as num?)?.toInt(),
      height: (json['height'] as num?)?.toInt(),
    );
  }
}
