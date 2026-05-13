import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:skidoo_app/API/dio_client_service.dart';
import 'package:skidoo_app/features/ads/data/models/ad_model.dart';
import 'package:skidoo_app/features/ads/data/models/feed_request_model.dart';
import 'package:skidoo_app/features/ads/models/ad.dart';
import 'package:skidoo_app/features/ads/models/ad_campaign.dart';
import 'package:skidoo_app/features/ads/models/ad_set.dart';

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
    if (data is Map) {
      // Try every common pagination key the API might use
      for (final key in const [
        'results', 'requests', 'campaigns', 'ads', 'items', 'data'
      ]) {
        if (data[key] is List) {
          debugPrint('$_tag _unwrapList — found list under key "$key"');
          return (data[key] as List).whereType<T>().toList();
        }
      }
    }
    debugPrint('$_tag _unwrapList — no list found. body type=${data.runtimeType} keys=${data is Map ? data.keys.toList() : "n/a"}');
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
      debugPrint('$_tag serveAd ← status=${resp.statusCode}');
      debugPrint('$_tag serveAd RAW BODY: ${resp.data}');

      // Extract the ad map — handle both {data: {...}} and {data: [{...}]} shapes
      Map<String, dynamic>? data;
      final body = resp.data;
      if (body is Map<String, dynamic>) {
        final raw = body['data'];
        if (raw is Map<String, dynamic>) {
          data = raw;
        } else if (raw is List && raw.isNotEmpty) {
          data = raw.first as Map<String, dynamic>?;
        }
        // If data key is missing, try the body itself as a flat ad object
        if (data == null && body.containsKey('id')) data = body;
      }

      debugPrint('$_tag serveAd UNWRAPPED keys: ${data?.keys.toList()}');

      if (data == null || data.isEmpty) {
        debugPrint('$_tag serveAd — no ad returned (null/empty data)');
        return null;
      }

      final ad = AdModel.fromJson(data);
      debugPrint(
        '$_tag serveAd PARSED: adId="${ad.adId}" headline="${ad.headline}" '
        'mediaType=${ad.mediaType} mediaUrl=${ad.mediaUrl} '
        'advertiserName="${ad.advertiserName}" placement="${ad.placement}"',
      );
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
      debugPrint('$_tag getRequests ← status=${resp.statusCode}');
      debugPrint('$_tag getRequests RAW BODY type=${resp.data.runtimeType}');
      // Log the body — truncate at 800 chars so it always shows in the terminal
      final bodyStr = resp.data.toString();
      debugPrint('$_tag getRequests RAW BODY: ${bodyStr.length > 800 ? '${bodyStr.substring(0, 800)}…' : bodyStr}');

      final rawList = _unwrapList<Map<String, dynamic>>(resp);
      debugPrint('$_tag getRequests — parsed ${rawList.length} raw items');

      final list = rawList.map(FeedRequestModel.fromJson).toList();
      for (final r in list) {
        debugPrint('$_tag getRequests item: id=${r.id} status=${r.status} title="${r.title}" visibleTo=${r.visibleTo}');
      }
      debugPrint('$_tag getRequests — returning ${list.length} requests');

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
    bool commentsEnabled = true,
  }) async {
    debugPrint('$_tag postRequest → title="$title" eventType=$eventType location=$location budget=$budgetAmount $currency commentsEnabled=$commentsEnabled');
    final resp = await _dio.post('/ads/requests', data: {
      'title': title,
      'description': description,
      'event_type': eventType,
      'location': location,
      if (budgetAmount != null) 'budget_amount': budgetAmount,
      'currency': currency,
      'comments_enabled': commentsEnabled,
    });
    debugPrint('$_tag postRequest ← status=${resp.statusCode} data=${resp.data}');
    final data = _unwrap<Map<String, dynamic>>(resp) ?? {};
    final id = data['id'] as String? ?? '';
    debugPrint('$_tag postRequest — created request id=$id');
    return id;
  }

  static String _mimeFor(String ext, bool isVideo) {
    if (!isVideo) {
      return switch (ext) {
        'png' => 'image/png',
        'gif' => 'image/gif',
        'webp' => 'image/webp',
        _ => 'image/jpeg',
      };
    }
    return switch (ext) {
      'mov' => 'video/quicktime',
      'avi' => 'video/x-msvideo',
      'webm' => 'video/webm',
      _ => 'video/mp4',
    };
  }

  Future<void> uploadRequestAsset(String requestId, String filePath) async {
    debugPrint('$_tag uploadRequestAsset → requestId=$requestId path=$filePath');
    final fileName = filePath.split('/').last;
    final ext = fileName.split('.').last.toLowerCase();
    final isVideo = ['mp4', 'mov', 'avi', 'webm', 'm4v'].contains(ext);
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        filePath,
        filename: fileName,
        contentType: MediaType.parse(_mimeFor(ext, isVideo)),
      ),
    });
    final resp = await _dio.post(
      '/ads/requests/$requestId/asset',
      data: formData,
    );
    debugPrint('$_tag uploadRequestAsset ← status=${resp.statusCode}');
  }

  Future<void> uploadAdCreative(
      String adId, String filePath, bool isVideo) async {
    debugPrint('$_tag uploadAdCreative → adId=$adId path=$filePath isVideo=$isVideo');
    final fileName = filePath.split('/').last;
    final ext = fileName.split('.').last.toLowerCase();
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        filePath,
        filename: fileName,
        contentType: MediaType.parse(_mimeFor(ext, isVideo)),
      ),
    });
    final resp = await _dio.post('/ads/ads/$adId/media', data: formData);
    debugPrint('$_tag uploadAdCreative ← status=${resp.statusCode}');
  }

  Future<FeedRequestModel> updateRequest(
    String requestId, {
    String? title,
    String? description,
    String? eventType,
    String? location,
    double? budgetAmount,
    bool? commentsEnabled,
  }) async {
    debugPrint('$_tag updateRequest → id=$requestId title=$title location=$location commentsEnabled=$commentsEnabled');
    final resp = await _dio.patch('/ads/requests/$requestId', data: {
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (eventType != null) 'event_type': eventType,
      if (location != null) 'location': location,
      if (budgetAmount != null) 'budget_amount': budgetAmount,
      if (commentsEnabled != null) 'comments_enabled': commentsEnabled,
    });
    debugPrint('$_tag updateRequest ← status=${resp.statusCode}');
    final data = _unwrap<Map<String, dynamic>>(resp) ?? {};
    return FeedRequestModel.fromJson(data);
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

  Future<AdCampaign> createCampaign({
    required String name,
    required String objective,
    required double budgetAmount,
    String currency = 'GHS',
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
    final data = _unwrap<Map<String, dynamic>>(resp) ?? {};
    debugPrint('$_tag createCampaign — campaign_id=${data['id']}');
    return AdCampaign.fromJson(data);
  }

  Future<AdSet> createAdSet({
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
    final data = _unwrap<Map<String, dynamic>>(resp) ?? {};
    debugPrint('$_tag createAdSet — adset_id=${data['id']}');
    return AdSet.fromJson(data);
  }

  Future<Ad> createAd({
    required String adsetId,
    required String headline,
    required String body,
    required String mediaType,
    required String ctaText,
    required String ctaUrl,
    bool commentsEnabled = true,
  }) async {
    debugPrint('$_tag createAd → adsetId=$adsetId headline="$headline" mediaType=$mediaType commentsEnabled=$commentsEnabled');
    final resp = await _dio.post('/ads/adsets/$adsetId/ads', data: {
      'headline': headline,
      'body': body,
      'media_type': mediaType,
      'cta_text': ctaText,
      'cta_url': ctaUrl,
      'comments_enabled': commentsEnabled,
    });
    debugPrint('$_tag createAd ← status=${resp.statusCode} data=${resp.data}');
    final data = _unwrap<Map<String, dynamic>>(resp) ?? {};
    debugPrint('$_tag createAd — ad_id=${data['id']}');
    return Ad.fromJson(data);
  }

  Future<({String authorizationUrl, String reference, double amountGhs, double originalAmount, String originalCurrency})>
      payCampaign(String campaignId) async {
    debugPrint('$_tag payCampaign → campaignId=$campaignId');
    final resp = await _dio.post('/ads/campaigns/$campaignId/pay');
    debugPrint('$_tag payCampaign ← status=${resp.statusCode} data=${resp.data}');
    final data = _unwrap<Map<String, dynamic>>(resp) ?? {};
    final url = data['authorization_url'] as String? ?? '';
    final ref = data['reference'] as String? ?? '';
    final amountGhs = (data['amount_ghs'] as num?)?.toDouble() ?? 0.0;
    final originalAmount = (data['original_amount'] as num?)?.toDouble() ?? 0.0;
    final originalCurrency = data['original_currency'] as String? ?? '';
    debugPrint('$_tag payCampaign — url=$url ref=$ref amountGhs=$amountGhs originalAmount=$originalAmount $originalCurrency');
    return (
      authorizationUrl: url,
      reference: ref,
      amountGhs: amountGhs,
      originalAmount: originalAmount,
      originalCurrency: originalCurrency,
    );
  }

  Future<({String authorizationUrl, String reference, double amountGhs, double originalAmount, String originalCurrency})>
      topUpCampaign(String campaignId, double amount) async {
    debugPrint('$_tag topUpCampaign → campaignId=$campaignId amount=$amount');
    final resp = await _dio.post(
      '/ads/campaigns/$campaignId/topup',
      queryParameters: {'amount': amount},
    );
    debugPrint('$_tag topUpCampaign ← status=${resp.statusCode} data=${resp.data}');
    final data = _unwrap<Map<String, dynamic>>(resp) ?? {};
    final url = data['authorization_url'] as String? ?? '';
    final ref = data['reference'] as String? ?? '';
    final amountGhs = (data['amount_ghs'] as num?)?.toDouble() ?? 0.0;
    final originalAmount = (data['original_amount'] as num?)?.toDouble() ?? 0.0;
    final originalCurrency = data['original_currency'] as String? ?? '';
    debugPrint('$_tag topUpCampaign — url=$url ref=$ref amountGhs=$amountGhs originalAmount=$originalAmount $originalCurrency');
    return (
      authorizationUrl: url,
      reference: ref,
      amountGhs: amountGhs,
      originalAmount: originalAmount,
      originalCurrency: originalCurrency,
    );
  }

  Future<List<AdCampaign>> getMyCampaigns() async {
    debugPrint('$_tag getMyCampaigns');
    try {
      final resp = await _dio.get('/ads/campaigns');
      debugPrint('$_tag getMyCampaigns ← status=${resp.statusCode}');
      return _unwrapList<Map<String, dynamic>>(resp)
          .map(AdCampaign.fromJson)
          .toList();
    } catch (e, st) {
      debugPrint('$_tag getMyCampaigns ERROR: $e\n$st');
      return [];
    }
  }

  Future<AdCampaign> updateCampaign(
    String campaignId, {
    String? name,
    String? objective,
    double? budgetAmount,
    String? currency,
    String? startAt,
    String? endAt,
  }) async {
    debugPrint('$_tag updateCampaign → id=$campaignId name=$name objective=$objective budget=$budgetAmount');
    final resp = await _dio.patch('/ads/campaigns/$campaignId', data: {
      if (name != null) 'name': name,
      if (objective != null) 'objective': objective,
      if (budgetAmount != null) 'budget_amount': budgetAmount,
      if (currency != null) 'currency': currency,
      if (startAt != null) 'start_at': startAt,
      if (endAt != null) 'end_at': endAt,
    });
    debugPrint('$_tag updateCampaign ← status=${resp.statusCode}');
    final data = _unwrap<Map<String, dynamic>>(resp) ?? {};
    return AdCampaign.fromJson(data);
  }

  Future<Ad> updateAd(
    String adId, {
    String? headline,
    String? body,
    String? ctaText,
    String? ctaUrl,
    bool? commentsEnabled,
  }) async {
    debugPrint('$_tag updateAd → adId=$adId headline=$headline commentsEnabled=$commentsEnabled');
    final resp = await _dio.patch('/ads/ads/$adId', data: {
      if (headline != null) 'headline': headline,
      if (body != null) 'body': body,
      if (ctaText != null) 'cta_text': ctaText,
      if (ctaUrl != null) 'cta_url': ctaUrl,
      if (commentsEnabled != null) 'comments_enabled': commentsEnabled,
    });
    debugPrint('$_tag updateAd ← status=${resp.statusCode}');
    final data = _unwrap<Map<String, dynamic>>(resp) ?? {};
    return Ad.fromJson(data);
  }

  Future<AdSet> updateAdSet(
    String adsetId, {
    String? name,
    double? dailyBudget,
    double? bidAmount,
    Map<String, dynamic>? targeting,
    String? status,
  }) async {
    debugPrint('$_tag updateAdSet → id=$adsetId status=$status');
    final resp = await _dio.patch('/ads/adsets/$adsetId', data: {
      if (name != null) 'name': name,
      if (dailyBudget != null) 'daily_budget': dailyBudget,
      if (bidAmount != null) 'bid_amount': bidAmount,
      if (targeting != null) 'targeting': targeting,
      if (status != null) 'status': status,
    });
    debugPrint('$_tag updateAdSet ← status=${resp.statusCode}');
    final data = _unwrap<Map<String, dynamic>>(resp) ?? {};
    return AdSet.fromJson(data);
  }

  Future<void> updateAdStatus(String adId, {required String status}) async {
    assert(status == 'active' || status == 'paused');
    debugPrint('$_tag updateAdStatus → adId=$adId status=$status');
    try {
      final resp = await _dio.patch(
        '/ads/ads/$adId/status',
        queryParameters: {'status': status},
      );
      debugPrint('$_tag updateAdStatus ← status=${resp.statusCode}');
    } catch (e, st) {
      debugPrint('$_tag updateAdStatus ERROR: $e\n$st');
      rethrow;
    }
  }

  Future<({bool success, String status, String message})> verifyPayment(
      String campaignId) async {
    debugPrint('$_tag verifyPayment → campaignId=$campaignId');
    final resp =
        await _dio.post('/ads/campaigns/$campaignId/verify-payment');
    debugPrint(
        '$_tag verifyPayment ← status=${resp.statusCode} data=${resp.data}');
    final body = resp.data as Map<String, dynamic>? ?? {};
    final data = body['data'] as Map<String, dynamic>? ?? {};
    final success = body['success'] as bool? ?? false;
    final status = data['status'] as String? ?? '';
    final message = data['message'] as String? ?? '';
    debugPrint(
        '$_tag verifyPayment — success=$success status=$status message=$message');
    return (success: success, status: status, message: message);
  }

  Future<AdCampaign> getCampaign(String campaignId) async {
    debugPrint('$_tag getCampaign → id=$campaignId');
    final resp = await _dio.get('/ads/campaigns/$campaignId');
    debugPrint('$_tag getCampaign ← status=${resp.statusCode}');
    final data = _unwrap<Map<String, dynamic>>(resp) ?? {};
    return AdCampaign.fromJson(data);
  }
}
