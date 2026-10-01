import 'package:flutter/material.dart';
import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/features/photographers/data/premium_service.dart';
import 'package:jperg_app/core/theme/app_typography.dart';
import 'package:jperg_app/core/widgets/jperg_image.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:jperg_app/core/validators/media_validator.dart';
import 'package:jperg_app/features/ads/presentation/pages/create_request_flow.dart';
import 'package:jperg_app/features/ads/models/ad_media.dart';
import 'package:jperg_app/core/common/widgets/app_widgets.dart';
import 'package:jperg_app/features/ads/presentation/widgets/create_bottom_sheet.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/utils/snackbar_utils.dart';
import 'package:jperg_app/features/ads/data/models/feed_request_model.dart';
import 'package:jperg_app/features/ads/data/repositories/ads_repository.dart';
import 'package:jperg_app/features/ads/presentation/pages/create_campaign_page.dart';
import 'package:jperg_app/features/ads/presentation/pages/review_photographers_page.dart';
import 'package:jperg_app/features/ads/models/boost_tier.dart';
import 'package:jperg_app/features/ads/presentation/pages/ads_checkout_page.dart';
import 'package:jperg_app/features/ads/presentation/pages/boost_success_page.dart';
import 'package:jperg_app/features/ads/presentation/widgets/boost_request_sheet.dart';
import 'package:jperg_app/features/ads/presentation/widgets/interested_row.dart';
import 'package:jperg_app/features/location/data/models/place.dart';
import 'package:jperg_app/features/location/presentation/widgets/location_picker_sheet.dart';
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_icons.dart';
import 'package:jperg_app/core/widgets/text_prompt_dialog.dart';

class MyRequestsPage extends StatefulWidget {
  const MyRequestsPage({super.key, this.embedded = false, this.onCount});

  /// True when this list is a tab inside Broadcasts, which already provides
  /// the header and the back button — so it renders as a bare list rather
  /// than a second page stacked inside the first.
  final bool embedded;

  /// How many this list holds, reported once it knows. Broadcasts puts it in
  /// the tab label — it used to fetch the whole list again to find out.
  final ValueChanged<int>? onCount;

  @override
  State<MyRequestsPage> createState() => _MyRequestsPageState();
}

