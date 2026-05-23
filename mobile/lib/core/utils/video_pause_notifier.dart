import 'dart:async';

/// Broadcast sink that any `VideoPlayerController` holder can listen to.
/// Call [pauseAll] whenever the user switches tabs — all registered video
/// states will pause their controller.
class VideoPauseNotifier {
  VideoPauseNotifier._();

  static final _controller = StreamController<void>.broadcast();

  /// Fire to request every active video to pause.
  static void pauseAll() => _controller.add(null);

  /// Subscribe; cancel the returned subscription in dispose().
  static StreamSubscription<void> listen(void Function() onPause) =>
      _controller.stream.listen((_) => onPause());
}
