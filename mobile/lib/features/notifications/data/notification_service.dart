import 'package:dio/dio.dart' as dio;
import 'package:flutter/foundation.dart';
import 'package:jperg_app/core/error/exceptions.dart';
import 'package:jperg_app/API/dio_client_service.dart';
import 'package:jperg_app/core/deep_links/deep_link.dart';
import 'package:jperg_app/core/di/service_locator.dart';

const _tag = '[Notifications]';

/// One row of the notification list.
///
/// The same event the push notification described, kept so it can be read
/// later. Preferences deliberately do not suppress these — someone who muted a
/// category should still find the item here rather than lose the history along
/// with the buzz. See main/app/services/notify.py.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.data,
    required this.isRead,
    required this.createdAt,
  });

  final String id;
  final String type;
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final bool isRead;
  final DateTime createdAt;

  /// Where tapping this should go, or null if this build has no screen for it.
  ///
  /// The row carries the same `data` block the push did, which is what makes
  /// the list and the notification land in the same place instead of two.
  DeepLink? get destination => parsePushPayload(data);

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      data: switch (json['data']) {
        final Map<String, dynamic> m => m,
        // Older rows were written with a JSON string rather than an object,
        // and a few have null. Neither should throw on a list that is mostly
        // fine.
        _ => const <String, dynamic>{},
      },
      isRead: json['isRead'] == true,
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '')?.toLocal() ??
              DateTime.now(),
    );
  }

  AppNotification copyWith({bool? isRead}) => AppNotification(
        id: id,
        type: type,
        title: title,
        body: body,
        data: data,
        isRead: isRead ?? this.isRead,
        createdAt: createdAt,
      );
}

/// Reads and updates the notification inbox.
///
/// These endpoints have existed on the backend since the Notification table
/// was added; nothing in the app had ever called them.
class NotificationApi {
  Future<List<AppNotification>> list({int page = 1, int limit = 20}) async {
    final response = await sl<Api>().dio.get(
      '/notifications',
      queryParameters: {'page': page, 'limit': limit},
    );
    final rows = (response.data?['data'] as List?) ?? const [];
    return rows
        .whereType<Map<String, dynamic>>()
        .map(AppNotification.fromJson)
        .toList();
  }

  Future<int> unreadCount() async {
    final response = await sl<Api>().dio.get('/notifications/unread-count');
    return (response.data?['count'] as num?)?.toInt() ?? 0;
  }

  /// Best-effort: a read receipt that fails must not stop the tap from
  /// opening what it was pointing at.
  Future<void> markRead(String id) async {
    try {
      await sl<Api>().dio.patch('/notifications/$id/read');
    } catch (e) {
      debugPrint('$_tag markRead failed for $id: $e');
    }
  }

  Future<void> markAllRead() async {
    try {
      await sl<Api>().dio.patch('/notifications/read-all');
    } catch (e) {
      debugPrint('$_tag markAllRead failed: $e');
    }
  }

  Future<void> delete(String id) async {
    await sl<Api>().dio.delete('/notifications/$id');
  }
}

/// Which categories this person still wants to be interrupted about.
///
/// Mirrors NotificationPreference on the backend. Absence of a stored row
/// means every default, which is all of them on — so this never has to
/// represent "unknown".
class NotificationPreferences {
  const NotificationPreferences({
    this.photos = true,
    this.purchases = true,
    this.bookings = true,
    this.social = true,
    this.likes = true,
    this.comments = true,
    this.follows = true,
    this.chat = true,
    this.marketing = true,
  });

  final bool photos;
  final bool purchases;
  final bool bookings;

  /// What is left of the social group once likes, comments and follows are
  /// taken out of it — reviews, and anything social added later with no
  /// switch of its own.
  final bool social;

  /// The three the settings screen offers separately. One column could not
  /// answer three switches: turning off likes silenced comments and new
  /// followers with it.
  final bool likes;
  final bool comments;
  final bool follows;

  final bool chat;
  final bool marketing;

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    bool read(String key) => json[key] != false;
    return NotificationPreferences(
      photos: read('photos'),
      purchases: read('purchases'),
      bookings: read('bookings'),
      social: read('social'),
      likes: read('likes'),
      comments: read('comments'),
      follows: read('follows'),
      chat: read('chat'),
      marketing: read('marketing'),
    );
  }

  bool byName(String name) => switch (name) {
        'photos' => photos,
        'purchases' => purchases,
        'bookings' => bookings,
        'social' => social,
        'likes' => likes,
        'comments' => comments,
        'follows' => follows,
        'chat' => chat,
        'marketing' => marketing,
        _ => true,
      };
}

class NotificationPreferencesApi {
  Future<NotificationPreferences> fetch() async {
    try {
      final response = await sl<Api>().dio.get('/notifications/preferences');
      final body = response.data;
      // Checked rather than assumed. `body['data']` on anything that is not a
      // map — an HTML error page from a proxy, a string, an empty 200 — throws
      // a NoSuchMethodError, which is an Error and not an Exception, so it
      // sailed past every `catch (e)` that tests for one and surfaced as a
      // blank "could not load".
      if (body is! Map) {
        debugPrint(
            '[NotificationPrefs] GET returned ${body.runtimeType}: $body');
        throw ServerException(
            'Unexpected response from the server (${body.runtimeType}).');
      }
      final data = body['data'];
      return data is Map<String, dynamic>
          ? NotificationPreferences.fromJson(data)
          : const NotificationPreferences();
    } on dio.DioException catch (err) {
      // Said out loud rather than swallowed into "could not load". Which of
      // these it is decides what to do about it, and a screen that reports
      // every failure with one sentence cannot tell anybody which.
      final status = err.response?.statusCode;
      final body = err.response?.data;
      debugPrint('[NotificationPrefs] GET failed — status=$status body=$body');
      if (err.response == null) throw const NetworkException();
      final error = body is Map ? body['error'] : null;
      final message = error is Map ? error['message'] : null;
      throw ServerException(
        message is String
            ? message
            : 'Notification settings unavailable (HTTP $status).',
      );
    }
  }

  /// Sends only the toggle that changed — the endpoint patches, so the other
  /// five keep whatever they were.
  Future<NotificationPreferences> update(String category, bool value) async {
    try {
      final response = await sl<Api>().dio.patch(
        '/notifications/preferences',
        data: {category: value},
      );
      final body = response.data;
      if (body is! Map) {
        debugPrint(
            '[NotificationPrefs] PATCH returned ${body.runtimeType}: $body');
        throw ServerException(
            'Unexpected response from the server (${body.runtimeType}).');
      }
      final data = body['data'];
      return data is Map<String, dynamic>
          ? NotificationPreferences.fromJson(data)
          : const NotificationPreferences();
    } on dio.DioException catch (err) {
      final status = err.response?.statusCode;
      debugPrint('[NotificationPrefs] PATCH $category failed — status=$status '
          'body=${err.response?.data}');
      if (err.response == null) throw const NetworkException();
      final body = err.response?.data;
      final error = body is Map ? body['error'] : null;
      final message = error is Map ? error['message'] : null;
      throw ServerException(
        message is String ? message : 'Could not save that (HTTP $status).',
      );
    }
  }
}
