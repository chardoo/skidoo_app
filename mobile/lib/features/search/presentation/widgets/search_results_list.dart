import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/theme/app_spacing.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/features/search/domain/entities/search_models.dart';
import 'package:skidoo_app/features/search/presentation/bloc/search_bloc.dart';
import 'package:skidoo_app/features/search/presentation/widgets/search_event_row_tile.dart';
import 'package:skidoo_app/features/search/presentation/widgets/search_photographer_row_tile.dart';
import 'package:skidoo_app/features/search/presentation/widgets/search_tag_row_tile.dart';

/// The rows of whichever chip is active, plus the paging spinner.
///
/// One list rather than three: only the row widget changes with the chip, so
/// padding, the paging footer and the scroll behaviour are defined once.
class SearchResultsList extends StatelessWidget {
  const SearchResultsList({
    super.key,
    required this.state,
    required this.onEventTap,
    required this.onPhotographerTap,
    required this.onTagTap,
  });

  final SearchState state;
  final ValueChanged<SearchEventRow> onEventTap;
  final ValueChanged<SearchPhotographerRow> onPhotographerTap;
  final ValueChanged<SearchTagRow> onTagTap;

  List<Widget> _rows() => switch (state.activeType) {
        SearchResultType.events => [
            for (final event in state.events.items)
              SearchEventRowTile(
                key: ValueKey('event_${event.id}'),
                event: event,
                onTap: () => onEventTap(event),
              ),
          ],
        SearchResultType.photographers => [
            for (final photographer in state.photographers.items)
              SearchPhotographerRowTile(
                key: ValueKey('photographer_${photographer.id}'),
                photographer: photographer,
                onTap: () => onPhotographerTap(photographer),
              ),
          ],
        SearchResultType.tags => [
            for (final tag in state.tags.items)
              SearchTagRowTile(
                key: ValueKey('tag_${tag.tag}'),
                tag: tag,
                onTap: () => onTagTap(tag),
              ),
          ],
      };

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final rows = _rows();
    final section = state.activeSection;

    return ListView.builder(
      padding: EdgeInsets.only(top: AppSpacing.sm.h, bottom: AppSpacing.huge.h),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: rows.length + (section.isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= rows.length) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.lg.h),
            child: Center(
              child: SizedBox(
                width: 20.w,
                height: 20.w,
                child: CircularProgressIndicator(
                    color: ext.accentGold, strokeWidth: 2),
              ),
            ),
          );
        }
        return rows[index];
      },
    );
  }
}
