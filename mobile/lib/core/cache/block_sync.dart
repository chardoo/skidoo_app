import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jperg_app/core/cache/deleted_content.dart';
import 'package:jperg_app/core/di/service_locator.dart';

/// Taking blocked content off this device, as soon as the device hears.
///
/// When a moderator blocks an album or a photo the server stops serving it
/// immediately — but the phone already has it. [FeedCacheService] and
/// [DiskCache] restore synchronously at launch, *before* any request goes out,
/// so blocked content is the first thing on screen on a cold start and stays
/// there until a fetch replaces the whole entry. For a takedown that is the
/// one surface where it matters most: the copy in somebody's hand.
///
/// Waiting for a 404 — which is how a *deleted* album is discovered — is too
/// slow here, because it needs the reader to tap the thing first. So the
/// server names blocked ids on requests the app is already making:
///
///     "blocked": { "events": [...], "pictures": [...], "syncedAt": "…Z" }
///
/// This holds the watermark, hands it back on the next request, and passes
/// whatever arrives to [DeletedContent.forgetAll], which prunes every cache
/// and bumps the content signal so on-screen lists drop it too.
///
/// The watermark is **persisted**, which is the whole economy of it: after the
/// first call the server has almost nothing to say, so the block rides along at
/// the cost of an index lookup and a couple of empty arrays. Without it every
/// request would re-send the same window and the phone would re-prune caches
/// it had already pruned.
class BlockSync {
  BlockSync._();

  /// Survives a launch on purpose — a block that happened while the app was
  /// closed is exactly the one a cold start would otherwise keep showing.
  static const _key = 'jperg.block_sync.watermark';

  /// Not cleared on sign-out, unlike the caches themselves.
  ///
  /// A takedown is not per-account: a different reader signing in on this
  /// phone is not a reason to be told again about content that is already gone
  /// from the disk. `DeletedContent.reset()` clears the per-session id set,
  /// which is what lets the ids be acted on again if they ever come back.
  static String? get watermark {
    if (!sl.isRegistered<SharedPreferences>()) return null;
    return sl<SharedPreferences>().getString(_key);
  }

  /// Act on a `blocked` block from any response, and remember how far we got.
  ///
  /// Shape-tolerant by design: it is handed whatever came back under
  /// `blocked`, from an endpoint whose main job was something else. A payload
  /// that is missing, null, or not a map means "nothing to do" rather than an
  /// error — losing this costs the phone a delayed purge, and it must never
  /// cost the reader the albums they asked for.
  ///
  /// Never throws.
  static Future<void> apply(dynamic blocked) async {
    if (blocked is! Map) return;
    try {
      final events = _ids(blocked['events']);
      final pictures = _ids(blocked['pictures']);

      if (events.isNotEmpty || pictures.isNotEmpty) {
        await DeletedContent.forgetAll(events: events, pictures: pictures);
      }

      // Only after the purge has run. A watermark stored first and a purge
      // that then failed would mean the ids are never offered again and the
      // content stays on the device for good.
      //
      // `more` says the server capped its answer and did *not* advance the
      // watermark — storing it would be storing the client's own value back,
      // which is harmless, but skipping the write makes the intent legible.
      final syncedAt = blocked['syncedAt'];
      if (syncedAt is String && syncedAt.isNotEmpty && blocked['more'] != true) {
        if (sl.isRegistered<SharedPreferences>()) {
          await sl<SharedPreferences>().setString(_key, syncedAt);
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[BlockSync] apply failed: $e');
    }
  }

  /// Ask outright, for the moments no list request covers.
  ///
  /// Called at launch and after a feed is restored from disk: the feeds answer
  /// with a bare array and cannot carry a sync block, and they are two of the
  /// caches that draw before anything is fetched. One small request with the
  /// stored watermark, which after the first run answers with nothing.
  ///
  /// Takes the fetcher as an argument rather than reaching for Dio, so this
  /// stays a cache concern and can be exercised without a client.
  static Future<void> pull(
    Future<Map<String, dynamic>?> Function(String? since) fetch,
  ) async {
    try {
      final payload = await fetch(watermark);
      if (payload == null) return;
      // `{success, data}` from the dedicated endpoint, or the bare block when
      // a caller has already unwrapped it.
      await apply(payload['data'] ?? payload);
    } catch (e) {
      if (kDebugMode) debugPrint('[BlockSync] pull failed: $e');
    }
  }

  static List<String> _ids(dynamic value) {
    if (value is! List) return const [];
    return value
        .map((e) => e?.toString() ?? '')
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
  }

  /// For tests, and for a signed-out launch that wants to start clean.
  static Future<void> forgetWatermark() async {
    if (!sl.isRegistered<SharedPreferences>()) return;
    await sl<SharedPreferences>().remove(_key);
  }
}
