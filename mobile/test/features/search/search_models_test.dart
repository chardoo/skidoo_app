import 'package:flutter_test/flutter_test.dart';
import 'package:skidoo_app/core/utils/number_format.dart';
import 'package:skidoo_app/features/search/domain/entities/search_models.dart';

/// The row shapes documented in docs/FRONTEND_SEARCH.md.
Map<String, dynamic> eventJson({String id = 'evt-1'}) => {
      'id': id,
      'eventName': 'Praise Reloaded 2026',
      'description': 'gospel night',
      'coverUrl': 'https://cdn/cover.jpg',
      'eventDate': '2026-07-12',
      'accessCode': 'AFRICA-26',
      'content_tags': ['reloaded', 'praise'],
      'photoCount': 108,
      'comments_enabled': true,
      'photographer': {
        'id': 'ph-1',
        'name': 'Efo Reloaded',
        'profile_url': 'https://cdn/efo.jpg',
        'specialty': 'Arts & Culture',
        'followerCount': 1024,
        'verified_by_admin': false,
      },
      'owner': false,
      'owners': ['couple@example.com'],
    };

Map<String, dynamic> photographerJson() => {
      'id': 'ph-1',
      'name': 'Efo Reloaded',
      'username': 'eforeloaded',
      'profile_url': 'https://cdn/efo.jpg',
      'bio': 'shoots weddings',
      'specialty': 'Arts & Culture',
      'specialties': ['Arts & Culture'],
      'studio_name': 'Efo Studios',
      'studio_image_url': 'https://cdn/studio.jpg',
      'verified_by_admin': false,
      'followerCount': 1024,
      'eventCount': 12,
      'isFollowedByMe': false,
    };

