import 'package:flutter/foundation.dart';
import 'package:jperg_app/features/chat/data/network/chat_api_client.dart';

/// The upload size caps this server enforces.
class ChatMediaLimits {
  const ChatMediaLimits({
    required this.maxImageBytes,
    required this.maxVideoBytes,
  });

  final int maxImageBytes;
  final int maxVideoBytes;

  /// What the chat service ships with, used until the real ones arrive and
  /// whenever they can't be fetched. Matches `_DEFAULTS` in
  /// `chat/app/services/media_config.py` — keep the two in step.
  static const fallback = ChatMediaLimits(
    maxImageBytes: 10 * 1024 * 1024,
    maxVideoBytes: 10 * 1024 * 1024,
  );

  int limitFor({required bool isVideo}) =>
      isVideo ? maxVideoBytes : maxImageBytes;
}

/// Reads the server's upload caps once per session.
///
/// The caps are admin-controlled, so hardcoding them client-side means the app
/// eventually disagrees with the server — and the way it disagrees is the worst
/// case: the file uploads in full over a mobile connection and is only then
/// rejected. Asking costs one cached request.
///
/// Never throws: an unreachable config endpoint falls back to the shipped
/// defaults, which is strictly better than blocking uploads outright.
class ChatMediaLimitsService {
  ChatMediaLimitsService(this._client);

  final ChatApiClient _client;

  ChatMediaLimits? _cached;
  Future<ChatMediaLimits>? _inFlight;

  /// The current limits, fetching them the first time.
  ///
  /// Concurrent callers share one request — both pickers can ask at the same
  /// moment when a user attaches media straight after opening a room.
  Future<ChatMediaLimits> get() {
    final cached = _cached;
    if (cached != null) return Future.value(cached);
    return _inFlight ??= _fetch();
  }

  /// Whatever is already known, without waiting. Lets a picker validate
  /// immediately on a warm cache and fall back to the defaults on a cold one.
  ChatMediaLimits get current => _cached ?? ChatMediaLimits.fallback;

  Future<ChatMediaLimits> _fetch() async {
    try {
      final res = await _client.dio.get<dynamic>('/chat/config/media');
      final body = res.data;
      if (body is! Map) return ChatMediaLimits.fallback;

      final image = (body['max_image_size_mb'] as num?)?.toInt();
      final video = (body['max_video_size_mb'] as num?)?.toInt();
      final limits = ChatMediaLimits(
        maxImageBytes: (image != null && image > 0)
            ? image * 1024 * 1024
            : ChatMediaLimits.fallback.maxImageBytes,
        maxVideoBytes: (video != null && video > 0)
            ? video * 1024 * 1024
            : ChatMediaLimits.fallback.maxVideoBytes,
      );
      _cached = limits;
      return limits;
    } catch (e) {
      debugPrint('[ChatMediaLimits] could not read server limits: $e');
      return ChatMediaLimits.fallback;
    } finally {
      _inFlight = null;
    }
  }
}
