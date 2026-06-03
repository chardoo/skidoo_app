import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/common/widgets/app_widgets.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/features/home/presentation/bloc/home_bloc.dart';
import 'package:skidoo_app/features/photographers/presentation/bloc/photographer_bloc.dart';
import 'package:skidoo_app/features/photographers/presentation/pages/photographer_profile_page.dart';
import 'package:skidoo_app/features/photographers/presentation/widgets/photographer_card.dart';
import 'package:skidoo_app/models/photographer/photographerModel.dart';
import 'package:skidoo_app/core/utils/web_wrap.dart';
import 'package:skidoo_app/core/widgets/animations/app_animations.dart';

class PhotographersPage extends StatefulWidget {
  const PhotographersPage({super.key});

  @override
  State<PhotographersPage> createState() => _PhotographersPageState();
}

class _PhotographersPageState extends State<PhotographersPage> {
  final _textCtrl = TextEditingController();

  // Layout chosen via the top toggle: true = grid of cards, false = list.
  bool _isGrid = true;

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  void _openProfile(BuildContext context, PhotographerModel p) {
    final homeBloc = context.read<HomeBloc>();
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => BlocProvider.value(
        value: homeBloc,
        child: PhotographerProfilePage(photographer: p),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    final page = Scaffold(
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
            actions: [
              Padding(
                padding: EdgeInsets.only(right: 12.w),
                child: _ViewToggle(
                  isGrid: _isGrid,
                  ext: ext,
                  onChanged: (grid) => setState(() => _isGrid = grid),
                ),
              ),
            ],
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
                              ? Semantics(button: true, label: 'Clear search', child: GestureDetector(
                                  onTap: () {
                                    _textCtrl.clear();
                                    context
                                        .read<PhotographerBloc>()
                                        .add(PhotographersSearched(''));
                                  },
                                  child: Icon(Icons.close_rounded,
                                      color: ext.searchHintColor, size: 18.sp),
                                ))
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
              if (_isGrid) {
                return GridView.builder(
                  padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 24.h),
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 190,
                    mainAxisSpacing: 12.h,
                    crossAxisSpacing: 12.w,
                    childAspectRatio: 0.72,
                  ),
                  itemCount: state.photographers.length,
                  itemBuilder: (context, index) {
                    final p = state.photographers[index];
                    return Reveal(
                      delay: AppMotion.stagger * (index < 8 ? index : 0),
                      offset: const Offset(0, 20),
                      child: PhotographerGridCard(
                        photographer: p,
                        onTap: () => _openProfile(context, p),
                      ),
                    );
                  },
                );
              }
              return ListView.builder(
                padding: EdgeInsets.only(top: 4.h, bottom: 24.h),
                itemCount: state.photographers.length,
                itemBuilder: (context, index) {
                  final p = state.photographers[index];
                  return Reveal(
                    delay: AppMotion.stagger * (index < 8 ? index : 0),
                    offset: const Offset(0, 16),
                    child: PhotographerCard(
                      photographer: p,
                      onTap: () => _openProfile(context, p),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
    return webWrap(page, backgroundColor: ext.homeBackground);
  }

}

/// Compact segmented control letting the user switch the creators list between
/// a grid of cards and a vertical list.
class _ViewToggle extends StatelessWidget {
  const _ViewToggle({
    required this.isGrid,
    required this.ext,
    required this.onChanged,
  });

  final bool isGrid;
  final AppThemeExtension ext;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ext.glassFill,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: ext.glassBorder),
      ),
      padding: EdgeInsets.all(2.r),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _segment(
            icon: Icons.grid_view_rounded,
            selected: isGrid,
            label: 'Grid view',
            onTap: () => onChanged(true),
          ),
          _segment(
            icon: Icons.view_agenda_outlined,
            selected: !isGrid,
            label: 'List view',
            onTap: () => onChanged(false),
          ),
        ],
      ),
    );
  }

  Widget _segment({
    required IconData icon,
    required bool selected,
    required String label,
    required VoidCallback onTap,
  }) {
    return Semantics(button: true, selected: selected, label: label, child: GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: selected
              ? ext.accentGold.withValues(alpha: 0.18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Icon(
          icon,
          size: 18.sp,
          color: selected ? ext.accentGold : ext.searchHintColor,
        ),
      ),
    ));
  }
}
