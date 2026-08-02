/// Compact count formatting — `800`, `1K`, `1.5K`, `100K`, `2.8M`.
///
/// The server sends exact numbers (`followerCount`, `postCount`) and leaves
/// the shortening to the client, so this is the one place that decides how
/// they read. A single trailing decimal is kept only when it says something:
/// `1.5K`, but `3K` rather than `3.0K`.
String compactCount(int value) {
  if (value < 0) return '0';
  if (value < 1000) return '$value';
  if (value < 1000000) return '${_trim(value / 1000)}K';
  if (value < 1000000000) return '${_trim(value / 1000000)}M';
  return '${_trim(value / 1000000000)}B';
}

/// `"1K followers"` / `"1 follower"`, and the same for posts and photos.
String countLabel(int value, String singular, [String? plural]) =>
    '${compactCount(value)} ${value == 1 ? singular : (plural ?? '${singular}s')}';

String _trim(double value) {
  final rounded = (value * 10).round() / 10;
  return rounded == rounded.roundToDouble()
      ? rounded.toStringAsFixed(0)
      : rounded.toStringAsFixed(1);
}
