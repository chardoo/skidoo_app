import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:jperg_app/api/dio_client_service.dart';
import 'package:jperg_app/features/location/data/models/place.dart';

const _tag = '[LocationRepository]';

/// Where the country and city lists come from, and where the account's own
/// location is read and written.
///
/// The city search is proxied by the ads service rather than called directly:
/// the cache lives there, so a type-ahead costs the geocoder one lookup per
/// distinct query per week instead of one per keystroke per user, and the day
/// that provider has to be replaced it changes in one file rather than in every
/// shipped build.
class LocationRepository {
  LocationRepository({Dio? dio}) : _injected = dio;

  final Dio? _injected;

  /// Resolved on first use rather than in the constructor, so a subclass that
  /// overrides every call — a fake in a widget test — never has to stand up
  /// the shared client just to exist.
  Dio? _resolved;
  Dio get _dio => _resolved ??= (_injected ?? Api().dio);

  /// The provider only prefix-matches from three characters up, but still
  /// matches a short name exactly — and Ho is the capital of the Volta Region.
  /// One character is nobody's search.
  static const minQuery = 2;

  /// Every country, for the first step of the picker. Cached for the session:
  /// it is a constant, and re-fetching it each time the sheet opens is a
  /// request that can only ever return the same few kilobytes.
  static List<Place>? _countries;

  /// Drop the session cache. For tests, which would otherwise inherit whatever
  /// the previous one left behind.
  @visibleForTesting
  static void resetCountriesCache() => _countries = null;

  Future<List<Place>> countries() async {
    if (_countries != null) return _countries!;
    try {
      final resp = await _dio.get('/ads/locations/countries');
      final data = resp.data;
      final rows = (data is Map ? data['data'] : data) as List<dynamic>? ?? [];
      _countries = rows
          .whereType<Map<String, dynamic>>()
          .map(Place.fromJson)
          .toList();
      debugPrint('$_tag countries — ${_countries!.length} loaded');
      return _countries!;
    } catch (e) {
      debugPrint('$_tag countries ERROR: $e');
      // Not cached, so the next open tries again rather than being stuck
      // empty for the rest of the session.
      return const [];
    }
  }

  /// Towns and cities matching what has been typed.
  ///
  /// Empty on anything that goes wrong, deliberately: this sits under a field
  /// somebody is typing into, and the list going quiet for a moment is
  /// recoverable in a way that an error banner mid-form is not.
  Future<List<Place>> search(String query, {String? countryCode}) async {
    final trimmed = query.trim();
    if (trimmed.length < minQuery) return const [];
    try {
      final resp = await _dio.get('/ads/locations/search', queryParameters: {
        'q': trimmed,
        if (countryCode != null) 'country': countryCode,
        'limit': 12,
      });
      final data = resp.data;
      final rows = (data is Map ? data['data'] : data) as List<dynamic>? ?? [];
      return rows
          .whereType<Map<String, dynamic>>()
          .map(Place.fromJson)
          .toList();
    } catch (e) {
      debugPrint('$_tag search("$trimmed") ERROR: $e');
      return const [];
    }
  }

  /// What the account has set, what the request appeared to come from, and
  /// whether those disagree. Asked on launch.
  Future<LocationContext?> context() async {
    try {
      final resp = await _dio.get('/api/location/context');
      final data = _data(resp);
      return data == null ? null : LocationContext.fromJson(data);
    } catch (e) {
      debugPrint('$_tag context ERROR: $e');
      return null;
    }
  }

  /// Store the account's own location. Throws — unlike the searches above,
  /// this one is a deliberate save and silence would look like success.
  Future<LocationContext?> setLocation(Place place) async {
    final resp = await _dio.put('/api/location', data: {
      'name': place.name,
      'country_code': place.countryCode,
      'lat': place.lat,
      'lon': place.lon,
    });
    final data = _data(resp);
    return data == null ? null : LocationContext.fromJson(data);
  }

  Future<LocationContext?> clearLocation() async {
    final resp = await _dio.delete('/api/location');
    final data = _data(resp);
    return data == null ? null : LocationContext.fromJson(data);
  }

  static Map<String, dynamic>? _data(Response resp) {
    final body = resp.data;
    if (body is Map<String, dynamic>) {
      final inner = body['data'];
      if (inner is Map<String, dynamic>) return inner;
      return body;
    }
    return null;
  }
}

/// The answer to "where does this account think it is, and is that still true".
class LocationContext {
  const LocationContext({
    required this.hasLocation,
    required this.locationMismatch,
    this.location,
    this.countryCode,
    this.lat,
    this.lon,
    this.detectedCountryCode,
  });

  final bool hasLocation;

  /// True only when the account has a location *and* the request came from
  /// somewhere else. Someone who has never set one is prompted by the empty
  /// state instead of being told they moved.
  final bool locationMismatch;

  final String? location;
  final String? countryCode;
  final double? lat;
  final double? lon;

  /// Where the server thinks the request came from. Null when it cannot tell —
  /// a private address, a provider that is down — which is a normal answer.
  final String? detectedCountryCode;

  /// The account's location as a [Place], for re-opening the picker on what
  /// was chosen last time.
  Place? get place => countryCode == null
      ? null
      : Place(
          countryCode: countryCode!,
          name: location,
          lat: lat,
          lon: lon,
        );

  factory LocationContext.fromJson(Map<String, dynamic> json) =>
      LocationContext(
        hasLocation: json['has_location'] as bool? ?? false,
        locationMismatch: json['location_mismatch'] as bool? ?? false,
        location: json['location'] as String?,
        countryCode: json['country_code'] as String?,
        lat: (json['lat'] as num?)?.toDouble(),
        lon: (json['lon'] as num?)?.toDouble(),
        detectedCountryCode: json['detected_country_code'] as String?,
      );
}
