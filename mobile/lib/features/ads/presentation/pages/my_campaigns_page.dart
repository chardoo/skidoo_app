import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/common/widgets/app_widgets.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/core/utils/snackbar_utils.dart';
import 'package:skidoo_app/features/ads/data/repositories/ads_repository.dart';
import 'package:skidoo_app/features/ads/models/ad_campaign.dart';
import 'package:skidoo_app/features/ads/presentation/pages/ads_checkout_page.dart';
import 'package:skidoo_app/features/ads/presentation/pages/edit_campaign_page.dart';
import 'package:skidoo_app/core/utils/web_wrap.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:skidoo_app/core/theme/app_radius.dart';
import 'package:skidoo_app/core/theme/app_spacing.dart';

class MyCampaignsPage extends StatefulWidget {
  const MyCampaignsPage({super.key, this.embedded = false});

  /// True when this list is a tab inside Broadcasts, which already provides
  /// the header and the back button — so it renders as a bare list rather
  /// than a second page stacked inside the first.
  final bool embedded;

  @override
  State<MyCampaignsPage> createState() => _MyCampaignsPageState();
}

class _MyCampaignsPageState extends State<MyCampaignsPage> {
  final _repo = AdsRepository();
  List<AdCampaign> _campaigns = [];
  bool _loading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    debugPrint('[MyCampaignsPage] _load');
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final campaigns = await _repo.getMyCampaigns();
      if (!mounted) return;
      debugPrint('[MyCampaignsPage] loaded ${campaigns.length} campaigns');
      setState(() {
        _campaigns = campaigns;
        _loading = false;
      });
    } catch (e) {
      debugPrint('[MyCampaignsPage] _load ERROR: $e');
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not load your campaigns.';
        _loading = false;
      });
    }
  }

  Future<void> _pause(AdCampaign campaign) async {
    debugPrint('[MyCampaignsPage] _pause campaignId=${campaign.id}');
    try {
      await _repo.pauseCampaign(campaign.id);
      if (!mounted) return;
      AppSnackBar.success(context, 'Campaign paused.');
    } catch (e) {
      debugPrint('[MyCampaignsPage] _pause ERROR: $e');
      if (!mounted) return;
      AppSnackBar.error(context, 'Could not pause campaign. Try again.');
    } finally {
      _load();
    }
  }

  Future<void> _resume(AdCampaign campaign) async {
    debugPrint('[MyCampaignsPage] _resume campaignId=${campaign.id}');
    try {
      await _repo.resumeCampaign(campaign.id);
      if (!mounted) return;
      AppSnackBar.success(context, 'Campaign resumed.');
    } catch (e) {
      debugPrint('[MyCampaignsPage] _resume ERROR: $e');
      if (!mounted) return;
      AppSnackBar.error(context, 'Could not resume campaign. Try again.');
    } finally {
      _load();
    }
  }

  Future<void> _confirmDelete(AdCampaign campaign) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Delete campaign?',
      message: '"${campaign.name}" will be permanently deleted.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (!confirmed) return;
    debugPrint('[MyCampaignsPage] _delete campaignId=${campaign.id}');
    try {
      await _repo.deleteCampaign(campaign.id);
      if (!mounted) return;
      AppSnackBar.success(context, 'Campaign deleted.');
    } catch (e) {
      debugPrint('[MyCampaignsPage] _delete ERROR: $e');
      if (!mounted) return;
      AppSnackBar.error(context, 'Could not delete campaign. Try again.');
    } finally {
      _load();
    }
  }

  Future<void> _showEditSheet(AdCampaign campaign) async {
    AdCampaign full;
    try {
      full = await _repo.getCampaign(campaign.id);
    } catch (e) {
      debugPrint('[MyCampaignsPage] _showEditSheet getCampaign ERROR: $e');
      if (!mounted) return;
      AppSnackBar.error(context, 'Could not load campaign details. Try again.');
      return;
    }
    if (!mounted) return;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EditCampaignPage(campaign: full),
      ),
    );
    if (saved == true) _load();
  }

  void _showTopUpDialog(AdCampaign campaign) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final ctrl = TextEditingController();

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
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
                    'Top Up Campaign',
                    style: TextStyle(
                      color: ext.greetingColor,
                      fontSize: 20.sp,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.4,
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    campaign.name,
                    style:
                        TextStyle(color: ext.searchHintColor, fontSize: 13.sp),
                  ),
                  SizedBox(height: AppSpacing.xl.h),
                  AppTextField(
                    controller: ctrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    autofocus: true,
                    dense: true,
                    hint: 'Amount to add (e.g. 200)',
                  ),
                  SizedBox(height: AppSpacing.xl.h),
                  Semantics(
                      button: true,
                      label: 'Amount',
                      child: GestureDetector(
                        onTap: () async {
                          final amount = double.tryParse(ctrl.text.trim());
                          if (amount == null || amount <= 0) {
                            AppSnackBar.error(context, 'Enter a valid amount.');
                            return;
                          }
                          Navigator.of(context).pop();
                          await _topUp(
                            campaign.id,
                            amount,
                          );
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
                            'Pay & Top Up',
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
      ),
    );
  }

  Future<void> _verifyPayment(String campaignId, {bool isTopUp = false}) async {
    debugPrint(
        '[MyCampaignsPage] _verifyPayment campaignId=$campaignId isTopUp=$isTopUp');
    try {
      final verify = await _repo.verifyPayment(campaignId);
      debugPrint(
          '[MyCampaignsPage] _verifyPayment — success=${verify.success} status=${verify.status}');
      if (!mounted) return;
      if (verify.success) {
        AppSnackBar.success(
          context,
          verify.message.isNotEmpty
              ? verify.message
              : isTopUp
                  ? 'Top-up confirmed! Campaign resumed.'
                  : 'Payment confirmed! Campaign is under review.',
        );
      }
    } catch (e) {
      debugPrint('[MyCampaignsPage] _verifyPayment ERROR: $e');
    } finally {
      _load();
    }
  }

  Future<void> _pay(String campaignId) async {
    debugPrint('[MyCampaignsPage] _pay campaignId=$campaignId');
    try {
      final result = await _repo.payCampaign(campaignId);
      debugPrint(
        '[MyCampaignsPage] _pay — authorizationUrl=${result.authorizationUrl} '
        'reference=${result.reference}',
      );
      if (!mounted) return;
      if (result.authorizationUrl.isEmpty) {
        AppSnackBar.error(context, 'Could not get payment URL. Try again.');
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AdsCheckoutPage(
            authorizationUrl: result.authorizationUrl,
            reference: result.reference,
            amountGhs: result.amountGhs,
            originalAmount: result.originalAmount,
            originalCurrency: result.originalCurrency,
            onSuccess: () {},
          ),
        ),
      );
      if (!mounted) return;
      await _verifyPayment(campaignId);
    } catch (e) {
      debugPrint('[MyCampaignsPage] _pay ERROR: $e');
      if (!mounted) return;
      AppSnackBar.error(context, 'Payment failed. Please try again.');
    }
  }

  Future<void> _topUp(String campaignId, double amount) async {
    debugPrint(
        '[MyCampaignsPage] _topUp campaignId=$campaignId amount=$amount');
    try {
      final result = await _repo.topUpCampaign(campaignId, amount);
      debugPrint(
        '[MyCampaignsPage] _topUp — authorizationUrl=${result.authorizationUrl} '
        'reference=${result.reference}',
      );
      if (!mounted) return;
      if (result.authorizationUrl.isEmpty) {
        AppSnackBar.error(context, 'Could not get payment URL. Try again.');
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AdsCheckoutPage(
            authorizationUrl: result.authorizationUrl,
            reference: result.reference,
            amountGhs: result.amountGhs,
            originalAmount: result.originalAmount,
            originalCurrency: result.originalCurrency,
            onSuccess: () {},
          ),
        ),
      );
      if (!mounted) return;
      await _verifyPayment(campaignId, isTopUp: true);
    } catch (e) {
      debugPrint('[MyCampaignsPage] _topUp ERROR: $e');
      if (!mounted) return;
      AppSnackBar.error(context, 'Top-up failed. Please try again.');
    }
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
          'My Campaigns',
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
              : _campaigns.isEmpty
                  ? const AppEmptyState(
                      icon: Icons.rocket_launch_outlined,
                      message: 'No campaigns yet',
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: ext.accentGold,
                      child: ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: EdgeInsets.only(bottom: AppSpacing.xl.h),
                        itemCount: _campaigns.length,
                        itemBuilder: (_, i) => _CampaignTile(
                          campaign: _campaigns[i],
                          ext: ext,
                          onTopUp: () => _showTopUpDialog(_campaigns[i]),
                          onPay: () => _pay(_campaigns[i].id),
                          onEdit: () => _showEditSheet(_campaigns[i]),
                          onPause: () => _pause(_campaigns[i]),
                          onResume: () => _resume(_campaigns[i]),
                          onDelete: () => _confirmDelete(_campaigns[i]),
                        ),
                      ),
                    ),
    );
    return widget.embedded
        ? page
        : webWrap(page, backgroundColor: ext.homeBackground);
  }
}

