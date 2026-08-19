/// One track, in the shape the API stores on an event and hands back.
///
/// Mirrors `MusicTrack` in `app/services/music.py` field for field. That
/// dataclass is the contract, and it was designed to outlive its provider:
/// the backend stores whole track objects on `Event.music` rather than a
/// provider id, precisely so an event scored under one music partner keeps
/// playing after a move to another.
///
/// The consequence for this app is the useful one — **there is no music
/// provider on this side.** Nothing here searches, resolves or knows where a
/// track came from. An event arrives carrying its own soundtrack, already
/// resolved, and the feed plays it. Swapping Deezer for a licenced partner
/// changes `services/music.py` and nothing in `lib/`.
class MusicTrack {
  const MusicTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.streamUrl,
    this.pageUrl = '',
    this.provider = '',
    this.artworkUrl,
    this.durationSeconds = 0,
    this.license,
  });

  /// The provider's id. Only ever used to tell tracks apart — never parsed,
  /// never sent back. The backend deliberately does not key anything on it.
  final String id;

  final String title;
  final String artist;

  /// Where it plays from.
  ///
  /// The backend's note says this "may be empty while the provider is
  /// undecided", so an empty string is a shape the client must handle rather
  /// than an error: [isPlayable] is false and the card stays silent.
  final String streamUrl;

  /// The track's page at the provider — attribution, and where a client should
  /// send someone when there is no [streamUrl] to play.
  final String pageUrl;

  /// Who supplied it. Display and diagnostics only; no behaviour branches on
  /// it, which is the point of storing whole tracks.
  final String provider;

  final String? artworkUrl;

  /// The **full** track's length, which is not necessarily how long
  /// [streamUrl] runs — a provider serving 30-second previews still reports
  /// the real duration here. Nothing about playback reads this for that exact
  /// reason; it is display only.
  final int durationSeconds;

  final String? license;

  /// A track with nowhere to stream from cannot play. Attribution alone is not
  /// enough to put a pill on a card.
  bool get isPlayable => streamUrl.isNotEmpty;

  Duration? get duration =>
      durationSeconds > 0 ? Duration(seconds: durationSeconds) : null;

  /// What the pill says. Falls back through the fields that are present rather
  /// than rendering a bare separator between two empty strings.
  String get label {
    if (title.isEmpty && artist.isEmpty) return 'Music';
    if (artist.isEmpty) return title;
    if (title.isEmpty) return artist;
    return '$title · $artist';
  }

  /// Built defensively: this is a JSON column the client does not control, and
  /// a feed must not fail to render because one event's soundtrack is odd.
  static MusicTrack? fromMap(dynamic json) {
    if (json is! Map) return null;
    final id = json['id']?.toString() ?? '';
    if (id.isEmpty) return null;
    return MusicTrack(
      id: id,
      title: json['title']?.toString() ?? '',
      artist: json['artist']?.toString() ?? '',
      streamUrl: json['streamUrl']?.toString() ?? '',
      pageUrl: json['pageUrl']?.toString() ?? '',
      provider: json['provider']?.toString() ?? '',
      artworkUrl: json['artworkUrl']?.toString(),
      durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
      license: json['license']?.toString(),
    );
  }

  /// An event's whole soundtrack, dropping anything unreadable or unplayable
  /// so callers never have to re-check what they were handed.
  static List<MusicTrack> listFrom(dynamic json) {
    if (json is! List) return const [];
    final tracks = <MusicTrack>[];
    for (final row in json) {
      final track = fromMap(row);
      if (track != null && track.isPlayable) tracks.add(track);
    }
    return tracks;
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'artist': artist,
        'streamUrl': streamUrl,
        'pageUrl': pageUrl,
        'provider': provider,
        'durationSeconds': durationSeconds,
        if (artworkUrl != null) 'artworkUrl': artworkUrl,
        if (license != null) 'license': license,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MusicTrack &&
          other.id == id &&
          other.streamUrl == streamUrl &&
          other.title == title &&
          other.artist == artist;

  @override
  int get hashCode => Object.hash(id, streamUrl, title, artist);

  @override
  String toString() => 'MusicTrack($id, "$label")';
}
