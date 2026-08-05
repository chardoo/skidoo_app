import 'dart:async';
import 'dart:ui' show FontFeature;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/common/widgets/app_widgets.dart';
import 'package:skidoo_app/core/theme/app_radius.dart';
import 'package:skidoo_app/core/theme/app_spacing.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/core/utils/snackbar_utils.dart';
import 'package:skidoo_app/core/utils/web_wrap.dart';
import 'package:skidoo_app/features/ads/data/repositories/ads_repository.dart';
import 'package:skidoo_app/features/ads/models/ad_campaign.dart';
import 'package:skidoo_app/features/ads/presentation/pages/ads_checkout_page.dart';
import 'package:skidoo_app/features/ads/presentation/widgets/campaign_status_pill.dart';

/// One campaign: what it is, and whatever it currently wants from its owner.
///
/// The four review cards are the same four the wizard ends on, deliberately —
/// the thing you approved is the thing you see afterwards.
class CampaignDetailsPage extends StatefulWidget {
  const CampaignDetailsPage({super.key, required this.campaign});

  final AdCampaign campaign;

  @override
  State<CampaignDetailsPage> createState() => _CampaignDetailsPageState();
}

class _CampaignDetailsPageState extends State<CampaignDetailsPage> {
  final _repo = AdsRepository();

  late AdCampaign _campaign = widget.campaign;
  bool _busy = false;
  bool _changed = false;

