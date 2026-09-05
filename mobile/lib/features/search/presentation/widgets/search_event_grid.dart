import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/utils/number_format.dart';
import 'package:jperg_app/core/widgets/jperg_image.dart';
import 'package:jperg_app/core/widgets/media_grid.dart';
import 'package:jperg_app/features/search/domain/entities/search_models.dart';

/// The "You may like" grid: suggested events, as a sliver so the recent
/// searches can scroll away above it.
///
/// It used to be a grid of loose photographs. Everything this product is about
/// is an event — a shoot, a wedding, a festival — and a single photo is a page
/// torn out of one: suggesting it asks somebody to want an image with no
/// occasion attached, and gives them nowhere to go when they do.
///
/// Cards rather than the thumbnails a photo grid uses. An event needs its name
/// and its size to be worth tapping — a cover alone is just a picture, and the
/// person is choosing between occasions, not between images. That is what
/// [MediaGridDensity.cards] is for, so the columns and gutters stay in step
/// with every other tiled collection in the app.
class SearchEventGridSliver extends StatelessWidget {
  const SearchEventGridSliver({
    super.key,
    required this.events,
    required this.onEventTap,
    this.padding = EdgeInsets.zero,
  });

  final List<SearchEventRow> events;
  final void Function(SearchEventRow event) onEventTap;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return MediaGridSliver(
      itemCount: events.length,
      density: MediaGridDensity.cards,
      padding: padding,
      itemBuilder: (context, index) => _EventCard(
        event: events[index],
        onTap: () => onEventTap(events[index]),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event, required this.onTap});

  final SearchEventRow event;
  final VoidCallback onTap;

  /// "108 photos", or the photographer when the server reports none.
  ///
  /// A brand-new event, or one whose gallery is private, would otherwise read
  /// "0 photos" — which says the event is empty when what is true is that
  /// there is nothing public in it yet. The same fallback the results row
  /// makes; see [SearchEventRowTile].
  String? _subtitle() {
    if (event.photoCount > 0) return countLabel(event.photoCount, 'photo');
    final photographer = event.photographer;
    if (photographer != null && photographer.name.isNotEmpty) {
      return photographer.name;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final subtitle = _subtitle();

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // The cover takes the space the text does not, so every card in a row
          // is the same height whether or not its event has a subtitle.
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md.r),
              child: SizedBox.expand(
                child: event.coverUrl.isEmpty
                    // An event with no cover still has a name worth reading,
                    // so it keeps its cell rather than being dropped from the
                    // grid or collapsing to nothing.
                    ? ColoredBox(color: ext.cardSurface)
                    : JpergImage(
                        imageUrl: event.coverUrl,
                        fit: BoxFit.cover,
                        semanticLabel: event.eventName,
                      ),
              ),
            ),
          ),
          SizedBox(height: AppSpacing.xs.h),
          Text(
            event.eventName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: ext.greetingColor,
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (subtitle != null)
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: ext.searchHintColor, fontSize: 11.sp),
            ),
        ],
      ),
    );
  }
}
