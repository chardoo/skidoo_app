import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/common/widgets/app_widgets.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/core/utils/snackbar_utils.dart';
import 'package:skidoo_app/features/ads/data/models/feed_request_model.dart';
import 'package:skidoo_app/features/ads/data/repositories/ads_repository.dart';
import 'package:skidoo_app/features/ads/presentation/pages/ads_checkout_page.dart';

class MyRequestsPage extends StatefulWidget {
  const MyRequestsPage({super.key});

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

  Future<void> _close(FeedRequestModel req, String status) async {
    debugPrint('[MyRequestsPage] _close id=${req.id} status=$status');
    try {
      await _repo.closeRequest(req.id, status: status);
      if (!mounted) return;
      AppSnackBar.success(
        context,
        status == 'filled'
            ? 'Request marked as filled.'
            : 'Request closed.',
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
      final campaignId = result['campaign_id'] as String? ?? result['id'] as String?;
      debugPrint('[MyRequestsPage] _promote — campaignId=$campaignId');
      if (campaignId == null || campaignId.isEmpty) {
        if (!mounted) return;
        AppSnackBar.error(context, 'Could not promote request. Try again.');
        return;
      }
      final url = await _repo.payCampaign(campaignId);
      debugPrint('[MyRequestsPage] _promote — authorizationUrl=$url');
      if (!mounted) return;
      if (url.isEmpty) {
        AppSnackBar.error(context, 'Could not get payment URL. Try again.');
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AdsCheckoutPage(
            authorizationUrl: url,
            onSuccess: () {
              AppSnackBar.success(
                context,
                'Payment received! Your campaign is under review.',
              );
            },
          ),
        ),
      );
    } catch (e) {
      debugPrint('[MyRequestsPage] _promote ERROR: $e');
      if (!mounted) return;
      AppSnackBar.error(context, 'Failed to promote request.');
    }
  }

  void _showActions(BuildContext context, FeedRequestModel req, AppThemeExtension ext) {
    final isActive = req.status == 'open' || req.status == 'promoted';
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: ext.homeBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: EdgeInsets.symmetric(vertical: 12.h),
                width: 36.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: ext.searchHintColor.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2.r),
                ),
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
              SizedBox(height: 8.h),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return Scaffold(
      backgroundColor: ext.homeBackground,
      appBar: AppBar(
        backgroundColor: ext.homeBackground,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: ext.greetingColor, size: 20.sp),
          onPressed: () => Navigator.of(context).pop(),
        ),
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
                            onActionTap: () =>
                                _showActions(context, req, ext),
                          );
                        },
                      ),
                    ),
    );
  }
}

// ── My request tile ───────────────────────────────────────────────────────────

class _MyRequestTile extends StatelessWidget {
  const _MyRequestTile({
    required this.request,
    required this.ext,
    required this.onActionTap,
  });
  final FeedRequestModel request;
  final AppThemeExtension ext;
  final VoidCallback onActionTap;

  @override
  Widget build(BuildContext context) {
    final r = request;
    final statusColor = _statusColor(r.status);

    return Container(
      margin: EdgeInsets.fromLTRB(14.w, 10.h, 14.w, 0),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: ext.cardSurface,
        borderRadius: BorderRadius.circular(16.r),
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
          SizedBox(height: 8.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 4.h,
            children: [
              if (r.eventType.isNotEmpty)
                _MetaText(icon: Icons.event_rounded, label: r.eventType, ext: ext),
              if (r.location.isNotEmpty)
                _MetaText(icon: Icons.location_on_outlined, label: r.location, ext: ext),
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
            SizedBox(height: 8.h),
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
          if (r.status == 'open' || r.status == 'promoted') ...[
            SizedBox(height: 12.h),
            GestureDetector(
              onTap: onActionTap,
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 10.h),
                decoration: BoxDecoration(
                  color: ext.searchFieldFill,
                  borderRadius: BorderRadius.circular(12.r),
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
            ),
          ],
        ],
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
  const _StatusBadge({required this.status, required this.color, required this.ext});
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
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20.r),
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
  const _MetaText({required this.icon, required this.label, required this.ext, this.color});
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
          style: TextStyle(color: c, fontSize: 11.sp, fontWeight: FontWeight.w500),
        ),
      ],
    );
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
