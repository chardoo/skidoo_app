import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';

/// The rows under the search box on the idle screen.
///
/// These are device-local — there is no endpoint and nothing is sent to the
/// server, so the ✕ is a real delete rather than a request.
class RecentSearchesList extends StatelessWidget {
  const RecentSearchesList({
    super.key,
    required this.queries,
    required this.onTap,
    required this.onRemove,
    this.maxVisible = 5,
  });

  final List<String> queries;
  final ValueChanged<String> onTap;
  final ValueChanged<String> onRemove;

  /// The store keeps more than this; the surplus is what fills the gap after
  /// a removal instead of the list shrinking row by row.
  final int maxVisible;

  @override
  Widget build(BuildContext context) {
    if (queries.isEmpty) return const SizedBox.shrink();
    final visible = queries.take(maxVisible).toList(growable: false);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final query in visible)
          _RecentRow(
            key: ValueKey(query),
            query: query,
            onTap: () => onTap(query),
            onRemove: () => onRemove(query),
          ),
      ],
    );
  }
}

class _RecentRow extends StatelessWidget {
  const _RecentRow({
    super.key,
    required this.query,
    required this.onTap,
    required this.onRemove,
  });

  final String query;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return Semantics(
      button: true,
      label: 'Recent search: $query',
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.lg.w,
            vertical: AppSpacing.md.h,
          ),
          child: Row(
            children: [
              Icon(Icons.access_time_rounded,
                  color: ext.searchHintColor, size: 18.sp),
              SizedBox(width: AppSpacing.md.w),
              Expanded(
                child: Text(
                  query,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: ext.greetingColor.withValues(alpha: 0.85),
                    fontSize: 14.sp,
                  ),
                ),
              ),
              Semantics(
                button: true,
                label: 'Remove $query from recent searches',
                child: GestureDetector(
                  onTap: onRemove,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    // Padding, not size — it widens the tap target to something
                    // a thumb can hit without making the glyph any bigger.
                    padding: EdgeInsets.all(AppSpacing.xs.w),
                    child: Icon(Icons.close_rounded,
                        color: ext.searchHintColor, size: 18.sp),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
