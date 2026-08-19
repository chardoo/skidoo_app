import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/features/music/domain/entities/music_track.dart';
import 'package:jperg_app/features/music/presentation/feed_music_controller.dart';
import 'package:jperg_app/features/music/presentation/feed_music_player.dart';

/// Records what the engine was asked to do, so the rules can be asserted
/// without a platform channel.
class FakePlayer implements FeedMusicPlayer {
  final List<List<String>> loads = [];
  final List<double> volumes = [];
  int plays = 0;
  int pauses = 0;
  bool disposed = false;

  /// Whether sound is running right now. Tracked as state rather than derived
  /// from the counts: a claim pauses before it starts, so plays and pauses
  /// legitimately tie while audible.
  bool _playing = false;

  /// Set to have [load] throw, standing in for a dead URL or an outage.
  Object? loadError;

  final _index = StreamController<int?>.broadcast();

  bool get isPlaying => _playing;

  /// The volume actually in force — what a listener would hear.
  double get volume => volumes.isEmpty ? 0 : volumes.last;

  @override
  Stream<int?> get currentIndexStream => _index.stream;

  void emitIndex(int i) => _index.add(i);

  @override
  Future<void> load(List<String> urls) async {
    if (loadError != null) throw loadError!;
    loads.add(List.of(urls));
  }

  @override
  Future<void> play() async {
    plays++;
    _playing = true;
  }

  @override
  Future<void> pause() async {
    pauses++;
    _playing = false;
  }

  @override
  Future<void> setVolume(double volume) async => volumes.add(volume);

  @override
  Future<void> dispose() async {
    disposed = true;
    await _index.close();
  }
}

MusicTrack track(String id, {String url = ''}) => MusicTrack(
      id: id,
      title: 'Track $id',
      artist: 'Artist $id',
      streamUrl: url.isEmpty ? 'https://cdn.test/$id.mp3' : url,
    );

const _settle = Duration(milliseconds: 10);

FeedMusicController build(FakePlayer player, {List<bool>? persisted}) =>
    FeedMusicController(
      player: player,
      settleDelay: _settle,
      // Ramping is orthogonal to every rule under test, and stepping a timer
      // through eight slices in each one would only obscure them.
      fadeDuration: Duration.zero,
      persistMuted: persisted == null
          ? null
          : (muted) async => persisted.add(muted),
    );

/// Let the settle timer fire and the async start run to completion.
Future<void> settle(WidgetTester t) async {
  await t.pump(_settle);
  await t.pumpAndSettle();
}

