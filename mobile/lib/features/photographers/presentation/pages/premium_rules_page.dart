import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/common/widgets/app_back_button.dart';
import 'package:jperg_app/core/common/widgets/app_button.dart';
import 'package:jperg_app/core/common/widgets/app_loading_indicator.dart';
import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/core/theme/app_icons.dart';
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/theme/app_typography.dart';
import 'package:jperg_app/core/utils/snackbar_utils.dart';
import 'package:jperg_app/features/photographers/data/premium_service.dart';

/// What joining the premium tier commits somebody to, before they join it.
///
/// This screen is the contract, and everything on it is read from the server —
/// the window, the number of misses allowed, the cooldown, and the tier's own
/// name. Nothing is written into the copy. Hardcoding "48 hours" here is how
/// the terms people agreed to and the rule they are enforced under drift
/// apart, and the first anybody would notice is an argument with a creator who
/// has just been demoted.
///
/// Reachable after joining as well as before it, so somebody can look up what
/// they agreed to without having to leave the app to find out.
class PremiumRulesPage extends StatefulWidget {
  const PremiumRulesPage({super.key});

  /// Returns true when the reader joined, so the screen behind can refresh.
  static Future<bool> show(BuildContext context) async {
    final joined = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const PremiumRulesPage()),
    );
    return joined ?? false;
  }

  @override
  State<PremiumRulesPage> createState() => _PremiumRulesPageState();
}

class _PremiumRulesPageState extends State<PremiumRulesPage> {
  late final PremiumService _service = PremiumService(sl());

