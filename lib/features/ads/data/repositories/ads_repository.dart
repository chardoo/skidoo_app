import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:skidoo_app/API/dio_client_service.dart';
import 'package:skidoo_app/features/ads/data/models/ad_model.dart';
import 'package:skidoo_app/features/ads/data/models/feed_request_model.dart';

const _tag = '[AdsRepository]';

class AdsRepository {
  AdsRepository() {
    debugPrint('$_tag init — using shared Api dio (baseUrl: ${Api().dio.options.baseUrl})');
    _dio = Api().dio;
  }

  late final Dio _dio;

  static T? _unwrap<T>(Response resp) {
    final body = resp.data;
    debugPrint('$_tag _unwrap — status: ${resp.statusCode} body: $body');
    if (body is Map<String, dynamic> && body['data'] != null) {
      return body['data'] as T?;
    }
    if (body is T) return body;
    debugPrint('$_tag _unwrap — could not unwrap, returning null');
    return null;
  }

  static List<T> _unwrapList<T>(Response resp) {
    final data = _unwrap<dynamic>(resp);
    if (data is List) return data.whereType<T>().toList();
    if (data is Map && data['results'] is List) {
      return (data['results'] as List).whereType<T>().toList();
    }
    debugPrint('$_tag _unwrapList — no list found in response');
    return [];
  }

  // ── Consumer side ─────────────────────────────────────────────────────────

  Future<AdModel?> serveAd({
    String placement = 'event_feed',
    String? contextEventType,
    String? contextLocation,
    String? contextEventId,
  }) async {
    debugPrint('$_tag serveAd → placement=$placement');
    try {
      final resp = await _dio.get('/ads/serve', queryParameters: {
        'placement': placement,
        if (contextEventType != null) 'context_event_type': contextEventType,
        if (contextLocation != null) 'context_location': contextLocation,
        if (contextEventId != null) 'context_event_id': contextEventId,
      });
      debugPrint('$_tag serveAd ← status=${resp.statusCode} data=${resp.data}');
      final data = _unwrap<Map<String, dynamic>>(resp);
      if (data == null) {
        debugPrint('$_tag serveAd — no ad returned (null data)');
        return null;
      }
      final ad = AdModel.fromJson(data);
      debugPrint('$_tag serveAd — parsed ad: id=${ad.adId} headline="${ad.headline}"');
      return ad;
    } catch (e, st) {
      debugPrint('$_tag serveAd ERROR: $e\n$st');
      return null;
    }
  }

  Future<void> trackImpression({
    required String adId,
    required String adsetId,
    required String campaignId,
    required String placement,
    required String impressionToken,
    String? contextEventId,
  }) async {
    if (adId.isEmpty || campaignId.isEmpty) {
      debugPrint('$_tag trackImpression skipped — empty adId or campaignId');
      return;
    }
    debugPrint('$_tag trackImpression → adId=$adId placement=$placement');
    try {
      final resp = await _dio.post('/ads/track/impression', data: {
        'ad_id': adId,
        'adset_id': adsetId,
        'campaign_id': campaignId,
        'placement': placement,
        'impression_token': impressionToken,
        if (contextEventId != null) 'context_event_id': contextEventId,
      });
      debugPrint('$_tag trackImpression ← status=${resp.statusCode}');
    } catch (e, st) {
      debugPrint('$_tag trackImpression ERROR: $e\n$st');
    }
  }

  Future<void> trackClick({
    required String adId,
    required String campaignId,
    String? impressionId,
  }) async {
    if (adId.isEmpty || campaignId.isEmpty) {
      debugPrint('$_tag trackClick skipped — empty adId or campaignId');
      return;
    }
    debugPrint('$_tag trackClick → adId=$adId');
    try {
      final resp = await _dio.post('/ads/track/click', data: {
        'ad_id': adId,
        'campaign_id': campaignId,
        if (impressionId != null) 'impression_id': impressionId,
      });
      debugPrint('$_tag trackClick ← status=${resp.statusCode}');
    } catch (e, st) {
      debugPrint('$_tag trackClick ERROR: $e\n$st');
    }
  }

  Future<void> trackConversion({
    required String adId,
    required String campaignId,
    String? impressionId,
  }) async {
    debugPrint('$_tag trackConversion → adId=$adId');
    try {
      final resp = await _dio.post('/ads/track/conversion', data: {
        'ad_id': adId,
        'campaign_id': campaignId,
        if (impressionId != null) 'impression_id': impressionId,
      });
      debugPrint('$_tag trackConversion ← status=${resp.statusCode}');
    } catch (e, st) {
      debugPrint('$_tag trackConversion ERROR: $e\n$st');
    }
  }

