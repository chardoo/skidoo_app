import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/common/widgets/app_widgets.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/features/home/presentation/bloc/home_bloc.dart';
import 'package:skidoo_app/features/photographers/presentation/bloc/photographer_bloc.dart';
import 'package:skidoo_app/features/photographers/presentation/pages/photographer_profile_page.dart';
import 'package:skidoo_app/features/photographers/presentation/widgets/photographer_card.dart';

class PhotographersPage extends StatefulWidget {
  const PhotographersPage({super.key});

  @override
  State<PhotographersPage> createState() => _PhotographersPageState();
}

class _PhotographersPageState extends State<PhotographersPage> {
  final _textCtrl = TextEditingController();

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverAppBar(
            automaticallyImplyLeading: false,
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            floating: true,
            snap: true,
            elevation: 0,
            titleSpacing: 16.w,
            title: Text(
              'Creators',
              style: TextStyle(
                color: ext.greetingColor,
                fontWeight: FontWeight.bold,
                fontSize: 20.sp,
              ),
            ),
            bottom: PreferredSize(
              preferredSize: Size.fromHeight(52.h),
              child: Padding(
                padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 10.h),
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _textCtrl,
                  builder: (context, value, _) {
                    return Container(
                      decoration: BoxDecoration(
                        color: ext.glassFill,
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(color: ext.glassBorder),
                      ),
                      child: TextField(
                        controller: _textCtrl,
                        style:
                            TextStyle(color: ext.greetingColor, fontSize: 14.sp),
                        decoration: InputDecoration(
                          hintText: 'Search creators...',
                          hintStyle: TextStyle(
                                    color: ext.glassHint, fontSize: 14.sp),
                          prefixIcon: Icon(Icons.search_rounded,
                              color: ext.glassIcon, size: 20.sp),
                          suffixIcon: value.text.isNotEmpty
                              ? GestureDetector(
                                  onTap: () {
                                    _textCtrl.clear();
                                    context
                                        .read<PhotographerBloc>()
                                        .add(PhotographersSearched(''));
                                  },
                                  child: Icon(Icons.close_rounded,
                                      color: ext.searchHintColor, size: 18.sp),
                                )
                              : null,
                          border: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          isDense: true,
                          contentPadding:
                              EdgeInsets.symmetric(vertical: 12.h),
                        ),
                        onChanged: (q) => context
                            .read<PhotographerBloc>()
                            .add(PhotographersSearched(q)),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
        body: SafeArea(
          top: false,
          child: BlocBuilder<PhotographerBloc, PhotographerState>(
            builder: (context, state) {
              if (state.isLoading) return const AppLoadingIndicator();
              if (state.errorMessage != null) {
                return AppErrorView(
                  message: state.errorMessage!,
                  onRetry: () => context
                      .read<PhotographerBloc>()
                      .add(const PhotographersLoadRequested()),
                );
              }
              if (state.photographers.isEmpty) {
                return const AppEmptyState(
                  icon: Icons.person_search_rounded,
                  message: 'No creators found.',
                );
              }
              return ListView.builder(
                padding: EdgeInsets.only(top: 4.h, bottom: 24.h),
                itemCount: state.photographers.length,
                itemBuilder: (context, index) {
                  final p = state.photographers[index];
                  return PhotographerCard(
                    photographer: p,
                    onTap: () {
                      final homeBloc = context.read<HomeBloc>();
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => BlocProvider.value(
                          value: homeBloc,
                          child: PhotographerProfilePage(photographer: p),
                        ),
                      ));
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