  /// Counted down locally from the server's number, and re-read from the server
  /// on every reload. The device clock is never consulted: a phone an hour
  /// fast would otherwise show a window that has already closed.
  int? _secondsLeft;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _secondsLeft = _campaign.paymentSecondsLeft;
    _startTicker();
    _reload();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _startTicker() {
    _ticker?.cancel();
    if (_secondsLeft == null) return;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final left = _secondsLeft;
      if (left == null || left <= 0) {
        _ticker?.cancel();
        // Hit zero — ask the server what that meant rather than deciding here.
        _reload();
        return;
      }
      setState(() => _secondsLeft = left - 1);
    });
  }

  Future<void> _reload() async {
    try {
      final fresh = await _repo.getCampaign(_campaign.id);
      if (!mounted) return;
      setState(() {
        _campaign = fresh;
        _secondsLeft = fresh.paymentSecondsLeft;
      });
      _startTicker();
    } catch (e) {
      debugPrint('[CampaignDetails] reload ERROR: $e');
    }
  }

  Future<void> _withdraw() async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel submission?'),
        content: const Text(
          'It goes back to a draft with everything you entered, and you can '
          'submit it again whenever you like.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep it in review'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Cancel submission'),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final updated = await _repo.cancelCampaignSubmission(_campaign.id);
      if (!mounted) return;
      setState(() {
        _campaign = updated;
        _changed = true;
        _busy = false;
      });
      AppSnackBar.success(context, 'Submission cancelled — saved as a draft.');
    } catch (e) {
      debugPrint('[CampaignDetails] withdraw ERROR: $e');
      if (!mounted) return;
      setState(() => _busy = false);
      AppSnackBar.error(context, 'Could not cancel that.');
    }
  }

  Future<void> _pay() async {
    setState(() => _busy = true);
    try {
      final result = await _repo.payCampaign(_campaign.id);
      if (!mounted) return;
      if (result.authorizationUrl.isEmpty) {
        setState(() => _busy = false);
        AppSnackBar.error(context, 'Could not start the payment. Try again.');
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
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
      // Paystack redirecting back is not the same as the payment having
      // landed — the server confirms it, and the reload reads the result.
      try {
        await _repo.verifyPayment(_campaign.id);
      } catch (e) {
        debugPrint('[CampaignDetails] verify ERROR: $e');
      }
      _changed = true;
      await _reload();
    } catch (e) {
      debugPrint('[CampaignDetails] pay ERROR: $e');
      if (mounted) AppSnackBar.error(context, 'Payment failed. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final c = _campaign;
    final cover = c.media.isNotEmpty ? c.media.first.url : null;

    final page = Scaffold(
      backgroundColor: ext.homeBackground,
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        leading: kIsWeb
            ? null
            : AppBackButton(
                onPressed: () => Navigator.of(context).pop(_changed),
              ),
        title: Text(
          'Campaign Details',
          style: TextStyle(
            color: ext.greetingColor,
            fontWeight: FontWeight.w700,
            fontSize: 16.sp,
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: c.status.canPay
          ? _PayButton(
              ext: ext,
              label: 'Pay Now (${c.currency} '
                  '${c.budgetAmount.toStringAsFixed(2)})',
              onTap: _busy ? null : _pay,
            )
          : null,
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.only(bottom: 96.h),
        children: [
          if (cover != null)
            SizedBox(
              height: 170.h,
              width: double.infinity,
              child: Image.network(
                cover,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    ColoredBox(color: ext.avatarBackground),
              ),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg.w, AppSpacing.md.h, AppSpacing.lg.w, 0,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    c.headline?.isNotEmpty == true ? c.headline! : c.name,
                    style: TextStyle(
                      color: ext.greetingColor,
                      fontSize: 19.sp,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                      height: 1.25,
                    ),
                  ),
                ),
                SizedBox(width: AppSpacing.sm.w),
                CampaignStatusPill(status: c.status, ext: ext),
              ],
            ),
          ),
          SizedBox(height: AppSpacing.md.h),
          Divider(
            height: 1,
            thickness: 0.7,
            color: ext.searchHintColor.withValues(alpha: 0.15),
          ),
          SizedBox(height: AppSpacing.md.h),

          if (_secondsLeft != null && c.status.canPay)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg.w),
              child: _PaymentWindow(seconds: _secondsLeft!, ext: ext),
            ),

          if (c.status == CampaignStatus.paymentExpired)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg.w),
              child: _Notice(
                ext: ext,
                tone: ext.errorRed,
                icon: Icons.timer_off_outlined,
                title: 'Payment window closed',
                body: 'This campaign was approved but not paid for in time. '
                    'You can submit it again.',
              ),
            ),

          if (c.status == CampaignStatus.rejected &&
              (c.rejectionReason?.isNotEmpty ?? false))
            Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg.w),
              child: _Notice(
                ext: ext,
                tone: ext.errorRed,
                icon: Icons.block_outlined,
                title: 'Not approved',
                body: c.rejectionReason!,
              ),
            ),

          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg.w),
            child: Column(
              children: [
                _Card(
                  title: '1. Campaign Type',
                  ext: ext,
                  rows: [
                    ('Objective', c.objective.label),
                    ('Format', c.format.label),
                  ],
                ),
                _Card(
                  title: '2. Creative',
                  ext: ext,
                  leading: cover,
                  body: c.headline,
                  bodySub: c.ctaText == null ? null : 'CTA: ${c.ctaText}',
                ),
                _Card(
                  title: '3. Audience',
                  ext: ext,
                  rows: [
                    if (c.placements.isNotEmpty)
                      ('Placements', c.placements
                          .map(_placementLabel)
                          .join(', ')),
                  ],
                ),
                _Card(
                  title: '4. Budget & Schedule',
                  ext: ext,
                  rows: [
                    if (c.dailyBudget != null)
                      ('Daily Budget',
                          '${c.currency} ${c.dailyBudget!.toStringAsFixed(2)}'),
                    if (c.durationDays != null)
                      ('Duration', '${c.durationDays} days'),
                    ('Total',
                        '${c.currency} ${c.budgetAmount.toStringAsFixed(2)}'),
                    if (c.startAt != null && c.endAt != null)
                      ('Schedule',
                          '${_short(c.startAt!)} – ${_short(c.endAt!)}'),
                  ],
                ),
              ],
            ),
          ),

          if (c.status == CampaignStatus.pendingReview) ...[
            SizedBox(height: AppSpacing.lg.h),
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl.w),
                child: Text(
                  'Your campaign is currently being reviewed. This process '
                  'usually takes 24 hours.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: ext.searchHintColor, fontSize: 12.5.sp, height: 1.45,
                  ),
                ),
              ),
            ),
            SizedBox(height: AppSpacing.sm.h),
            Center(
              child: TextButton(
                onPressed: _busy ? null : _withdraw,
                child: Text(
                  'Cancel Campaign Submission',
                  style: TextStyle(color: ext.errorRed, fontSize: 14.sp),
                ),
              ),
            ),
          ],
        ],
      ),
    );
    return webWrap(page, backgroundColor: ext.homeBackground);
  }
}

