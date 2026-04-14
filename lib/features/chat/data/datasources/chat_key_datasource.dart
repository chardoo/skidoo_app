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
    await _api.dio.post('/chat/keys/bundle', data: bundle.toJson());
  }

  /// Tops up the one-time prekey pool.
  Future<void> topUpPrekeys(List<OtpkEntry> prekeys) async {
    await _api.dio.post('/chat/keys/prekeys', data: {
      'one_time_prekeys': prekeys.map((e) => e.toJson()).toList(),
    });
  }

  /// Fetches [userId]'s public key bundle.
  /// The server atomically consumes one OTPK and returns it (or null if none left).
  Future<RecipientKeyBundle> fetchBundle(String userId) async {
    final res = await _api.dio.get('/chat/keys/$userId/bundle');
    return RecipientKeyBundle.fromJson(res.data as Map<String, dynamic>);
  }

  /// Returns how many one-time prekeys remain in the server pool.
  Future<int> prekeyCount() async {
    final res = await _api.dio.get('/chat/keys/me/prekeys/count');
    return (res.data['count'] as num?)?.toInt() ?? 0;
  }
}
