import 'package:dio/dio.dart' as dio;
import 'package:jperg_app/api/dio_client_service.dart';
import 'package:jperg_app/core/error/exceptions.dart' as app_ex;

/// The premium tier's terms, as the server states them.
///
/// Every number here is read rather than written into the app. The rules page
/// quotes these back to somebody before they agree to be held to them, and copy
/// that hardcodes "48 hours" is how the terms and the enforcement drift apart —
/// the first anybody notices being an argument with a creator who has just been
/// demoted.
///
/// [name] is read for the same reason: the tier is still being named, and a
/// build that ships the word would render one thing while the server and the
/// admin panel say another.
class PremiumTerms {
  const PremiumTerms({
    required this.name,
    required this.enabled,
    required this.joiningOpen,
    required this.deliveryHours,
    required this.strikeLimit,
    required this.strikeWindowDays,
    required this.cooldownDays,
    required this.termsVersion,
  });

  final String name;
  final bool enabled;
  final bool joiningOpen;
  final int deliveryHours;
  final int strikeLimit;
  final int strikeWindowDays;
  final int cooldownDays;
  final int termsVersion;

  /// The window as somebody would say it out loud: "48 hours", "3 days".
  ///
  /// Hours up to and including 48, days beyond it. Two reasons for the break
  /// being there rather than at 24: the rule itself is written and argued about
  /// as "48 hours", so rendering it as "2 days" on the screen where somebody
  /// agrees to it would state the promise in words nobody else uses — and past
  /// that, "72 hours" is a number people have to convert before it means
  /// anything.
  ///
  /// Anything that is not a whole number of days stays in hours. Rounding 36
  /// up to "2 days" would describe the promise as longer than it is.
  String get windowLabel {
    if (deliveryHours > 48 && deliveryHours % 24 == 0) {
      return '${deliveryHours ~/ 24} days';
    }
    return '$deliveryHours hours';
  }

  String get cooldownLabel {
    if (cooldownDays % 30 == 0 && cooldownDays >= 30) {
      final months = cooldownDays ~/ 30;
      return months == 1 ? 'a month' : '$months months';
    }
    return '$cooldownDays days';
  }

  static const fallback = PremiumTerms(
    name: 'Premium',
    enabled: false,
    joiningOpen: false,
    deliveryHours: 48,
    strikeLimit: 2,
    strikeWindowDays: 180,
    cooldownDays: 90,
    termsVersion: 1,
  );

  factory PremiumTerms.fromJson(Map<String, dynamic> json) => PremiumTerms(
        name: (json['name'] as String?)?.trim().isNotEmpty == true
            ? json['name'] as String
            : fallback.name,
        enabled: json['enabled'] as bool? ?? false,
        joiningOpen: json['joining_open'] as bool? ?? false,
        deliveryHours: (json['delivery_hours'] as num?)?.toInt() ?? 48,
        strikeLimit: (json['strike_limit'] as num?)?.toInt() ?? 2,
        strikeWindowDays: (json['strike_window_days'] as num?)?.toInt() ?? 180,
        cooldownDays: (json['cooldown_days'] as num?)?.toInt() ?? 90,
        termsVersion: (json['terms_version'] as num?)?.toInt() ?? 1,
      );
}

/// Where this account stands with the tier.
class PremiumStatus {
  const PremiumStatus({
    required this.terms,
    required this.member,
    required this.canJoin,
    required this.needsReaccept,
    this.reason,
    this.since,
    this.blockedUntil,
    this.onTime = 0,
    this.late = 0,
    this.score,
  });

  final PremiumTerms terms;
  final bool member;
  final bool canJoin;

  /// True when the terms moved under an existing member. They stay a member —
  /// and stay held to the version they agreed to — until they accept the new
  /// one.
  final bool needsReaccept;

  /// Why joining is refused, when it is: `disabled`, `closed`, `not_creator`,
  /// `already`, `cooling_down`.
  final String? reason;

  final DateTime? since;
  final DateTime? blockedUntil;

  final int onTime;
  final int late;

  /// 0–100, or null before there is any record to speak of. Null is not zero:
  /// a creator who has taken no premium work yet has no record, and showing
  /// them as 0 would say something false about them.
  final double? score;

  bool get coolingDown => reason == 'cooling_down';

  static DateTime? _date(Object? value) =>
      value is String ? DateTime.tryParse(value)?.toLocal() : null;

