import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart' as dio;
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:saver_gallery/saver_gallery.dart';

import 'package:jperg_app/features/user_profile/data/owned_events.dart';

/// Saving a whole album to the camera roll, one file at a time, in the
/// background.
///
/// "Background" here means **it keeps going while the app is used**: the
/// download is owned by this singleton rather than by the screen that started
/// it, so leaving the album, switching tabs, or opening a photo does not
/// cancel it, and coming back shows it still running. It does *not* survive
/// the app being killed — that needs a foreground service on Android and
/// BGTaskScheduler on iOS, which is a different piece of work and is
/// deliberately not pretended at here.
///
/// Serial, not parallel. Saving sixty full-resolution originals at once on a
/// mobile connection is how you get a stalled queue and a device that drops
/// half of them; one at a time finishes sooner in practice and gives a
/// progress number that means something.
///
/// Progress is a [ValueNotifier] so any widget can watch it — the album
/// screen draws a bar, and the tab that launched it can draw one too without
/// either of them owning the work.
@immutable
class AlbumDownloadProgress {
  const AlbumDownloadProgress({
    this.eventId = '',
    this.eventName = '',
    this.total = 0,
    this.saved = 0,
    this.failed = 0,
    this.running = false,
    this.cancelled = false,
  });

  final String eventId;
  final String eventName;
  final int total;
  final int saved;

  /// Files that could not be saved. Counted rather than aborting the run: one
  /// unreachable photo in sixty is not a reason to deny somebody the other
  /// fifty-nine, and the count is reported at the end so the failure is not
  /// silent either.
  final int failed;

  final bool running;
  final bool cancelled;

  int get done => saved + failed;

  /// 0.0–1.0, or null when there is nothing to measure yet. Null rather than
  /// zero so the bar can be indeterminate before the first file lands.
  double? get fraction => total == 0 ? null : done / total;

  bool get isIdle => !running && total == 0;
  bool get finished => !running && total > 0;

  AlbumDownloadProgress copyWith({
    String? eventId,
    String? eventName,
    int? total,
    int? saved,
    int? failed,
    bool? running,
    bool? cancelled,
  }) =>
      AlbumDownloadProgress(
        eventId: eventId ?? this.eventId,
        eventName: eventName ?? this.eventName,
        total: total ?? this.total,
        saved: saved ?? this.saved,
        failed: failed ?? this.failed,
        running: running ?? this.running,
        cancelled: cancelled ?? this.cancelled,
      );
}

class AlbumDownloader {
  AlbumDownloader._();

  static final AlbumDownloader instance = AlbumDownloader._();

  /// The live state of the one run in flight, if any.
  static final progress =
      ValueNotifier<AlbumDownloadProgress>(const AlbumDownloadProgress());

  final _client = dio.Dio();
  bool _cancelRequested = false;

  /// Ask the OS once, before the run rather than per file.
  ///
  /// Per file would put sixty prompts in front of somebody on the first
  /// album they ever save. The answer is not checked for "granted" because
  /// the plugin's answer differs across Android versions and iOS — a refusal
  /// surfaces as the save failing, which is counted and reported, and that
  /// is a better outcome than refusing to start on a permission model we
  /// guessed wrong about.
  Future<void> _requestPermission() async {
    try {
      await [Permission.storage, Permission.photos].request();
    } catch (e) {
      debugPrint('[AlbumDownload] permission request failed: $e');
    }
  }

  /// Save one photo to the camera roll. Returns false rather than throwing.
  Future<bool> saveOne(OwnedPhoto photo, {String albumName = ''}) async {
    try {
      final res = await _client.get<List<int>>(
        photo.downloadUrl,
        options: dio.Options(responseType: dio.ResponseType.bytes),
      );
      final bytes = res.data;
      if (bytes == null || bytes.isEmpty) return false;

      final stamp = DateTime.now().millisecondsSinceEpoch;
      final name = photo.filename.isNotEmpty
          ? photo.filename
          : 'jperg_${photo.id}_$stamp';

      if (photo.isVideo) {
        // Videos take a different call, and that call takes a path rather
        // than bytes: SaverGallery.saveImage writes an image record, and a
        // video pushed through it lands in the gallery as something the
        // photo app will not play. So the bytes go to a temp file first.
        final dir = await getTemporaryDirectory();
        final temp = File('${dir.path}/$name');
        await temp.writeAsBytes(bytes, flush: true);
        try {
          await SaverGallery.saveFile(
            filePath: temp.path,
            fileName: name,
            androidRelativePath: 'Movies',
            skipIfExists: false,
          );
        } finally {
          // The camera roll has its own copy by now; leaving ours behind
          // would double the disk cost of every album saved.
          try {
            await temp.delete();
          } catch (_) {}
        }
        return true;
      }

      await SaverGallery.saveImage(
        Uint8List.fromList(bytes),
        quality: 100,
        fileName: name,
        androidRelativePath: 'Pictures',
        skipIfExists: false,
      );
      return true;
    } catch (e) {
      debugPrint('[AlbumDownload] ${photo.id} failed: $e');
      return false;
    }
  }

  /// Stop after the file currently in flight.
  ///
  /// Not mid-file: a half-written image in the camera roll is worse than one
  /// extra complete one, and the wait is a single file long.
  void cancel() {
    if (!progress.value.running) return;
    _cancelRequested = true;
    progress.value = progress.value.copyWith(cancelled: true);
  }

  /// Clear a finished run's state, so the bar goes away.
  void reset() {
    if (progress.value.running) return;
    progress.value = const AlbumDownloadProgress();
  }

  /// Save every photo in [photos]. Returns when the run ends.
  ///
  /// Refuses to start a second run while one is going: two albums saving at
  /// once would share one progress bar and neither number would mean
  /// anything.
  Future<AlbumDownloadProgress> downloadAll(
    List<OwnedPhoto> photos, {
    required String eventId,
    required String eventName,
  }) async {
    if (progress.value.running) return progress.value;

    final savable = photos;

    _cancelRequested = false;
    progress.value = AlbumDownloadProgress(
      eventId: eventId,
      eventName: eventName,
      total: savable.length,
      running: true,
    );

    if (savable.isEmpty) {
      progress.value = progress.value.copyWith(running: false);
      return progress.value;
    }

    await _requestPermission();

    for (final photo in savable) {
      if (_cancelRequested) break;
      final ok = await saveOne(photo, albumName: eventName);
      progress.value = progress.value.copyWith(
        saved: progress.value.saved + (ok ? 1 : 0),
        failed: progress.value.failed + (ok ? 0 : 1),
      );
    }

    progress.value = progress.value.copyWith(running: false);
    _cancelRequested = false;
    return progress.value;
  }
}
