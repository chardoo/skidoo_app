import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/utils/number_format.dart';
import 'package:jperg_app/core/widgets/jperg_image.dart';
import 'package:jperg_app/features/search/domain/entities/search_models.dart';
import 'package:jperg_app/features/search/presentation/widgets/search_result_row.dart';

/// An Events result: cover thumbnail, event name, photo count, chevron.
class SearchEventRowTile extends StatelessWidget {
  const SearchEventRowTile({
    super.key,
    required this.event,
    required this.onTap,
  });

  final SearchEventRow event;
  final VoidCallback onTap;

  /// "108 photos" is the design's subtitle. When the server reports no public
  /// photos — a brand-new event, or one whose gallery is private — the
  /// photographer line stands in rather than leaving the row looking broken
  /// with "0 photos".
  String _subtitle() {
    if (event.photoCount > 0) return countLabel(event.photoCount, 'photo');

    final photographer = event.photographer;
    if (photographer != null && !photographer.isEmpty) {
      final parts = [
        if (photographer.specialty.isNotEmpty) photographer.specialty,
        if (photographer.followerCount > 0)
          countLabel(photographer.followerCount, 'follower'),
      ];
      if (parts.isNotEmpty) return parts.join(' · ');
      if (photographer.name.isNotEmpty) return photographer.name;
    }
    return event.eventDate;
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return SearchResultRow(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.sm.r),
        child: SizedBox(
          width: 62.w,
          height: 48.h,
          child: event.coverUrl.isEmpty
              ? _CoverFallback(ext: ext)
              : JpergImage(
                  imageUrl: event.coverUrl,
                  fit: BoxFit.cover,
                  logicalWidth: 62.w,
                  semanticLabel: 'Cover of ${event.eventName}',
                  placeholder: (_, __) => const JpergImagePlaceholder(),
                  errorWidget: (_, __, ___) => _CoverFallback(ext: ext),
                ),
        ),
      ),
      title: event.eventName,
      subtitle: _subtitle(),
      trailing: SearchResultRow.chevron(context),
      semanticLabel: '${event.eventName}, ${_subtitle()}',
      onTap: onTap,
    );
  }
}

class _CoverFallback extends StatelessWidget {
  const _CoverFallback({required this.ext});

  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: ext.searchFieldFill,
      child: Icon(Icons.event_outlined, color: ext.searchHintColor, size: 20.sp),
    );
  }
}
