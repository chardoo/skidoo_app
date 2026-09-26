import 'package:flutter/material.dart';

import 'package:jperg_app/core/utils/snackbar_utils.dart';
import 'package:jperg_app/features/admin/data/repositories/app_config_repository.dart';
import 'package:jperg_app/features/ads/data/models/ad_model.dart';
import 'package:jperg_app/features/ads/data/models/feed_request_model.dart';
import 'package:jperg_app/features/ads/campaigns_enabled.dart';
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
  }) {
    _wasAdsEnabled = adsEnabled;
    _wasRequestsEnabled = requestsEnabled;
    AppConfigRepository.notifier.addListener(_onConfigChanged);
  }

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

  /// Every request id shown to this reader since the app started.
  ///
  /// Static, and deliberately not cleared by [reset]: "once per launch" is a
  /// promise about the launch, not about the feed widget, and a pull-to-refresh
  /// that re-dealt the board from the top would repeat the card somebody just
  /// scrolled past — which is the bug this whole rota was rewritten for.
  static final Set<String> dealt = <String>{};

  /// This instance's share of [dealt], so re-deciding a slot it already filled
  /// does not treat its own card as somebody else's.
  final _dealtHere = <String>{};

  bool _fetchingMore = false;
  bool _disposed = false;

  /// The flags as they stood last time anything looked, so a config arriving
  /// unchanged (every resume refetches it) is not mistaken for a switch being
  /// thrown.
  late bool _wasAdsEnabled;
  late bool _wasRequestsEnabled;

  /// What [loadInitial] was last given, so the reload after a switch is thrown
  /// asks for the same feed position rather than a context-free ad.
  String? _lastContextEventId;

  // ── Configuration ─────────────────────────────────────────────────────────

  bool get adsEnabled => campaignsEnabled;
  bool get requestsEnabled => AppConfigRepository.current.requestsEnabled;

  int get adsInterval =>
      (AppConfigRepository.current.adsEveryNEvents * intervalScale)
          .clamp(1, 9999);

  int get requestsInterval =>
      (AppConfigRepository.current.requestsEveryNEvents * intervalScale)
          .clamp(1, 9999);

  // ── What goes in a slot ───────────────────────────────────────────────────

  List<FeedRequestModel> get visibleRequests => [
        for (final r in _requests)
          if (!_hiddenRequestIds.contains(r.id)) r
      ];

  AdModel? adForSlot(int slot) =>
      slot >= 0 && slot < _ads.length ? _ads[slot] : null;

  String? impressionIdForSlot(int slot) =>
      slot >= 0 && slot < _impressionIds.length ? _impressionIds[slot] : null;

  /// Which request belongs in request slot [slot]. See [requestInSlot].
  ///
  /// Stable for a given slot, which is the whole reason this instance's own
  /// deals are held apart from the ledger. A feed rebuilds constantly, and if
  /// marking a card as dealt also hid it from the slot it is *in*, slot 0
  /// would answer with a different request on every frame — the card would
  /// change under somebody's thumb.
  FeedRequestModel? requestForSlot(int slot) {
    final pick = requestInSlot(visibleRequests, slot, seen: _dealtElsewhere);
    if (pick != null) {
      dealt.add(pick.id);
      _dealtHere.add(pick.id);
    }
    return pick;
  }

  /// Ids this launch has shown that are *not* this instance's own.
  ///
  /// The other feed's cards, and this feed's cards from before the last
  /// refresh. Excluding them is what makes a request one card per launch
  /// across both feeds and every pull-to-refresh; excluding this instance's
  /// own would make its slots unstable.
  Set<String> get _dealtElsewhere => dealt.difference(_dealtHere);

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
    // Not `dealt` — the launch ledger outlives a refresh on purpose. Letting
    // go of this instance's claim is what moves its cards into "already shown
    // elsewhere", so the next deal starts after them instead of repeating the
    // board from the top.
    _dealtHere.clear();
  }

  /// The admin threw one of the switches while this feed was on screen.
  ///
  /// Both directions matter and they are the same operation: drop everything
  /// fetched under the old answer and ask again. Off, and [loadInitial] fetches
  /// nothing, leaving a feed of events alone; on, and the slots fill without
  /// the reader having to restart the app to see a feature that now exists.
  void _onConfigChanged() {
    if (_disposed) return;
    final ads = adsEnabled;
    final requests = requestsEnabled;
    if (ads == _wasAdsEnabled && requests == _wasRequestsEnabled) return;
    _wasAdsEnabled = ads;
    _wasRequestsEnabled = requests;
    reset();
    // Redraws now with the slots emptied, rather than holding the old campaigns
    // on screen until the refetch answers.
    onChanged();
    loadInitial(contextEventId: _lastContextEventId);
  }

  Future<void> loadInitial({String? contextEventId}) async {
    _lastContextEventId = contextEventId;
    try {
      final results = await Future.wait([
        adsEnabled
            ? _repo.serveAd(
                placement: placement, contextEventId: contextEventId)
            : Future<AdModel?>.value(null),
        requestsEnabled
            ? _repo.getRequests(page: 1, paced: true)
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
            ? _repo.serveAd(
                placement: placement, contextEventId: contextEventId)
            : Future<AdModel?>.value(null),
        requestsEnabled
            ? _repo.getRequests(page: nextPage, paced: true)
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

  void dispose() {
    _disposed = true;
    AppConfigRepository.notifier.removeListener(_onConfigChanged);
  }
}

/// Which of [requests] belongs in request slot [slot].
///
/// **Once each, per launch.** Boosted first — that is what the boost buys and
/// what the server's ordering already delivers — then everything else in the
/// order the board sent it, and then nothing. A slot past the end of the board
/// is empty.
///
/// It used to cycle: boosted requests took every other slot and came back
/// round, and once the unboosted ran out they took *every* slot. On a board
/// holding one boosted request — the ordinary case — that is the same card in
/// half the feed and then in all of it. The intention was reach, and reach is
/// the right thing to sell; repeating one card down a single scroll is not how
/// a campaign delivers it. A campaign wins more slots across more sessions,
/// capped per viewer per day, and is dropped outright if it would appear twice
/// in one scroll (see [FeedPromos.loadMore]). This now works the same way: the
/// boost decides *which* request is seen and how soon, the pacing decides how
/// often it comes back, and a scroll never shows the same one twice.
///
/// [seen] is what this launch has already dealt — see [FeedPromos.dealt].
/// Passing it keeps a pull-to-refresh from starting the board again from the
/// top, which would repeat everything the reader just scrolled past.
FeedRequestModel? requestInSlot(
  List<FeedRequestModel> requests,
  int slot, {
  Set<String> seen = const {},
}) {
  if (slot < 0 || requests.isEmpty) return null;

  final pool = [
    for (final r in requests)
      if (r.isBoosted && !seen.contains(r.id)) r,
    for (final r in requests)
      if (!r.isBoosted && !seen.contains(r.id)) r,
  ];
  return slot < pool.length ? pool[slot] : null;
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
