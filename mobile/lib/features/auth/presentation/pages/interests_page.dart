import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:jperg_app/l10n/app_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/utils/snackbar_utils.dart';
import 'package:jperg_app/features/auth/presentation/bloc/interests/interests_bloc.dart';
import 'package:jperg_app/features/auth/presentation/widgets/onboarding_step_scaffold.dart';
import 'package:jperg_app/features/follow/presentation/pages/follow_suggestions_page.dart';
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';

class InterestsPage extends StatelessWidget {
  static const routeName = '/interests';

  const InterestsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<InterestsBloc>(),
      child: const _InterestsView(),
    );
  }
}

class _InterestsView extends StatelessWidget {
  const _InterestsView();

  static const _interests = [
    'Wedding',
    'Nature',
    'Fashion',
    'Food',
    'Sports',
    'Events',
    'Documentary',
    'Concert',
    'Travel',
    'Architecture',
    'Portraits',
    'Lifestyle',
    'Technology',
    'Aviation',
    'Animals',
  ];

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    return BlocConsumer<InterestsBloc, InterestsState>(
      listener: (context, state) {
        if (state.isSuccess) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const FollowSuggestionsPage()),
          );
        }
        if (state.errorMessage != null && !state.isLoading) {
          AppSnackBar.error(context, state.errorMessage!);
        }
      },
      builder: (context, state) {
        return OnboardingStepScaffold(
          currentStep: 3,
          totalSteps: 4,
          title: AppLocalizations.of(context)!.interestsTitle,
          subtitle: AppLocalizations.of(context)!.interestsSubtitle,
          primaryLabel: AppLocalizations.of(context)!.interestsContinue,
          primaryEnabled: state.selected.length >= 3,
          primaryLoading: state.isLoading,
          onPrimaryPressed: () =>
              context.read<InterestsBloc>().add(const InterestsSubmitted()),
          child: Wrap(
            spacing: 10.w,
            runSpacing: 10.h,
            children: _interests.map((tag) {
              final selected = state.selected.contains(tag);
              return Semantics(
                button: true,
                selected: selected,
                label: tag,
                child: GestureDetector(
                  onTap: () =>
                      context.read<InterestsBloc>().add(InterestToggled(tag)),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding:
                        EdgeInsets.symmetric(horizontal: AppSpacing.lg.w, vertical: 10.h),
                    decoration: BoxDecoration(
                      color: selected ? ext.accentGold : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppRadius.xxl.r),
                      border: Border.all(
                        color: selected
                            ? ext.accentGold
                            : ext.searchHintColor.withValues(alpha: 0.5),
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      tag,
                      style: TextStyle(
                        color: selected ? Colors.white : ext.searchHintColor,
                        fontSize: 13.sp,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}