// ── Campaign tile ─────────────────────────────────────────────────────────────

class _CampaignTile extends StatelessWidget {
  const _CampaignTile({
    required this.campaign,
    required this.ext,
    required this.onTopUp,
    required this.onPay,
    required this.onEdit,
    required this.onPause,
    required this.onResume,
    required this.onDelete,
  });
  final AdCampaign campaign;
  final AppThemeExtension ext;
  final VoidCallback onTopUp;
  final VoidCallback onPay;
  final VoidCallback onEdit;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(campaign.status);

    return Container(
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
          // ── Name + status ────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: Text(
                  campaign.name,
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
              _Badge(label: campaign.status.label, color: statusColor),
              if (campaign.status.isEditable &&
                  !campaign.status.canPause &&
                  !campaign.status.canResume &&
                  campaign.status != CampaignStatus.rejected) ...[
                SizedBox(width: 6.w),
                Semantics(
                    button: true,
                    label: 'Edit',
                    child: GestureDetector(
                      onTap: onEdit,
                      child: Icon(Icons.edit_outlined,
                          size: 16.sp,
                          color: ext.searchHintColor.withValues(alpha: 0.7)),
                    )),
              ],
            ],
          ),

          SizedBox(height: 10.h),

          // ── Budget bar ───────────────────────────────────────────────────
          if (campaign.budgetAmount > 0) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Budget',
                  style: TextStyle(color: ext.searchHintColor, fontSize: 11.sp),
                ),
                Text(
                  '${campaign.currency} ${campaign.spent.toStringAsFixed(0)} / ${campaign.budgetAmount.toStringAsFixed(0)}',
                  style: TextStyle(
                    color: ext.greetingColor,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            SizedBox(height: 6.h),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.xs.r),
              child: LinearProgressIndicator(
                value: campaign.spentPercent,
                backgroundColor: ext.searchFieldFill,
                color:
                    campaign.remaining <= 0 ? Colors.redAccent : ext.accentGold,
                minHeight: 5.h,
              ),
            ),
            SizedBox(height: 10.h),
          ],

          // ── Objective ────────────────────────────────────────────────────
          Text(
            campaign.objective.label,
            style: TextStyle(color: ext.searchHintColor, fontSize: 12.sp),
          ),

          // ── Pay & Submit button (draft / pending payment) ─────────────
          if (campaign.status.canPay) ...[
            SizedBox(height: AppSpacing.md.h),
            Semantics(
                button: true,
                label: 'Pay',
                child: GestureDetector(
                  onTap: onPay,
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 10.h),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [ext.accentGold, ext.accentGoldDark],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(AppRadius.md.r),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.payment_rounded,
                            color: Colors.white, size: 16.sp),
                        SizedBox(width: 5.w),
                        Text(
                          'Pay & Submit for Review',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                )),
          ],

          // ── Active: Edit + Pause side by side ────────────────────────
          if (campaign.status.canPause) ...[
            SizedBox(height: AppSpacing.md.h),
            Row(
              children: [
                Expanded(
                  child: _OutlinedActionBtn(
                    icon: Icons.edit_outlined,
                    label: 'Edit',
                    ext: ext,
                    onTap: onEdit,
                  ),
                ),
                SizedBox(width: AppSpacing.sm.w),
                Expanded(
                  child: _OutlinedActionBtn(
                    icon: Icons.pause_circle_outline_rounded,
                    label: 'Pause',
                    ext: ext,
                    onTap: onPause,
                  ),
                ),
              ],
            ),
          ],

          // ── Paused: Resume + Top-up, then Edit below ──────────────────
          if (campaign.status.canResume) ...[
            SizedBox(height: AppSpacing.md.h),
            Row(
              children: [
                Expanded(
                  child: Semantics(
                      button: true,
                      label: 'Resume',
                      child: GestureDetector(
                        onTap: onResume,
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 10.h),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF10B981), Color(0xFF059669)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(AppRadius.md.r),
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.play_circle_outline_rounded,
                                  color: Colors.white, size: 16.sp),
                              SizedBox(width: 5.w),
                              Text(
                                'Resume',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )),
                ),
                SizedBox(width: AppSpacing.sm.w),
                Expanded(
                  child: Semantics(
                      button: true,
                      label: 'Top up',
                      child: GestureDetector(
                        onTap: onTopUp,
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 10.h),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [ext.accentGold, ext.accentGoldDark],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(AppRadius.md.r),
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add_rounded,
                                  color: Colors.white, size: 16.sp),
                              SizedBox(width: 5.w),
                              Text(
                                'Top Up',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )),
                ),
              ],
            ),
            SizedBox(height: AppSpacing.sm.h),
            _OutlinedActionBtn(
              icon: Icons.edit_outlined,
              label: 'Edit Campaign',
              ext: ext,
              onTap: onEdit,
            ),
          ],

          // ── Rejected: Fix & Resubmit (gold) ──────────────────────────
          if (campaign.status == CampaignStatus.rejected) ...[
            SizedBox(height: AppSpacing.md.h),
            Semantics(
                button: true,
                label: 'Edit',
                child: GestureDetector(
                  onTap: onEdit,
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 10.h),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [ext.accentGold, ext.accentGoldDark],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(AppRadius.md.r),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.edit_outlined,
                            color: Colors.white, size: 16.sp),
                        SizedBox(width: 5.w),
                        Text(
                          'Fix & Resubmit',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                )),
            if (campaign.rejectionReason != null &&
                campaign.rejectionReason!.isNotEmpty) ...[
              SizedBox(height: AppSpacing.sm.h),
              Container(
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(
                      color: Colors.redAccent.withValues(alpha: 0.2),
                      width: 0.8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded,
                        color: Colors.redAccent, size: 14.sp),
                    SizedBox(width: 6.w),
                    Expanded(
                      child: Text(
                        campaign.rejectionReason!,
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontSize: 11.sp,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],

          // ── Delete button (draft only) ────────────────────────────────
          if (campaign.status.canDelete) ...[
            SizedBox(height: 10.h),
            Semantics(
                button: true,
                label: 'Delete',
                child: GestureDetector(
                  onTap: onDelete,
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 10.h),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppRadius.md.r),
                      border: Border.all(
                        color: Colors.redAccent.withValues(alpha: 0.3),
                        width: 1.0,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.delete_outline_rounded,
                            color: Colors.redAccent, size: 16.sp),
                        SizedBox(width: 5.w),
                        Text(
                          'Delete Draft',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                )),
          ],
        ],
      ),
    );
  }

  static Color _statusColor(CampaignStatus s) => switch (s) {
        CampaignStatus.active => const Color(0xFF10B981),
        CampaignStatus.paused => Colors.orangeAccent,
        CampaignStatus.pendingReview => const Color(0xFF3B82F6),
        CampaignStatus.pendingPayment => const Color(0xFFF59E0B),
        CampaignStatus.draft => const Color(0xFF6B7280),
        CampaignStatus.completed => const Color(0xFF8B5CF6),
        CampaignStatus.rejected => Colors.redAccent,
      };
}

class _OutlinedActionBtn extends StatelessWidget {
  const _OutlinedActionBtn({
    required this.icon,
    required this.label,
    required this.ext,
    required this.onTap,
  });
  final IconData icon;
  final String label;
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
            padding: EdgeInsets.symmetric(vertical: 10.h),
            decoration: BoxDecoration(
              color: ext.searchFieldFill,
              borderRadius: BorderRadius.circular(AppRadius.md.r),
              border: Border.all(
                color: ext.searchHintColor.withValues(alpha: 0.25),
                width: 1.0,
              ),
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: ext.greetingColor, size: 15.sp),
                SizedBox(width: 5.w),
                Text(
                  label,
                  style: TextStyle(
                    color: ext.greetingColor,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ));
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});
  final String label;
  final Color color;

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
        label,
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
