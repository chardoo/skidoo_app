import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/photographers/data/premium_service.dart';
import 'package:jperg_app/features/photographers/presentation/pages/premium_rules_page.dart';

/// The premium tier's place in Settings › Account & Security.
///
/// Three states, and each is a different offer:
///
/// * **Not a member** — an invitation, with what it asks of them.
/// * **A member** — their delivery record, and a way back to the terms they
///   agreed to. Somebody held to a promise should be able to re-read it.
/// * **Terms moved** — a prompt to accept the new ones. They stay a member
///   meanwhile, held to the version they actually agreed to.
///
/// Draws nothing at all while the tier is switched off, or while the status is
/// still loading. A row that appears and then disappears is worse than one that
/// arrives a moment late.
class PremiumTierRow extends StatefulWidget {
  const PremiumTierRow({super.key});

  @override
  State<PremiumTierRow> createState() => _PremiumTierRowState();
}

class _PremiumTierRowState extends State<PremiumTierRow> {
  late final PremiumService _service = PremiumService(sl());
  PremiumStatus? _status;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final status = await _service.status();
      if (mounted) setState(() => _status = status);
    } catch (_) {
      // Silently nothing. This is an optional offer on a settings page, and an
      // error banner here would be about a feature the reader did not ask for.
    }
  }

  Future<void> _open() async {
    final joined = await PremiumRulesPage.show(context);
    if (joined && mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    // Nothing to offer: the tier is off, or this account cannot hold it.
    if (status == null || !status.terms.enabled) return const SizedBox.shrink();
    if (!status.member && !status.canJoin && !status.coolingDown) {
      return const SizedBox.shrink();
    }

    final terms = status.terms;
    final needsAction = !status.member || status.needsReaccept;

    return Container(
      margin: EdgeInsets.only(bottom: AppSpacing.xl.h),
      padding: EdgeInsets.all(AppSpacing.lg.w),
      decoration: BoxDecoration(
        color: ext.accentGold.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.lg.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified_rounded, color: ext.accentGold, size: 20.sp),
              SizedBox(width: AppSpacing.sm.w),
              Expanded(
                child: Text(
                  status.member
                      ? 'You are a ${terms.name}'
                      : 'Become a ${terms.name}',
                  style: TextStyle(
                    color: ext.greetingColor,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (status.score != null)
                Text(
                  '${status.score!.round()}',
                  style: TextStyle(
                    color: ext.accentGold,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
            ],
          ),
          SizedBox(height: AppSpacing.sm.h),
          Text(
            _subtitle(status, terms),
            style: TextStyle(
              color: ext.searchHintColor,
              fontSize: 14.sp,
              height: 1.45,
            ),
          ),
          SizedBox(height: AppSpacing.md.h),
          GestureDetector(
            onTap: _open,
            behavior: HitTestBehavior.opaque,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  needsAction
                      ? (status.needsReaccept
                          ? 'Read the new terms'
                          : 'Read the rules')
                      : 'What I agreed to',
                  style: TextStyle(
                    color: ext.accentGold,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(width: AppSpacing.xs.w),
                Icon(Icons.arrow_forward_rounded,
                    color: ext.accentGold, size: 16.sp),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _subtitle(PremiumStatus status, PremiumTerms terms) {
    if (status.needsReaccept) {
      return 'The terms have changed. Until you accept them you are held to '
          'the ones you agreed to.';
    }
    if (status.member) {
      final done = status.onTime + status.late;
      if (done == 0) {
        return 'Deliver within ${terms.windowLabel} of every shoot you take '
            'as a ${terms.name}.';
      }
      return '${status.onTime} of $done delivered on time.';
    }
    if (status.coolingDown) {
      final until = status.blockedUntil;
      return until == null
          ? 'You cannot join again yet.'
          : 'You can apply again on ${until.day}/${until.month}/${until.year}.';
    }
    return 'Promise delivery within ${terms.windowLabel} and get work only '
        '${terms.name}s can see.';
  }
}
