import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/common/widgets/user_avatar.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/features/discovery/presentation/utils/open_photographer_profile.dart';
import 'package:jperg_app/features/gallery/presentation/found/models/found_photo_actions.dart';
import 'package:jperg_app/features/gallery/presentation/found/widgets/found_action_rail.dart';
import 'package:jperg_app/features/gallery/presentation/found/widgets/found_photo_quick_actions.dart';
import 'package:jperg_app/models/photos/Photo.dart';

/// Footer strip over the bottom of the photo in the Found viewer:
/// photographer identity on the left, the actions on the right.
///
/// What sits on that right-hand end depends on the photo. Every photo that
/// earns one gets the download. A **private** photo gets its engagements here
/// too, laid along the bottom instead of down the right edge — see
/// [FoundPhotoActions.engagementsAtBottom], which explains why a private
/// photo's rail was not worth having.
///
/// The right-hand end used to be a "View album" button. It went for two
/// reasons: the album is one back-swipe away from almost everywhere this
/// viewer is opened, and the two actions that belong beside a photographer's
/// name are the ones that take their work out of the app. Those came down off
/// the vertical rail to sit here, which is where the design puts them.
///
/// Every text line degrades gracefully — an unnamed photographer, a photo
/// with no event, or an event with no location each just drop out instead of
/// leaving stray separators behind.
class FoundPhotoMetaBar extends StatelessWidget {
  const FoundPhotoMetaBar({
    super.key,
    required this.photo,
    this.purchaseGated = false,
  });

  final Photo photo;

  /// Whether the photo's price and visibility decide what is offered — true
  /// only in Found you. Passed straight through to [FoundPhotoQuickActions].
  final bool purchaseGated;

  String get _name =>
      photo.photographerName.isNotEmpty ? photo.photographerName : 'Photographer';

  String get _subtitle => [
        if (photo.eventName.isNotEmpty) photo.eventName,
        if (photo.location.isNotEmpty) photo.location,
      ].join(' | ');

  /// What this photo is offered, so the bar knows whether the engagements
  /// belong to it. The same call the stage makes for the rail — one photo has
  /// one set of permissions, and asking twice is how two surfaces start
  /// disagreeing about the same photo.
  FoundPhotoActions get _offered =>
      FoundActionRail.actionsFor(photo, gated: purchaseGated);

  @override
  Widget build(BuildContext context) {
    final offered = _offered;

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
          Expanded(
            child: _PhotographerTapTarget(
                photo: photo, name: _name, subtitle: _subtitle),
          ),
          // A private photo's engagements, on the same line. The rail widget
          // itself, turned on its side — every handler behind these glyphs is
          // the same work wherever they are drawn.
          if (offered.engagementsAtBottom && offered.anyEngagement)
            Padding(
              padding: EdgeInsets.only(left: AppSpacing.sm.w),
              child: FoundActionRail(
                key: ValueKey('found_actions_bar_${photo.id}'),
                photo: photo,
                purchaseGated: purchaseGated,
                axis: Axis.horizontal,
              ),
            ),
          // Zero-width when there is no download to offer, and it carries its
          // own leading gap so there is none to take back. A spacer out here
          // would narrow the name on every photo that has no button, which is
          // most of them — enough to overflow the row on a long event title.
          FoundPhotoQuickActions(photo: photo, purchaseGated: purchaseGated),
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