/// Kept alive because this page is a child of the Broadcasts [TabBarView],
/// which disposes whichever tab is off screen. Without this, every switch to
/// Campaigns and back re-ran initState and refetched a list identical to the
/// one the user was just looking at.
class _MyRequestsPageState extends State<MyRequestsPage>
    with AutomaticKeepAliveClientMixin {
  final _repo = AdsRepository();
  List<FeedRequestModel> _requests = [];
  bool _loading = true;
  String? _errorMessage;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    debugPrint('[MyRequestsPage] _load');
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final requests = await _repo.getMyRequests();
      if (!mounted) return;
      debugPrint('[MyRequestsPage] loaded ${requests.length} requests');
      setState(() {
        _requests = requests;
        widget.onCount?.call(requests.length);
        _loading = false;
      });
    } catch (e) {
      debugPrint('[MyRequestsPage] _load ERROR: $e');
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not load your requests.';
        _loading = false;
      });
    }
  }

  /// Put a closed request back on the board. The answers it already collected
  /// come with it, so the count on the card does not reset.
  Future<void> _republish(FeedRequestModel req) async {
    debugPrint('[MyRequestsPage] _republish id=${req.id}');
    try {
      final updated = await _repo.republishRequest(req.id);
      if (!mounted) return;
      setState(() {
        _requests = [
          for (final r in _requests)
            if (r.id == req.id) updated ?? r.copyWith(status: 'open') else r,
        ];
      });
      AppSnackBar.success(context, 'Request is back on the board.');
    } catch (e) {
      debugPrint('[MyRequestsPage] _republish ERROR: $e');
      if (!mounted) return;
      AppSnackBar.error(context, 'Could not republish this request.');
    }
  }

  /// The card opens the request itself — who answered, and choosing one of
  /// them.
  ///
  /// Coming back reloads only if something actually changed in there. Merely
  /// looking at a request and pressing back used to refetch the whole list,
  /// which is a request per glance and the list is identical to the one
  /// already on screen.
  Future<void> _openRequest(FeedRequestModel req) async {
    final outcome = await Navigator.of(context).push<RequestOutcome>(
      MaterialPageRoute(builder: (_) => ReviewPhotographersPage(request: req)),
    );
    if (!mounted || outcome == null || outcome == RequestOutcome.unchanged) {
      return;
    }
    if (outcome == RequestOutcome.deleted) {
      AppSnackBar.success(context, 'Request deleted.');
    }
    await _load();
  }

  Future<void> _close(FeedRequestModel req, String status) async {
    debugPrint('[MyRequestsPage] _close id=${req.id} status=$status');
    try {
      await _repo.closeRequest(req.id, status: status);
      if (!mounted) return;
      AppSnackBar.success(
        context,
        status == 'filled' ? 'Request marked as filled.' : 'Request closed.',
      );
      _load();
    } catch (e) {
      debugPrint('[MyRequestsPage] _close ERROR: $e');
      if (!mounted) return;
      AppSnackBar.error(context, 'Failed to update request.');
    }
  }

  Future<void> _promote(FeedRequestModel req) async {
    debugPrint('[MyRequestsPage] _promote id=${req.id}');
    try {
      final result = await _repo.promoteRequest(req.id);
      final campaignId =
          result['campaign_id'] as String? ?? result['id'] as String?;
      debugPrint('[MyRequestsPage] _promote — campaignId=$campaignId');
      if (campaignId == null || campaignId.isEmpty) {
        if (!mounted) return;
        AppSnackBar.error(context, 'Could not promote request. Try again.');
        return;
      }
      // Navigate to the campaign wizard pre-filled at Step 2 (ad set) so the
      // user can review targeting and creative before paying.
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CreateCampaignPage(existingCampaignId: campaignId),
        ),
      );
      if (mounted) _load();
    } catch (e) {
      debugPrint('[MyRequestsPage] _promote ERROR: $e');
      if (!mounted) return;
      AppSnackBar.error(context, 'Failed to promote request.');
    }
  }

  /// Buy a boost: pick a tier, pay, then confirm before claiming anything.
  ///
  /// The success screen is only reached once the server has said the money
  /// landed. Paystack redirecting back is not the same as the payment having
  /// been confirmed, and a receipt for a boost that did not happen is worse
  /// than no receipt at all.
  Future<void> _boost(FeedRequestModel req) async {
    debugPrint('[MyRequestsPage] _boost id=${req.id}');

    BoostCatalogue catalogue;
    try {
      catalogue = await _repo.boostTiers();
    } catch (e) {
      debugPrint('[MyRequestsPage] _boost tiers ERROR: $e');
      if (!mounted) return;
      AppSnackBar.error(context, 'Could not load boost options. Try again.');
      return;
    }
    if (!mounted) return;
    if (catalogue.tiers.isEmpty) {
      AppSnackBar.error(context, 'Boosting is not available right now.');
      return;
    }

    final tier = await showModalBottomSheet<BoostTier>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BoostRequestSheet(catalogue: catalogue),
    );
    if (tier == null || !mounted) return;

    try {
      final started = await _repo.startBoost(req.id, days: tier.days);
      if (!mounted) return;

      // A previous attempt turned out to have gone through. The server has
      // applied the boost rather than charging again, so there is no checkout
      // to open — go straight to the receipt.
      if (!started.alreadyPaid) {
        if (started.authorizationUrl.isEmpty) {
          AppSnackBar.error(context, 'Could not start the payment. Try again.');
          return;
        }
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => AdsCheckoutPage(
              authorizationUrl: started.authorizationUrl,
              reference: started.reference,
              amountGhs: started.amountGhs,
              onSuccess: () {},
            ),
          ),
        );
        if (!mounted) return;

        final verified = await _repo.verifyBoost(req.id);
        if (!mounted) return;
        if (!verified.isBoosted) {
          // Closing the WebView without paying lands here, which is the common
          // case and not an error worth alarming anybody about.
          AppSnackBar.info(
            context,
            verified.message.isNotEmpty
                ? verified.message
                : 'Payment not confirmed yet.',
          );
          await _load();
          return;
        }
      }

      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => BoostSuccessPage(
            requestTitle: req.title,
            days: started.days,
          ),
        ),
      );
      if (mounted) await _load();
    } catch (e) {
      debugPrint('[MyRequestsPage] _boost ERROR: $e');
      if (!mounted) return;
      AppSnackBar.error(context, 'Could not boost this request. Try again.');
      // Reload before inviting a retry. A failure here does not mean nothing
      // happened: a boost can be applied and confirmed server-side and still
      // come back as an error, which is exactly what a bug in verify-boost did.
      // Leaving the stale card up offers "Boost Request" on something already
      // paid for, and "Try again" then charges for it twice.
      await _load();
    }
  }

  void _showActions(
      BuildContext context, FeedRequestModel req, AppThemeExtension ext) {
    final canEdit = req.status == 'open';
    final isActive = req.status == 'open' || req.status == 'promoted';
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: ext.homeBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        ),
        // _ActionTile is a ListTile; its ink needs a Material beneath this
        // decorated Container rather than above it.
        child: Material(
          type: MaterialType.transparency,
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: EdgeInsets.symmetric(vertical: AppSpacing.md.h),
                  width: 36.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: ext.searchHintColor.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
                if (canEdit)
                  _ActionTile(
                    icon: Icons.edit_outlined,
                    label: 'Edit Request',
                    color: ext.infoBlue,
                    ext: ext,
                    onTap: () {
                      Navigator.of(context).pop();
                      _showEditSheet(context, req, ext);
                    },
                  ),
                if (isActive && req.promotedCampaignId == null)
                  _ActionTile(
                    icon: Icons.rocket_launch_rounded,
                    label: 'Promote to Campaign',
                    color: ext.accentGold,
                    ext: ext,
                    onTap: () {
                      Navigator.of(context).pop();
                      _promote(req);
                    },
                  ),
                if (isActive)
                  _ActionTile(
                    icon: Icons.check_circle_outline_rounded,
                    label: 'Mark as Filled',
                    color: const Color(0xFF10B981),
                    ext: ext,
                    onTap: () {
                      Navigator.of(context).pop();
                      _close(req, 'filled');
                    },
                  ),
                if (isActive)
                  _ActionTile(
                    icon: Icons.cancel_outlined,
                    label: 'Close Request',
                    color: Colors.redAccent,
                    ext: ext,
                    onTap: () {
                      Navigator.of(context).pop();
                      _close(req, 'closed');
                    },
                  ),
                SizedBox(height: AppSpacing.sm.h),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEditSheet(
      BuildContext context, FeedRequestModel req, AppThemeExtension ext) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => EditRequestSheet(
        request: req,
        ext: ext,
        onSave: (updated) {
          setState(() {
            final idx = _requests.indexWhere((r) => r.id == updated.id);
            if (idx != -1) _requests[idx] = updated;
          });
          AppSnackBar.success(context, 'Request updated.');
        },
        repo: _repo,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // required by AutomaticKeepAliveClientMixin
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    final page = Scaffold(
      backgroundColor: ext.homeBackground,
      appBar: widget.embedded
          ? null
          : AppBar(
              backgroundColor: ext.homeBackground,
              elevation: 0,
              leading: const AppBackButton(),
              title: Text(
                'My Requests',
                style: TextStyle(
                  color: ext.greetingColor,
                  fontFamily: AppTypography.displayFontFamily,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              centerTitle: false,
            ),
      body: _loading
          ? const AppLoadingIndicator()
          : _errorMessage != null
              ? AppErrorView(
                  message: _errorMessage!,
                  icon: Icons.cloud_off_outlined,
                  onRetry: _load,
                )
              : _requests.isEmpty
                  ? AppEmptyState(
                      icon: Icons.inbox_outlined,
                      message: 'No requests yet',
                      actionLabel: 'Request a photographer',
                      hint: 'to get started.',
                      onAction: () => CreateBottomSheet.show(context),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: ext.accentGold,
                      child: ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        itemCount: _requests.length,
                        itemBuilder: (_, i) {
                          final req = _requests[i];
                          return _MyRequestTile(
                            request: req,
                            ext: ext,
                            onActionTap: () => _showActions(context, req, ext),
                            onOpen: () => _openRequest(req),
                            onRepublish: () => _republish(req),
                            onInterestedTap: () => _openRequest(req),
                            // Only an active, not-already-boosted request has
                            // anything to buy — the server refuses the rest.
                            onBoost: req.canBoost ? () => _boost(req) : null,
                          );
                        },
                      ),
                    ),
    );
    return widget.embedded ? page : page;
  }
}

// ── My request tile ───────────────────────────────────────────────────────────

class _MyRequestTile extends StatelessWidget {
  const _MyRequestTile({
    required this.request,
    required this.ext,
    required this.onActionTap,
    this.onRepublish,
    this.onInterestedTap,
    this.onOpen,
    this.onBoost,
  });
  final FeedRequestModel request;
  final AppThemeExtension ext;
  final VoidCallback onActionTap;

  /// Tapping the card opens the request and who answered it.
  final VoidCallback? onOpen;
  final VoidCallback? onRepublish;
  final VoidCallback? onInterestedTap;

  /// Offered only on an active request that is not already boosted — see
  /// [FeedRequestModel.canBoost]. Null hides the button entirely.
  final VoidCallback? onBoost;

  @override
  Widget build(BuildContext context) {
    final r = request;
    final statusColor = _statusColor(r.status);

    return GestureDetector(
      // Opaque, so the whole card takes the tap and not just its text.
      behavior: HitTestBehavior.opaque,
      onTap: onOpen,
      child: Container(
        margin: EdgeInsets.fromLTRB(14.w, 10.h, 14.w, 0),
        padding: EdgeInsets.all(AppSpacing.lg.w),
        decoration: BoxDecoration(
          color: ext.cardSurface,
          borderRadius: BorderRadius.circular(AppRadius.lg.r),
          border: Border.all(
            color: ext.searchHintColor.withValues(alpha: 0.1),
            width: 0.8,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    r.title,
                    style: TextStyle(
                      color: ext.greetingColor,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(width: 10.w),
                _StatusBadge(
                  // Expiry is not a status the server writes, so the card has to
                  // work it out: a request whose window has closed is off the
                  // board however "open" it still says it is.
                  status:
                      r.isExpired && r.status == 'open' ? 'expired' : r.status,
                  color: r.isExpired && r.status == 'open'
                      ? ext.searchHintColor
                      : statusColor,
                  ext: ext,
                  isBoosted: r.isBoosted,
                ),
              ],
            ),
            SizedBox(height: AppSpacing.xs.h),
            Text(
              _dateAndPlace(r),
              style: TextStyle(
                color: ext.searchHintColor,
                fontSize: 12.sp,
              ),
            ),
            // The answers and the Boost button share a row: the designs put
            // them on the same line, and on a card with no answers yet the
            // button still sits where it always does, at the right.
            if (r.interestedCount > 0 || onBoost != null) ...[
              SizedBox(height: AppSpacing.md.h),
              Row(
                children: [
                  if (r.interestedCount > 0)
                    Flexible(
                      child: InterestedRow(
                        interested: r.interested,
                        count: r.interestedCount,
                        ext: ext,
                        onTap: onInterestedTap,
                      ),
                    ),
                  if (onBoost != null) ...[
                    const Spacer(),
                    _BoostButton(onTap: onBoost!, ext: ext),
                  ],
                ],
              ),
            ],
            // A closed request keeps its answers, so republishing is offered
            // right on the card rather than buried in the actions sheet.
            if (r.canRepublish && onRepublish != null) ...[
              SizedBox(height: AppSpacing.md.h),
              Semantics(
                button: true,
                label: 'Republish request',
                child: GestureDetector(
                  onTap: onRepublish,
                  child: Text(
                    'Republish',
                    style: TextStyle(
                      color: ext.accentGold,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// "28.07.2026 | Accra" — the two things the card carries under the title.
  /// Either may be missing, and the separator goes with whichever one is.
  static String _dateAndPlace(FeedRequestModel r) {
    // The event's date, not the posting date: "15.09.2026 | Cape Coast" is
    // where the photographer has to be. Falls back to when it was posted for
    // requests made before the field existed.
    final date = r.eventDate ?? r.createdAt;
    final parts = <String>[
      if (date != null)
        '${date.day.toString().padLeft(2, '0')}.'
            '${date.month.toString().padLeft(2, '0')}.${date.year}',
      if (r.location.isNotEmpty) r.location,
    ];
    return parts.join(' | ');
  }

  static Color _statusColor(String status) {
    return switch (status) {
      'open' => const Color(0xFF10B981),
      'promoted' => const Color(0xFFFFAB00),
      'pending_review' => const Color(0xFF3B82F6),
      'filled' => const Color(0xFF8B5CF6),
      'closed' || 'rejected' => Colors.redAccent,
      _ => const Color(0xFF6B7280),
    };
  }
}

/// The outlined "Boost Request" pill on an active card.
///
/// Outlined rather than filled: the card already carries a status badge and a
/// row of faces, and a solid accent block would make every unboosted request
/// shout. It is an offer, not the point of the card.
class _BoostButton extends StatelessWidget {
  const _BoostButton({required this.onTap, required this.ext});

  final VoidCallback onTap;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Boost request',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.xl.r),
        child: Container(
          padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.md.w, vertical: AppSpacing.sm.h),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.xl.r),
            border: Border.all(color: ext.accentGold, width: 1.2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.trending_up_rounded,
                  size: 15.sp, color: ext.accentGold),
              SizedBox(width: AppSpacing.xs.w),
              Text(
                'Boost Request',
                style: TextStyle(
                  color: ext.accentGold,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge(
      {required this.status,
      required this.color,
      required this.ext,
      this.isBoosted = false});
  final String status;
  final Color color;
  final AppThemeExtension ext;

  /// Reads "Active | Boosted" rather than getting its own pill. It qualifies
  /// the status — a boost on a closed request would mean nothing — so it
  /// belongs inside the same badge rather than beside it.
  final bool isBoosted;

  /// The card says Active or Closed. The server has more states than that —
  /// promoted, filled, rejected — but from the requester's side the only
  /// question the card answers is whether photographers can still apply. In
  /// Review is kept: a request waiting on a moderator is neither.
  static String _label(String s) => switch (s) {
        'open' || 'promoted' => 'Active',
        'pending_review' => 'In Review',
        'expired' => 'Expired',
        'filled' || 'closed' || 'rejected' => 'Closed',
        _ => s,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.xl.r),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 0.8),
      ),
      child: Text(
        isBoosted ? '${_label(status)} | Boosted' : _label(status),
        style: TextStyle(
          color: color,
          fontSize: 10.sp,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

// ── Edit request bottom sheet ─────────────────────────────────────────────────

const _editEventTypes = [
  'Wedding',
  'Birthday',
  'Corporate',
  'Concert',
  'Graduation',
  'Engagement',
  'Baby Shower',
  'Anniversary',
  'Sports',
  'Other',
];

/// Shared with the review screen, which is where editing a request is reached
/// from now that the card opens it rather than a "Manage" button.
class EditRequestSheet extends StatefulWidget {
  const EditRequestSheet({
    super.key,
    required this.request,
    required this.ext,
    required this.onSave,
    required this.repo,
  });
  final FeedRequestModel request;
  final AppThemeExtension ext;
  final ValueChanged<FeedRequestModel> onSave;
  final AdsRepository repo;

  @override
  State<EditRequestSheet> createState() => _EditRequestSheetState();
}

class _EditRequestSheetState extends State<EditRequestSheet> {
  final _picker = ImagePicker();
  late List<AdMedia> _media = widget.request.media;
  bool _mediaBusy = false;

  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _locationCtrl;
  late final TextEditingController _budgetCtrl;
  String? _eventType;

  /// When the shoot is.
  ///
  /// The card leads on it, the board filters on it, and the premium promise is
  /// measured from it — so a sheet that could not change it left the one field
  /// most likely to move (a postponed wedding) needing the request deleted and
  /// posted again.
  DateTime? _eventDate;
  TimeOfDay? _eventTime;

  /// How much of the day is being asked for, and the detail the choice needs.
  String? _coverageKind;
  int? _coverageHours;
  String _coverageNote = '';

  /// The budget as a range, which is what the create form collects and what
  /// the card renders. The single figure this sheet used to hold could only
  /// ever write the midpoint back over it.
  late final TextEditingController _budgetMinCtrl;
  late final TextEditingController _budgetMaxCtrl;
  bool _commentsEnabled = true;

  /// Whether this request asks for a creator under a delivery promise.
  ///
  /// Seeded from the request, not defaulted: a form that opened this false
  /// would quietly drop the promise from a request that had one the moment
  /// somebody edited the title, and the requester would find out when
  /// ordinary photographers started answering.
  bool _premiumOnly = false;
  PremiumTerms? _premiumTerms;
  bool _saving = false;

  /// Who the request reaches, editable here for the same reason the venue is:
  /// a requester who aimed too narrowly and got no answers has to be able to
  /// widen it without deleting the request and posting it again.
  late List<Place> _targets;

  @override
  void initState() {
    super.initState();
    final r = widget.request;
    _titleCtrl = TextEditingController(text: r.title);
    _descCtrl = TextEditingController(text: r.description);
    _locationCtrl = TextEditingController(text: r.location);
    _targets = List<Place>.from(r.targetLocations);
    _budgetCtrl = TextEditingController(
      text: r.budgetAmount != null ? r.budgetAmount!.toStringAsFixed(0) : '',
    );
    _eventType = r.eventType.isEmpty ? null : r.eventType;
    _commentsEnabled = r.commentsEnabled;
    _premiumOnly = r.premiumOnly;
    _eventDate = r.eventDate;
    _eventTime = _parseTime(r.eventTime);
    _coverageKind = r.coverageKind;
    _coverageHours = r.coverageHours;
    _coverageNote = r.coverageNote ?? '';
    _budgetMinCtrl = TextEditingController(
      text: r.budgetMin != null ? r.budgetMin!.toStringAsFixed(0) : '',
    );
    _budgetMaxCtrl = TextEditingController(
      text: r.budgetMax != null ? r.budgetMax!.toStringAsFixed(0) : '',
    );
    _loadPremiumTerms();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _locationCtrl.dispose();
    _budgetCtrl.dispose();
    _budgetMinCtrl.dispose();
    _budgetMaxCtrl.dispose();
    super.dispose();
  }

  /// Photos are saved as they are changed, not on Save.
  ///
  /// They go over their own endpoints — a picture is uploaded, a picture is
  /// deleted — so batching them behind the button would mean a half-applied
  /// edit if one upload failed, and no way to tell which half.
  Future<void> _addPhoto() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (file == null) return;
    final error = await MediaValidator.validate(file, isVideo: false);
    if (!mounted) return;
    if (error != null) {
      AppSnackBar.error(context, error);
      return;
    }

    setState(() => _mediaBusy = true);
    try {
      await widget.repo.uploadRequestMedia(widget.request.id, file);
      final refreshed = await widget.repo.getRequest(widget.request.id);
      if (!mounted) return;
      if (refreshed != null) {
        setState(() => _media = refreshed.media);
        widget.onSave(refreshed);
      }
    } catch (e) {
      debugPrint('[EditRequestSheet] addPhoto ERROR: $e');
      if (mounted) AppSnackBar.error(context, 'Could not add that photo.');
    } finally {
      if (mounted) setState(() => _mediaBusy = false);
    }
  }

  Future<void> _removePhoto(AdMedia media) async {
    setState(() => _mediaBusy = true);
    try {
      await widget.repo.deleteRequestMedia(widget.request.id, media.id);
      if (!mounted) return;
      setState(() => _media = [
            for (final m in _media)
              if (m.id != media.id) m,
          ]);
    } catch (e) {
      debugPrint('[EditRequestSheet] removePhoto ERROR: $e');
      if (mounted) AppSnackBar.error(context, 'Could not remove that photo.');
    } finally {
      if (mounted) setState(() => _mediaBusy = false);
    }
  }

  /// The tier's terms, so the row can name it and disappear when it is off.
  ///
  /// Fetched rather than assumed: the name is a setting and still being
  /// decided, and drawing a control for a tier that has been wound down is an
  /// edit the server would refuse.
  Future<void> _loadPremiumTerms() async {
    try {
      final status = await PremiumService(sl()).status();
      if (mounted) setState(() => _premiumTerms = status.terms);
    } catch (_) {
      // One optional row on a sheet somebody opened to change something else.
    }
  }

  /// "HH:MM" as the server stores it, back into a picker value.
  ///
  /// Null on anything unparseable rather than throwing: an odd value on one
  /// request should leave that field empty, not stop the sheet opening.
  static TimeOfDay? _parseTime(String? wire) {
    if (wire == null || wire.isEmpty) return null;
    final parts = wire.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null || h > 23 || m > 59) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  String get _eventTimeWire => _eventTime == null
      ? ''
      : '${_eventTime!.hour.toString().padLeft(2, '0')}:'
          '${_eventTime!.minute.toString().padLeft(2, '0')}';

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _eventDate ?? now.add(const Duration(days: 7)),
      // Editing a request whose date has already passed is a real case — the
      // shoot slipped — so the floor is today rather than the old date.
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365 * 3)),
    );
    if (picked != null) setState(() => _eventDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _eventTime ?? const TimeOfDay(hour: 10, minute: 0),
    );
    if (picked != null) setState(() => _eventTime = picked);
  }

  /// Pick the coverage, and ask for the detail that choice needs.
  ///
  /// Hourly with no hours, and Other with no note, both render as a label with
  /// nothing after it — so the follow-up is part of choosing rather than a
  /// second field to forget. Same rule the create flow applies.
  Future<void> _pickCoverage(AppThemeExtension ext) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        decoration: BoxDecoration(
          color: ext.homeBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final option in RequestCoverage.values)
                  ListTile(
                    title: Text(
                      option.label,
                      style: TextStyle(
                        color: ext.greetingColor,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      option.hint,
                      style: TextStyle(
                        color: ext.searchHintColor,
                        fontSize: 12.sp,
                      ),
                    ),
                    onTap: () =>
                        Navigator.of(sheetContext).pop(option.wire),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    if (picked == null) return;

    if (picked == 'hourly') {
      final hours = await _askHours(ext);
      if (hours == null) return;
      setState(() {
        _coverageKind = picked;
        _coverageHours = hours;
        _coverageNote = '';
      });
      return;
    }
    if (picked == 'other') {
      final note = await _askNote(ext);
      if (note == null || note.trim().isEmpty) return;
      setState(() {
        _coverageKind = picked;
        _coverageNote = note.trim();
        _coverageHours = null;
      });
      return;
    }
    setState(() {
      _coverageKind = picked;
      // The other choice's detail goes with it, or "Full Day Coverage (~3
      // hrs)" survives an edit from hourly.
      _coverageHours = null;
      _coverageNote = '';
    });
  }

  Future<int?> _askHours(AppThemeExtension ext) async {
    final result = await showTextPromptDialog<int>(
      context: context,
      initialText: _coverageHours?.toString() ?? '',
      builder: (dialogContext, controller) => AlertDialog(
        backgroundColor: ext.cardSurface,
        title: Text('How many hours?',
            style: TextStyle(color: ext.greetingColor, fontSize: 16.sp)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          style: TextStyle(color: ext.greetingColor),
          decoration: const InputDecoration(hintText: 'e.g. 3'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext)
                .pop(int.tryParse(controller.text.trim())),
            child: const Text('Done'),
          ),
        ],
      ),
    );
    return (result != null && result > 0) ? result : null;
  }

  Future<String?> _askNote(AppThemeExtension ext) async {
    final result = await showTextPromptDialog<String>(
      context: context,
      initialText: _coverageNote,
      builder: (dialogContext, controller) => AlertDialog(
        backgroundColor: ext.cardSurface,
        title: Text('Describe the coverage',
            style: TextStyle(color: ext.greetingColor, fontSize: 16.sp)),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 60,
          style: TextStyle(color: ext.greetingColor),
          decoration: const InputDecoration(hintText: 'e.g. Ceremony only'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Done'),
          ),
        ],
      ),
    );
    return result;
  }

  /// The coverage as the sheet shows it back.
  String get _coverageLabel {
    switch (_coverageKind) {
      case 'half_day':
        return 'Half day (~4 hrs)';
      case 'full_day':
        return 'Full day (~8 hrs)';
      case 'multi_day':
        return 'Multi-day';
      case 'hourly':
        final h = _coverageHours;
        return h == null ? 'Hourly' : 'Hourly (~$h ${h == 1 ? 'hr' : 'hrs'})';
      case 'other':
        return _coverageNote.isEmpty ? 'Other' : _coverageNote;
      default:
        return 'Not set';
    }
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;
    setState(() => _saving = true);
    try {
      final updated = await widget.repo.updateRequest(
        widget.request.id,
        title: title,
        description:
            _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        eventType: _eventType,
        location: _locationCtrl.text.trim().isEmpty
            ? null
            : _locationCtrl.text.trim(),
        // Always sent, including empty: an empty list is a deliberate "show it
        // everywhere", and the PATCH reads absent as "leave it alone".
        targetLocations: _targets.map((p) => p.toJson()).toList(),
        eventDate: _eventDate,
        eventTime: _eventTimeWire.isEmpty ? null : _eventTimeWire,
        coverageKind: _coverageKind,
        coverageHours: _coverageKind == 'hourly' ? _coverageHours : null,
        coverageNote: _coverageKind == 'other' ? _coverageNote : null,
        budgetMin: double.tryParse(_budgetMinCtrl.text.trim()),
        budgetMax: double.tryParse(_budgetMaxCtrl.text.trim()),
        commentsEnabled: _commentsEnabled,
        // Only when the tier exists. Sending it to a server that has wound the
        // feature down would have the edit refused or silently ignored, and
        // neither is worth risking for a control the reader cannot see.
        premiumOnly: _premiumTerms?.enabled == true ? _premiumOnly : null,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onSave(updated);
    } catch (e) {
      debugPrint('[EditRequestSheet] save ERROR: $e');
      if (!mounted) return;
      setState(() => _saving = false);
      AppSnackBar.error(context, 'Failed to update request.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = widget.ext;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      decoration: BoxDecoration(
        color: ext.homeBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 20.h + bottom),
      // See the sibling sheets: tile ink has to land on a Material, and this
      // decorated Container would otherwise sit between the two.
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
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
                  'Edit Request',
                  style: TextStyle(
                    color: ext.greetingColor,
                    fontFamily: AppTypography.displayFontFamily,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: AppSpacing.lg.h),
                _EditField(label: 'Title *', ctrl: _titleCtrl, ext: ext),
                SizedBox(height: AppSpacing.md.h),
                _EditField(
                    label: 'Description',
                    ctrl: _descCtrl,
                    ext: ext,
                    maxLines: 3),
                SizedBox(height: AppSpacing.md.h),
                _EditField(label: 'Location', ctrl: _locationCtrl, ext: ext),
                SizedBox(height: AppSpacing.xs.h),
                Text(
                  'Where the shoot happens.',
                  style: TextStyle(color: ext.searchHintColor, fontSize: 11.sp),
                ),
                SizedBox(height: AppSpacing.md.h),
                // The other half of what used to be one field. Separate here as
                // it is on the create form: the venue says where to turn up,
                // this says which photographers ever see the card.
                Text(
                  'Who should see this',
                  style: TextStyle(
                    color: ext.greetingColor,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: AppSpacing.xs.h),
                LocationChips(
                  places: _targets,
                  emptyLabel: 'Everywhere',
                  onAdd: () async {
                    final place = await LocationPickerSheet.show(
                      context,
                      title: 'Show photographers in…',
                    );
                    if (place == null || !mounted) return;
                    if (!_targets.contains(place)) {
                      setState(() => _targets = [..._targets, place]);
                    }
                  },
                  onRemove: (place) => setState(
                    () => _targets = [
                      for (final p in _targets)
                        if (p != place) p,
                    ],
                  ),
                ),
                SizedBox(height: AppSpacing.md.h),
                // ── When, and how much of the day ──────────────────────
                //
                // All four were missing from this sheet while the create form
                // collected them and the server's PATCH already accepted them.
                // The date is the one that mattered most: the card leads on
                // it, the board filters on it, and the premium promise is
                // measured from it — so a postponed shoot meant deleting the
                // request and posting it again.
                _EditPicker(
                  label: 'Event date',
                  value: _eventDate == null
                      ? 'Not set'
                      : '${_eventDate!.day.toString().padLeft(2, '0')}.'
                          '${_eventDate!.month.toString().padLeft(2, '0')}.'
                          '${_eventDate!.year}',
                  isSet: _eventDate != null,
                  ext: ext,
                  onTap: _pickDate,
                ),
                SizedBox(height: AppSpacing.md.h),
                _EditPicker(
                  label: 'Start time',
                  value: _eventTime == null
                      ? 'Not set'
                      : _eventTime!.format(context),
                  isSet: _eventTime != null,
                  ext: ext,
                  onTap: _pickTime,
                  // Optional on a request and always has been: plenty are
                  // posted before the day is planned that far.
                  onClear: _eventTime == null
                      ? null
                      : () => setState(() => _eventTime = null),
                ),
                SizedBox(height: AppSpacing.md.h),
                _EditPicker(
                  label: 'Coverage',
                  value: _coverageLabel,
                  isSet: _coverageKind != null,
                  ext: ext,
                  onTap: () => _pickCoverage(ext),
                  onClear: _coverageKind == null
                      ? null
                      : () => setState(() {
                            _coverageKind = null;
                            _coverageHours = null;
                            _coverageNote = '';
                          }),
                ),
                SizedBox(height: AppSpacing.md.h),
                // A range, like the create form. The single figure this sheet
                // used to hold could only write the midpoint back over what
                // somebody had actually asked for.
                Row(
                  children: [
                    Expanded(
                      child: _EditField(
                        label: 'Budget from (${widget.request.currency})',
                        ctrl: _budgetMinCtrl,
                        ext: ext,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    SizedBox(width: AppSpacing.md.w),
                    Expanded(
                      child: _EditField(
                        label: 'to',
                        ctrl: _budgetMaxCtrl,
                        ext: ext,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: AppSpacing.lg.h),
                Text(
                  'Event Type',
                  style: TextStyle(
                    color: ext.greetingColor,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: AppSpacing.sm.h),
                Wrap(
                  spacing: 8.w,
                  runSpacing: 8.h,
                  children: [
                    _Chip(
                      label: 'Any',
                      selected: _eventType == null,
                      ext: ext,
                      onTap: () => setState(() => _eventType = null),
                    ),
                    ..._editEventTypes.map((t) => _Chip(
                          label: t,
                          selected: _eventType == t.toLowerCase(),
                          ext: ext,
                          onTap: () =>
                              setState(() => _eventType = t.toLowerCase()),
                        )),
                  ],
                ),
                SizedBox(height: AppSpacing.xl.h),
                Text(
                  'Photos',
                  style: TextStyle(
                    color: ext.greetingColor,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: AppSpacing.sm.h),
                _EditPhotos(
                  media: _media,
                  ext: ext,
                  busy: _mediaBusy,
                  onAdd: _addPhoto,
                  onRemove: _removePhoto,
                ),
                // Asking for a creator under a delivery promise, changed
                // after the fact. Drawn only while the tier exists, and only
                // enabled once there is an event date — the promise is
                // measured from it and the server refuses the pair without
                // one, so a switch that could be turned on without a date
                // would only ever produce an error.
                if (_premiumTerms?.enabled == true) ...[
                  SizedBox(height: AppSpacing.xl.h),
                  Material(
                    color: ext.searchFieldFill,
                    borderRadius: BorderRadius.circular(AppRadius.md.r),
                    clipBehavior: Clip.antiAlias,
                    child: SwitchListTile(
                      value: _premiumOnly,
                      onChanged: _eventDate == null
                          ? null
                          : (v) => setState(() => _premiumOnly = v),
                      activeThumbColor: ext.accentGold,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 14.w, vertical: 2.h),
                      title: Text(
                        'Only a ${_premiumTerms!.name} can answer',
                        style: TextStyle(
                          color: ext.greetingColor,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        _eventDate == null
                            ? 'Needs an event date — the promise is measured '
                                'from it.'
                            : 'Creators who promise your photos within '
                                '${_premiumTerms!.windowLabel} of the shoot.',
                        style: TextStyle(
                          color: ext.searchHintColor,
                          fontSize: 12.sp,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),
                ],
                SizedBox(height: AppSpacing.xl.h),
                Material(
                  // Not a decorated Container: the tile's ink needs a Material
                  // beneath it, and a DecoratedBox in between swallows it.
                  color: ext.searchFieldFill,
                  borderRadius: BorderRadius.circular(AppRadius.md.r),
                  clipBehavior: Clip.antiAlias,
                  child: SwitchListTile(
                    value: _commentsEnabled,
                    onChanged: (v) => setState(() => _commentsEnabled = v),
                    activeThumbColor: ext.accentGold,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 14.w, vertical: 2.h),
                    title: Text(
                      'Allow comments',
                      style: TextStyle(
                        color: ext.greetingColor,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      'Let people comment on this request',
                      style: TextStyle(
                          color: ext.searchHintColor, fontSize: 12.sp),
                    ),
                  ),
                ),
                SizedBox(height: AppSpacing.xxl.h),
                Semantics(
                    button: true,
                    label: 'Save',
                    child: GestureDetector(
                      onTap: _saving ? null : _save,
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 15.h),
                        decoration: BoxDecoration(
                          gradient: _saving
                              ? null
                              : LinearGradient(
                                  colors: [ext.accentGold, ext.accentGoldDark],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                          color: _saving ? ext.searchFieldFill : null,
                          borderRadius: BorderRadius.circular(14.r),
                        ),
                        alignment: Alignment.center,
                        child: _saving
                            ? SizedBox(
                                width: 20.w,
                                height: 20.w,
                                child: CircularProgressIndicator(
                                    color: ext.accentGold, strokeWidth: 2),
                              )
                            : Text(
                                'Save changes',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A field whose value is chosen rather than typed — a date, a time, the
/// coverage.
///
/// Shaped like [_EditField] beside it so a form of both does not read as two
/// different forms: same ground, same border, same label above a value. The
/// difference is that tapping it opens a picker, and that an optional one can
/// be cleared again — which matters because a time or a coverage somebody set
/// by accident would otherwise be stuck on the request for good.
class _EditPicker extends StatelessWidget {
  const _EditPicker({
    required this.label,
    required this.value,
    required this.isSet,
    required this.ext,
    required this.onTap,
    this.onClear,
  });

  final String label;
  final String value;

  /// Unset values are shown in the hint colour, so "Not set" does not read as
  /// something somebody typed.
  final bool isSet;
  final AppThemeExtension ext;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md.w,
          vertical: AppSpacing.md.h,
        ),
        decoration: BoxDecoration(
          color: ext.searchFieldFill,
          borderRadius: BorderRadius.circular(AppRadius.md.r),
          border: Border.all(
            color: ext.searchHintColor.withValues(alpha: 0.25),
            width: 0.8,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: ext.searchHintColor,
                      fontSize: 12.sp,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    value,
                    style: TextStyle(
                      color: isSet ? ext.greetingColor : ext.searchHintColor,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (onClear != null)
              GestureDetector(
                onTap: onClear,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: EdgeInsets.only(left: AppSpacing.sm.w),
                  child: Icon(Icons.close_rounded,
                      size: 18.sp, color: ext.searchHintColor),
                ),
              )
            else
              Icon(Icons.chevron_right_rounded,
                  size: 20.sp, color: ext.searchHintColor),
          ],
        ),
      ),
    );
  }
}

class _EditField extends StatelessWidget {
  const _EditField({
    required this.label,
    required this.ctrl,
    required this.ext,
    this.maxLines = 1,
    this.keyboardType = TextInputType.text,
  });
  final String label;
  final TextEditingController ctrl;
  final AppThemeExtension ext;
  final int maxLines;
  final TextInputType keyboardType;

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboardType,
      dense: true,
      label: label,
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
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

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.ext,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final AppThemeExtension ext;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 38.w,
        height: 38.w,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10.r),
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: color, size: 20.sp),
      ),
      title: Text(
        label,
        style: TextStyle(
          color: ext.greetingColor,
          fontSize: 14.sp,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// The request's photos while editing: what is on it, and a tile to add more.
///
/// Changes here are applied as they are made rather than on Save — each photo
/// is its own upload or delete — so the thumbnails always show what the
/// request actually has.
class _EditPhotos extends StatelessWidget {
  const _EditPhotos({
    required this.media,
    required this.ext,
    required this.busy,
    required this.onAdd,
    required this.onRemove,
  });

  final List<AdMedia> media;
  final AppThemeExtension ext;
  final bool busy;
  final VoidCallback onAdd;
  final void Function(AdMedia) onRemove;

  static const _tile = 72.0;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8.w,
      runSpacing: 8.h,
      children: [
        for (final item in media)
          SizedBox(
            width: _tile.w,
            height: _tile.w,
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.sm.r),
                    child: ColoredBox(
                      color: ext.searchFieldFill,
                      child: JpergImage(
                        imageUrl: item.url,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Icon(
                          Icons.broken_image_outlined,
                          size: 18.r,
                          color: ext.searchHintColor,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  child: Semantics(
                    button: true,
                    label: 'Remove photo',
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: busy ? null : () => onRemove(item),
                      child: Padding(
                        padding: EdgeInsets.all(4.r),
                        child: Container(
                          padding: EdgeInsets.all(2.r),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: AppSvgIcon(AppIcons.closeMd,
                              size: 12.r, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        Semantics(
          button: true,
          label: 'Add photo',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: busy ? null : onAdd,
            child: Container(
              width: _tile.w,
              height: _tile.w,
              decoration: BoxDecoration(
                color: ext.searchFieldFill,
                borderRadius: BorderRadius.circular(AppRadius.sm.r),
                border: Border.all(
                  color: ext.searchHintColor.withValues(alpha: 0.25),
                  width: 0.8,
                ),
              ),
              child: busy
                  ? Center(
                      child: SizedBox(
                        width: 16.r,
                        height: 16.r,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: ext.accentGold,
                        ),
                      ),
                    )
                  : AppSvgIcon(AppIcons.add,
                      color: ext.searchHintColor, size: 22.r),
            ),
          ),
        ),
      ],
    );
  }
}