  factory PremiumStatus.fromJson(Map<String, dynamic> json) {
    final delivery = json['delivery'] as Map<String, dynamic>? ?? const {};
    return PremiumStatus(
      terms: PremiumTerms.fromJson(
        json['terms'] as Map<String, dynamic>? ?? const {},
      ),
      member: json['member'] as bool? ?? false,
      canJoin: json['can_join'] as bool? ?? false,
      needsReaccept: json['needs_reaccept'] as bool? ?? false,
      reason: json['reason'] as String?,
      since: _date(json['since']),
      blockedUntil: _date(json['blocked_until']),
      onTime: (delivery['on_time'] as num?)?.toInt() ?? 0,
      late: (delivery['late'] as num?)?.toInt() ?? 0,
      score: (delivery['score'] as num?)?.toDouble(),
    );
  }
}

/// Joining the premium tier, leaving it, and reading where you stand.
class PremiumService {
  PremiumService(this._api);

  final Api _api;

  Future<PremiumStatus> status() => _wrap(() async {
        final res = await _api.dio.get('/photographer/premium');
        return PremiumStatus.fromJson(
          (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
        );
      });

  /// Accept the terms and take the badge.
  ///
  /// The version is sent back so the server can refuse a stale screen —
  /// somebody who opened the rules while an admin was changing the window must
  /// not be able to agree to terms that no longer exist.
  Future<PremiumStatus> join(int termsVersion) => _wrap(() async {
        final res = await _api.dio.post(
          '/photographer/premium/join',
          data: {'terms_version': termsVersion},
        );
        return PremiumStatus.fromJson(
          (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
        );
      });

  /// Agree to terms that changed under an existing member.
  Future<PremiumStatus> acceptTerms(int termsVersion) => _wrap(() async {
        final res = await _api.dio.post(
          '/photographer/premium/accept-terms',
          data: {'terms_version': termsVersion},
        );
        return PremiumStatus.fromJson(
          (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
        );
      });

  Future<PremiumStatus> leave() => _wrap(() async {
        final res = await _api.dio.delete('/photographer/premium');
        return PremiumStatus.fromJson(
          (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
        );
      });

  /// This account's own delivery record — including, deliberately, the misses.
  /// Somebody being held to a promise is entitled to see what they are being
  /// judged on before the judgement, not after it.
  Future<List<PremiumDeliveryRow>> history() => _wrap(() async {
        final res = await _api.dio.get('/photographer/premium/history');
        final rows = (res.data as Map<String, dynamic>)['data'] as List<dynamic>;
        return rows
            .map((r) => PremiumDeliveryRow.fromJson(r as Map<String, dynamic>))
            .toList();
      });

  Future<T> _wrap<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on dio.DioException catch (err) {
      if (err.response == null) throw const app_ex.NetworkException();
      // The server's own sentence where there is one. These refusals are
      // written to be read — "You can join again on 2026-12-24" is the whole
      // answer, and replacing it with a status code would lose it.
      final data = err.response?.data;
      final message = data is Map<String, dynamic>
          ? (data['error'] is Map<String, dynamic>
              ? (data['error'] as Map<String, dynamic>)['message'] as String?
              : data['message'] as String?)
          : null;
      throw app_ex.ServerException(message ?? 'Something went wrong.');
    } catch (e) {
      if (e is app_ex.NetworkException || e is app_ex.ServerException) rethrow;
      throw app_ex.ServerException('Unexpected error: $e');
    }
  }
}

/// One resolved delivery, or one change of membership.
class PremiumDeliveryRow {
  const PremiumDeliveryRow({
    required this.outcome,
    this.dueAt,
    this.deliveredAt,
    this.hoursFromDue,
    this.counted = true,
    this.note,
    this.at,
  });

  /// `on_time` | `late` | `missed` | `demoted` | `left` | `restored`.
  final String outcome;
  final DateTime? dueAt;
  final DateTime? deliveredAt;
  final double? hoursFromDue;

  /// False on outcomes recorded while the tier was switched off. They are kept
  /// for the record and count against nobody.
  final bool counted;
  final String? note;
  final DateTime? at;

  static DateTime? _date(Object? v) =>
      v is String ? DateTime.tryParse(v)?.toLocal() : null;

  factory PremiumDeliveryRow.fromJson(Map<String, dynamic> json) =>
      PremiumDeliveryRow(
        outcome: json['outcome'] as String? ?? 'missed',
        dueAt: _date(json['due_at']),
        deliveredAt: _date(json['delivered_at']),
        hoursFromDue: (json['hours_from_due'] as num?)?.toDouble(),
        counted: json['counted'] as bool? ?? true,
        note: json['note'] as String?,
        at: _date(json['at']),
      );
}
