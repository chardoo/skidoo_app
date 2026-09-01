import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:jperg_app/api/dio_client_service.dart';

const _tag = '[ReviewsRepository]';

/// What clients thought of a photographer.
///
/// Ratings live with the main service rather than the ads one: they are a fact
/// about the photographer, not about any request that led to them.
class ReviewsRepository {
  ReviewsRepository() : _dio = Api().dio;

  final Dio _dio;

  Future<ReviewPage> list(
    String photographerId, {
    int? stars,
    String sort = 'recent',
    int page = 1,
    int limit = 25,
  }) async {
    debugPrint('$_tag list → $photographerId stars=$stars sort=$sort');
    final resp = await _dio.get(
      '/client/photographers/$photographerId/reviews',
      queryParameters: {
        if (stars != null) 'rating': stars,
        'sort': sort,
        'page': page,
        'limit': limit,
      },
    );
    return ReviewPage.fromJson(
      resp.data is Map<String, dynamic>
          ? resp.data as Map<String, dynamic>
          : const {},
    );
  }

  /// Leave a review. Once.
  ///
  /// This used to say a second review was treated as an edit, and the screen
  /// was built on that promise. The server stopped allowing it — a rating you
  /// can keep adjusting is one a photographer's average can be walked down
  /// with — and refuses the second attempt. The app was never told, so it went
  /// on offering the form and turning the refusal into "Could not publish your
  /// review", which names neither the cause nor anything to do about it.
  ///
  /// Throws [ReviewRejected] when the server explains itself, so the screen can
  /// repeat the reason rather than invent one.
  Future<void> leave(
    String photographerId, {
    required int rating,
    String? comment,
    String? requestId,
  }) async {
    debugPrint('$_tag leave → $photographerId rating=$rating');
    try {
      await _dio.post(
        '/client/photographers/$photographerId/review',
        data: {
          'rating': rating,
          if (comment != null && comment.isNotEmpty) 'comment': comment,
          if (requestId != null) 'requestId': requestId,
        },
      );
    } on DioException catch (e) {
      final body = e.response?.data;
      final error = body is Map ? body['error'] : null;
      final message = error is Map ? error['message']?.toString() : null;
      final code = error is Map ? error['code']?.toString() : null;
      debugPrint('$_tag leave REJECTED ${e.response?.statusCode} $code');
      if (message == null || message.isEmpty) rethrow;
      throw ReviewRejected(message, code: code);
    }
  }
}

/// The server refused a review and said why.
///
/// Carries the message so the screen can show the real reason, and the code so
/// it can tell a settled state from a retryable one: `ALREADY_REVIEWED` means
/// the review is published and tapping again will never work, while anything
/// else may be worth another go.
class ReviewRejected implements Exception {
  const ReviewRejected(this.message, {this.code});

  final String message;
  final String? code;

  /// This person has already had their say. Nothing to retry.
  bool get isFinal => code == 'ALREADY_REVIEWED';

  @override
  String toString() => 'ReviewRejected($code): $message';
}

class ReviewPage {
  const ReviewPage({
    this.average,
    this.count = 0,
    this.breakdown = const {},
    this.reviews = const [],
    this.filteredTotal = 0,
  });

  final double? average;

  /// The photographer's real total, whatever filter is applied.
  final int count;

  /// How many reviews sit behind each star chip, counted over everything —
  /// so the chips can say before you tap them.
  final Map<int, int> breakdown;
  final List<Review> reviews;

  /// How many the current filter holds; the list's own count.
  final int filteredTotal;

  static const empty = ReviewPage();

  factory ReviewPage.fromJson(Map<String, dynamic> json) {
    final raw = json['breakdown'];
    final breakdown = <int, int>{};
    if (raw is Map) {
      raw.forEach((key, value) {
        final star = int.tryParse('$key');
        if (star != null) breakdown[star] = (value as num?)?.toInt() ?? 0;
      });
    }
    final pagination = json['pagination'];
    return ReviewPage(
      average: (json['ratingAverage'] as num?)?.toDouble(),
      count: (json['ratingCount'] as num?)?.toInt() ?? 0,
      breakdown: breakdown,
      reviews: (json['data'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(Review.fromJson)
          .toList(),
      filteredTotal: pagination is Map<String, dynamic>
          ? (pagination['total'] as num?)?.toInt() ?? 0
          : 0,
    );
  }
}

class Review {
  const Review({
    required this.id,
    required this.rating,
    this.comment,
    this.createdAt,
    this.clientName,
    this.clientPhotoUrl,
  });

  final String id;
  final int rating;
  final String? comment;
  final DateTime? createdAt;
  final String? clientName;
  final String? clientPhotoUrl;

  /// "2 days ago" — the design dates reviews relatively, because how long ago
  /// someone was happy matters more than the calendar day it happened.
  String get age {
    if (createdAt == null) return '';
    final days = DateTime.now().difference(createdAt!).inDays;
    if (days < 1) return 'today';
    if (days == 1) return 'yesterday';
    if (days < 7) return '$days days ago';
    if (days < 30) {
      final weeks = (days / 7).floor();
      return weeks == 1 ? '1 week ago' : '$weeks weeks ago';
    }
    if (days < 365) {
      final months = (days / 30).floor();
      return months == 1 ? '1 month ago' : '$months months ago';
    }
    final years = (days / 365).floor();
    return years == 1 ? '1 year ago' : '$years years ago';
  }

  factory Review.fromJson(Map<String, dynamic> json) {
    final client = json['client'] is Map<String, dynamic>
        ? json['client'] as Map<String, dynamic>
        : const <String, dynamic>{};
    return Review(
      id: json['id'] as String? ?? '',
      rating: (json['rating'] as num?)?.toInt() ?? 0,
      comment: json['comment'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
      clientName: client['name'] as String?,
      clientPhotoUrl: client['profile_url'] as String?,
    );
  }
}
