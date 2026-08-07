import 'package:flutter/material.dart';
import 'package:jperg_app/core/widgets/media_grid.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/common/widgets/app_widgets.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/home/presentation/bloc/home_bloc.dart';
import 'package:jperg_app/features/photographers/presentation/bloc/photographer_bloc.dart';
import 'package:jperg_app/features/photographers/presentation/pages/photographer_profile_page.dart';
import 'package:jperg_app/features/photographers/presentation/widgets/photographer_card.dart';
import 'package:jperg_app/models/photographer/photographerModel.dart';
import 'package:jperg_app/core/utils/web_wrap.dart';
import 'package:jperg_app/core/widgets/animations/app_animations.dart';
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';

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
                padding: EdgeInsets.only(right: AppSpacing.md.w),
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
                    return SearchField(
                      controller: _textCtrl,
                      hint: 'Search creators...',
                      onChanged: (q) => context
                          .read<PhotographerBloc>()
                          .add(PhotographersSearched(q)),
                      onClear: () {
                        _textCtrl.clear();
                        context
                            .read<PhotographerBloc>()
                            .add(const PhotographersSearched(''));
                      },
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
                return RefreshIndicator(
                  color: ext.accentGold,
                  onRefresh: () async => context
                      .read<PhotographerBloc>()
                      .add(const PhotographersLoadRequested()),
                  child: MediaGrid(
                  density: MediaGridDensity.cards,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: MediaGrid.pagePadding,
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
                ));
              }
              return RefreshIndicator(
                color: ext.accentGold,
                onRefresh: () async => context
                    .read<PhotographerBloc>()
                    .add(const PhotographersLoadRequested()),
                child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.only(top: AppSpacing.xs.h, bottom: AppSpacing.xxl.h),
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
              ));
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
          borderRadius: BorderRadius.circular(AppRadius.sm.r),
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
