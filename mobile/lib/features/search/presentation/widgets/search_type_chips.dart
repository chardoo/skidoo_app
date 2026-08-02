import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/theme/app_radius.dart';
import 'package:skidoo_app/core/theme/app_spacing.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/features/search/domain/entities/search_models.dart';

/// Events / Photographers / Tags. Only the sections the query actually matched
/// are offered — a chip that opens an empty list is a dead end — and the whole
/// row disappears with the results, which is the `No results` state.
class SearchTypeChips extends StatelessWidget {
  const SearchTypeChips({
    super.key,
    required this.types,
    required this.selected,
    required this.onSelected,
  });

  final List<SearchResultType> types;
  final SearchResultType selected;
  final ValueChanged<SearchResultType> onSelected;

  @override
  Widget build(BuildContext context) {
    if (types.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 40.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg.w),
        itemCount: types.length,
        separatorBuilder: (_, __) => SizedBox(width: AppSpacing.sm.w),
        itemBuilder: (context, index) {
          final type = types[index];
          return _Chip(
            label: type.label,
            active: type == selected,
            onTap: () => onSelected(type),
          );
        },
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    // The active chip is a tinted wash of the accent rather than a solid fill:
    // it has to carry accent-coloured text, which a solid accent could not.
    // The same pair of alphas works on both the near-black and the off-white
    // page background.
    final background =
        active ? ext.accentGold.withValues(alpha: 0.14) : ext.searchFieldFill;
    final border =
        active ? ext.accentGold.withValues(alpha: 0.55) : Colors.transparent;
    final foreground = active ? ext.accentGold : ext.greetingColor;

    return Semantics(
      button: true,
      selected: active,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg.w),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(AppRadius.md.r),
            border: Border.all(color: border, width: 1),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: 13.sp,
              fontWeight: active ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
