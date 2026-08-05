/// What a link asks the app to open.
///
/// Parsing is kept apart from opening on purpose. Where a link came from — a
/// cold start, a resume, a push payload — changes nothing about what it means,
/// and this way the meaning can be tested without a Navigator.
enum DeepLinkKind {
  /// The photos found of the signed-in person. The link in the "we found you"
  /// email, and the one place the link says nothing about whose photos.
  myPhotos,

  /// One photo, shared.
  picture,

  /// An event album.
  event,

  /// A photographer request.
  request,

  /// A photographer's profile.
  photographer,
}

class DeepLink {
  const DeepLink(this.kind, {this.id});

  final DeepLinkKind kind;

  /// The thing being opened. Null for [DeepLinkKind.myPhotos], which is about
  /// the viewer rather than a particular object.
  final String? id;

  /// Whether following this needs a signed-in user. Someone arriving from an
  /// email may well not be signed in, and the answer decides whether they are
  /// sent to sign in first or straight through.
  bool get requiresAuth => kind == DeepLinkKind.myPhotos;

  /// The link a share should carry, given the domain the app links live on.
  String path() => switch (kind) {
        DeepLinkKind.myPhotos => '/my-photos',
        DeepLinkKind.picture => '/p/$id',
        DeepLinkKind.event => '/e/$id',
        DeepLinkKind.request => '/r/$id',
        DeepLinkKind.photographer => '/photographer/$id',
      };

  @override
  String toString() => 'DeepLink(${kind.name}${id == null ? '' : ', $id'})';

  @override
  bool operator ==(Object other) =>
      other is DeepLink && other.kind == kind && other.id == id;

  @override
  int get hashCode => Object.hash(kind, id);
}

/// Turns a URL into something the app can open, or nothing.
///
/// Returning null is a real answer and the common one: the domain also serves
/// a website, and a link to a page the app has no screen for should stay in
/// the browser rather than open the app on a blank route.
DeepLink? parseDeepLink(Uri? uri) {
  if (uri == null) return null;

  // Custom scheme (jperg://photo/abc) and https share the same grammar below,
  // but a custom scheme puts the first segment in `host` instead of `path`.
  final segments = <String>[
    if (uri.scheme.isNotEmpty && uri.scheme != 'http' && uri.scheme != 'https')
      if (uri.host.isNotEmpty) uri.host,
    ...uri.pathSegments,
  ].where((s) => s.isNotEmpty).toList();

  if (segments.isEmpty) return null;

  String? at(int i) => segments.length > i && segments[i].trim().isNotEmpty
      ? segments[i].trim()
      : null;

  return switch (segments.first) {
    'my-photos' || 'my_photos' || 'photos' => const DeepLink(
        DeepLinkKind.myPhotos,
      ),
    'p' || 'photo' when at(1) != null =>
      DeepLink(DeepLinkKind.picture, id: at(1)),
    'e' || 'event' when at(1) != null => DeepLink(DeepLinkKind.event, id: at(1)),
    'r' || 'request' when at(1) != null =>
      DeepLink(DeepLinkKind.request, id: at(1)),
    'photographer' when at(1) != null =>
      DeepLink(DeepLinkKind.photographer, id: at(1)),
    _ => null,
  };
}

/// The same mapping the push payloads already use — `{"screen": "my_photos"}`
/// — so a notification and a link end up in one place rather than two.
DeepLink? parsePushScreen(String? screen, {String? id}) {
  if (screen == null || screen.trim().isEmpty) return null;
  return switch (screen.trim()) {
    'my_photos' || 'my-photos' => const DeepLink(DeepLinkKind.myPhotos),
    'picture' || 'photo' when id != null => DeepLink(
        DeepLinkKind.picture,
        id: id,
      ),
    'event' when id != null => DeepLink(DeepLinkKind.event, id: id),
    'request' when id != null => DeepLink(DeepLinkKind.request, id: id),
    'photographer' when id != null => DeepLink(
        DeepLinkKind.photographer,
        id: id,
      ),
    _ => null,
  };
}