  PremiumStatus? _status;
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final status = await _service.status();
      if (!mounted) return;
      setState(() {
        _status = status;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  /// Agreeing. The version travels with it so a screen opened before an admin
  /// changed the terms cannot accept the ones it happens to be showing.
  Future<void> _accept() async {
    final status = _status;
    if (status == null || _submitting) return;
    setState(() => _submitting = true);
    try {
      final updated = status.needsReaccept
          ? await _service.acceptTerms(status.terms.termsVersion)
          : await _service.join(status.terms.termsVersion);
      if (!mounted) return;
      setState(() {
        _status = updated;
        _submitting = false;
      });
      AppSnackBar.success(
        context,
        'You are now a ${updated.terms.name}.',
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      // The server's sentence, not a code. "You can join again on 24 December"
      // is the whole answer, and it has to survive reaching the reader.
      AppSnackBar.error(context, '$e'.replaceFirst('ServerException: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final status = _status;
    final terms = status?.terms ?? PremiumTerms.fallback;

    return Scaffold(
      backgroundColor: ext.homeBackground,
      appBar: AppBar(
        backgroundColor: ext.homeBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: const AppBackButton(),
        title: Text(
          terms.name,
          style: TextStyle(
            color: ext.greetingColor,
            fontFamily: AppTypography.displayFontFamily,
            fontSize: 16.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: _loading
          ? const AppLoadingIndicator()
          : _error != null
              ? _Retry(ext: ext, onRetry: _load)
              : _body(context, ext, status!, terms),
    );
  }

  Widget _body(
    BuildContext context,
    AppThemeExtension ext,
    PremiumStatus status,
    PremiumTerms terms,
  ) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg.w,
              AppSpacing.lg.h,
              AppSpacing.lg.w,
              AppSpacing.xxl.h,
            ),
            children: [
              _Hero(ext: ext, terms: terms, status: status),
              SizedBox(height: AppSpacing.xxl.h),

              _Rule(
                ext: ext,
                icon: Icons.schedule_rounded,
                title: 'Deliver within ${terms.windowLabel}',
                // The worked example, because "48 hours from the event date"
                // and "by midnight two days later" are the same rule and only
                // one of them is unambiguous.
                body: 'The clock starts at midnight on the day of the shoot. '
                    'A programme on the 10th means the photos are with your '
                    'client by midnight on the '
                    '${10 + (terms.deliveryHours / 24).ceil()}th.',
              ),
              _Rule(
                ext: ext,
                icon: Icons.photo_library_outlined,
                title: 'Delivering means they can see the photos',
                body: 'You hand over an album from the booking. Your client is '
                    'added to it automatically — you never type their address. '
                    'An album with no photos in it does not count.',
              ),
              _Rule(
                ext: ext,
                icon: Icons.warning_amber_rounded,
                tone: ext.publicAmber,
                title: 'Miss it once and you get a warning',
                body: 'Still deliver — your client is waiting, and a late '
                    'delivery is better than none. The delay goes on your '
                    'record.',
              ),
              _Rule(
                ext: ext,
                icon: Icons.remove_circle_outline_rounded,
                tone: ext.errorRed,
                title: terms.strikeLimit <= 1
                    ? 'A miss removes the badge'
                    : 'Miss it ${terms.strikeLimit} times and you lose the badge',
                body: 'Counted over the last ${terms.strikeWindowDays} days. '
                    'You can apply again after ${terms.cooldownLabel}. Your '
                    'account, albums and earnings are not affected.',
              ),
              _Rule(
                ext: ext,
                icon: Icons.trending_up_rounded,
                title: 'Delivering quickly lifts you up the board',
                body: 'Your delivery record is shown to clients choosing a '
                    'photographer. The faster you turn work round, the higher '
                    'it goes.',
              ),

              SizedBox(height: AppSpacing.lg.h),
              Text(
                'Leaving the tier yourself also carries the '
                '${terms.cooldownLabel} wait, so it is not a way around a '
                'missed deadline.',
                style: TextStyle(
                  color: ext.searchHintColor,
                  fontSize: 12.sp,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        _Footer(
          ext: ext,
          status: status,
          terms: terms,
          submitting: _submitting,
          onAccept: _accept,
        ),
      ],
    );
  }
}

// ── The opening ──────────────────────────────────────────────────────────────

class _Hero extends StatelessWidget {
  const _Hero({required this.ext, required this.terms, required this.status});

  final AppThemeExtension ext;
  final PremiumTerms terms;
  final PremiumStatus status;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.md.w,
            vertical: AppSpacing.sm.h,
          ),
          decoration: BoxDecoration(
            color: ext.accentGold.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadius.pill.r),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppSvgIcon(AppIcons.check, color: ext.accentGold, size: 14.sp),
              SizedBox(width: AppSpacing.sm.w),
              Text(
                terms.name,
                style: TextStyle(
                  color: ext.accentGold,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: AppSpacing.lg.h),
        Text(
          status.member
              ? 'What you agreed to'
              : 'A promise your clients can count on',
          style: TextStyle(
            color: ext.greetingColor,
            fontFamily: AppTypography.displayFontFamily,
            fontSize: 22.sp,
            fontWeight: FontWeight.w700,
            height: 1.25,
          ),
        ),
        SizedBox(height: AppSpacing.sm.h),
        Text(
          status.member
              ? 'These are the terms your badge is held to.'
              : 'Clients can ask for a ${terms.name} when they post a '
                  'request — work only members can see and answer.',
          style: TextStyle(
            color: ext.searchHintColor,
            fontSize: 14.sp,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

// ── One rule ─────────────────────────────────────────────────────────────────

class _Rule extends StatelessWidget {
  const _Rule({
    required this.ext,
    required this.icon,
    required this.title,
    required this.body,
    this.tone,
  });

  final AppThemeExtension ext;
  final IconData icon;
  final String title;
  final String body;

  /// Amber on the warning, red on the demotion. The two rules that cost
  /// something should not read the same as the three that do not.
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final colour = tone ?? ext.accentGold;
    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.xl.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36.r,
            height: 36.r,
            decoration: BoxDecoration(
              color: colour.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.md.r),
            ),
            child: Icon(icon, color: colour, size: 19.sp),
          ),
          SizedBox(width: AppSpacing.md.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: ext.greetingColor,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
                SizedBox(height: AppSpacing.xs.h),
                Text(
                  body,
                  style: TextStyle(
                    color: ext.searchHintColor,
                    fontSize: 14.sp,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── The decision ─────────────────────────────────────────────────────────────

class _Footer extends StatelessWidget {
  const _Footer({
    required this.ext,
    required this.status,
    required this.terms,
    required this.submitting,
    required this.onAccept,
  });

  final AppThemeExtension ext;
  final PremiumStatus status;
  final PremiumTerms terms;
  final bool submitting;
  final Future<void> Function() onAccept;

  /// What the button says, or why there isn't one.
  ///
  /// Every refusal names its reason. "You cannot join" with no explanation is
  /// the kind of screen people contact support about.
  String? get _blockedMessage {
    if (status.needsReaccept) return null;
    if (status.member) return 'You are already a ${terms.name}.';
    if (status.canJoin) return null;
    switch (status.reason) {
      case 'cooling_down':
        final until = status.blockedUntil;
        return until == null
            ? 'You cannot join again yet.'
            : 'You can apply again on '
                '${until.day}/${until.month}/${until.year}.';
      case 'not_creator':
        return 'Only creators can join.';
      case 'closed':
        return 'This is closed to new members at the moment.';
      default:
        return 'This is not available at the moment.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final blocked = _blockedMessage;

    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg.w,
        AppSpacing.md.h,
        AppSpacing.lg.w,
        AppSpacing.lg.h,
      ),
      decoration: BoxDecoration(
        color: ext.homeBackground,
        border: Border(
          top: BorderSide(
            color: ext.searchHintColor.withValues(alpha: 0.18),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: blocked != null
            ? Text(
                blocked,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: ext.searchHintColor,
                  fontSize: 14.sp,
                  height: 1.5,
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    status.needsReaccept
                        ? 'The terms have changed since you joined. Until you '
                            'accept them, you are held to the ones you agreed to.'
                        : 'By continuing you agree to deliver within '
                            '${terms.windowLabel} of every shoot you take as a '
                            '${terms.name}.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: ext.searchHintColor,
                      fontSize: 12.sp,
                      height: 1.5,
                    ),
                  ),
                  SizedBox(height: AppSpacing.md.h),
                  AppButton(
                    label: status.needsReaccept
                        ? 'Accept the new terms'
                        : 'I agree — make me a ${terms.name}',
                    fullWidth: true,
                    borderRadius: AppRadius.pill,
                    isLoading: submitting,
                    onPressed: onAccept,
                  ),
                ],
              ),
      ),
    );
  }
}

class _Retry extends StatelessWidget {
  const _Retry({required this.ext, required this.onRetry});

  final AppThemeExtension ext;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xxl.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Could not load the terms.',
              style: TextStyle(color: ext.greetingColor, fontSize: 15.sp),
            ),
            SizedBox(height: AppSpacing.md.h),
            AppButton(
              label: 'Try again',
              variant: AppButtonVariant.secondary,
              borderRadius: AppRadius.pill,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
