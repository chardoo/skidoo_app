import 'package:flutter/material.dart';

import 'package:jperg_app/core/utils/snackbar_utils.dart';
import 'package:jperg_app/features/admin/data/repositories/app_config_repository.dart';
import 'package:jperg_app/features/ads/data/models/ad_model.dart';
import 'package:jperg_app/features/ads/data/models/feed_request_model.dart';
import 'package:jperg_app/features/ads/data/repositories/ads_repository.dart';
import 'package:jperg_app/features/ads/presentation/widgets/invitation_sheet.dart';

/// The campaigns and requests a feed deals in between its own cards.
///
/// Both feeds carry them now — Explore always did, and Following does since a
/// feed of only the people you already follow is the one place a job going
/// begging and a photographer paying to be seen have nobody to reach. So the
/// fetching, the slot arithmetic and the boost rota live here rather than
/// twice, and the two feeds differ only in how often they open a slot.
///
/// A feed owns one of these, hands it its own `setState` as [onChanged], and
/// asks it what belongs in slot *n*.
class FeedPromos {
  FeedPromos({
    required this.onChanged,
    this.intervalScale = 1,
    this.placement = 'event_feed',
  });

  /// Called whenever anything here changes — the feed's `setState`.
  final VoidCallback onChanged;

  /// How much quieter this feed is than Explore. Following passes 2: the
  /// people you followed are what you came for, and a request every twenty
  /// events there reads as an interruption where the same one on Explore reads
  /// as part of the feed.
  final int intervalScale;

  final String placement;

  final _repo = AdsRepository();

  // One ad per slot, fetched fresh for each — with its impression id and the
  // event it was served against, both of which the click needs later.
  final List<AdModel?> _ads = [];
  final List<String?> _impressionIds = [];
  final List<String?> _adContextEventIds = [];
  final _firedImpressions = <int>{};

  List<FeedRequestModel> _requests = const [];
  int _requestPage = 1;
  final _hiddenRequestIds = <String>{};

  bool _fetchingMore = false;
  bool _disposed = false;

  // ── Configuration ─────────────────────────────────────────────────────────

  bool get adsEnabled => AppConfigRepository.current.adsEnabled;
  bool get requestsEnabled => AppConfigRepository.current.requestsEnabled;

  int get adsInterval =>
      (AppConfigRepository.current.adsEveryNEvents * intervalScale)
          .clamp(1, 9999);

  int get requestsInterval =>
      (AppConfigRepository.current.requestsEveryNEvents * intervalScale)
          .clamp(1, 9999);

  // ── What goes in a slot ───────────────────────────────────────────────────

  List<FeedRequestModel> get visibleRequests =>
      [for (final r in _requests) if (!_hiddenRequestIds.contains(r.id)) r];

  AdModel? adForSlot(int slot) =>
      slot >= 0 && slot < _ads.length ? _ads[slot] : null;

  String? impressionIdForSlot(int slot) =>
      slot >= 0 && slot < _impressionIds.length ? _impressionIds[slot] : null;

  /// Which request belongs in request slot [slot]. See [requestInSlot].
  FeedRequestModel? requestForSlot(int slot) =>
      requestInSlot(visibleRequests, slot);

  // ── Fetching ──────────────────────────────────────────────────────────────

  /// Throws away everything fetched so far. For a pull-to-refresh, or a feed
  /// whose first card changed underneath it.
  void reset() {
    _ads.clear();
    _impressionIds.clear();
    _adContextEventIds.clear();
    _firedImpressions.clear();
    _requests = const [];
    _requestPage = 1;
  }

  Future<void> loadInitial({String? contextEventId}) async {
    try {
      final results = await Future.wait([
        adsEnabled
            ? _repo.serveAd(placement: placement, contextEventId: contextEventId)
            : Future<AdModel?>.value(null),
        requestsEnabled
            ? _repo.getRequests(page: 1)
            : Future<List<FeedRequestModel>>.value(const []),
      ]);
      if (_disposed) return;

      _ads
        ..clear()
        ..add(results[0] as AdModel?);
      _impressionIds
        ..clear()
        ..add(null);
      _adContextEventIds
        ..clear()
        ..add(contextEventId);
      _requests = results[1] as List<FeedRequestModel>;
      _requestPage = 1;
      onChanged();
    } catch (e) {
      // A feed without its promos is still a feed. Nothing here is worth an
      // error screen over somebody's photos.
      debugPrint('[FeedPromos] loadInitial ERROR: $e');
    }
  }

  Future<void> loadMore({String? contextEventId}) async {
    if (_fetchingMore) return;
    _fetchingMore = true;
    try {
      final nextPage = _requestPage + 1;
      final results = await Future.wait([
        adsEnabled
            ? _repo.serveAd(placement: placement, contextEventId: contextEventId)
            : Future<AdModel?>.value(null),
        requestsEnabled
            ? _repo.getRequests(page: nextPage)
            : Future<List<FeedRequestModel>>.value(const []),
      ]);
      if (_disposed) return;

      var ad = results[0] as AdModel?;
      // The same campaign twice in one scroll is the server answering the same
      // question twice, not two impressions.
      if (ad != null &&
          _ads.whereType<AdModel>().any((a) => a.adId == ad!.adId)) {
        ad = null;
      }
      _ads.add(ad);
      _impressionIds.add(null);
      _adContextEventIds.add(contextEventId);

      final more = results[1] as List<FeedRequestModel>;
      if (more.isNotEmpty) {
        _requests = [..._requests, ...more];
        _requestPage = nextPage;
      }
      onChanged();
    } catch (e) {
      debugPrint('[FeedPromos] loadMore ERROR: $e');
    } finally {
      _fetchingMore = false;
    }
  }

