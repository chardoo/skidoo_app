import 'dart:async';

import 'package:dio/dio.dart' show DioException;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/common/widgets/app_widgets.dart';
import 'package:skidoo_app/core/theme/app_radius.dart';
import 'package:skidoo_app/core/theme/app_spacing.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/core/utils/number_format.dart';
import 'package:skidoo_app/core/utils/snackbar_utils.dart';
import 'package:skidoo_app/core/utils/web_wrap.dart';
import 'package:skidoo_app/features/ads/data/repositories/ads_repository.dart';
import 'package:skidoo_app/features/ads/models/ad_campaign.dart';
import 'package:skidoo_app/features/ads/presentation/pages/ads_checkout_page.dart';
import 'package:skidoo_app/features/ads/presentation/pages/edit_campaign_form_page.dart';
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


  Future<void> _pause() async {
    setState(() => _busy = true);
    try {
      final updated = await _repo.pauseCampaign(_campaign.id);
      if (!mounted) return;
      setState(() {
        _campaign = updated;
        _changed = true;
      });
      AppSnackBar.success(context, 'Campaign paused. Your budget is preserved.');
    } catch (e) {
      debugPrint('[CampaignDetails] pause ERROR: $e');
      if (mounted) AppSnackBar.error(context, 'Could not pause the campaign.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resume() async {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final go = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ConfirmSheet(
        ext: ext,
        title: 'Resume Campaign?',
        body: 'Your campaign will go live again and start using your '
            'remaining budget.',
        confirmLabel: 'Resume Campaign',
      ),
    );
    if (go != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final updated = await _repo.resumeCampaign(_campaign.id);
      if (!mounted) return;
      setState(() {
        _campaign = updated;
        _changed = true;
        _busy = false;
      });
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => CampaignResumedPage(campaign: updated),
        ),
      );
    } catch (e) {
      debugPrint('[CampaignDetails] resume ERROR: $e');
      if (!mounted) return;
      setState(() => _busy = false);
      // The server refuses a resume onto a spent budget or a finished
      // schedule, and its reason is worth more than a generic failure.
      AppSnackBar.error(context, _reason(e) ?? 'Could not resume the campaign.');
    }
  }

  Future<void> _duplicate() async {
    setState(() => _busy = true);
    try {
      final copy = await _repo.duplicateCampaign(_campaign.id);
      if (!mounted) return;
      setState(() => _busy = false);
      _changed = true;
      // Straight into the edit form: a copy exists to be changed — the dates
      // at minimum, which are deliberately not carried over.
      final saved = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => EditCampaignFormPage(campaign: copy)),
      );
      if (saved == true && mounted) Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint('[CampaignDetails] duplicate ERROR: $e');
      if (!mounted) return;
      setState(() => _busy = false);
      AppSnackBar.error(context, 'Could not duplicate the campaign.');
    }
  }

  Future<void> _edit() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EditCampaignFormPage(campaign: _campaign),
      ),
    );
    if (saved == true) {
      _changed = true;
      await _reload();
    }
  }

  /// The server's own message, when it bothered to send one.
  String? _reason(Object e) {
    if (e is! DioException) return null;
    final data = e.response?.data;
    if (data is Map && data['error'] is Map) {
      final message = (data['error'] as Map)['message'];
      if (message is String && message.isNotEmpty) return message;
    }
    return null;
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
        actions: [
          if (c.status.isEditable || c.status.canDuplicate)
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert_rounded, color: ext.greetingColor),
              onSelected: (value) => switch (value) {
                'edit' => _edit(),
                'duplicate' => _duplicate(),
                _ => null,
              },
              itemBuilder: (_) => [
                if (c.status.canSubmit)
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                if (c.status.canDuplicate)
                  const PopupMenuItem(
                      value: 'duplicate', child: Text('Duplicate')),
              ],
            ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: switch (c.status) {
        // Only while there is a window to pay in — an expired one needs
        // resubmitting, not paying.
        _ when c.status.canPay => _PayButton(
            ext: ext,
            label: 'Pay Now (${c.currency} '
                '${c.budgetAmount.toStringAsFixed(2)})',
            onTap: _busy ? null : _pay,
          ),
        CampaignStatus.active => _ActionButton(
            ext: ext,
            label: 'Pause Campaign',
            filled: false,
            onTap: _busy ? null : _pause,
          ),
        CampaignStatus.paused => _ActionButton(
            ext: ext,
            label: 'Resume Campaign',
            onTap: _busy ? null : _resume,
          ),
        CampaignStatus.completed => _ActionButton(
            ext: ext,
            label: 'Duplicate Campaign',
            filled: false,
            onTap: _busy ? null : _duplicate,
          ),
        _ => null,
      },
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

          if (c.status == CampaignStatus.paused)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg.w),
              child: _Notice(
                ext: ext,
                tone: const Color(0xFFB45309),
                icon: Icons.pause_circle_outline_rounded,
                title: 'Campaign Paused',
                body: c.pausedAt == null
                    ? 'Your budget is preserved. You can resume this campaign '
                        'at any time to go live again.'
                    : 'Paused on ${_long(c.pausedAt!)}. Your budget is '
                        'preserved. You can resume this campaign at any time '
                        'to go live again.',
              ),
            ),

          if (c.status == CampaignStatus.completed)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg.w),
              child: _Notice(
                ext: ext,
                tone: ext.searchHintColor,
                icon: Icons.flag_outlined,
                title: 'Campaign Ended',
                body: [
                  if (c.durationDays != null)
                    'Completed ${c.durationDays}-day campaign'
                  else
                    'Campaign completed',
                  if (c.completedAt != null) ' on ${_long(c.completedAt!)}',
                  '.',
                ].join(),
              ),
            ),

          if (_hasRun(c))
            Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg.w),
              child: _PerformanceSummary(campaign: c, ext: ext),
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
                    if (c.locations.isNotEmpty)
                      ('Locations', c.locations.join(', ')),
                    if (c.ageLabel != null) ('Target Age', c.ageLabel!),
                    if (c.interests.isNotEmpty)
                      ('Interests', c.interests.join(', ')),
                    if (c.placements.isNotEmpty)
                      ('Placements',
                          c.placements.map(_placementLabel).join(', ')),
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


