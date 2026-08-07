import 'package:jperg_app/api/dio_client_service.dart';
import 'package:jperg_app/services/auth_service.dart';

/// A single saved-item record returned by GET /api/client/{id}/saved.
class SavedItem {
  /// The record ID used for DELETE /api/client/{id}/saved/{saved_item_id}.
  final String savedItemId;
  final String assetType;
  final String assetId;

  /// Display title derived from the nested asset object when provided.
  final String? title;

  /// Thumbnail URL (first picture URL for events, direct URL for photos).
  final String? thumbnailUrl;

  const SavedItem({
    required this.savedItemId,
    required this.assetType,
    required this.assetId,
    this.title,
    this.thumbnailUrl,
  });

  factory SavedItem.fromJson(Map<String, dynamic> json) {
    final rawAsset = json['asset'];
    final Map<String, dynamic>? asset =
        rawAsset is Map<String, dynamic> ? rawAsset : null;
    // The server may nest under 'event' or expose fields at the top level.
    final Map<String, dynamic>? event = asset?['event'] is Map<String, dynamic>
        ? asset!['event'] as Map<String, dynamic>
        : asset;

    // Helper: first non-empty value across candidate keys in a map.
    String? firstOf(Map<String, dynamic>? m, List<String> keys) {
      if (m == null) return null;
      for (final k in keys) {
        final v = m[k];
        if (v != null && v.toString().isNotEmpty) return v.toString();
      }
      return null;
    }

    // Pictures can be under 'pictures' or 'images'.
    final rawPics = (event?['pictures'] as List<dynamic>?) ??
        (event?['images'] as List<dynamic>?);
    final String? thumb = rawPics != null && rawPics.isNotEmpty
        ? (rawPics.first as Map<String, dynamic>)['url']?.toString()
        : firstOf(asset, ['url', 'thumbnailUrl', 'thumbnail_url', 'coverUrl']);

    final title =
        firstOf(event, ['eventName', 'event_name', 'name', 'title']) ??
            firstOf(asset, ['eventName', 'event_name', 'name', 'title']);

    // assetType / assetId may be camelCase at the top level, snake_case, or only
    // present on the nested asset/event object. Falling back through all of
    // these is what keeps the title resolvable and the detail page non-empty.
    final assetType = firstOf(json, ['assetType', 'asset_type', 'type']) ??
        firstOf(asset, ['type', 'assetType']) ??
        '';
    final assetId = firstOf(json, ['assetId', 'asset_id']) ??
        firstOf(asset, ['id', '_id', 'eventId', 'event_id']) ??
        firstOf(event, ['id', '_id', 'eventId', 'event_id']) ??
        '';

    return SavedItem(
      savedItemId:
          firstOf(json, ['id', '_id', 'savedItemId', 'saved_item_id']) ?? '',
      assetType: assetType,
      assetId: assetId,
      title: title,
      thumbnailUrl: thumb,
    );
  }
}

/// Wraps the saved-items endpoints:
///
///   POST   /api/client/{id}/saved?assetType=…&assetId=…
///   GET    /api/client/{id}/saved[?assetType=…]
///   DELETE /api/client/{id}/saved/{saved_item_id}
///   DELETE /api/client/{id}/saved?assetType=…&assetId=…
class ClientSavedDataSource {
  final Api _api;
  final AuthService _authService;

  ClientSavedDataSource(this._api, this._authService);

  Future<SavedItem> saveItem({
    required String assetType,
    required String assetId,
  }) async {
    final userId = await _authService.getUserId();
    final res = await _api.dio.post(
      '/client/$userId/saved',
      queryParameters: {'assetType': assetType, 'assetId': assetId},
    );
    return SavedItem.fromJson(res.data as Map<String, dynamic>);
  }

  Future<List<SavedItem>> listSaved({String? assetType}) async {
    final userId = await _authService.getUserId();
    final res = await _api.dio.get(
      '/client/$userId/saved',
      queryParameters: {
        if (assetType != null) 'assetType': assetType,
        'page': 1,
        'limit': 25,
      },
    );
    final raw = res.data;
    final List<dynamic> list;
    if (raw is Map<String, dynamic> && raw['data'] is List) {
      list = raw['data'] as List<dynamic>;
    } else if (raw is List) {
      list = raw;
    } else {
      list = [];
    }
    return list
        .map((e) => SavedItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Removes a saved item by its record ID.
  Future<void> unsaveById(String savedItemId) async {
    final userId = await _authService.getUserId();
    await _api.dio.delete('/client/$userId/saved/$savedItemId');
  }

  /// Removes a saved item by asset type + asset ID (no record ID needed).
  Future<void> unsaveByAsset({
    required String assetType,
    required String assetId,
  }) async {
    final userId = await _authService.getUserId();
    await _api.dio.delete(
      '/client/$userId/saved',
      queryParameters: {'assetType': assetType, 'assetId': assetId},
    );
  }
}
