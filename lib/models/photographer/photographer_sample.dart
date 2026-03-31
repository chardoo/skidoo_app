class PhotographerSample {
  final String id;
  final String url;

  const PhotographerSample({required this.id, required this.url});

  factory PhotographerSample.fromJson(Map<String, dynamic> json) {
    return PhotographerSample(
      id: json['id']?.toString() ?? '',
      url: json['url']?.toString() ?? json['imageUrl']?.toString() ?? '',
    );
  }
}