/// Whether there is anything worth summarising. A campaign nobody has seen
/// shows four zeros, which looks like a bug rather than a new campaign.
bool _hasRun(AdCampaign c) =>
    c.impressions > 0 ||
    c.clicks > 0 ||
    c.spent > 0 ||
    c.status == CampaignStatus.active ||
    c.status == CampaignStatus.paused ||
    c.status == CampaignStatus.completed;

String _long(DateTime d) =>
    '${_kLongMonths[d.month - 1]} ${d.day}, ${d.year}';

const _kLongMonths = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

/// Impressions, clicks, spend and conversions — the four the design shows,
/// each with the smaller line underneath that gives it meaning.
class _PerformanceSummary extends StatelessWidget {
  const _PerformanceSummary({required this.campaign, required this.ext});

  final AdCampaign campaign;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    final c = campaign;
    final trend = c.impressionsTrendPct;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: AppSpacing.sm.h),
          child: Text(
            'Performance Summary',
            style: TextStyle(
              color: ext.greetingColor,
              fontSize: 15.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Row(
          children: [
            Expanded(child: _Stat(
              ext: ext,
              label: 'Impressions',
              value: compactCount(c.impressions),
              // Null on a campaign with no prior week — a made-up +100% on
              // everything new would be worse than saying nothing.
              foot: trend == null
                  ? null
                  : '${trend >= 0 ? '+' : ''}${trend.toStringAsFixed(0)}% this week',
              footTone: trend == null
                  ? null
                  : (trend >= 0 ? ext.accentGold : ext.errorRed),
            )),
            SizedBox(width: AppSpacing.sm.w),
            Expanded(child: _Stat(
              ext: ext,
              label: 'Clicks',
              value: compactCount(c.clicks),
              foot: c.ctr == null ? null : '${c.ctr!.toStringAsFixed(1)}% CTR',
            )),
          ],
        ),
        SizedBox(height: AppSpacing.sm.h),
        Row(
          children: [
            Expanded(child: _Stat(
              ext: ext,
              label: 'Amount Spent',
              value: '${c.currency} ${c.spent.toStringAsFixed(2)}',
              foot: 'of ${c.currency} ${c.budgetAmount.toStringAsFixed(2)} total',
            )),
            SizedBox(width: AppSpacing.sm.w),
            Expanded(child: _Stat(
              ext: ext,
              label: 'Conversions',
              value: compactCount(c.conversions),
              foot: c.costPerConversion == null
                  ? null
                  : '${c.currency} '
                      '${c.costPerConversion!.toStringAsFixed(2)} per lead',
            )),
          ],
        ),
        SizedBox(height: AppSpacing.md.h),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.ext,
    required this.label,
    required this.value,
    this.foot,
    this.footTone,
  });

  final AppThemeExtension ext;
  final String label;
  final String value;
  final String? foot;
  final Color? footTone;

  @override
  Widget build(BuildContext context) => Container(
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
              label,
              style: TextStyle(color: ext.searchHintColor, fontSize: 11.sp),
            ),
            SizedBox(height: 3.h),
            Text(
              value,
              style: TextStyle(
                color: ext.greetingColor,
                fontSize: 19.sp,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            SizedBox(height: 2.h),
            // Reserved even when empty, so the two cards in a row keep the
            // same height whether or not their footnote has a value yet.
            SizedBox(
              height: 14.h,
              child: foot == null
                  ? null
                  : Text(
                      foot!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: footTone ?? ext.searchHintColor,
                        fontSize: 10.5.sp,
                      ),
                    ),
            ),
          ],
        ),
      );
}

class _ConfirmSheet extends StatelessWidget {
  const _ConfirmSheet({
    required this.ext,
    required this.title,
    required this.body,
    required this.confirmLabel,
  });

