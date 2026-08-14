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

  // ── Destinations a push can name, but a URL cannot ─────────────────────────
  //
  // These are reachable from a notification tap and nothing else. They are not
  // in the gateway's APP_PATHS and not in the AASA file, so they are not
  // claimed as https links — see [DeepLink.isShareable]. Adding one to the web
  // grammar means adding it in all four places DEEP_LINKS.md lists, and none
  // of these name anything a person would share.

  /// The app's own launch screen. What "just open the app" resolves to.
  home,

  /// The notifications list.
  notifications,

  /// The messages tab, or one room when the link carries an id.
  chat,

  /// The advertiser's campaigns.
  adsDashboard,

  /// One campaign of theirs. Every campaign notification names the campaign it
  /// is about — approved, paused, rejected, running out of budget — and landing
  /// on the list left someone to find which of nine it meant.
  campaign,

  /// The board of open photographer requests.
  requestBoard,

  /// A photographer's earnings and payouts.
  earnings,

  /// The basket — where a failed payment is retried from.
  cart,
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
  ///
  /// The push-only destinations are all about the viewer rather than about a
  /// public object — your messages, your earnings, your notifications — so
  /// every one of them needs a session. A signed-out tap holds the link,
  /// shows the sign-in screen, and resumes afterwards.
  bool get requiresAuth => switch (kind) {
        DeepLinkKind.myPhotos ||
        DeepLinkKind.notifications ||
        DeepLinkKind.chat ||
        DeepLinkKind.adsDashboard ||
        DeepLinkKind.campaign ||
        DeepLinkKind.earnings ||
        DeepLinkKind.cart =>
          true,
        _ => false,
      };

  /// Whether this can be handed out as an https link.
  ///
  /// False for the push-only destinations: the domain is not claiming those
  /// paths, so a link to one would open a browser and land on the gateway's
  /// "no app" page. Sharing UI must not offer them.
  bool get isShareable => switch (kind) {
        DeepLinkKind.myPhotos ||
        DeepLinkKind.picture ||
        DeepLinkKind.event ||
        DeepLinkKind.request ||
        DeepLinkKind.photographer =>
          true,
        _ => false,
      };

  /// The link a share should carry, given the domain the app links live on.
  ///
  /// Only meaningful when [isShareable]; the rest have a path so this switch
  /// stays exhaustive and so they can be logged, not so they can be sent to
  /// anyone.
  String path() => switch (kind) {
        DeepLinkKind.myPhotos => '/my-photos',
        DeepLinkKind.picture => '/p/$id',
        DeepLinkKind.event => '/e/$id',
        DeepLinkKind.request => '/r/$id',
        DeepLinkKind.photographer => '/photographer/$id',
        DeepLinkKind.home => '/',
        DeepLinkKind.notifications => '/notifications',
        DeepLinkKind.chat => id == null ? '/chat' : '/chat/$id',
        DeepLinkKind.adsDashboard => '/campaigns',
        DeepLinkKind.campaign => '/campaigns/$id',
        DeepLinkKind.requestBoard => '/requests',
        DeepLinkKind.earnings => '/earnings',
        DeepLinkKind.cart => '/cart',
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
    'p' ||
    'photo' when at(1) != null =>
      DeepLink(DeepLinkKind.picture, id: at(1)),
    'e' ||
    'event' when at(1) != null =>
      DeepLink(DeepLinkKind.event, id: at(1)),
    'r' ||
    'request' when at(1) != null =>
      DeepLink(DeepLinkKind.request, id: at(1)),
    'photographer' when at(1) != null =>
      DeepLink(DeepLinkKind.photographer, id: at(1)),
    _ => null,
  };
}

/// The same mapping the push payloads already use — `{"screen": "my_photos"}`
/// — so a notification and a link end up in one place rather than two.
///
/// Every `screen` value the backend can emit is here; POLICY in
/// main/app/services/notify.py is the other half of this table, and the two
/// have to be changed together. An unrecognised screen returns null, which the
/// caller turns into "open the app normally" rather than a dead tap.
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

    // The push-only destinations. `chat` is the one that takes an optional id:
    // with a room it opens the conversation, without one the messages list.
    'home' => const DeepLink(DeepLinkKind.home),
    'notifications' => const DeepLink(DeepLinkKind.notifications),
    'chat' => DeepLink(DeepLinkKind.chat, id: id),

    // `ads_dashboard` is the other one that takes an optional id, and for the
    // same reason: with a campaign id it opens that campaign, without one the
    // list. The backend sends the id on every campaign notification — the key
    // stayed `ads_dashboard` so builds from before this understood it still
    // land on the list rather than on nothing. `campaign` is accepted too, for
    // when the backend has no old builds left to carry.
    'ads_dashboard' || 'campaign' when id != null => DeepLink(
        DeepLinkKind.campaign,
        id: id,
      ),
    'ads_dashboard' => const DeepLink(DeepLinkKind.adsDashboard),
    'request_board' => const DeepLink(DeepLinkKind.requestBoard),
    'earnings' => const DeepLink(DeepLinkKind.earnings),
    'cart' => const DeepLink(DeepLinkKind.cart),

    // A screen this build has no destination for — an older app meeting a
    // newer backend. Null, so the tap still opens the app.
    _ => null,
  };
}

/// Read a whole push payload, whichever convention it was written under.
///
/// The backend now sends `{"screen": …, "id": …}`, but three older shapes are
/// still in flight: rows already stored in the Notification table, tasks
/// already queued on the broker, and — for a while — payloads from an ads
/// service that had not been redeployed. Those put the id under `event_id`,
/// `room_id`, `requestId`, `pictureId`, `campaignId` or `followerId`.
///
/// Reading all of them costs one list; not reading them means every
/// notification written before this change taps through to nothing.
DeepLink? parsePushPayload(Map<String, dynamic>? data) {
  if (data == null) return null;

  String? asString(Object? v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  const legacyIdKeys = [
    'id',
    'event_id',
    'room_id',
    'requestId',
    'pictureId',
    'campaignId',
    'followerId',
  ];

  String? id;
  for (final key in legacyIdKeys) {
    id = asString(data[key]);
    if (id != null) break;
  }

  return parsePushScreen(asString(data['screen']), id: id);
}
