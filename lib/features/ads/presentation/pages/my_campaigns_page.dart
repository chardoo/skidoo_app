import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/common/widgets/app_widgets.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/core/utils/snackbar_utils.dart';
import 'package:skidoo_app/features/ads/data/repositories/ads_repository.dart';
import 'package:skidoo_app/features/ads/presentation/pages/ads_checkout_page.dart';

class MyCampaignsPage extends StatefulWidget {
  const MyCampaignsPage({super.key});

  @override
  State<MyCampaignsPage> createState() => _MyCampaignsPageState();
}

class _MyCampaignsPageState extends State<MyCampaignsPage> {
  final _repo = AdsRepository();
  List<Map<String, dynamic>> _campaigns = [];
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

  void _showTopUpDialog(Map<String, dynamic> campaign) {
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
                      margin: EdgeInsets.symmetric(vertical: 12.h),
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
                    campaign['name'] as String? ?? 'Campaign',
                    style:
                        TextStyle(color: ext.searchHintColor, fontSize: 13.sp),
                  ),
                  SizedBox(height: 20.h),
                  TextField(
                    controller: ctrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    autofocus: true,
                    style: TextStyle(color: ext.greetingColor, fontSize: 14.sp),
                    decoration: InputDecoration(
                      hintText: 'Amount to add (e.g. 200)',
                      hintStyle:
                          TextStyle(color: ext.searchHintColor, fontSize: 14.sp),
                      filled: true,
                      fillColor: ext.searchFieldFill,
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 14.w, vertical: 13.h),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: BorderSide(
                            color: ext.accentGold.withValues(alpha: 0.6),
                            width: 1.2),
                      ),
                    ),
                  ),
                  SizedBox(height: 20.h),
                  GestureDetector(
                    onTap: () async {
                      final amount = double.tryParse(ctrl.text.trim());
                      if (amount == null || amount <= 0) {
                        AppSnackBar.error(context, 'Enter a valid amount.');
                        return;
                      }
                      Navigator.of(context).pop();
                      await _topUp(
                        campaign['id'] as String? ?? '',
                        amount,
                      );
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 15.h),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [ext.accentGold, const Color(0xFFFF6B35)],
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
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _topUp(String campaignId, double amount) async {
    debugPrint('[MyCampaignsPage] _topUp campaignId=$campaignId amount=$amount');
    try {
      final url = await _repo.topUpCampaign(campaignId, amount);
      debugPrint('[MyCampaignsPage] _topUp — authorizationUrl=$url');
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
              AppSnackBar.success(context, 'Top-up successful! Campaign resumed.');
              _load();
            },
          ),
        ),
      );
    } catch (e) {
      debugPrint('[MyCampaignsPage] _topUp ERROR: $e');
      if (!mounted) return;
      AppSnackBar.error(context, 'Top-up failed. Please try again.');
    }
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
                        padding: EdgeInsets.only(bottom: 20.h),
                        itemCount: _campaigns.length,
                        itemBuilder: (_, i) => _CampaignTile(
                          campaign: _campaigns[i],
                          ext: ext,
                          onTopUp: () => _showTopUpDialog(_campaigns[i]),
                        ),
                      ),
                    ),
    );
  }
}

// ── Campaign tile ─────────────────────────────────────────────────────────────

class _CampaignTile extends StatelessWidget {
  const _CampaignTile({
    required this.campaign,
    required this.ext,
    required this.onTopUp,
  });
  final Map<String, dynamic> campaign;
  final AppThemeExtension ext;
  final VoidCallback onTopUp;

  @override
  Widget build(BuildContext context) {
    final name = campaign['name'] as String? ?? 'Unnamed';
    final status = campaign['status'] as String? ?? 'draft';
    final budget = (campaign['budget_amount'] as num?)?.toDouble();
    final spent = (campaign['amount_spent'] as num?)?.toDouble();
    final currency = campaign['currency'] as String? ?? 'USD';
    final objective = campaign['objective'] as String? ?? '';
    final statusColor = _statusColor(status);

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
          // ── Name + status ────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
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
              _Badge(label: _statusLabel(status), color: statusColor),
            ],
          ),

          SizedBox(height: 10.h),

          // ── Budget bar ───────────────────────────────────────────────────
          if (budget != null && budget > 0) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Budget',
                  style: TextStyle(
                      color: ext.searchHintColor, fontSize: 11.sp),
                ),
                Text(
                  spent != null
                      ? '$currency ${spent.toStringAsFixed(0)} / ${budget.toStringAsFixed(0)}'
                      : '$currency ${budget.toStringAsFixed(0)}',
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
              borderRadius: BorderRadius.circular(4.r),
              child: LinearProgressIndicator(
                value: spent != null ? (spent / budget).clamp(0.0, 1.0) : 0.0,
                backgroundColor: ext.searchFieldFill,
                color: spent != null && spent >= budget
                    ? Colors.redAccent
                    : ext.accentGold,
                minHeight: 5.h,
              ),
            ),
            SizedBox(height: 10.h),
          ],

          // ── Objective ────────────────────────────────────────────────────
          if (objective.isNotEmpty)
            Text(
              objective[0].toUpperCase() + objective.substring(1),
              style: TextStyle(
                  color: ext.searchHintColor, fontSize: 12.sp),
            ),

          // ── Top-up button (only for paused campaigns) ─────────────────
          if (status == 'paused') ...[
            SizedBox(height: 12.h),
            GestureDetector(
              onTap: onTopUp,
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 10.h),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [ext.accentGold, const Color(0xFFFF6B35)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, color: Colors.white, size: 16.sp),
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
            ),
          ],
        ],
      ),
    );
  }

  static Color _statusColor(String s) => switch (s) {
        'active' => const Color(0xFF10B981),
        'paused' => Colors.orangeAccent,
        'pending_review' => const Color(0xFF3B82F6),
        'draft' => const Color(0xFF6B7280),
        'completed' => const Color(0xFF8B5CF6),
        'rejected' => Colors.redAccent,
        _ => const Color(0xFF6B7280),
      };

  static String _statusLabel(String s) => switch (s) {
        'active' => 'Active',
        'paused' => 'Paused',
        'pending_review' => 'In Review',
        'draft' => 'Draft',
        'completed' => 'Completed',
        'rejected' => 'Rejected',
        _ => s,
      };
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});
  final String label;
  final Color color;

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
