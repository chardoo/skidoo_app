import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

/// The audio engine, reduced to what the feed actually asks of it.
///
/// Two reasons this is an interface rather than a bare [AudioPlayer]:
///
/// * [FeedMusicController] holds every playback rule worth testing — focus,
///   video slides, mute, lifecycle — and none of them should need a platform
///   channel to exercise. A fake implementing this plays a whole feed in a
///   widget test.
/// * It is the second thing that would change if the audio package ever did,
///   and it keeps that change out of the controller.
abstract class FeedMusicPlayer {
  /// Queue [urls] and make the first one current, without starting playback.
  ///
  /// The list is a soundtrack in the order the photographer chose. Playing
  /// past the end returns to the start — a card held long enough to exhaust
  /// the queue keeps playing rather than falling silent.
  Future<void> load(List<String> urls);

  Future<void> play();
  Future<void> pause();

  /// 0.0 to 1.0. Set directly rather than ramped — [FeedMusicController] owns
  /// the fade, because it is the thing that knows what a fade is for.
  Future<void> setVolume(double volume);

  /// Which entry of the last [load] is playing, so a pill can name it. Null
  /// before anything is queued.
  Stream<int?> get currentIndexStream;

  Future<void> dispose();
}

/// [FeedMusicPlayer] on top of `just_audio`.
class JustAudioFeedMusicPlayer implements FeedMusicPlayer {
  JustAudioFeedMusicPlayer({AudioPlayer? player})
      : _player = player ?? AudioPlayer();

  final AudioPlayer _player;

  /// What is currently queued, so re-claiming the same event does not tear
  /// down and re-buffer audio that is already loaded and playing.
  List<String>? _loaded;

  @override
  Stream<int?> get currentIndexStream => _player.currentIndexStream;

  @override
  Future<void> load(List<String> urls) async {
    if (_loaded != null && listEquals(_loaded, urls)) return;
    _loaded = List.unmodifiable(urls);

    // LoopMode.all over the whole queue: with one track it repeats that track,
    // with several it cycles them. Either way the card never goes quiet on its
    // own — which matters more than usual here, because the stand-in provider
    // serves 30-second previews and almost every card outlives one.
    await _player.setLoopMode(LoopMode.all);
    await _player.setAudioSource(
      ConcatenatingAudioSource(
        children: [
          for (final url in urls) AudioSource.uri(Uri.parse(url)),
        ],
      ),
      // Queued, not started. The controller decides when sound begins, and it
      // has gates to check first.
      preload: false,
    );
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> setVolume(double volume) => _player.setVolume(volume);

  @override
  Future<void> dispose() async {
    _loaded = null;
    await _player.dispose();
  }
}
