import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/common/widgets/user_avatar.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/utils/number_format.dart';
import 'package:jperg_app/features/search/domain/entities/search_models.dart';
import 'package:jperg_app/features/search/presentation/widgets/search_result_row.dart';

/// A People result: avatar, name, "@handle · 12 followers".
///
/// The same row as [SearchPhotographerRowTile] with a thinner subtitle, because
/// a person has no shopfront to describe. The handle leads it rather than
/// trailing as a fallback: it is the thing that tells two people with the same
/// name apart, which is the whole reason somebody searched a person by name.
class SearchUserRowTile extends StatelessWidget {
  const SearchUserRowTile({
    super.key,
    required this.user,
    required this.onTap,
  });

  final SearchUserRow user;
  final VoidCallback onTap;

  /// Handle and followers, dropping whichever is absent so the row never shows
  /// a stranded separator or "0 followers".
  String _subtitle() {
    final parts = [
      if (user.username.isNotEmpty) '@${user.username}',
      if (user.followerCount > 0) countLabel(user.followerCount, 'follower'),
    ];
    if (parts.isNotEmpty) return parts.join(' · ');
    return user.location;
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final subtitle = _subtitle();

    return SearchResultRow(
      leading: UserAvatar(
        initial: user.name,
        imageUrl: user.profileUrl,
        radius: 21,
      ),
      title: user.name,
      subtitle: subtitle,
      trailing: user.isVerified
          ? Padding(
              padding: EdgeInsets.only(right: AppSpacing.xs.w),
              child: Icon(Icons.verified_rounded,
                  color: ext.accentGold, size: 16.sp),
            )
          : null,
      semanticLabel: subtitle.isEmpty ? user.name : '${user.name}, $subtitle',
      onTap: onTap,
    );
  }
}
