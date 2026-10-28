import 'package:jperg_app/core/utils/media_transform.dart';

class PhotographerSample {
  final String id;
  final String url;
  final String imageId;
  final String mediaType;

  /// Server-side pixel dimensions. Null for legacy records.
  final int? width;
  final int? height;

  /// The pre-sized copies that exist for this sample, and the stand-in to
  /// paint until one lands — see [ImageLadder].
  final int? derivativesVersion;
  final String? blurhash;

  double? get aspectRatio =>
      (width != null && height != null && height! > 0) ? width! / height! : null;

  ImageLadder get ladder =>
      ImageLadder(version: derivativesVersion, sourceWidth: width);

  /// Same fallback as `Photo.isVideo`: the url settles it when the record
  /// carries no `media_type`.
  bool get isVideo =>
      mediaType == 'video' || MediaTransform.isVideoUrl(url);

  const PhotographerSample({
    required this.id,
    required this.url,
    this.imageId = '',
    this.mediaType = 'image',
    this.width,
    this.height,
    this.derivativesVersion,
    this.blurhash,
  });

  factory PhotographerSample.fromJson(Map<String, dynamic> json) {
    return PhotographerSample(
      id: json['id']?.toString() ?? '',
      url: json['url']?.toString() ?? json['imageUrl']?.toString() ?? '',
      imageId: json['imageId']?.toString() ?? '',
      mediaType: json['media_type']?.toString() ?? json['mediaType']?.toString() ?? 'image',
      width: (json['width'] as num?)?.toInt(),
      height: (json['height'] as num?)?.toInt(),
      derivativesVersion:
          ((json['derivativesVersion'] ?? json['derivatives_version']) as num?)
              ?.toInt(),
      blurhash: json['blurhash']?.toString(),
    );
  }
}
