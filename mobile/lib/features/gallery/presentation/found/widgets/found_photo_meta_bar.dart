import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/common/widgets/user_avatar.dart';
import 'package:skidoo_app/core/theme/app_radius.dart';
import 'package:skidoo_app/core/theme/app_spacing.dart';
import 'package:skidoo_app/features/discovery/presentation/utils/open_photographer_profile.dart';
import 'package:skidoo_app/models/photos/Photo.dart';

/// Footer strip over the bottom of the photo in the Found viewer:
/// photographer identity on the left, "View album" on the right.
///
/// Every text line degrades gracefully — an unnamed photographer, a photo
/// with no event, or an event with no location each just drop out instead of
/// leaving stray separators behind.
class FoundPhotoMetaBar extends StatelessWidget {
  const FoundPhotoMetaBar({
    super.key,
    required this.photo,
    this.onViewAlbum,
  });

  final Photo photo;

  /// Null hides the button — e.g. when the viewer was opened *from* the album
  /// page, where "View album" would just go back where you came from.
  final VoidCallback? onViewAlbum;

  String get _name =>
      photo.photographerName.isNotEmpty ? photo.photographerName : 'Photographer';

  String get _subtitle => [
        if (photo.eventName.isNotEmpty) photo.eventName,
        if (photo.location.isNotEmpty) photo.location,
      ].join(' | ');

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md.w, vertical: AppSpacing.md.h),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Color(0xB3000000)],
        ),
      ),
      child: Row(
        children: [
          Expanded(child: _PhotographerTapTarget(photo: photo, name: _name, subtitle: _subtitle)),
          if (onViewAlbum != null) ...[
            SizedBox(width: AppSpacing.sm.w),
            _ViewAlbumButton(onTap: onViewAlbum!),
          ],
        ],
      ),
    );
  }
}

/// Avatar + name + event line, as one tap target that opens the
/// photographer's profile.
///
/// The whole cluster is tappable rather than just the avatar: it sits over a
/// photo where a 32 dp circle is a hard target, and the block reads as a
/// single attribution unit. [openPhotographerProfile] is the same helper the
/// discovery cards use, so the HomeBloc-carry and web-wrap behaviour stays in
/// one place.
class _PhotographerTapTarget extends StatelessWidget {
  const _PhotographerTapTarget({
    required this.photo,
    required this.name,
    required this.subtitle,
  });

  final Photo photo;
  final String name;
  final String subtitle;

  /// `Photo.userId` is the event's owner — the photographer — not the viewer.
  /// Payloads that never carried one leave it empty; the cluster then renders
  /// exactly as before rather than offering a tap that goes nowhere.
  String get _photographerId => photo.userId;

  @override
  Widget build(BuildContext context) {
    final row = Row(
      children: [
        UserAvatar(
          initial: name.substring(0, 1).toUpperCase(),
          imageUrl: photo.photographerAvatarUrl.isNotEmpty
              ? photo.photographerAvatarUrl
              : null,
          radius: 16,
        ),
        SizedBox(width: AppSpacing.sm.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (subtitle.isNotEmpty)
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        ),
      ],
    );

    if (_photographerId.isEmpty) return row;

    return Semantics(
      button: true,
      label: "View $name's profile",
      child: GestureDetector(
        onTap: () => openPhotographerProfile(
          context,
          photographerId: _photographerId,
          photographerName: photo.photographerName,
          photographerProfileUrl: photo.photographerAvatarUrl.isNotEmpty
              ? photo.photographerAvatarUrl
              : null,
        ),
        behavior: HitTestBehavior.opaque,
        child: row,
      ),
    );
  }
}

class _ViewAlbumButton extends StatelessWidget {
  const _ViewAlbumButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'View album',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.md.w, vertical: AppSpacing.sm.h),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(AppRadius.sm.r),
            // The design's outline is essentially opaque white — sampled at
            // #F5EFE6 over a bright photo, which no 35 % white could reach.
            // At 35 % it disappeared against light image content, which is
            // exactly where the button most needs an edge.
            border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
          ),
          child: Text(
            'View album',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
