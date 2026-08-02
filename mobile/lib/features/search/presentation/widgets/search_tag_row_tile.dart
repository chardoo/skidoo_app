import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/core/utils/number_format.dart';
import 'package:skidoo_app/features/search/domain/entities/search_models.dart';
import 'package:skidoo_app/features/search/presentation/widgets/search_result_row.dart';

/// A Tags result: the `#` mark, the tag label, and its post count.
class SearchTagRowTile extends StatelessWidget {
  const SearchTagRowTile({super.key, required this.tag, required this.onTap});

  final SearchTagRow tag;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final subtitle = countLabel(tag.postCount, 'post');

    return SearchResultRow(
      // Sized to the same box the other rows' avatars occupy so the three
      // lists' titles line up when the user flicks between chips.
      leading: SizedBox(
        width: 42.w,
        height: 42.h,
        child: Center(
          child: Text(
            '#',
            style: TextStyle(
              color: ext.searchHintColor,
              fontSize: 20.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
      title: tag.label,
      subtitle: subtitle,
      semanticLabel: '${tag.label}, $subtitle',
      onTap: onTap,
    );
  }
}
