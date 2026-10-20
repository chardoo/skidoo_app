import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/common/widgets/user_avatar.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/utils/number_format.dart';
import 'package:jperg_app/features/search/domain/entities/search_models.dart';
import 'package:jperg_app/features/search/presentation/widgets/search_result_row.dart';
import 'package:jperg_app/core/common/widgets/verified_badge.dart';

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
    // The studio name used to sit here, and it is the account's name now —
    // the line above this row already shows it, so a row with no specialty
    // and no followers said the same thing twice. The handle is what is left
    // to say. See the backend's app/utils/account_name.py.
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
              child: const VerifiedBadge(),
            )
          : null,
      semanticLabel: '${photographer.name}, ${_subtitle()}',
      onTap: onTap,
    );
  }
}
