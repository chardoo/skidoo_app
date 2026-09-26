import 'package:dio/dio.dart' as dio;
import 'package:flutter/foundation.dart';
import 'package:jperg_app/api/dio_client_service.dart';
import 'package:jperg_app/core/di/service_locator.dart';

/// One payment, whichever service recorded it.
///
/// Money moves in three places and this is the shape all of them arrive in:
/// `main` knows what was spent on photos and what has been paid out, and the
/// ads service knows about boosts, campaigns and booking deposits. They stay
/// separate endpoints — joining across a service boundary to build one screen
/// is how two services quietly become one — and are merged here, where the
/// list is actually drawn.
@immutable
class PaymentRecord {
  const PaymentRecord({
    required this.id,
    required this.kind,
    required this.direction,
    required this.title,
    required this.amount,
    required this.currency,
    required this.status,
    this.subtitle,
    this.reference,
    this.date,
  });

  /// `purchase` · `payout` · `boost` · `campaign` · `booking`.
  final String kind;

  /// `out` for money spent, `in` for money received. A payout is the only
  /// thing coming the other way, and a history that did not say so would read
  /// as an expense.
  final String direction;

  final String id;
  final String title;
  final String? subtitle;
  final double amount;
  final String currency;

  /// `success` · `pending` · `failed` — three words, because somebody looking
  /// at their own history is asking one question with three answers. Both
  /// services collapse their own statuses to these before sending them.
  final String status;

  final String? reference;
  final DateTime? date;

  bool get isIncoming => direction == 'in';

  factory PaymentRecord.fromJson(Map<String, dynamic> json) => PaymentRecord(
        id: (json['id'] ?? '').toString(),
        kind: (json['kind'] ?? '').toString(),
        direction: (json['direction'] ?? 'out').toString(),
        title: (json['title'] ?? 'Payment').toString(),
        subtitle: json['subtitle'] as String?,
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        currency: (json['currency'] ?? 'GHS').toString(),
        status: (json['status'] ?? 'pending').toString(),
        reference: json['reference'] as String?,
        date: DateTime.tryParse((json['date'] ?? '').toString()),
      );
}

/// Fetches both halves of the history and hands back one list.
class PaymentsApi {
  PaymentsApi({dio.Dio? client}) : _dio = client ?? sl<Api>().dio;

  final dio.Dio _dio;

  /// Everything, newest first.
  ///
  /// The two calls go out together and a failure in either is survivable: a
  /// history missing its boosts is worth more than an error screen, and the
  /// far more common reason for one to fail is that the account has never
  /// touched that service at all.
  Future<List<PaymentRecord>> fetch({int page = 1, int limit = 50}) async {
    final results = await Future.wait([
      _get('/client/payments', page: page, limit: limit),
      _get('/ads/payments/mine', page: page, limit: limit),
    ]);

    final all = [...results[0], ...results[1]];
    // Merged, then sorted — the two services each order their own and know
    // nothing of the other's. Undated rows sort last rather than throwing.
    all.sort((a, b) {
      final left = a.date, right = b.date;
      if (left == null && right == null) return 0;
      if (left == null) return 1;
      if (right == null) return -1;
      return right.compareTo(left);
    });
    return all;
  }

  Future<List<PaymentRecord>> _get(String path,
      {required int page, required int limit}) async {
    try {
      final resp = await _dio.get(path, queryParameters: {
        'page': page,
        'limit': limit,
      });
      final data = resp.data is Map ? resp.data['data'] : null;
      if (data is! List) return const [];
      return [
        for (final row in data)
          if (row is Map<String, dynamic>) PaymentRecord.fromJson(row)
      ];
    } catch (e) {
      debugPrint('[Payments] $path failed: $e');
      return const [];
    }
  }
}
