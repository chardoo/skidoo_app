import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/common/widgets/app_widgets.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/core/utils/snackbar_utils.dart';
import 'package:skidoo_app/features/ads/data/models/feed_request_model.dart';
import 'package:skidoo_app/features/ads/data/repositories/ads_repository.dart';
import 'package:skidoo_app/features/ads/presentation/pages/create_campaign_page.dart';
import 'package:skidoo_app/features/ads/presentation/pages/review_photographers_page.dart';
import 'package:skidoo_app/features/ads/presentation/widgets/interested_row.dart';
import 'package:skidoo_app/core/utils/web_wrap.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:skidoo_app/core/theme/app_radius.dart';
import 'package:skidoo_app/core/theme/app_spacing.dart';

class MyRequestsPage extends StatefulWidget {
  const MyRequestsPage({super.key, this.embedded = false});

  /// True when this list is a tab inside Broadcasts, which already provides
  /// the header and the back button — so it renders as a bare list rather
  /// than a second page stacked inside the first.
  final bool embedded;

  @override
  State<MyRequestsPage> createState() => _MyRequestsPageState();
}

class _MyRequestsPageState extends State<MyRequestsPage> {
  final _repo = AdsRepository();
  List<FeedRequestModel> _requests = [];
  bool _loading = true;
  String? _errorMessage;

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
  /// them. Deleting from in there pops with true, so the list reloads without
  /// the request that no longer exists.
  Future<void> _openRequest(FeedRequestModel req) async {
    final deleted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ReviewPhotographersPage(request: req)),
    );
    if (!mounted) return;
    if (deleted == true) AppSnackBar.success(context, 'Request deleted.');
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
      builder: (_) => _EditRequestSheet(
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
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    final page = Scaffold(
      backgroundColor: ext.homeBackground,
      appBar: widget.embedded ? null : AppBar(
        backgroundColor: ext.homeBackground,
        elevation: 0,
        leading: kIsWeb
            ? null
            : AppBackButton(onPressed: () => Navigator.of(context).pop()),
        title: Text(
          'My Requests',
          style: TextStyle(
            color: ext.greetingColor,
            fontSize: 17.sp,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
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
                  ? const AppEmptyState(
                      icon: Icons.inbox_outlined,
                      message: 'You haven\'t posted any requests yet',
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
                          );
                        },
                      ),
                    ),
    );
    return widget.embedded
        ? page
        : webWrap(page, backgroundColor: ext.homeBackground);
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
  });
  final FeedRequestModel request;
  final AppThemeExtension ext;
  final VoidCallback onActionTap;

  /// Tapping the card opens the request and who answered it.
  final VoidCallback? onOpen;
  final VoidCallback? onRepublish;
  final VoidCallback? onInterestedTap;

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
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: 10.w),
              _StatusBadge(status: r.status, color: statusColor, ext: ext),
            ],
          ),
          SizedBox(height: AppSpacing.sm.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 4.h,
            children: [
              if (r.eventType.isNotEmpty)
                _MetaText(
                    icon: Icons.event_rounded, label: r.eventType, ext: ext),
              if (r.location.isNotEmpty)
                _MetaText(
                    icon: Icons.location_on_outlined,
                    label: r.location,
                    ext: ext),
              if (r.budgetAmount != null)
                _MetaText(
                  icon: Icons.payments_outlined,
                  label: '${r.currency} ${r.budgetAmount!.toStringAsFixed(0)}',
                  ext: ext,
                ),
              if (r.promotedCampaignId != null)
                _MetaText(
                  icon: Icons.rocket_launch_rounded,
                  label: 'Promoted',
                  ext: ext,
                  color: ext.accentGold,
                ),
            ],
          ),
          if (r.description.isNotEmpty) ...[
            SizedBox(height: AppSpacing.sm.h),
            Text(
              r.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: ext.searchHintColor,
                fontSize: 12.sp,
                height: 1.4,
              ),
            ),
          ],
          if (r.interestedCount > 0) ...[
            SizedBox(height: AppSpacing.md.h),
            InterestedRow(
              interested: r.interested,
              count: r.interestedCount,
              ext: ext,
              onTap: onInterestedTap,
            ),
          ],
          // A closed request keeps its answers, so republishing is offered
          // right on the card rather than buried in the actions sheet.
          if ((r.status == 'closed' || r.status == 'filled') &&
              onRepublish != null) ...[
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
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
          if (r.status == 'open' || r.status == 'promoted') ...[
            SizedBox(height: AppSpacing.md.h),
            Semantics(
                button: true,
                label: 'Action tap',
                child: GestureDetector(
                  onTap: onActionTap,
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 10.h),
                    decoration: BoxDecoration(
                      color: ext.searchFieldFill,
                      borderRadius: BorderRadius.circular(AppRadius.md.r),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Manage',
                      style: TextStyle(
                        color: ext.greetingColor,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                )),
          ],
        ],
      ),
      ),
    );
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

class _StatusBadge extends StatelessWidget {
  const _StatusBadge(
      {required this.status, required this.color, required this.ext});
  final String status;
  final Color color;
  final AppThemeExtension ext;

  static String _label(String s) => switch (s) {
        'open' => 'Open',
        'promoted' => 'Promoted',
        'pending_review' => 'In Review',
        'filled' => 'Filled',
        'closed' => 'Closed',
        'rejected' => 'Rejected',
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
        _label(status),
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

class _MetaText extends StatelessWidget {
  const _MetaText(
      {required this.icon, required this.label, required this.ext, this.color});
  final IconData icon;
  final String label;
  final AppThemeExtension ext;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? ext.searchHintColor;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11.sp, color: c),
        SizedBox(width: 3.w),
        Text(
          label,
          style:
              TextStyle(color: c, fontSize: 11.sp, fontWeight: FontWeight.w500),
        ),
      ],
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

class _EditRequestSheet extends StatefulWidget {
  const _EditRequestSheet({
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
  State<_EditRequestSheet> createState() => _EditRequestSheetState();
}

class _EditRequestSheetState extends State<_EditRequestSheet> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _locationCtrl;
  late final TextEditingController _budgetCtrl;
  String? _eventType;
  bool _commentsEnabled = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final r = widget.request;
    _titleCtrl = TextEditingController(text: r.title);
    _descCtrl = TextEditingController(text: r.description);
    _locationCtrl = TextEditingController(text: r.location);
    _budgetCtrl = TextEditingController(
      text: r.budgetAmount != null ? r.budgetAmount!.toStringAsFixed(0) : '',
    );
    _eventType = r.eventType.isEmpty ? null : r.eventType;
    _commentsEnabled = r.commentsEnabled;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _locationCtrl.dispose();
    _budgetCtrl.dispose();
    super.dispose();
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
        budgetAmount: double.tryParse(_budgetCtrl.text.trim()),
        commentsEnabled: _commentsEnabled,
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
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
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
                SizedBox(height: AppSpacing.md.h),
                _EditField(
                  label: 'Budget (${widget.request.currency})',
                  ctrl: _budgetCtrl,
                  ext: ext,
                  keyboardType: TextInputType.number,
                ),
                SizedBox(height: AppSpacing.lg.h),
                Text(
                  'Event Type',
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
                        fontWeight: FontWeight.w600,
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
                                  fontWeight: FontWeight.w800,
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
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