void main() {
  group('event row', () {
    test('reads every field the design uses', () {
      final row = SearchEventRow.fromJson(eventJson());

      expect(row.id, 'evt-1');
      expect(row.eventName, 'Praise Reloaded 2026');
      expect(row.coverUrl, 'https://cdn/cover.jpg');
      expect(row.accessCode, 'AFRICA-26');
      expect(row.contentTags, ['reloaded', 'praise']);
      expect(row.photoCount, 108);
      expect(row.isOwner, isFalse);
      expect(row.photographer?.name, 'Efo Reloaded');
      expect(row.photographer?.followerCount, 1024);
    });

    test('survives a payload with nothing but an id', () {
      final row = SearchEventRow.fromJson(const {'id': 'evt-2'});

      expect(row.eventName, '');
      expect(row.photoCount, 0);
      expect(row.contentTags, isEmpty);
      expect(row.photographer, isNull);
      // The server's own default — a payload predating the field is not a
      // reason to silence an event's comments.
      expect(row.commentsEnabled, isTrue);
    });
  });

  group('photographer row', () {
    test('honours profile_url over the legacy profile array', () {
      final row = SearchPhotographerRow.fromJson({
        ...photographerJson(),
        'profile': const ['https://cdn/legacy.jpg'],
      });
      expect(row.profileUrl, 'https://cdn/efo.jpg');
    });

    test('falls back to the legacy profile array for old accounts', () {
      final json = photographerJson()..remove('profile_url');
      final row = SearchPhotographerRow.fromJson({
        ...json,
        'profile': const ['https://cdn/legacy.jpg'],
      });
      expect(row.profileUrl, 'https://cdn/legacy.jpg');
    });

    test('takes the first specialty when the singular field is absent', () {
      final json = photographerJson()..remove('specialty');
      expect(SearchPhotographerRow.fromJson(json).specialty, 'Arts & Culture');
    });

    // The server now builds the subtitle itself — the first two specialties
    // joined — and sends it as `category`. Reading `specialty` instead would
    // settle for the first of them while the full line sat in the payload.
    test('the server-built category line wins over the singular specialty', () {
      final row = SearchPhotographerRow.fromJson({
        ...photographerJson(),
        'category': 'Events & Nature',
        'specialty': 'Events',
        'specialties': ['Events', 'Nature', 'Weddings'],
      });
      expect(row.specialty, 'Events & Nature');
      // The uncapped list stays available to anything that wants more.
      expect(row.specialties, ['Events', 'Nature', 'Weddings']);
    });

    test('without a category, two specialties are joined the same way', () {
      final json = photographerJson()
        ..remove('category')
        ..remove('specialty')
        ..['specialties'] = ['Events', 'Nature', 'Weddings'];
      // Capped at two, as the server caps it: a third pushes the follower
      // count off the row.
      expect(SearchPhotographerRow.fromJson(json).specialty, 'Events & Nature');
    });

    test('a creator with nothing on record has no line, not an empty one', () {
      final json = photographerJson()
        ..remove('specialty')
        ..remove('specialties');
      expect(SearchPhotographerRow.fromJson(json).specialty, '');
    });
  });

  group('the event grid\'s photographer block', () {
    test('reads the same category line as a photographer row', () {
      final json = eventJson();
      (json['photographer'] as Map<String, dynamic>)
        ..['category'] = 'Events & Nature'
        ..['specialty'] = 'Events';

      expect(SearchEventRow.fromJson(json).photographer!.specialty,
          'Events & Nature');
    });
  });

  group('tag row', () {
    test('uses the server label as the display key', () {
      final row = SearchTagRow.fromJson(
          const {'tag': 'reloaded', 'label': '#reloaded', 'postCount': 100000});
      expect(row.label, '#reloaded');
      expect(row.tag, 'reloaded');
    });

    test('derives a label when the server sends only the tag', () {
      expect(SearchTagRow.fromJson(const {'tag': 'reloaded'}).label, '#reloaded');
    });

    test('a bare label is hashed so it matches the # beside it', () {
      // The row draws a `#` mark next to the label; a bare one would read as
      // a different thing to the hashed rows above and below it.
      final row =
          SearchTagRow.fromJson(const {'tag': 'reloaded', 'label': 'reloaded'});
      expect(row.label, '#reloaded');
    });

    test('the drill-down key stays bare even when the tag arrives hashed', () {
      final row = SearchTagRow.fromJson(const {'tag': '#reloaded'});
      expect(row.tag, 'reloaded');
      expect(row.label, '#reloaded');
    });
  });

  group('what a public surface must not carry', () {
    test('a photographer row has no email, however the server sends one', () {
      // The endpoint drops email from photographer matching on purpose — a
      // public surface shouldn't confirm whether an address has an account.
      // Nothing here should be able to put one back on screen.
      final row = SearchPhotographerRow.fromJson({
        ...photographerJson(),
        'email': 'efo@example.com',
      });

      expect(row.props.whereType<String>(),
          isNot(contains(contains('@example.com'))));
    });

    test('an event row drops the owner email list', () {
      // `owners` is a list of email addresses; the row is rendered on a public
      // screen, so it is never parsed.
      final row = SearchEventRow.fromJson(eventJson());
      expect(row.props.whereType<String>(),
          isNot(contains(contains('@example.com'))));
      expect(row.props.whereType<List>().expand((e) => e),
          isNot(contains('couple@example.com')));
    });
  });

  group('type=all envelope', () {
    test('parses the sections, the counts and the total', () {
      final results = SearchAllResults.fromJson({
        'query': 'Reloaded',
        'type': 'all',
        'counts': const {'events': 7, 'photographers': 5, 'tags': 4},
        'total': 16,
        'events': [eventJson()],
        'photographers': [photographerJson()],
        'tags': const [
          {'tag': 'reloaded', 'label': '#reloaded', 'postCount': 100000}
        ],
      });

      expect(results.total, 16);
      expect(results.counts.of(SearchResultType.events), 7);
      expect(results.counts.of(SearchResultType.photographers), 5);
      expect(results.counts.of(SearchResultType.tags), 4);
      expect(results.events, hasLength(1));
      expect(results.firstNonEmptyType, SearchResultType.events);
    });

    test('total 0 is the empty state', () {
      final results = SearchAllResults.fromJson(const {
        'query': 'Vnzbd',
        'counts': {'events': 0, 'photographers': 0, 'tags': 0},
        'total': 0,
        'events': [],
        'photographers': [],
        'tags': [],
      });

      expect(results.total, 0);
      expect(results.firstNonEmptyType, isNull);
    });

    test('the first chip is the leftmost section that matched', () {
      final results = SearchAllResults.fromJson(const {
        'counts': {'events': 0, 'photographers': 0, 'tags': 3},
        'total': 3,
        'tags': [
          {'tag': 'reloaded'}
        ],
      });
      expect(results.firstNonEmptyType, SearchResultType.tags);
    });

    test('a missing total falls back to the rows delivered', () {
      // Better to show the rows than to claim "no results" over a field the
      // envelope happened to omit.
      final results = SearchAllResults.fromJson({
        'events': [eventJson()],
      });
      expect(results.total, 1);
    });
  });

  group('pagination', () {
    test('derives hasNext when the envelope omits it', () {
      final page = SearchPagination.fromJson(
          const {'page': 1, 'limit': 25, 'total': 40, 'totalPages': 2});
      expect(page.hasNext, isTrue);
    });

    test('trusts an explicit hasNext', () {
      final page = SearchPagination.fromJson(
          const {'page': 1, 'totalPages': 5, 'hasNext': false});
      expect(page.hasNext, isFalse);
    });
  });

  group('compactCount', () {
    test('matches the counts in the design', () {
      expect(compactCount(800), '800');
      expect(compactCount(1024), '1K');
      expect(compactCount(1500), '1.5K');
      expect(compactCount(2500), '2.5K');
      expect(compactCount(3000), '3K');
      expect(compactCount(100000), '100K');
      expect(compactCount(2800000), '2.8M');
    });

    test('countLabel pluralises on the real number, not the short one', () {
      expect(countLabel(1, 'follower'), '1 follower');
      expect(countLabel(108, 'photo'), '108 photos');
      // 1K is one thousand followers, not one.
      expect(countLabel(1000, 'follower'), '1K followers');
    });
  });
}
