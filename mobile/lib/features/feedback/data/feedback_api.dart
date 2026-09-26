import 'package:dio/dio.dart' as dio;
import 'package:flutter/foundation.dart';
import 'package:jperg_app/api/dio_client_service.dart';
import 'package:jperg_app/core/di/service_locator.dart';

/// Which half of the prompt an answer came from.
///
/// A rating is a verdict and carries a score; a feature request is a proposal
/// and carries sentences. They are one table on the server — see
/// `app/models/app_feedback.py` — because they arrive through one prompt.
enum FeedbackKind {
  rating('rating'),
  featureRequest('feature_request');

  const FeedbackKind(this.wire);
  final String wire;
}

class FeedbackApi {
  FeedbackApi({dio.Dio? client}) : _dio = client ?? sl<Api>().dio;

  final dio.Dio _dio;

  /// File a rating or a feature request. False means it did not land.
  ///
  /// The caller shows somebody a thank-you either way and moves on: a person
  /// who has just been generous enough to answer a prompt should not then be
  /// handed an error about it. What false is for is *not* recording it as
  /// answered, so the prompt can come back rather than the opinion being lost.
  Future<bool> submit({
    required FeedbackKind kind,
    int? rating,
    String? message,
    String? appVersion,
    String? platform,
  }) async {
    try {
      await _dio.post('/client/feedback', data: {
        'kind': kind.wire,
        if (rating != null) 'rating': rating,
        if (message != null && message.trim().isNotEmpty)
          'message': message.trim(),
        if (appVersion != null) 'app_version': appVersion,
        if (platform != null) 'platform': platform,
      });
      return true;
    } catch (e) {
      debugPrint('[Feedback] submit failed: $e');
      return false;
    }
  }

  /// When this person last gave feedback of [kind], or null.
  ///
  /// Asked because the device only knows what *it* has shown: somebody who
  /// rated the app on their old phone should not be asked again on their new
  /// one, and a reinstall is the same problem wearing a different coat.
  ///
  /// Null on any failure, which reads as "never" — the cost of that is one
  /// prompt somebody may have seen before, against the cost of the other
  /// default, which is never asking anybody anything because the network
  /// blipped once.
  Future<DateTime?> lastSubmitted(FeedbackKind kind) async {
    try {
      final resp = await _dio.get('/client/feedback/mine',
          queryParameters: {'kind': kind.wire});
      final raw = resp.data is Map ? resp.data['data'] : null;
      final value = raw is Map ? raw['lastSubmittedAt'] : null;
      return value is String ? DateTime.tryParse(value) : null;
    } catch (e) {
      debugPrint('[Feedback] lastSubmitted failed: $e');
      return null;
    }
  }
}
