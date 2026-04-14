import 'package:skidoo_app/api/dio_client_service.dart';
import 'package:skidoo_app/services/auth_service.dart';

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
    final Map<String, dynamic>? event =
        asset?['event'] is Map<String, dynamic>
            ? asset!['event'] as Map<String, dynamic>
            : asset;
    final pictures = event?['pictures'] as List<dynamic>?;
    final String? thumb = pictures != null && pictures.isNotEmpty
        ? (pictures.first as Map<String, dynamic>)['url']?.toString()
        : asset?['url']?.toString();

    return SavedItem(
      savedItemId: json['id']?.toString() ?? '',
      assetType: json['assetType']?.toString() ?? '',
      assetId: json['assetId']?.toString() ?? '',
      title: event?['eventName']?.toString() ??
          event?['name']?.toString() ??
          asset?['name']?.toString(),
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
      queryParameters:
          assetType != null ? {'assetType': assetType} : null,
    );
    final list = res.data as List<dynamic>? ?? [];
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
