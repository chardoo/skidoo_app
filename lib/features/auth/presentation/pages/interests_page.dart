import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/common/customButtom.dart';
import 'package:skidoo_app/core/di/service_locator.dart';
import 'package:skidoo_app/features/auth/presentation/bloc/interests/interests_bloc.dart';
import 'package:skidoo_app/features/home/presentation/pages/home_page.dart';
import 'package:skidoo_app/widgets/loader.dart';

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
    return Scaffold(
      body: BlocConsumer<InterestsBloc, InterestsState>(
        listener: (context, state) {
          if (state.isSuccess) {
            Navigator.of(context)
                .pushReplacementNamed(HomePage.routeName);
          }
          if (state.errorMessage != null && !state.isLoading) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(
                content: Text(state.errorMessage!),
                backgroundColor: Colors.red,
              ));
          }
        },
        builder: (context, state) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  Text(
                    'What interests you?',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Select topics to personalise your feed',
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: _interests.map((tag) {
                          final selected = state.selected.contains(tag);
                          return GestureDetector(
                            onTap: () => context
                                .read<InterestsBloc>()
                                .add(InterestToggled(tag)),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: selected
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(24),
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
                                  fontWeight: selected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
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
                          label: 'Continue',
                        ),
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.of(context)
                          .pushReplacementNamed(HomePage.routeName),
                      child: const Text(
                        'Skip for now',
                        style: TextStyle(color: Colors.grey),
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
  }
}
