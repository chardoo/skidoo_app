import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/common/widgets/user_avatar.dart';
import 'package:skidoo_app/core/theme/app_spacing.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/core/utils/number_format.dart';
import 'package:skidoo_app/features/search/domain/entities/search_models.dart';
import 'package:skidoo_app/features/search/presentation/widgets/search_result_row.dart';

/// A Photographers result: avatar, name, "Arts & Culture · 1K followers".
class SearchPhotographerRowTile extends StatelessWidget {
  const SearchPhotographerRowTile({
    super.key,
    required this.photographer,
    required this.onTap,
  });

  final SearchPhotographerRow photographer;
  final VoidCallback onTap;

  /// Specialty and followers, dropping whichever the server didn't send so the
  /// row never shows a stranded separator or "0 followers".
  String _subtitle() {
    final parts = [
      if (photographer.specialty.isNotEmpty) photographer.specialty,
      if (photographer.followerCount > 0)
        countLabel(photographer.followerCount, 'follower'),
    ];
    if (parts.isNotEmpty) return parts.join(' · ');
    if (photographer.studioName.isNotEmpty) return photographer.studioName;
    return photographer.username.isEmpty ? '' : '@${photographer.username}';
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return SearchResultRow(
      leading: UserAvatar(
        initial: photographer.name,
        imageUrl: photographer.profileUrl,
        radius: 21,
      ),
      title: photographer.name,
      subtitle: _subtitle(),
      trailing: photographer.isVerified
          ? Padding(
              padding: EdgeInsets.only(right: AppSpacing.xs.w),
              child: Icon(Icons.verified_rounded,
                  color: ext.accentGold, size: 16.sp),
            )
          : null,
      semanticLabel: '${photographer.name}, ${_subtitle()}',
      onTap: onTap,
    );
  }
}
