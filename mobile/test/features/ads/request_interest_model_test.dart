import 'package:flutter_test/flutter_test.dart';
import 'package:skidoo_app/features/ads/data/models/feed_request_model.dart';

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

  test('an older payload without the new fields still parses', () {
    // Rolling deploys: the app can be newer than the service it is talking to.
    final person = RequestInterest.fromJson({'id': 'ph-1', 'name': 'Kwame'});

    expect(person.viewed, isFalse);
    expect(person.selected, isFalse);
    expect(person.followerCount, 0);
    expect(person.portfolio, isEmpty);
  });
}
