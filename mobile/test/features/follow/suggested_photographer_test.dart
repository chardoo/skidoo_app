import 'package:flutter_test/flutter_test.dart';
import 'package:skidoo_app/features/follow/data/follow_repository.dart';

SuggestedPhotographer parse(Map<String, dynamic> extra) =>
    SuggestedPhotographer.fromJson({
      'id': 'p1',
      'name': 'Cle Williams',
      'follower_count': 1200,
      ...extra,
    });

/// The category line the suggestion row shows. The server now builds it —
/// first two `specialties`, joined with " & " — but older deploys sent only
/// the raw fields, so the reader has to make the best line available at any
/// point in the rollout.
void main() {
  test('the server-built line wins outright', () {
    final result = parse({
      'category': 'Events & Nature',
      'specialty': 'Events',
      'specialties': ['Events', 'Nature', 'Weddings'],
    });
    expect(result.category, 'Events & Nature');
  });

  test('without it, the array beats the singular — same line, not just its '
      'first half', () {
    final result = parse({
      'specialty': 'Events',
      'specialties': ['Events', 'Nature', 'Weddings'],
    });
    expect(result.category, 'Events & Nature');
  });

  test('the array is capped at two, as the server caps it', () {
    final result = parse({
      'specialties': ['Events', 'Nature', 'Weddings', 'Portraits'],
    });
    expect(result.category, 'Events & Nature');
  });

  test('the singular is the last resort', () {
    expect(parse({'specialty': 'Events'}).category, 'Events');
  });

  test('null when there is nothing to say', () {
    expect(parse({}).category, isNull);
    expect(parse({'category': null, 'specialties': []}).category, isNull);
    // The server sends null rather than "", but an empty string must not
    // become a category either — the row would render a stranded "·".
    expect(parse({'category': '', 'specialties': []}).category, isNull);
  });

  test('the rest of the record still parses', () {
    final result = parse({'category': 'Events', 'profile_url': 'https://x/y'});
    expect(result.id, 'p1');
    expect(result.name, 'Cle Williams');
    expect(result.followerCount, 1200);
    expect(result.profileUrl, 'https://x/y');
  });
}
