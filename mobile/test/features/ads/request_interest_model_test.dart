import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/features/ads/data/models/feed_request_model.dart';

/// The review screen sorts photographers into Pending and Viewed and pins the
/// selected one, all off three fields on this model. If they stop being read,
/// everyone silently lands in the same section.
Map<String, dynamic> _interest({
  String id = 'ph-1',
  bool viewed = false,
  bool selected = false,
}) =>
    {
      'id': id,
      'name': 'Kwame Studios',
      'profile_url': 'https://x/ph.jpg',
      'bio': 'Weddings across Accra',
      'location': 'Accra',
      'follower_count': 1200,
      'event_count': 132,
      'rating': 4.7,
      'rating_count': 12,
      'verified_by_admin': true,
      'message': 'I have flexible pricing',
      'viewed': viewed,
      'selected': selected,
      'portfolio': [
        {'id': 's1', 'url': 'https://x/s1.jpg', 'width': 1600, 'height': 900},
      ],
      'createdAt': '2026-08-01T10:00:00+00:00',
    };

void main() {
  test('the line under a name comes back whole', () {
    final person = RequestInterest.fromJson(_interest());

    expect(person.location, 'Accra');
    expect(person.followerCount, 1200);
    expect(person.eventCount, 132);
    expect(person.rating, 4.7);
    expect(person.message, 'I have flexible pricing');
    expect(person.portfolio.single.url, 'https://x/s1.jpg');
    expect(person.portfolio.single.width, 1600);
  });

  test('a photographer with no rating has none, not zero', () {
    // Zero would render as a one-star review of someone nobody has rated.
    final json = _interest()..remove('rating');

    expect(RequestInterest.fromJson(json).rating, isNull);
  });

  test('viewed and selected decide which section they land in', () {
    expect(RequestInterest.fromJson(_interest()).viewed, isFalse);
    expect(RequestInterest.fromJson(_interest(viewed: true)).viewed, isTrue);
    expect(RequestInterest.fromJson(_interest(selected: true)).selected, isTrue);
  });

  group('expiry', _expiryTests);

  test('an older payload without the new fields still parses', () {
    // Rolling deploys: the app can be newer than the service it is talking to.
    final person = RequestInterest.fromJson({'id': 'ph-1', 'name': 'Kwame'});

    expect(person.viewed, isFalse);
    expect(person.selected, isFalse);
    expect(person.followerCount, 0);
    expect(person.portfolio, isEmpty);
  });
}

/// A request stops being visible when its window closes, but nothing rewrites
/// its status — so "open" and "on the board" are different questions, and the
/// card has to answer the second one.
void _expiryTests() {
  FeedRequestModel request({String status = 'open', DateTime? expires}) =>
      FeedRequestModel.fromJson({
        'id': 'req-1',
        'title': 'wedding',
        'status': status,
        'location': 'Accra',
        if (expires != null) 'expires_at': expires.toIso8601String(),
      });

  test('an open request inside its window is live', () {
    final r = request(expires: DateTime.now().add(const Duration(days: 3)));

    expect(r.isExpired, isFalse);
    expect(r.isLive, isTrue);
  });

  test('an open request past its window is not', () {
    // The state the board was silently in: status open, invisible to everyone.
    final r = request(expires: DateTime.now().subtract(const Duration(days: 1)));

    expect(r.isExpired, isTrue);
    expect(r.isLive, isFalse);
  });

  test('a request with no expiry never expires', () {
    expect(request().isExpired, isFalse);
    expect(request().isLive, isTrue);
  });

  test('republish is offered exactly where the server allows it', () {
    // The button used to appear on requests the server refused, which is a
    // 400 with a nice label on it.
    final past = DateTime.now().subtract(const Duration(days: 1));
    final future = DateTime.now().add(const Duration(days: 3));

    expect(request(expires: past).canRepublish, isTrue,
        reason: 'expired is the case republishing exists for');
    expect(request(status: 'closed', expires: future).canRepublish, isTrue);
    expect(request(status: 'filled', expires: future).canRepublish, isTrue);

    expect(request(expires: future).canRepublish, isFalse,
        reason: 'already on the board');
    expect(request(status: 'pending_review', expires: future).canRepublish,
        isFalse, reason: 'never published in the first place');
    expect(request(status: 'promoted', expires: future).canRepublish, isFalse,
        reason: 'it became a campaign');
  });

  test('a closed request is not live whatever its dates say', () {
    final r = request(
      status: 'closed', expires: DateTime.now().add(const Duration(days: 3)),
    );

    expect(r.isLive, isFalse);
  });
}