  // ── Request board ─────────────────────────────────────────────────────────

  Future<List<FeedRequestModel>> getRequests({
    String? eventType,
    String? location,
    int page = 1,
    int limit = 20,
  }) async {
    debugPrint('$_tag getRequests → page=$page limit=$limit eventType=$eventType');
    try {
      final resp = await _dio.get('/ads/requests', queryParameters: {
        if (eventType != null) 'event_type': eventType,
        if (location != null) 'location': location,
        'page': page,
        'limit': limit,
      });
      debugPrint('$_tag getRequests ← status=${resp.statusCode} data=${resp.data}');
      final list = _unwrapList<Map<String, dynamic>>(resp)
          .map(FeedRequestModel.fromJson)
          .toList();
      debugPrint('$_tag getRequests — parsed ${list.length} requests');
      return list;
    } catch (e, st) {
      debugPrint('$_tag getRequests ERROR: $e\n$st');
      return [];
    }
  }

  Future<FeedRequestModel?> getRequest(String requestId) async {
    debugPrint('$_tag getRequest → id=$requestId');
    try {
      final resp = await _dio.get('/ads/requests/$requestId');
      debugPrint('$_tag getRequest ← status=${resp.statusCode}');
      final data = _unwrap<Map<String, dynamic>>(resp);
      if (data == null) return null;
      return FeedRequestModel.fromJson(data);
    } catch (e, st) {
      debugPrint('$_tag getRequest ERROR: $e\n$st');
      return null;
    }
  }

  Future<List<FeedRequestModel>> getMyRequests() async {
    debugPrint('$_tag getMyRequests');
    try {
      final resp = await _dio.get('/ads/requests/mine');
      debugPrint('$_tag getMyRequests ← status=${resp.statusCode}');
      return _unwrapList<Map<String, dynamic>>(resp)
          .map(FeedRequestModel.fromJson)
          .toList();
    } catch (e, st) {
      debugPrint('$_tag getMyRequests ERROR: $e\n$st');
      return [];
    }
  }

  Future<String> postRequest({
    required String title,
    required String description,
    required String eventType,
    required String location,
    double? budgetAmount,
    String currency = 'USD',
  }) async {
    debugPrint('$_tag postRequest → title="$title" eventType=$eventType location=$location budget=$budgetAmount $currency');
    final resp = await _dio.post('/ads/requests', data: {
      'title': title,
      'description': description,
      'event_type': eventType,
      'location': location,
      if (budgetAmount != null) 'budget_amount': budgetAmount,
      'currency': currency,
    });
    debugPrint('$_tag postRequest ← status=${resp.statusCode} data=${resp.data}');
    final data = _unwrap<Map<String, dynamic>>(resp) ?? {};
    final id = data['id'] as String? ?? '';
    debugPrint('$_tag postRequest — created request id=$id');
    return id;
  }

