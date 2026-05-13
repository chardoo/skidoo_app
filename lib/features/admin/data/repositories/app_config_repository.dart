import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:skidoo_app/api/dio_client_service.dart';
import 'package:skidoo_app/features/admin/data/models/app_config.dart';
import 'package:skidoo_app/features/admin/data/models/exchange_rates.dart';

class AppConfigRepository {
  AppConfigRepository(Api api) : _dio = api.dio;

  final Dio _dio;

  /// Cached feature-flag config — safe to read before first fetch (returns defaults).
  static AppConfig current = const AppConfig();

  /// Cached exchange rates — safe to read before first fetch (returns empty defaults).
  static ExchangeRates rates = const ExchangeRates();

  // ── Public read endpoint (all users) ─────────────────────────────────────────

  Future<AppConfig> fetch() async {
    debugPrint('[AppConfig] GET /config');
    try {
      final resp = await _dio.get('/config');
      debugPrint('[AppConfig] fetch ← status=${resp.statusCode}');
      final config = AppConfig.fromJson(
        resp.data is Map<String, dynamic> ? resp.data as Map<String, dynamic> : {},
      );
      current = config;
      return config;
    } on DioException catch (e) {
      debugPrint('[AppConfig] fetch ERROR ${e.response?.statusCode} ${e.response?.data}');
      return current;
    }
  }

  Future<ExchangeRates> fetchRates() async {
    debugPrint('[AppConfig] GET /config/rates');
    try {
      final resp = await _dio.get('/config/rates');
      debugPrint('[AppConfig] fetchRates ← status=${resp.statusCode} data=${resp.data}');
      final r = ExchangeRates.fromJson(
        resp.data is Map<String, dynamic> ? resp.data as Map<String, dynamic> : {},
      );
      rates = r;
      return r;
    } on DioException catch (e) {
      debugPrint('[AppConfig] fetchRates ERROR ${e.response?.statusCode} ${e.response?.data}');
      return rates;
    }
  }

  // ── Admin-only write endpoint ─────────────────────────────────────────────────

  Future<AppConfig> update(AppConfig config) async {
    debugPrint('[AppConfig] PATCH /admin/app-config ${config.toJson()}');
    try {
      final resp = await _dio.patch('/admin/app-config', data: config.toJson());
      debugPrint('[AppConfig] update ← status=${resp.statusCode}');
      final updated = AppConfig.fromJson(
        resp.data is Map<String, dynamic>
            ? resp.data as Map<String, dynamic>
            : config.toJson(),
      );
      current = updated;
      return updated;
    } on DioException catch (e) {
      debugPrint('[AppConfig] update ERROR ${e.response?.statusCode} ${e.response?.data}');
      throw Exception('Failed to update config: ${e.response?.data ?? e.message}');
    }
  }
}