  final AppThemeExtension ext;
  final String title;
  final String body;
  final String confirmLabel;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: ext.homeBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.xl.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36.w,
                    height: 4.h,
                    margin: EdgeInsets.only(bottom: AppSpacing.lg.h),
                    decoration: BoxDecoration(
                      color: ext.searchHintColor.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                ),
                Text(
                  title,
                  style: TextStyle(
                    color: ext.greetingColor,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: AppSpacing.sm.h),
                Text(
                  body,
                  style: TextStyle(
                    color: ext.searchHintColor, fontSize: 13.sp, height: 1.45,
                  ),
                ),
                SizedBox(height: AppSpacing.xl.h),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 46.h,
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: ext.searchHintColor.withValues(alpha: 0.4),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999.r),
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              color: ext.greetingColor, fontSize: 14.sp,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: AppSpacing.md.w),
                    Expanded(
                      child: SizedBox(
                        height: 46.h,
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ext.accentGold,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999.r),
                            ),
                          ),
                          child: Text(
                            confirmLabel,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
}

/// Pause is outlined, Resume filled — the design gives the destructive-ish one
/// less weight than the one that puts money back to work.
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.ext,
    required this.label,
    this.filled = true,
    this.onTap,
  });

  final AppThemeExtension ext;
  final String label;
  final bool filled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl.w),
        child: SizedBox(
          height: 50.h,
          child: filled
              ? ElevatedButton(
                  onPressed: onTap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ext.accentGold,
                    padding: EdgeInsets.symmetric(horizontal: 32.w),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999.r),
                    ),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              : OutlinedButton(
                  onPressed: onTap,
                  style: OutlinedButton.styleFrom(
                    backgroundColor: ext.homeBackground,
                    side: BorderSide(color: ext.accentGold, width: 1.2),
                    padding: EdgeInsets.symmetric(horizontal: 32.w),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999.r),
                    ),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: ext.accentGold,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
        ),
      );
}

/// "Campaign Resumed!" — what it will do now, and for how long.
class CampaignResumedPage extends StatelessWidget {
  const CampaignResumedPage({super.key, required this.campaign});

  final AdCampaign campaign;

  /// Whole days from now to the end date. Never negative — a campaign that
  /// resumed on its last day has a day left, not minus one.
  int get _daysRemaining {
    final end = campaign.endAt;
    if (end == null) return campaign.durationDays ?? 0;
    return end.difference(DateTime.now()).inDays.clamp(0, 100000);
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final page = Scaffold(
      backgroundColor: ext.homeBackground,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.xl.w),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 76.r,
                  height: 76.r,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: ext.accentGold.withValues(alpha: 0.14),
                  ),
                  child: Icon(Icons.check_rounded,
                      size: 34.r, color: ext.accentGold),
                ),
                SizedBox(height: AppSpacing.lg.h),
                Text(
                  'Campaign Resumed!',
                  style: TextStyle(
                    color: ext.greetingColor,
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: AppSpacing.sm.h),
                Text(
                  campaign.endAt == null
                      ? 'Your campaign is now live again.'
                      : 'Your campaign is now live again and will continue '
                          'running until ${_long(campaign.endAt!)}.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: ext.searchHintColor, fontSize: 13.sp, height: 1.5,
                  ),
                ),
                SizedBox(height: AppSpacing.lg.h),
                Container(
                  padding: EdgeInsets.all(AppSpacing.md.w),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.md.r),
                    border: Border.all(
                      color: ext.searchHintColor.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Live Campaign Summary',
                        style: TextStyle(
                          color: ext.greetingColor,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: AppSpacing.sm.h),
                      Divider(
                        height: 1,
                        color: ext.searchHintColor.withValues(alpha: 0.2),
                      ),
                      SizedBox(height: AppSpacing.sm.h),
                      _SummaryRow(
                        ext: ext,
                        label: 'Daily Budget',
                        value: campaign.dailyBudget == null
                            ? '—'
                            : '${campaign.currency} '
                                '${campaign.dailyBudget!.toStringAsFixed(2)}',
                      ),
                      SizedBox(height: 6.h),
                      _SummaryRow(
                        ext: ext,
                        label: 'Remaining Duration',
                        value: '$_daysRemaining Days Remaining',
                      ),
                    ],
                  ),
                ),
                SizedBox(height: AppSpacing.xl.h),
                SizedBox(
                  height: 48.h,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ext.accentGold,
                      padding: EdgeInsets.symmetric(horizontal: 28.w),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999.r),
                      ),
                    ),
                    child: Text(
                      'Back to Campaigns',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return webWrap(page, backgroundColor: ext.homeBackground);
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.ext,
    required this.label,
    required this.value,
  });

  final AppThemeExtension ext;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: ext.searchHintColor, fontSize: 13.sp),
          ),
          Text(
            value,
            style: TextStyle(
              color: ext.greetingColor,
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
}