  Future<void> uploadRequestAsset(String requestId, String filePath) async {
    debugPrint('$_tag uploadRequestAsset → requestId=$requestId path=$filePath');
    final fileName = filePath.split('/').last;
    final ext = fileName.split('.').last.toLowerCase();
    final mime = ext == 'png' ? 'image/png' : 'image/jpeg';
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        filePath,
        filename: fileName,
        contentType: MediaType.parse(mime),
      ),
    });
    final resp = await _dio.post(
      '/ads/requests/$requestId/asset',
      data: formData,
    );
    debugPrint('$_tag uploadRequestAsset ← status=${resp.statusCode}');
  }

  Future<void> closeRequest(String requestId, {required String status}) async {
    debugPrint('$_tag closeRequest → id=$requestId status=$status');
    final resp = await _dio.post(
      '/ads/requests/$requestId/close',
      queryParameters: {'status': status},
    );
    debugPrint('$_tag closeRequest ← status=${resp.statusCode}');
  }

  Future<Map<String, dynamic>> promoteRequest(String requestId) async {
    debugPrint('$_tag promoteRequest → id=$requestId');
    final resp = await _dio.post('/ads/requests/$requestId/promote');
    debugPrint('$_tag promoteRequest ← status=${resp.statusCode} data=${resp.data}');
    return _unwrap<Map<String, dynamic>>(resp) ?? {};
  }

  // ── Campaign management ───────────────────────────────────────────────────

  Future<Map<String, dynamic>> createCampaign({
    required String name,
    required String objective,
    required double budgetAmount,
    String currency = 'USD',
    String? startAt,
    String? endAt,
  }) async {
    debugPrint('$_tag createCampaign → name="$name" objective=$objective budget=$budgetAmount $currency');
    final resp = await _dio.post('/ads/campaigns', data: {
      'name': name,
      'objective': objective,
      'budget_amount': budgetAmount,
      'currency': currency,
      if (startAt != null) 'start_at': startAt,
      if (endAt != null) 'end_at': endAt,
    });
    debugPrint('$_tag createCampaign ← status=${resp.statusCode} data=${resp.data}');
    final result = _unwrap<Map<String, dynamic>>(resp) ?? {};
    debugPrint('$_tag createCampaign — campaign_id=${result['id']}');
    return result;
  }

  Future<Map<String, dynamic>> createAdSet({
    required String campaignId,
    required String name,
    required String placement,
    required double dailyBudget,
    required String bidType,
    required double bidAmount,
    required String audience,
    List<String> eventTypes = const [],
    List<String> locations = const [],
  }) async {
    debugPrint('$_tag createAdSet → campaignId=$campaignId placement=$placement audience=$audience');
    final resp = await _dio.post('/ads/campaigns/$campaignId/adsets', data: {
      'name': name,
      'placement': placement,
      'daily_budget': dailyBudget,
      'bid_type': bidType,
      'bid_amount': bidAmount,
      'targeting': {
        'audience': audience,
        if (eventTypes.isNotEmpty) 'event_types': eventTypes,
        if (locations.isNotEmpty) 'locations': locations,
      },
    });
    debugPrint('$_tag createAdSet ← status=${resp.statusCode} data=${resp.data}');
    final result = _unwrap<Map<String, dynamic>>(resp) ?? {};
    debugPrint('$_tag createAdSet — adset_id=${result['id']}');
    return result;
  }

  Future<Map<String, dynamic>> createAd({
    required String adsetId,
    required String headline,
    required String body,
    required String mediaType,
    required String ctaText,
    required String ctaUrl,
  }) async {
    debugPrint('$_tag createAd → adsetId=$adsetId headline="$headline" mediaType=$mediaType');
    final resp = await _dio.post('/ads/adsets/$adsetId/ads', data: {
      'headline': headline,
      'body': body,
      'media_type': mediaType,
      'cta_text': ctaText,
      'cta_url': ctaUrl,
    });
    debugPrint('$_tag createAd ← status=${resp.statusCode} data=${resp.data}');
    final result = _unwrap<Map<String, dynamic>>(resp) ?? {};
    debugPrint('$_tag createAd — ad_id=${result['id']}');
    return result;
  }

  Future<String> payCampaign(String campaignId) async {
    debugPrint('$_tag payCampaign → campaignId=$campaignId');
    final resp = await _dio.post('/ads/campaigns/$campaignId/pay');
    debugPrint('$_tag payCampaign ← status=${resp.statusCode} data=${resp.data}');
    final data = _unwrap<Map<String, dynamic>>(resp) ?? {};
    final url = data['authorization_url'] as String? ?? '';
    debugPrint('$_tag payCampaign — authorization_url=$url');
    return url;
  }

  Future<String> topUpCampaign(String campaignId, double amount) async {
    debugPrint('$_tag topUpCampaign → campaignId=$campaignId amount=$amount');
    final resp = await _dio.post(
      '/ads/campaigns/$campaignId/topup',
      queryParameters: {'amount': amount},
    );
    debugPrint('$_tag topUpCampaign ← status=${resp.statusCode} data=${resp.data}');
    final data = _unwrap<Map<String, dynamic>>(resp) ?? {};
    return data['authorization_url'] as String? ?? '';
  }

  Future<List<Map<String, dynamic>>> getMyCampaigns() async {
    debugPrint('$_tag getMyCampaigns');
    try {
      final resp = await _dio.get('/ads/campaigns');
      debugPrint('$_tag getMyCampaigns ← status=${resp.statusCode}');
      return _unwrapList<Map<String, dynamic>>(resp);
    } catch (e, st) {
      debugPrint('$_tag getMyCampaigns ERROR: $e\n$st');
      return [];
    }
  }

  Future<Map<String, dynamic>> getCampaign(String campaignId) async {
    debugPrint('$_tag getCampaign → id=$campaignId');
    final resp = await _dio.get('/ads/campaigns/$campaignId');
    debugPrint('$_tag getCampaign ← status=${resp.statusCode}');
    return _unwrap<Map<String, dynamic>>(resp) ?? {};
  }
}
