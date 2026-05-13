class PhotographerSample {
  final String id;
  final String url;
  final String imageId;

  const PhotographerSample({
    required this.id,
    required this.url,
    this.imageId = '',
  });

  factory PhotographerSample.fromJson(Map<String, dynamic> json) {
    return PhotographerSample(
      id: json['id']?.toString() ?? '',
      url: json['url']?.toString() ?? json['imageUrl']?.toString() ?? '',
      imageId: json['imageId']?.toString() ?? '',
    );
  }
}
