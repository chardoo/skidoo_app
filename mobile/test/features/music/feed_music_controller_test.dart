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

  /// Have [play] return a Future that never resolves — which is precisely what
  /// the real just_audio player did. Its `play()` completes only when playback
  /// completes, is paused or is stopped, and the feed loops forever, so it
  /// resolved never. See the test that uses this.
  bool playNeverCompletes = false;

  final _index = StreamController<int?>.broadcast();
  final _errors = StreamController<Object>.broadcast();

  bool get isPlaying => _playing;

  /// The volume actually in force — what a listener would hear.
  double get volume => volumes.isEmpty ? 0 : volumes.last;

  @override
  Stream<int?> get currentIndexStream => _index.stream;

  @override
  Stream<Object> get errorStream => _errors.stream;

  void emitIndex(int i) => _index.add(i);

  /// What the platform reports when it cannot play something — a refused
  /// redirect, an unsupported codec, a URL that 404s.
  void emitError(Object error) => _errors.add(error);

  /// An error delivered on the index stream rather than as a value, which is
  /// how just_audio surfaces some failures.
  void emitIndexError(Object error) => _index.addError(error);

  @override
  Future<void> load(List<String> urls) async {
    if (loadError != null) throw loadError!;
    loads.add(List.of(urls));
  }

  @override
  Future<void> play() async {
    plays++;
    _playing = true;
    if (playNeverCompletes) await Completer<void>().future;
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
  _buildPhaseTests();
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

    testWidgets('the sound comes up even if play() never resolves', (t) async {
      // The bug that shipped, and the reason the feed was silent on device
      // while every test here passed.
      //
      // just_audio's play() completes "when the playback completes or is
      // paused or stopped". The feed loops with LoopMode.all, so it resolved
      // never — and the controller awaited it. Everything after that await was
      // unreachable: the pill never lit, and the fade that takes the volume off
      // zero never ran. The audio was playing perfectly, at volume zero, with
      // no error anywhere to say so.
      //
      // The fake used to resolve immediately, which is why nothing caught it.
      final player = FakePlayer()..playNeverCompletes = true;
      final music = build(player);
      addTearDown(music.dispose);

      music.claim(#cardA, 'event-1', [track('a')]);
      await settle(t);

      expect(player.isPlaying, isTrue);
      expect(player.volume, 1.0, reason: 'the fade must still have run');
      expect(music.nowPlaying.value?.eventId, 'event-1',
          reason: 'the pill must still have lit');
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

    testWidgets('a platform error clears the pill rather than lighting a lie',
        (t) async {
      // With preload:false nothing validates the source until playback starts,
      // so a failure arrives on the player's error stream after the pill is
      // already lit. A lit pill over a silent card claims something the card
      // is not doing.
      final player = FakePlayer();
      final music = build(player);
      addTearDown(music.dispose);

      music.claim(#cardA, 'event-1', [track('a')]);
      await settle(t);
      expect(music.nowPlaying.value, isNotNull);

      player.emitError(StateError('ExoPlaybackException'));
      await settle(t);

      expect(music.nowPlaying.value, isNull);
    });

    testWidgets('an error on the index stream does not escape the zone',
        (t) async {
      // A `listen` without `onError` lets a stream error become an unhandled
      // async error — fatal in debug, silent in release. Either way the
      // failure never reaches whoever has to fix it.
      final player = FakePlayer();
      final music = build(player);
      addTearDown(music.dispose);

      music.claim(#cardA, 'event-1', [track('a')]);
      await settle(t);

      player.emitIndexError(StateError('source error'));
      await settle(t);

      // Reaching here at all is the assertion: an unhandled error would have
      // failed this test.
      expect(music.nowPlaying.value, isNull);
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

// ── Publishing during build ───────────────────────────────────────────────────

void _buildPhaseTests() {
  testWidgets('claiming during build does not crash the frame', (t) async {
    // The crash that shipped. Cards call claim/release from
    // didChangeDependencies, which runs *during* build, and the controller
    // assigned nowPlaying.value there — notifying every ValueListenableBuilder
    // on the pill synchronously, each of which called setState mid-build:
    //
    //   setState() or markNeedsBuild() called during build.
    //   The widget on which setState() was called was:
    //     ValueListenableBuilder<FeedMusicNowPlaying?>
    //
    // The card being built when it fired then failed to lay out.
    final player = FakePlayer();
    final music = build(player);
    addTearDown(music.dispose);

    // Something is already playing, so the claim below genuinely *changes*
    // nowPlaying. Without this the test is vacuous: ValueNotifier skips
    // notifying when the value is unchanged, so claiming into an already-null
    // pill never reaches the listener that used to blow up.
    music.claim(#cardA, 'event-1', [track('a')]);
    await settle(t);
    expect(music.nowPlaying.value, isNotNull);

    await t.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ValueListenableBuilder<FeedMusicNowPlaying?>(
          valueListenable: music.nowPlaying,
          builder: (_, now, __) => _ClaimOnDependencies(
            onDependencies: () =>
                music.claim(#cardB, 'event-2', [track('b')]),
            label: now?.track.title ?? 'nothing',
          ),
        ),
      ),
    );
    await t.pumpAndSettle();

    expect(t.takeException(), isNull);
  });

  testWidgets('releasing during build does not crash the frame', (t) async {
    // The exact stack from the report: release() → nowPlaying.value = null.
    final player = FakePlayer();
    final music = build(player);
    addTearDown(music.dispose);

    music.claim(#cardA, 'event-1', [track('a')]);
    await settle(t);

    await t.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ValueListenableBuilder<FeedMusicNowPlaying?>(
          valueListenable: music.nowPlaying,
          builder: (_, now, __) => _ClaimOnDependencies(
            onDependencies: () => music.release(#cardA),
            label: now?.track.title ?? 'nothing',
          ),
        ),
      ),
    );
    await t.pumpAndSettle();

    expect(t.takeException(), isNull);
  });

  testWidgets('the pill still updates, just after the frame', (t) async {
    // Deferring must not mean dropping: whoever draws the pill has to end up
    // with the right value.
    final player = FakePlayer();
    final music = build(player);
    addTearDown(music.dispose);

    await t.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ValueListenableBuilder<FeedMusicNowPlaying?>(
          valueListenable: music.nowPlaying,
          builder: (_, now, __) => _ClaimOnDependencies(
            onDependencies: () =>
                music.claim(#cardA, 'event-1', [track('a')]),
            label: now?.track.title ?? 'nothing',
          ),
        ),
      ),
    );
    await settle(t);
    await t.pumpAndSettle();

    expect(music.nowPlaying.value?.eventId, 'event-1');
    expect(find.text('Track a'), findsOneWidget);
  });
}

/// Calls back from didChangeDependencies — where the real cards claim and
/// release, and the phase in which the notifier used to explode.
class _ClaimOnDependencies extends StatefulWidget {
  const _ClaimOnDependencies({
    required this.onDependencies,
    required this.label,
  });

  final VoidCallback onDependencies;
  final String label;

  @override
  State<_ClaimOnDependencies> createState() => _ClaimOnDependenciesState();
}

class _ClaimOnDependenciesState extends State<_ClaimOnDependencies> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    widget.onDependencies();
  }

  @override
  Widget build(BuildContext context) => Text(widget.label);
}