void main() {
  group('claiming', () {
    testWidgets('a claimed card plays its soundtrack', (t) async {
      final player = FakePlayer();
      final music = build(player);
      addTearDown(music.dispose);

      music.claim(#cardA, 'event-1', [track('a')]);
      await settle(t);

      expect(player.loads, [
        ['https://cdn.test/a.mp3']
      ]);
      expect(player.isPlaying, isTrue);
      expect(music.nowPlaying.value?.eventId, 'event-1');
    });

    testWidgets('nothing starts before the card has settled', (t) async {
      final player = FakePlayer();
      final music = build(player);
      addTearDown(music.dispose);

      music.claim(#cardA, 'event-1', [track('a')]);
      // Mid-flick: the card is in focus but the thumb has not stopped.
      await t.pump(const Duration(milliseconds: 5));

      expect(player.loads, isEmpty, reason: 'must not load until settled');
      expect(player.isPlaying, isFalse);

      await settle(t);
      expect(player.isPlaying, isTrue);
    });

    testWidgets('flicking through cards costs one load, not one per card',
        (t) async {
      final player = FakePlayer();
      final music = build(player);
      addTearDown(music.dispose);

      // Ten cards go by under the settle delay — the debounce this exists for.
      for (var i = 0; i < 10; i++) {
        music.claim(#card, 'event-$i', [track('$i')]);
        await t.pump(const Duration(milliseconds: 2));
      }
      await settle(t);

      expect(player.loads, hasLength(1));
      expect(player.loads.single.single, contains('9'),
          reason: 'the card actually landed on is the one that plays');
    });

    testWidgets('an unscored event plays nothing at all', (t) async {
      final player = FakePlayer();
      final music = build(player);
      addTearDown(music.dispose);

      music.claim(#cardA, 'event-1', const []);
      await settle(t);

      expect(player.loads, isEmpty);
      expect(player.isPlaying, isFalse);
      expect(music.nowPlaying.value, isNull);
    });

    testWidgets('re-claiming the same event does not restart it', (t) async {
      final player = FakePlayer();
      final music = build(player);
      addTearDown(music.dispose);

      music.claim(#cardA, 'event-1', [track('a')]);
      await settle(t);
      final playsAfterFirst = player.plays;

      // What every rebuild does — the card recomputes its desire and pushes it.
      music.claim(#cardA, 'event-1', [track('a')]);
      await settle(t);

      expect(player.plays, playsAfterFirst);
      expect(player.loads, hasLength(1));
    });
  });

  group('releasing', () {
    testWidgets('a released card goes silent', (t) async {
      final player = FakePlayer();
      final music = build(player);
      addTearDown(music.dispose);

      music.claim(#cardA, 'event-1', [track('a')]);
      await settle(t);
      expect(player.isPlaying, isTrue);

      music.release(#cardA);
      await t.pumpAndSettle();

      expect(player.isPlaying, isFalse);
      expect(music.nowPlaying.value, isNull);
    });

    testWidgets('an outgoing card cannot silence the incoming one', (t) async {
      // The ordering hazard the ownership guard exists for: swiping A → B
      // fires both cards' handlers, and if A's release lands *after* B's claim
      // an unguarded controller would stop the music B just started — silence
      // on every second swipe.
      final player = FakePlayer();
      final music = build(player);
      addTearDown(music.dispose);

      music.claim(#cardA, 'event-1', [track('a')]);
      await settle(t);

      music.claim(#cardB, 'event-2', [track('b')]);
      music.release(#cardA); // arrives late, from the card that lost focus
      await settle(t);

      expect(player.isPlaying, isTrue, reason: 'B must still be playing');
      expect(music.nowPlaying.value?.eventId, 'event-2');
    });

    testWidgets('releasing a card that never held the sound changes nothing',
        (t) async {
      final player = FakePlayer();
      final music = build(player);
      addTearDown(music.dispose);

      music.claim(#cardA, 'event-1', [track('a')]);
      await settle(t);

      music.release(#somebodyElse);
      await t.pumpAndSettle();

      expect(player.isPlaying, isTrue);
      expect(music.nowPlaying.value?.eventId, 'event-1');
    });
  });

  group('mute', () {
    testWidgets('muting silences without stopping the track', (t) async {
      final player = FakePlayer();
      final music = build(player);
      addTearDown(music.dispose);

      music.claim(#cardA, 'event-1', [track('a')]);
      await settle(t);
      expect(player.volume, 1);

      await music.setMuted(true);

      expect(player.volume, 0);
      // The distinction that makes unmuting land where the sound would have
      // been rather than restarting it.
      expect(player.isPlaying, isTrue);
      expect(music.nowPlaying.value, isNotNull,
          reason: 'the pill stays, showing the muted icon');
    });

    testWidgets('mute carries to the next card', (t) async {
      final player = FakePlayer();
      final music = build(player);
      addTearDown(music.dispose);

      music.claim(#cardA, 'event-1', [track('a')]);
      await settle(t);
      await music.setMuted(true);

      music.claim(#cardB, 'event-2', [track('b')]);
      await settle(t);

      expect(player.volume, 0, reason: 'a muted feed stays muted');
      expect(player.isPlaying, isTrue);
    });

    testWidgets('the choice is handed to storage once per change', (t) async {
      final player = FakePlayer();
      final persisted = <bool>[];
      final music = build(player, persisted: persisted);
      addTearDown(music.dispose);

      await music.toggleMute();
      await music.toggleMute();
      // Already unmuted — nothing changed, so nothing is written.
      await music.setMuted(false);

      expect(persisted, [true, false]);
    });

    testWidgets('a restored preference applies to the first card', (t) async {
      final player = FakePlayer();
      final music = build(player);
      addTearDown(music.dispose);

      music.restoreMuted(true);
      music.claim(#cardA, 'event-1', [track('a')]);
      await settle(t);

      expect(music.muted.value, isTrue);
      expect(player.volume, 0);
    });
  });

  group('multi-track soundtracks', () {
    testWidgets('the whole selection is queued in the creator\'s order',
        (t) async {
      final player = FakePlayer();
      final music = build(player);
      addTearDown(music.dispose);

      music.claim(#cardA, 'event-1', [track('a'), track('b'), track('c')]);
      await settle(t);

      expect(player.loads.single, [
        'https://cdn.test/a.mp3',
        'https://cdn.test/b.mp3',
        'https://cdn.test/c.mp3',
      ]);
      expect(music.nowPlaying.value?.track.id, 'a');
    });

    testWidgets('the pill follows the queue as it advances', (t) async {
      final player = FakePlayer();
      final music = build(player);
      addTearDown(music.dispose);

      music.claim(#cardA, 'event-1', [track('a'), track('b')]);
      await settle(t);
      expect(music.nowPlaying.value?.track.id, 'a');

      player.emitIndex(1);
      await t.pumpAndSettle();

      expect(music.nowPlaying.value?.track.id, 'b');
    });

    testWidgets('a track with no stream URL is dropped, not queued',
        (t) async {
      final player = FakePlayer();
      final music = build(player);
      addTearDown(music.dispose);

      music.claim(#cardA, 'event-1', [
        const MusicTrack(id: 'x', title: 'T', artist: 'A', streamUrl: ''),
        track('b'),
      ]);
      await settle(t);

      expect(player.loads.single, ['https://cdn.test/b.mp3']);
    });
  });

  group('failure', () {
    testWidgets('an unplayable soundtrack leaves the card quiet, not broken',
        (t) async {
      final player = FakePlayer()..loadError = StateError('404');
      final music = build(player);
      addTearDown(music.dispose);

      music.claim(#cardA, 'event-1', [track('a')]);
      await settle(t);

      expect(player.isPlaying, isFalse);
      // No pill: music is decoration, and there is nothing the viewer asked
      // for or could act on.
      expect(music.nowPlaying.value, isNull);
    });

    testWidgets('a later card still plays after an earlier one failed',
        (t) async {
      final player = FakePlayer()..loadError = StateError('404');
      final music = build(player);
      addTearDown(music.dispose);

      music.claim(#cardA, 'event-1', [track('a')]);
      await settle(t);

      player.loadError = null;
      music.claim(#cardB, 'event-2', [track('b')]);
      await settle(t);

      expect(player.isPlaying, isTrue);
      expect(music.nowPlaying.value?.eventId, 'event-2');
    });
  });

  group('app lifecycle', () {
    testWidgets('backgrounding stops the sound and returning resumes it',
        (t) async {
      final player = FakePlayer();
      final music = build(player);
      addTearDown(music.dispose);

      music.claim(#cardA, 'event-1', [track('a')]);
      await settle(t);
      expect(player.isPlaying, isTrue);

      music.didChangeAppLifecycleState(AppLifecycleState.paused);
      await t.pumpAndSettle();
      expect(player.isPlaying, isFalse);

      music.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await t.pumpAndSettle();
      expect(player.isPlaying, isTrue,
          reason: 'the card is still on screen — it should still be playing');
    });

    testWidgets('a transient inactive state is ignored', (t) async {
      // Control centre, a permission sheet. Cutting the music for these and
      // not restoring it reads as a bug.
      final player = FakePlayer();
      final music = build(player);
      addTearDown(music.dispose);

      music.claim(#cardA, 'event-1', [track('a')]);
      await settle(t);

      music.didChangeAppLifecycleState(AppLifecycleState.inactive);
      await t.pumpAndSettle();

      expect(player.isPlaying, isTrue);
    });

    testWidgets('nothing starts while the app is backgrounded', (t) async {
      final player = FakePlayer();
      final music = build(player);
      addTearDown(music.dispose);

      music.didChangeAppLifecycleState(AppLifecycleState.paused);
      music.claim(#cardA, 'event-1', [track('a')]);
      await settle(t);

      expect(player.isPlaying, isFalse);
    });
  });
}
