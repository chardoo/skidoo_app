import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:skidoo_app/l10n/app_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/common/customButtom.dart';
import 'package:skidoo_app/core/di/service_locator.dart';
import 'package:skidoo_app/core/utils/snackbar_utils.dart';
import 'package:skidoo_app/features/auth/presentation/bloc/interests/interests_bloc.dart';
import 'package:skidoo_app/features/home/presentation/pages/home_page.dart';
import 'package:skidoo_app/widgets/loader.dart';
import 'package:skidoo_app/core/utils/web_wrap.dart';

const _kBg = Color(0xFF0A0D11);

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
    'Portrait',
    'Landscape',
    'Wildlife',
    'Street Photography',
    'Sports',
    'Fashion',
    'Travel',
    'Food & Drink',
    'Nature',
    'Architecture',
    'Wedding',
    'Events',
    'Underwater',
    'Aerial',
    'Documentary',
    'Abstract',
    'Night Photography',
    'Black & White',
  ];

  @override
  Widget build(BuildContext context) {
    final page = Scaffold(
      body: BlocConsumer<InterestsBloc, InterestsState>(
        listener: (context, state) {
          if (state.isSuccess) {
            Navigator.of(context).pushNamedAndRemoveUntil(
                HomePage.routeName, (route) => false);
          }
          if (state.errorMessage != null && !state.isLoading) {
            AppSnackBar.error(context, state.errorMessage!);
          }
        },
        builder: (context, state) {
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 16.h),
                  Text(
                    AppLocalizations.of(context)!.interestsTitle,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 24.sp,
                        ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    AppLocalizations.of(context)!.interestsSubtitle,
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: Colors.grey),
                  ),
                  SizedBox(height: 24.h),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Wrap(
                        spacing: 10.w,
                        runSpacing: 10.h,
                        children: _interests.map((tag) {
                          final selected = state.selected.contains(tag);
                          return Semantics(button: true, label: 'Tag', child: GestureDetector(
                            onTap: () => context
                                .read<InterestsBloc>()
                                .add(InterestToggled(tag)),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: EdgeInsets.symmetric(
                                  horizontal: 16.w, vertical: 10.h),
                              decoration: BoxDecoration(
                                color: selected
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(24.r),
                                border: Border.all(
                                  color: selected
                                      ? Theme.of(context).colorScheme.primary
                                      : Colors.grey.shade600,
                                  width: 1.5,
                                ),
                              ),
                              child: Text(
                                tag,
                                style: TextStyle(
                                  color: selected
                                      ? Colors.white
                                      : Colors.grey.shade400,
                                  fontSize: 13.sp,
                                  fontWeight: selected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          ));
                        }).toList(),
                      ),
                    ),
                  ),
                  SizedBox(height: 16.h),
                  state.isLoading
                      ? const LoadingButton()
                      : CustomButton(
                          height: 50.h,
                          width: double.infinity,
                          ontap: state.selected.isEmpty
                              ? null
                              : () => context
                                  .read<InterestsBloc>()
                                  .add(const InterestsSubmitted()),
                          label: AppLocalizations.of(context)!.interestsContinue,
                        ),
                  SizedBox(height: 8.h),
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.of(context)
                          .pushNamedAndRemoveUntil(
                              HomePage.routeName, (route) => false),
                      child: Text(
                        AppLocalizations.of(context)!.interestsSkip,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    return webWrap(page, backgroundColor: _kBg);
  }

}
