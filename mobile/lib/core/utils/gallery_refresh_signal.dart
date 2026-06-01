import 'package:flutter/foundation.dart';

/// Global nudge to refetch the user's gallery.
///
/// Bumped whenever the set of photos the user owns changes outside the gallery
/// screen — after a successful purchase or a free save — so the gallery shows
/// the new photos without a manual pull-to-refresh or app restart.
class GalleryRefreshSignal {
  GalleryRefreshSignal._();

  /// Incremented on every change; [GalleryBloc] listens and reloads.
  static final revision = ValueNotifier<int>(0);

  static void bump() => revision.value++;
}
