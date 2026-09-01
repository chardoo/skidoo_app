import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/common/widgets/app_widgets.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/utils/snackbar_utils.dart';
import 'package:jperg_app/features/ads/data/models/ad_model.dart';
import 'package:jperg_app/features/ads/data/models/feed_request_model.dart';
import 'package:jperg_app/features/ads/data/repositories/ads_repository.dart';
import 'package:jperg_app/services/auth_service.dart';
import 'package:jperg_app/features/ads/presentation/widgets/feed_item_card.dart';
import 'package:jperg_app/features/ads/presentation/widgets/invitation_sheet.dart';
import 'package:jperg_app/core/utils/web_wrap.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';

const _eventTypes = [
  'Wedding',
  'Birthday',
  'Corporate',
  'Concert',
  'Graduation',
  'Engagement',
  'Baby Shower',
  'Other',
];

class RequestBoardPage extends StatefulWidget {
  const RequestBoardPage({super.key});

  @override
  State<RequestBoardPage> createState() => _RequestBoardPageState();
}

class _RequestBoardPageState extends State<RequestBoardPage> {
  final _repo = AdsRepository();
  final _locationCtrl = TextEditingController();

  List<FeedRequestModel> _requests = [];
  final _hiddenIds = <String>{};
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  String? _errorMessage;
  String? _selectedEventType;

  /// Read once so the board can tell your own requests apart from everyone
  /// else's — you cannot answer your own.
  String _myUserId = '';

  // Sponsored ad at top of the board (null = show nothing)
  AdModel? _sponsoredAd;
  String? _sponsoredImpressionId;

  static const _limit = 20;

  @override
  void initState() {
    super.initState();
    _loadMyUserId();
    _load();
  }

  Future<void> _loadMyUserId() async {
    final id = await AuthService().getUserId();
    if (mounted) setState(() => _myUserId = id);
  }

