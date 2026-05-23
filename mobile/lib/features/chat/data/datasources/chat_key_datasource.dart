import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:skidoo_app/api/dio_client_service.dart';
import 'package:skidoo_app/services/e2ee_service.dart';

/// Communicates with the server's key-management endpoints:
///
///   POST /chat/keys/bundle        — publish / rotate IK + SPK + OPKs
///   POST /chat/keys/prekeys       — top up one-time prekey pool
///   GET  /chat/keys/{userId}/bundle — fetch a recipient's bundle (consumes OTPK)
///   GET  /chat/keys/me/prekeys/count — remaining OTPK count
class ChatKeyDataSource {
  final Api _api;
  ChatKeyDataSource(this._api);

  /// Publishes (or rotates) the full key bundle for the current user.
  Future<void> publishBundle(PublishableKeyBundle bundle) async {
    try {
      await _api.dio.post('/chat/keys/bundle', data: bundle.toJson());
    } on DioException catch (e) {
      final body = e.response?.data;
      throw Exception('publishBundle ${e.response?.statusCode}: $body');
    }
  }

  /// Tops up the one-time prekey pool.
  Future<void> topUpPrekeys(List<OtpkEntry> prekeys) async {
    try {
      await _api.dio.post('/chat/keys/prekeys', data: {
        'oneTimePreKeys': prekeys.map((e) => e.toJson()).toList(),
      });
    } on DioException catch (e) {
      final body = e.response?.data;
      throw Exception('topUpPrekeys ${e.response?.statusCode}: $body');
    }
  }

  /// Fetches [userId]'s public key bundle.
  /// The server atomically consumes one OTPK and returns it (or null if none left).
  /// Returns null if the recipient has not yet published a bundle.
  Future<RecipientKeyBundle?> fetchBundle(String userId) async {
    try {
      final res = await _api.dio.get('/chat/keys/$userId/bundle');
      final data = res.data;
      if (data == null) {
        debugPrint('[E2EE] fetchBundle: server returned null for $userId');
        return null;
      }
      if (data is! Map<String, dynamic>) {
        debugPrint('[E2EE] fetchBundle: unexpected response type ${data.runtimeType} for $userId');
        return null;
      }
      // Server wraps the bundle: { userId, bundle: {...}|null, e2eAvailable: bool }
      final e2eAvailable = data['e2eAvailable'] as bool? ?? false;
      if (!e2eAvailable) {
        debugPrint('[E2EE] fetchBundle: recipient $userId has not published E2EE keys');
        return null;
      }
      final bundleData = data['bundle'];
      if (bundleData == null || bundleData is! Map<String, dynamic>) {
        debugPrint('[E2EE] fetchBundle: bundle field is null/invalid for $userId');
        return null;
      }
      return RecipientKeyBundle.fromJson(bundleData);
    } on DioException catch (e) {
      final body = e.response?.data;
      throw Exception('fetchBundle ${e.response?.statusCode}: $body');
    }
  }

  /// Returns how many one-time prekeys remain in the server pool.
  Future<int> prekeyCount() async {
    final res = await _api.dio.get('/chat/keys/me/prekeys/count');
    return (res.data['oneTimePreKeysRemaining'] as num?)?.toInt() ?? 0;
  }

  // ── Group sender keys ──────────────────────────────────────────────────────

  /// GET /chat/keys/groups/{roomId}/sender-keys
  /// Returns each member's sender key (encrypted for us) together with their
  /// identity key public (needed to decrypt + to re-encrypt our key for them).
  Future<List<GroupSenderKeyEntry>> fetchGroupSenderKeys(String roomId) async {
    try {
      final res = await _api.dio.get('/chat/keys/groups/$roomId/sender-keys');
      final data = res.data;
      final List<dynamic> list;
      if (data is List) {
        list = data;
      } else if (data is Map<String, dynamic>) {
        // Server wraps the array — try common field names.
        final wrapped = data['distributions'] ?? data['senderKeys'] ?? data['keys'] ?? data['data'];
        list = wrapped is List ? wrapped : [];
      } else {
        list = [];
      }
      return list
          .whereType<Map<String, dynamic>>()
          .map(GroupSenderKeyEntry.fromJson)
          .toList();
    } on DioException catch (e) {
      throw Exception('fetchGroupSenderKeys ${e.response?.statusCode}: ${e.response?.data}');
    }
  }

  /// POST /chat/keys/groups/{roomId}/sender-keys
  /// Distributes our sender key, encrypted once per remaining member.
  Future<void> distributeGroupSenderKey(
      String roomId, List<GroupSenderKeyRecipient> recipients) async {
    try {
      await _api.dio.post(
        '/chat/keys/groups/$roomId/sender-keys',
        data: {
          'distributions': recipients.map((r) => r.toJson()).toList(),
        },
      );
    } on DioException catch (e) {
      throw Exception('distributeGroupSenderKey ${e.response?.statusCode}: ${e.response?.data}');
    }
  }
}

// ── Models ─────────────────────────────────────────────────────────────────────

/// One entry from GET /chat/keys/groups/{roomId}/sender-keys.
class GroupSenderKeyEntry {
  final String userId;      // sender_id from server
  final String encryptedKey; // message field from server — encrypted sender key

  const GroupSenderKeyEntry({
    required this.userId,
    required this.encryptedKey,
  });

  factory GroupSenderKeyEntry.fromJson(Map<String, dynamic> json) =>
      GroupSenderKeyEntry(
        userId: json['sender_id'] as String,
        encryptedKey: json['message'] as String,
      );
}

/// One per-recipient entry inside POST /chat/keys/groups/{roomId}/sender-keys.
class GroupSenderKeyRecipient {
  final String userId;
  final String encryptedKey; // our sender key encrypted for this recipient

  const GroupSenderKeyRecipient({
    required this.userId,
    required this.encryptedKey,
  });

  Map<String, dynamic> toJson() => {
        'recipient_id': userId,
        'message': encryptedKey,
      };
}