String _placementLabel(String p) => switch (p) {
      'event_feed' => 'Feed',
      'explore' => 'Explore',
      'search_results' => 'Search results',
      _ => p.replaceAll('_', ' '),
    };

const _kMonths = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _short(DateTime d) => '${_kMonths[d.month - 1]} ${d.day}, ${d.year}';

/// "47:23:15" — hours, minutes, seconds, zero-padded so it does not jitter.
class _PaymentWindow extends StatelessWidget {
  const _PaymentWindow({required this.seconds, required this.ext});

  final int seconds;
  final AppThemeExtension ext;

  String get _clock {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(h)}:${two(m)}:${two(s)}';
  }

  @override
  Widget build(BuildContext context) {
    const amber = Color(0xFFB45309);
    return Container(
      margin: EdgeInsets.only(bottom: AppSpacing.md.h),
      padding: EdgeInsets.all(AppSpacing.md.w),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.md.r),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.schedule_rounded, size: 16.r, color: amber),
              SizedBox(width: 6.w),
              Text(
                'Payment Window Closing',
                style: TextStyle(
                  color: amber, fontSize: 13.sp, fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          Text(
            _clock,
            style: TextStyle(
              color: amber,
              fontSize: 27.sp,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              // Tabular, so the digits do not shuffle as they tick.
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            'Your campaign is approved! Complete payment within 48 hours to '
            'publish your campaign.',
            style: TextStyle(
              color: ext.greetingColor, fontSize: 12.sp, height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.ext,
    required this.tone,
    required this.icon,
    required this.title,
    required this.body,
  });

  final AppThemeExtension ext;
  final Color tone;
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Container(
        margin: EdgeInsets.only(bottom: AppSpacing.md.h),
        padding: EdgeInsets.all(AppSpacing.md.w),
        decoration: BoxDecoration(
          color: tone.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadius.md.r),
          border: Border.all(color: tone.withValues(alpha: 0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 17.r, color: tone),
            SizedBox(width: AppSpacing.sm.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: tone, fontSize: 13.sp, fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    body,
                    style: TextStyle(
                      color: ext.greetingColor, fontSize: 12.sp, height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _Card extends StatelessWidget {
  const _Card({
    required this.title,
    required this.ext,
    this.rows = const [],
    this.leading,
    this.body,
    this.bodySub,
  });

  final String title;
  final AppThemeExtension ext;
  final List<(String, String)> rows;
  final String? leading;
  final String? body;
  final String? bodySub;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: AppSpacing.sm.h),
      padding: EdgeInsets.all(AppSpacing.md.w),
      decoration: BoxDecoration(
        color: ext.cardSurface,
        borderRadius: BorderRadius.circular(AppRadius.md.r),
        border: Border.all(
          color: ext.searchHintColor.withValues(alpha: 0.16), width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: ext.greetingColor,
              fontSize: 14.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: AppSpacing.sm.h),
          if (body != null)
            Row(
              children: [
                if (leading != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.sm.r),
                    child: Image.network(
                      leading!,
                      width: 48.w, height: 48.w, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => SizedBox(
                        width: 48.w, height: 48.w,
                      ),
                    ),
                  ),
                  SizedBox(width: AppSpacing.md.w),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        body!,
                        style: TextStyle(
                          color: ext.greetingColor,
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (bodySub != null)
                        Text(
                          bodySub!,
                          style: TextStyle(
                            color: ext.searchHintColor, fontSize: 12.sp,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          for (final (label, value) in rows)
            Padding(
              padding: EdgeInsets.only(bottom: 3.h),
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(
                    text: '$label: ',
                    style: TextStyle(
                      color: ext.greetingColor, fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(text: value),
                ]),
                style: TextStyle(color: ext.searchHintColor, fontSize: 12.5.sp),
              ),
            ),
        ],
      ),
    );
  }
}

class _PayButton extends StatelessWidget {
  const _PayButton({required this.ext, required this.label, this.onTap});

  final AppThemeExtension ext;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl.w),
        child: SizedBox(
          height: 52.h,
          child: ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: ext.accentGold,
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999.r),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(width: 8.w),
                Icon(Icons.arrow_forward_rounded, size: 18.r,
                    color: Colors.white),
              ],
            ),
          ),
        ),
      );
}