  @override
  void dispose() {
    _locationCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    debugPrint(
        '[RequestBoardPage] _load eventType=$_selectedEventType location="${_locationCtrl.text.trim()}"');
    setState(() {
      _loading = true;
      _errorMessage = null;
      _page = 1;
      _hasMore = true;
    });
    try {
      final results = await Future.wait([
        _repo.getRequests(
          eventType: _selectedEventType,
          location: _locationCtrl.text.trim().isEmpty
              ? null
              : _locationCtrl.text.trim(),
          page: 1,
          limit: _limit,
        ),
        _repo.serveAd(placement: 'request_board'),
      ]);
      if (!mounted) return;
      final requests = results[0] as List<FeedRequestModel>;
      final ad = results[1] as AdModel?;
      debugPrint(
          '[RequestBoardPage] _load done — ${requests.length} requests, ad=${ad?.adId}');
      setState(() {
        _requests = requests;
        _sponsoredAd = ad;
        _sponsoredImpressionId = null;
        _hasMore = requests.length == _limit;
        _loading = false;
      });
    } catch (e) {
      debugPrint('[RequestBoardPage] _load ERROR: $e');
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not load requests.';
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    final next = _page + 1;
    try {
      final more = await _repo.getRequests(
        eventType: _selectedEventType,
        location: _locationCtrl.text.trim().isEmpty
            ? null
            : _locationCtrl.text.trim(),
        page: next,
        limit: _limit,
      );
      if (!mounted) return;
      setState(() {
        _page = next;
        _requests = [..._requests, ...more];
        _loadingMore = false;
        _hasMore = more.length == _limit;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  /// Answer a request, or take the answer back.
  ///
  /// Not a conversation. The photographer puts themselves in front of the
  /// requester, who reads through everyone who answered and starts the DM with
  /// whoever they like — so this posts an interest and stops there.
  Future<void> _answer(FeedRequestModel req) async {
    final result = await InvitationSheet.show(
      context,
      requestTitle: req.title,
      requesterName:
          req.requesterName.isNotEmpty ? req.requesterName : 'The requester',
      existingMessage: req.viewerInterested ? (req.viewerMessage ?? '') : null,
    );
    if (result == null || !mounted) return;

    final sending = result.action == InvitationAction.send;
    try {
      final count = sending
          ? await _repo.expressInterest(req.id, message: result.message)
          : await _repo.withdrawInterest(req.id);
      if (!mounted) return;
      setState(() {
        _requests = [
          for (final r in _requests)
            if (r.id == req.id)
              r.copyWith(
                interestedCount: count,
                viewerInterested: sending,
                viewerMessage: sending ? result.message : '',
              )
            else
              r,
        ];
      });
      AppSnackBar.success(
        context,
        sending ? 'Invitation sent' : 'Invitation withdrawn',
      );
    } catch (e) {
      debugPrint('[RequestBoardPage] _answer ERROR: $e');
      if (!mounted) return;
      AppSnackBar.error(
        context,
        sending ? 'Could not send that.' : 'Could not withdraw that.',
      );
    }
  }

  void _showFilterSheet() {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _FilterSheet(
        ext: ext,
        selectedEventType: _selectedEventType,
        locationCtrl: _locationCtrl,
        onApply: (eventType) {
          setState(() => _selectedEventType = eventType);
          _load();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final hasFilters =
        _selectedEventType != null || _locationCtrl.text.trim().isNotEmpty;

    final page = Scaffold(
      backgroundColor: ext.homeBackground,
      appBar: AppBar(
        backgroundColor: ext.homeBackground,
        elevation: 0,
        leading: kIsWeb ? null : const AppBackButton(),
        title: Text(
          'Request Board',
          style: TextStyle(
            color: ext.greetingColor,
            fontSize: 17.sp,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: hasFilters,
              backgroundColor: ext.accentGold,
              child: Icon(Icons.tune_rounded,
                  color: ext.greetingColor, size: 22.sp),
            ),
            onPressed: _showFilterSheet,
          ),
        ],
      ),
      body: _loading
          ? const AppLoadingIndicator()
          : _errorMessage != null
              ? AppErrorView(
                  message: _errorMessage!,
                  icon: Icons.cloud_off_outlined,
                  onRetry: _load,
                )
              : Builder(builder: (context) {
                  final visible = _requests
                      .where((r) => !_hiddenIds.contains(r.id))
                      .toList();
                  final hasAd = _sponsoredAd != null;
                  final adOffset = hasAd ? 1 : 0;
                  final itemCount =
                      adOffset + visible.length + (_loadingMore ? 1 : 0);

                  if (!hasAd && visible.isEmpty) {
                    return const AppEmptyState(
                      icon: Icons.inbox_outlined,
                      message: 'No open requests found',
                    );
                  }
                  return NotificationListener<ScrollNotification>(
                    onNotification: (n) {
                      if (n is ScrollUpdateNotification &&
                          n.metrics.pixels >= n.metrics.maxScrollExtent - 800) {
                        _loadMore();
                      }
                      return false;
                    },
                    child: RefreshIndicator(
                      onRefresh: _load,
                      color: ext.accentGold,
                      child: ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        itemCount: itemCount,
                        itemBuilder: (_, i) {
                          // Loading spinner at the very end
                          if (i == adOffset + visible.length) {
                            return Padding(
                              padding: EdgeInsets.symmetric(
                                  vertical: AppSpacing.xl.h),
                              child: const AppLoadingIndicator(),
                            );
                          }

                          // Sponsored ad at position 0
                          if (hasAd && i == 0) {
                            final ad = _sponsoredAd!;
                            // Boxed: the same poster the feed shows, as a tile
                            // in a list. See [FeedItemCard.fullBleed].
                            return _BoardTile(
                              child: FeedItemCard(
                                fullBleed: false,
                                key: ValueKey('sponsored_${ad.adId}'),
                                data: FeedItemData.fromAd(
                                  ad,
                                  onCtaTap: () => _repo.trackClick(
                                    adId: ad.adId,
                                    campaignId: ad.campaignId,
                                    impressionId: _sponsoredImpressionId,
                                  ),
                                  onInit: () async {
                                    final id = await _repo.trackImpression(
                                      adId: ad.adId,
                                      adsetId: ad.adsetId,
                                      campaignId: ad.campaignId,
                                      placement: 'request_board',
                                      impressionToken: ad.impressionToken,
                                    );
                                    if (mounted) {
                                      setState(
                                          () => _sponsoredImpressionId = id);
                                    }
                                  },
                                ),
                                onHide: () =>
                                    setState(() => _sponsoredAd = null),
                              ),
                            );
                          }

                          final req = visible[i - adOffset];
                          return _BoardTile(
                            child: FeedItemCard(
                              fullBleed: false,
                              data: FeedItemData.fromRequest(
                                req,
                                // Your own request is one you cannot answer, so
                                // the card shows its count without the button.
                                onAnswerTap: req.requesterId == _myUserId
                                    ? null
                                    : () => _answer(req),
                              ),
                              onHide: () =>
                                  setState(() => _hiddenIds.add(req.id)),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                }),
    );
    return webWrap(page, backgroundColor: ext.homeBackground);
  }
}

// ── Filter bottom sheet ───────────────────────────────────────────────────────

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({
    required this.ext,
    required this.selectedEventType,
    required this.locationCtrl,
    required this.onApply,
  });

  final AppThemeExtension ext;
  final String? selectedEventType;
  final TextEditingController locationCtrl;
  final ValueChanged<String?> onApply;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  String? _eventType;

  @override
  void initState() {
    super.initState();
    _eventType = widget.selectedEventType;
  }

  @override
  Widget build(BuildContext context) {
    final ext = widget.ext;

    return Container(
      decoration: BoxDecoration(
        color: ext.homeBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 20.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  margin: EdgeInsets.symmetric(vertical: AppSpacing.md.h),
                  width: 36.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: ext.searchHintColor.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              Text(
                'Filter Requests',
                style: TextStyle(
                  color: ext.greetingColor,
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                ),
              ),
              SizedBox(height: AppSpacing.xl.h),
              Text(
                'Event type',
                style: TextStyle(
                  color: ext.greetingColor,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: AppSpacing.sm.h),
              Wrap(
                spacing: 8.w,
                runSpacing: 8.h,
                children: [
                  _FilterChip(
                    label: 'All',
                    selected: _eventType == null,
                    ext: ext,
                    onTap: () => setState(() => _eventType = null),
                  ),
                  ..._eventTypes.map((t) => _FilterChip(
                        label: t,
                        selected: _eventType == t,
                        ext: ext,
                        onTap: () => setState(() => _eventType = t),
                      )),
                ],
              ),
              SizedBox(height: AppSpacing.xl.h),
              Text(
                'Location',
                style: TextStyle(
                  color: ext.greetingColor,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: AppSpacing.sm.h),
              AppTextField(
                controller: widget.locationCtrl,
                dense: true,
                hint: 'e.g. Accra',
              ),
              SizedBox(height: AppSpacing.xxl.h),
              Semantics(
                  button: true,
                  label: 'Event type',
                  child: GestureDetector(
                    onTap: () {
                      Navigator.of(context).pop();
                      widget.onApply(_eventType);
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 15.h),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [ext.accentGold, ext.accentGoldDark],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(14.r),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Apply Filters',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.ext,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final AppThemeExtension ext;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
        button: true,
        label: label,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.md.w, vertical: 7.h),
            decoration: BoxDecoration(
              color: selected
                  ? ext.accentGold.withValues(alpha: 0.15)
                  : ext.searchFieldFill,
              borderRadius: BorderRadius.circular(AppRadius.xl.r),
              border: Border.all(
                color: selected
                    ? ext.accentGold.withValues(alpha: 0.6)
                    : Colors.transparent,
                width: 1.0,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: selected ? ext.accentGold : ext.searchHintColor,
                fontSize: 12.sp,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ));
  }
}

/// One poster in the board's list.
///
/// The card it holds is the feed's page, boxed: same media, same pill, same
/// button, given a height and a corner radius so a list of them reads as a
/// list rather than as a stack of screens. The height is the poster shape the
/// designs draw — tall enough for the copy block to sit on real photo.
class _BoardTile extends StatelessWidget {
  const _BoardTile({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md.w,
        AppSpacing.sm.h,
        AppSpacing.md.w,
        AppSpacing.sm.h,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg.r),
        child: SizedBox(height: 520.h, child: child),
      ),
    );
  }
}
