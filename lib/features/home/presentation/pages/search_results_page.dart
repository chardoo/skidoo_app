import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/core/utils/responsive.dart';
import 'package:skidoo_app/features/home/presentation/bloc/home_bloc.dart';
import 'package:skidoo_app/models/photos/Photo.dart';

class SearchResultsPage extends StatefulWidget {
  static const routeName = '/searchresults';
  const SearchResultsPage({super.key});

  @override
  State<SearchResultsPage> createState() => _SearchResultsPageState();
}

class _SearchResultsPageState extends State<SearchResultsPage> {
  final Set<String> _selectedIds = {};
  bool _selectionMode = false;

  void _toggleSelection(Photo photo) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedIds.contains(photo.id)) {
        _selectedIds.remove(photo.id);
        if (_selectedIds.isEmpty) _selectionMode = false;
      } else {
        _selectedIds.add(photo.id);
      }
    });
  }

  void _enterSelectionMode(Photo photo) {
    HapticFeedback.mediumImpact();
    setState(() {
      _selectionMode = true;
      _selectedIds.add(photo.id);
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  void _selectAll(List<Photo> photos) {
    setState(() {
      _selectedIds.addAll(photos.map((p) => p.id));
    });
  }

  void _saveSelected(List<Photo> all) {
    final toSave = all.where((p) => _selectedIds.contains(p.id)).toList();
    if (toSave.isEmpty) return;
    context.read<HomeBloc>().add(HomeFreeImagesSaved(toSave));
    _exitSelectionMode();
  }

  void _saveAll(List<Photo> photos) {
    context.read<HomeBloc>().add(HomeFreeImagesSaved(photos));
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return BlocListener<HomeBloc, HomeState>(
      listenWhen: (prev, curr) =>
          prev.savedFreeCount != curr.savedFreeCount ||
          prev.errorMessage != curr.errorMessage,
      listener: (context, state) {
        if (state.savedFreeCount != null) {
          _showSnack(
            context,
            '${state.savedFreeCount} photo${state.savedFreeCount == 1 ? '' : 's'} saved to your gallery!',
            isError: false,
          );
        } else if (state.errorMessage != null) {
          _showSnack(context, state.errorMessage!, isError: true);
        }
      },
      child: Scaffold(
        backgroundColor: ext.homeBackground,
        appBar: _buildAppBar(ext, context),
        body: LayoutBuilder(
          builder: (context, constraints) =>
              BlocBuilder<HomeBloc, HomeState>(
            builder: (context, state) {
              // ── Full-screen loading ───────────────────────────────────────
              if (state.isLoadingImages && state.searchImages.isEmpty) {
                return _buildInitialLoader(ext);
              }

              // ── Empty state ───────────────────────────────────────────────
              if (state.searchImages.isEmpty && !state.isLoadingImages) {
                return _buildEmpty(ext);
              }

              final photos = state.searchImages;
              final colCount = responsiveColumnCount(
                  constraints.maxWidth,
                  minColWidth: 160);

              return Stack(
                children: [
                  // ── Masonry grid ──────────────────────────────────────────
                  CustomScrollView(
                    cacheExtent: 800,
                    slivers: [
                      // Saving overlay indicator
                      if (state.isSavingFree)
                        SliverToBoxAdapter(
                          child: LinearProgressIndicator(
                            color: ext.accentGold,
                            backgroundColor:
                                ext.accentGold.withValues(alpha: 0.15),
                            minHeight: 3,
                          ),
                        ),

                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                            10.w, 12.h, 10.w, _selectionMode ? 100.h : 16.h),
                        sliver: SliverMasonryGrid.count(
                          crossAxisCount: colCount,
                          mainAxisSpacing: 8.h,
                          crossAxisSpacing: 8.w,
                          childCount: photos.length,
                          itemBuilder: (context, index) =>
                              _buildCard(photos[index], ext),
                        ),
                      ),

                      // Streaming tail indicator
                      if (state.isLoadingImages)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 20.h),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 16.w,
                                  height: 16.w,
                                  child: CircularProgressIndicator(
                                      color: ext.accentGold, strokeWidth: 2),
                                ),
                                SizedBox(width: 10.w),
                                Text('Finding more…',
                                    style: TextStyle(
                                        color: ext.searchHintColor,
                                        fontSize: 13.sp)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),

                  // ── Bottom action bar ─────────────────────────────────────
                  if (!state.isLoadingImages || state.searchImages.isNotEmpty)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: _buildBottomBar(ext, photos, state.isSavingFree),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ── AppBar ──────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(AppThemeExtension ext, BuildContext ctx) {
    if (_selectionMode) {
      return AppBar(
        backgroundColor: ext.cardSurface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: ext.greetingColor),
          onPressed: _exitSelectionMode,
        ),
        title: Text(
          '${_selectedIds.length} selected',
          style: TextStyle(
            color: ext.greetingColor,
            fontWeight: FontWeight.w700,
            fontSize: 16.sp,
          ),
        ),
        actions: [
          BlocBuilder<HomeBloc, HomeState>(
            builder: (context, state) => TextButton(
              onPressed: _selectedIds.length == state.searchImages.length
                  ? null
                  : () => _selectAll(state.searchImages),
              child: Text(
                'Select All',
                style: TextStyle(
                  color: ext.accentGold,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return AppBar(
      backgroundColor: ext.homeBackground,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: BackButton(
          onPressed: () => Navigator.of(ctx).pop(),
          color: ext.greetingColor),
      title: Text(
        'Search Results',
        style: TextStyle(
          color: ext.greetingColor,
          fontWeight: FontWeight.w700,
          fontSize: 16.sp,
        ),
      ),
      actions: [
        BlocBuilder<HomeBloc, HomeState>(
          builder: (context, state) {
            if (state.searchImages.isEmpty) return const SizedBox.shrink();
            return TextButton.icon(
              onPressed: () => _enterSelectionMode(state.searchImages.first),
              icon: Icon(Icons.check_circle_outline_rounded,
                  color: ext.accentGold, size: 18.sp),
              label: Text(
                'Select',
                style: TextStyle(
                    color: ext.accentGold,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600),
              ),
            );
          },
        ),
      ],
    );
  }

  // ── Photo card ──────────────────────────────────────────────────────────────

  Widget _buildCard(Photo photo, AppThemeExtension ext) {
    final isSelected = _selectedIds.contains(photo.id);

    return GestureDetector(
      onTap: _selectionMode
          ? () => _toggleSelection(photo)
          : null,
      onLongPress: _selectionMode ? null : () => _enterSelectionMode(photo),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12.r),
          border: isSelected
              ? Border.all(color: ext.accentGold, width: 2.5)
              : Border.all(color: Colors.transparent, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? ext.accentGold.withValues(alpha: 0.3)
                  : Colors.black.withValues(alpha: 0.2),
              blurRadius: isSelected ? 10 : 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10.r),
          child: Stack(
            children: [
              CachedNetworkImage(
                imageUrl: photo.url,
                fit: BoxFit.cover,
                width: double.infinity,
                memCacheWidth: 600,
                filterQuality: FilterQuality.medium,
                placeholder: (_, __) => Container(
                  height: 150.h,
                  color: ext.searchFieldFill,
                  child: Center(
                    child: SizedBox(
                      width: 18.w,
                      height: 18.h,
                      child: CircularProgressIndicator(
                          color: ext.accentGold, strokeWidth: 2),
                    ),
                  ),
                ),
                errorWidget: (_, __, ___) => Container(
                  height: 150.h,
                  color: ext.searchFieldFill,
                  child: Icon(Icons.broken_image_outlined,
                      color: ext.searchHintColor, size: 28.sp),
                ),
              ),

              // Selection overlay + checkmark
              if (_selectionMode)
                Positioned.fill(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    color: isSelected
                        ? Colors.black.withValues(alpha: 0.25)
                        : Colors.transparent,
                    child: Align(
                      alignment: Alignment.topRight,
                      child: Padding(
                        padding: EdgeInsets.all(8.w),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          child: isSelected
                              ? Container(
                                  key: const ValueKey('checked'),
                                  width: 24.w,
                                  height: 24.w,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: ext.accentGold,
                                  ),
                                  child: Icon(Icons.check_rounded,
                                      color: Colors.black,
                                      size: 14.sp),
                                )
                              : Container(
                                  key: const ValueKey('unchecked'),
                                  width: 24.w,
                                  height: 24.w,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.black.withValues(alpha: 0.35),
                                    border: Border.all(
                                        color: Colors.white60, width: 1.5),
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Bottom bar ──────────────────────────────────────────────────────────────

  Widget _buildBottomBar(
      AppThemeExtension ext, List<Photo> photos, bool isSaving) {
    if (photos.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: ext.cardSurface,
        border: Border(
          top: BorderSide(
              color: ext.searchHintColor.withValues(alpha: 0.12), width: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          child: _selectionMode
              ? Row(
                  children: [
                    // Save Selected
                    Expanded(
                      child: _SaveButton(
                        label:
                            'Save Selected (${_selectedIds.length})',
                        icon: Icons.save_alt_rounded,
                        color: ext.accentGold,
                        textColor: Colors.black,
                        disabled: _selectedIds.isEmpty || isSaving,
                        loading: isSaving,
                        onTap: () => _saveSelected(photos),
                      ),
                    ),
                    SizedBox(width: 10.w),
                    // Save All (secondary style)
                    Expanded(
                      child: _SaveButton(
                        label: 'Save All (${photos.length})',
                        icon: Icons.download_for_offline_rounded,
                        color: ext.searchFieldFill,
                        textColor: ext.greetingColor,
                        borderColor:
                            ext.searchHintColor.withValues(alpha: 0.3),
                        disabled: isSaving,
                        loading: false,
                        onTap: () => _saveAll(photos),
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    // Save All — primary action when not in selection mode
                    Expanded(
                      child: _SaveButton(
                        label: 'Save All Photos (${photos.length})',
                        icon: Icons.download_for_offline_rounded,
                        color: ext.accentGold,
                        textColor: Colors.black,
                        disabled: isSaving,
                        loading: isSaving,
                        onTap: () => _saveAll(photos),
                      ),
                    ),
                    SizedBox(width: 10.w),
                    // Select Some — secondary
                    _SaveButton(
                      label: 'Pick',
                      icon: Icons.checklist_rounded,
                      color: ext.searchFieldFill,
                      textColor: ext.greetingColor,
                      borderColor:
                          ext.searchHintColor.withValues(alpha: 0.3),
                      disabled: isSaving,
                      loading: false,
                      onTap: () => _enterSelectionMode(photos.first),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  Widget _buildInitialLoader(AppThemeExtension ext) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.image_search_rounded,
              size: 56.sp, color: ext.accentGold.withValues(alpha: 0.7)),
          SizedBox(height: 24.h),
          SizedBox(
            width: 220.w,
            child: LinearProgressIndicator(
              color: ext.accentGold,
              backgroundColor: ext.accentGold.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4.r),
              minHeight: 4.h,
            ),
          ),
          SizedBox(height: 20.h),
          Text(
            'Scanning your photos…',
            style: TextStyle(
                color: ext.greetingColor,
                fontSize: 15.sp,
                fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 8.h),
          Text('This may take a moment',
              style:
                  TextStyle(color: ext.searchHintColor, fontSize: 12.sp)),
        ],
      ),
    );
  }

  Widget _buildEmpty(AppThemeExtension ext) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.image_search_outlined,
              size: 64.sp, color: ext.searchHintColor),
          SizedBox(height: 12.h),
          Text('No photos found',
              style: TextStyle(color: ext.searchHintColor, fontSize: 15.sp)),
        ],
      ),
    );
  }

  void _showSnack(BuildContext context, String msg, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red[800] : Colors.green[800],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.r)),
        margin: EdgeInsets.only(bottom: 80.h, left: 16.w, right: 16.w),
      ),
    );
  }
}

// ── Reusable save button ──────────────────────────────────────────────────────

class _SaveButton extends StatelessWidget {
  const _SaveButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.textColor,
    required this.disabled,
    required this.loading,
    required this.onTap,
    this.borderColor,
  });

  final String label;
  final IconData icon;
  final Color color;
  final Color textColor;
  final Color? borderColor;
  final bool disabled;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: disabled ? 0.5 : 1.0,
        child: Container(
          height: 46.h,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12.r),
            border: borderColor != null
                ? Border.all(color: borderColor!, width: 1)
                : null,
          ),
          alignment: Alignment.center,
          child: loading
              ? SizedBox(
                  width: 18.w,
                  height: 18.w,
                  child: CircularProgressIndicator(
                      color: textColor, strokeWidth: 2),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: textColor, size: 18.sp),
                    SizedBox(width: 6.w),
                    Text(
                      label,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
