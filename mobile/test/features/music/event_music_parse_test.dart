import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/features/music/domain/entities/music_track.dart';
import 'package:jperg_app/models/event_discovery/event_discovery.dart';

/// One track as the API actually sends it — `MusicTrack.to_dict()` in
/// `app/services/music.py`, camel-cased, with a Deezer preview for a stream.
Map<String, dynamic> apiTrack({
  String id = '585584062',
  String streamUrl = 'https://cdnt-preview.dzcdn.net/api/1/1/0/b.mp3',
}) =>
    {
      'id': id,
      'title': 'On the Low',
      'artist': 'Burna Boy',
      'durationSeconds': 185,
      'provider': 'deezer',
      'streamUrl': streamUrl,
      'pageUrl': 'https://www.deezer.com/track/585584062',
      'artworkUrl': 'https://e-cdns-images.dzcdn.net/cover_medium.jpg',
      'license': null,
    };

Map<String, dynamic> feedEvent({dynamic music}) => {
      'event': {
        'id': 'event-1',
        'eventName': 'Beach day',
        'user': {'id': 'p1', 'name': 'Ama'},
        'pictures': const [],
        if (music != null) 'music': music,
      }
    };

void main() {
  group('an event carries its own soundtrack', () {
    test('a scored event parses its tracks in order', () {
      final event = EventDiscovery.fromMap(feedEvent(music: [
        apiTrack(id: 'a'),
        apiTrack(id: 'b'),
      ]));

      expect(event.music.map((t) => t.id), ['a', 'b'],
          reason: 'the order the photographer picked is the play order');
      expect(event.music.first.title, 'On the Low');
      expect(event.music.first.artist, 'Burna Boy');
      expect(event.music.first.durationSeconds, 185);
      expect(event.music.first.provider, 'deezer');
      expect(event.music.first.isPlayable, isTrue);
    });

    test('an unscored event has an empty soundtrack, not a null one', () {
      expect(EventDiscovery.fromMap(feedEvent(music: [])).music, isEmpty);
    });

    test('an endpoint that sends no music field at all is simply quiet', () {
      // Every cached feed written before this shipped, and any endpoint not
      // yet taught to send it. Both must read as "unscored", never as a crash.
      expect(EventDiscovery.fromMap(feedEvent()).music, isEmpty);
    });

    test('a soundtrack that is not a list is ignored rather than fatal', () {
      expect(EventDiscovery.fromMap(feedEvent(music: 'nonsense')).music,
          isEmpty);
    });

    test('a track with no stream URL is dropped', () {
      // The backend's own note says streamUrl "may be empty" while a provider
      // is undecided. Nothing playable means nothing to offer the player.
      final event = EventDiscovery.fromMap(feedEvent(music: [
        apiTrack(id: 'silent', streamUrl: ''),
        apiTrack(id: 'good'),
      ]));
      expect(event.music.map((t) => t.id), ['good']);
    });

    test('a malformed row does not take the rest of the soundtrack with it',
        () {
      final event = EventDiscovery.fromMap(feedEvent(music: [
        'not a map',
        {'title': 'no id'},
        apiTrack(id: 'good'),
      ]));
      expect(event.music.map((t) => t.id), ['good']);
    });

    test('the soundtrack survives a cache round-trip', () {
      // The feed cache writes events through toMap and reads them back, so a
      // cached card must come back still scored.
      final original = EventDiscovery.fromMap(feedEvent(music: [apiTrack()]));
      final restored = EventDiscovery.fromMap(original.toMap());
      expect(restored.music, original.music);
    });

    test('copyWith keeps the soundtrack through a reaction', () {
      // Liking a card rebuilds the event. Losing its music there would stop
      // the sound mid-scroll for no visible reason.
      final event = EventDiscovery.fromMap(feedEvent(music: [apiTrack()]));
      expect(event.copyWith(likes: 5).music, event.music);
    });
  });

  group('what a track says about itself', () {
    test('the pill names the track and the artist', () {
      expect(MusicTrack.fromMap(apiTrack())!.label, 'On the Low · Burna Boy');
    });

    test('a half-known track says what it can rather than a bare separator',
        () {
      const noArtist =
          MusicTrack(id: '1', title: 'Untitled', artist: '', streamUrl: 'u');
      const noTitle =
          MusicTrack(id: '2', title: '', artist: 'Someone', streamUrl: 'u');
      const neither = MusicTrack(id: '3', title: '', artist: '', streamUrl: 'u');

      expect(noArtist.label, 'Untitled');
      expect(noTitle.label, 'Someone');
      expect(neither.label, 'Music');
    });

    test('duration is display only and tolerates a missing value', () {
      expect(MusicTrack.fromMap(apiTrack())!.duration,
          const Duration(seconds: 185));
      const unknown =
          MusicTrack(id: '1', title: 't', artist: 'a', streamUrl: 'u');
      expect(unknown.duration, isNull);
    });
  });
}