  // ── Impressions ───────────────────────────────────────────────────────────

  /// Counts the ad in [slot] as seen, once.
  Future<void> fireImpression(int slot) async {
    if (_firedImpressions.contains(slot)) return;
    final ad = adForSlot(slot);
    if (ad == null) return;
    _firedImpressions.add(slot);

    final contextEventId =
        slot < _adContextEventIds.length ? _adContextEventIds[slot] : null;
    final id = await _repo.trackImpression(
      adId: ad.adId,
      adsetId: ad.adsetId,
      campaignId: ad.campaignId,
      placement: ad.placement,
      impressionToken: ad.impressionToken,
      contextEventId: contextEventId,
    );
    if (_disposed) return;
    if (slot < _impressionIds.length) _impressionIds[slot] = id;
  }

  Future<void> trackClick(AdModel ad, int slot) => _repo.trackClick(
        adId: ad.adId,
        campaignId: ad.campaignId,
        impressionId: impressionIdForSlot(slot),
      );

  // ── Hiding ────────────────────────────────────────────────────────────────

  void hideAd(int slot) {
    if (slot >= 0 && slot < _ads.length) {
      _ads[slot] = null;
      onChanged();
    }
  }

  /// By id rather than by slot: a boosted request holds more than one slot,
  /// and hiding it in one place means hiding it.
  void hideRequest(String id) {
    _hiddenRequestIds.add(id);
    onChanged();
  }

  // ── Answering ─────────────────────────────────────────────────────────────

  /// Answering a request that turned up in a feed. Same rule as the board:
  /// this is an invitation, not a conversation — the requester starts those.
  Future<void> answer(BuildContext context, FeedRequestModel req) async {
    final updated = await answerFeedRequest(context, req, repo: _repo);
    if (updated == null || _disposed) return;
    _requests = [
      for (final r in _requests) r.id == updated.id ? updated : r,
    ];
    onChanged();
  }

  void dispose() => _disposed = true;
}

/// Which of [requests] belongs in request slot [slot].
///
/// Boosted requests take every other slot and cycle, so one comes back round
/// rather than scrolling past once and being gone for the rest of the feed;
/// everything else is dealt in the order the board sent it, once each. When the
/// unboosted run out the remaining slots go to boosted requests too — reach is
/// the thing that was paid for, and "appear at the top of photographer feeds"
/// is the first line on the sheet somebody bought.
///
/// With nothing boosted this is the plain list in order, which is exactly what
/// the feed did before boosts existed.
///
/// The server already sorts boosted first (`GET /ads/requests`). This is the
/// other half of that promise: an ordering says which request is seen first, and
/// only a rota can say how often it is seen again.
FeedRequestModel? requestInSlot(List<FeedRequestModel> requests, int slot) {
  if (slot < 0 || requests.isEmpty) return null;

  final boosted = [for (final r in requests) if (r.isBoosted) r];
  if (boosted.isEmpty) {
    return slot < requests.length ? requests[slot] : null;
  }
  final plain = [for (final r in requests) if (!r.isBoosted) r];

  var b = 0;
  var p = 0;
  for (var i = 0;; i++) {
    final takeBoosted = i.isEven || p >= plain.length;
    final pick = takeBoosted ? boosted[b++ % boosted.length] : plain[p++];
    if (i == slot) return pick;
  }
}

/// Opens the invitation sheet for [req] and applies whatever came back.
///
/// Returns the request as it now stands, or null when the sheet was dismissed
/// or the call failed — the caller puts it back into whichever list it holds.
/// Shared because three screens deal the same card: Explore, Following and the
/// board itself.
Future<FeedRequestModel?> answerFeedRequest(
  BuildContext context,
  FeedRequestModel req, {
  AdsRepository? repo,
}) async {
  final result = await InvitationSheet.show(
    context,
    requestTitle: req.title,
    requesterName:
        req.requesterName.isNotEmpty ? req.requesterName : 'The requester',
    existingMessage: req.viewerInterested ? (req.viewerMessage ?? '') : null,
  );
  if (result == null || !context.mounted) return null;

  final ads = repo ?? AdsRepository();
  final sending = result.action == InvitationAction.send;
  try {
    final count = sending
        ? await ads.expressInterest(req.id, message: result.message)
        : await ads.withdrawInterest(req.id);
    if (context.mounted) {
      AppSnackBar.success(
          context, sending ? 'Invitation sent' : 'Invitation withdrawn');
    }
    return req.copyWith(
      interestedCount: count,
      viewerInterested: sending,
      viewerMessage: sending ? result.message : '',
    );
  } catch (e) {
    debugPrint('[FeedPromos] answer ERROR: $e');
    if (context.mounted) {
      AppSnackBar.error(context,
          sending ? 'Could not send that.' : 'Could not withdraw that.');
    }
    return null;
  }
}
