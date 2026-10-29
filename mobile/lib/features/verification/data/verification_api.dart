import 'package:dio/dio.dart' as dio;
import 'package:flutter/foundation.dart';
import 'package:jperg_app/api/dio_client_service.dart';
import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/services/auth_service.dart';

/// A document somebody can verify with, as the server offers it.
///
/// Which ones appear depends on the country — the form has to say "Ghana Card"
/// rather than "National ID" to somebody in Accra — so the list is fetched
/// rather than hardcoded here. See `app/services/identity_documents.py`.
@immutable
class IdDocumentType {
  const IdDocumentType({
    required this.value,
    required this.label,
    required this.hint,
  });

  final String value;
  final String label;

  /// What the number looks like, shown in the field. The difference between
  /// somebody typing their number and somebody guessing at the format.
  final String hint;

  factory IdDocumentType.fromJson(Map<String, dynamic> json) => IdDocumentType(
        value: (json['value'] ?? '').toString(),
        label: (json['label'] ?? '').toString(),
        hint: (json['hint'] ?? '').toString(),
      );
}

/// Where somebody's own verification stands.
@immutable
class VerificationStatus {
  const VerificationStatus({
    required this.status,
    this.legalName,
    this.idType,
    this.idNumberMasked,
    this.dateOfBirth,
    this.rejectionReason,
    this.submittedAt,
  });

  /// `none` · `pending` · `approved` · `rejected`.
  final String status;

  final String? legalName;
  final String? idType;

  /// Only ever the last four. They typed it, so it is not a secret from them,
  /// but a screen printing a full ID number is a screen that can be
  /// photographed over somebody's shoulder.
  final String? idNumberMasked;

  final String? dateOfBirth;
  final String? rejectionReason;
  final DateTime? submittedAt;

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
  bool get hasSubmitted => status != 'none';

  factory VerificationStatus.fromJson(Map<String, dynamic> json) =>
      VerificationStatus(
        status: (json['status'] ?? 'none').toString(),
        legalName: json['legalName'] as String?,
        idType: json['idType'] as String?,
        idNumberMasked: json['idNumberMasked'] as String?,
        dateOfBirth: json['dateOfBirth'] as String?,
        rejectionReason: json['rejectionReason'] as String?,
        submittedAt: DateTime.tryParse((json['submittedAt'] ?? '').toString()),
      );
}

/// What was submitted, and what came back.
///
/// Details, never a photograph of the card. Ghana's NIA and Data Protection
/// Commission both treat storing an image of a Ghana Card as something a
/// private company may not casually do — so this asks for the number the way a
/// bank does, and the image upload that used to be here is gone.
class VerificationApi {
  VerificationApi({dio.Dio? client}) : _dio = client ?? sl<Api>().dio;

  final dio.Dio _dio;

  Future<List<IdDocumentType>> documentTypes({String? country}) async {
    try {
      final resp = await _dio.get(
        '/photographer/verification/id-types',
        queryParameters: {if (country != null) 'country': country},
      );
      final data = resp.data is Map ? resp.data['data'] : null;
      final types = data is Map ? data['types'] : null;
      if (types is! List) return const [];
      return [
        for (final t in types)
          if (t is Map<String, dynamic>) IdDocumentType.fromJson(t)
      ];
    } catch (e) {
      debugPrint('[Verification] documentTypes failed: $e');
      return const [];
    }
  }

  Future<VerificationStatus?> status() async {
    try {
      final resp = await _dio.get('/photographer/verification');
      final data = resp.data is Map<String, dynamic> ? resp.data : null;
      if (data == null) return null;
      // The endpoint answers the record itself, not a {data: …} envelope.
      return VerificationStatus.fromJson(
        data['data'] is Map<String, dynamic>
            ? data['data'] as Map<String, dynamic>
            : data,
      );
    } catch (e) {
      debugPrint('[Verification] status failed: $e');
      return null;
    }
  }

  /// Submits, and returns the server's complaint if it refused.
  ///
  /// Null means it went through. The message is returned rather than shown
  /// because the server is the only thing that knows *which* field was wrong —
  /// "that does not look like a valid number for that document" is worth
  /// putting in front of somebody, and a generic failure is not.
  ///
  /// **The identity details are optional and the agreements are not.** Leaving
  /// all four out is a creator accepting the terms without claiming an
  /// identity yet: the role still moves, the badge still waits. Sending some
  /// of them is refused — half an identity is nothing to check.
  ///
  /// This is also where the session's token is replaced. The role lives inside
  /// the JWT and the request board reads it from there, so an app still
  /// holding the token it signed in with is a creator the board answers as a
  /// viewer: an empty list, for the whole life of that token.
  Future<String?> submit({
    String? legalName,
    String? idType,
    String? idNumber,
    DateTime? dateOfBirth,
    String? countryCode,
    ({bool terms, bool uploadRights, bool payoutPolicy}) agreements =
        const (terms: true, uploadRights: true, payoutPolicy: true),
  }) async {
    try {
      final resp = await _dio.post('/photographer/verification', data: {
        if (legalName != null) 'legal_name': legalName.trim(),
        if (idType != null) 'id_type': idType,
        if (idNumber != null) 'id_number': idNumber.trim(),
        if (dateOfBirth != null) 'date_of_birth': _date(dateOfBirth),
        if (countryCode != null) 'country_code': countryCode,
        // Passed through rather than assumed: they are a record of what was
        // agreed to, and the server stores the three separately for the same
        // reason — one of them moving later must not silently rewrite what
        // somebody consented to.
        'accepted_terms': agreements.terms,
        'confirmed_upload_rights': agreements.uploadRights,
        'accepted_payout_policy': agreements.payoutPolicy,
      });
      await _storeToken(resp.data);
      return null;
    } on dio.DioException catch (e) {
      // The server's own words, which are the only thing that knows *which*
      // field was wrong: "that does not look like a valid number for that
      // document" is worth putting in front of somebody.
      final data = e.response?.data;
      final error = data is Map ? data['error'] : null;
      final message = error is Map ? error['message'] : null;
      return message?.toString() ??
          'We could not submit that just now. Please try again.';
    } catch (e) {
      debugPrint('[Verification] submit failed: $e');
      return 'We could not submit that just now. Please try again.';
    }
  }

  /// Replace the session's token with the one this submission answered with.
  ///
  /// The role moved server-side, and the old token still says what the account
  /// used to be. Every service behind the gateway reads the role out of the
  /// token rather than the database — the request board is photographers-only
  /// and decides that from the claim — so until this lands the app is a
  /// creator that every other service still treats as a viewer. Tokens here
  /// last for months, so "it will sort itself out at the next sign-in" is not
  /// a timescale anybody would wait through.
  ///
  /// Quiet when there is no token in the answer: an older server does not send
  /// one, and that is a session that keeps working exactly as it did before.
  Future<void> _storeToken(dynamic body) async {
    final data = body is Map && body['data'] is Map ? body['data'] : body;
    final token = data is Map ? data['token'] : null;
    if (token is! String || token.isEmpty) return;
    try {
      await sl<AuthService>().setToken(token);
    } catch (e) {
      debugPrint('[Verification] could not store the new token: $e');
    }
  }

  /// `YYYY-MM-DD`, which is what the server's `date` field parses. Not
  /// `toIso8601String()` — that carries a time the server has no use for.
  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
