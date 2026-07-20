import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/common/widgets/app_loading_indicator.dart';
import 'package:skidoo_app/core/common/widgets/expandable_caption.dart';
import 'package:skidoo_app/core/widgets/skidoo_image.dart';
import 'package:skidoo_app/core/widgets/video_player/skidoo_video_player.dart';
import 'package:skidoo_app/models/photos/Photo.dart';
import 'package:skidoo_app/core/theme/app_spacing.dart';

/// One full-screen page of the "Found" tab's vertically-paged feed — photos
/// (and videos) the current user was found in via face-match
/// (`GalleryBloc`/`POST /client/dashboard`). Deliberately simpler than
/// [FullBleedEventCard]: `Photo` has no photographer/follow data and
/// `GalleryBloc` has no like/save/comment-toggle event, so like/comment
/// counts are shown read-only rather than faking interactivity the data
/// doesn't support.
class FoundPhotoCard extends StatelessWidget {
  const FoundPhotoCard({
    super.key,
    required this.photo,
    required this.cardIndex,
    required this.activeCardIndex,
  });

  final Photo photo;
  final int cardIndex;
  final ValueNotifier<int> activeCardIndex;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (photo.isVideo)
          _ActiveGatedVideo(
            url: photo.url,
            cardIndex: cardIndex,
            activeCardIndex: activeCardIndex,
          )
        else
          SkidooImage(
            imageUrl: photo.url,
            fit: BoxFit.cover,
            semanticLabel: 'Found photo',
            placeholder: (_, __) => const ColoredBox(
              color: Color(0xFF111111),
              child: AppLoadingIndicator(),
            ),
            errorWidget: (_, __, ___) => const ColoredBox(color: Color(0xFF111111)),
          ),

        const Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 180,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xAA000000)],
                ),
              ),
            ),
          ),
        ),

        Positioned(
          left: 16.w,
          right: 88.w,
          bottom: 24.h,
          child: ExpandableCaption(
            text: photo.eventName.isNotEmpty
                ? photo.eventName
                : 'Found you in this photo',
            collapsedMaxLines: 2,
            style: TextStyle(
              color: Colors.white,
              fontSize: 15.sp,
              fontWeight: FontWeight.w700,
            ),
            linkStyle: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        Positioned(
          right: 12.w,
          top: 0,
          bottom: 0,
          child: Align(
            alignment: const Alignment(0, 0.4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.favorite_rounded,
                  color: photo.isLikedByUser ? const Color(0xFFFF3B5C) : Colors.white,
                  size: 26.sp,
                  shadows: const [Shadow(color: Colors.black45, blurRadius: 4)],
                ),
                SizedBox(height: 3.h),
                Text('${photo.likeCount}', style: _countStyle),
                SizedBox(height: AppSpacing.lg.h),
                Icon(Icons.mode_comment_rounded,
                    color: Colors.white,
                    size: 26.sp,
                    shadows: const [Shadow(color: Colors.black45, blurRadius: 4)]),
                SizedBox(height: 3.h),
                Text('${photo.commentCount}', style: _countStyle),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static final _countStyle = TextStyle(
    color: Colors.white,
    fontSize: 11.sp,
    fontWeight: FontWeight.w600,
    shadows: const [Shadow(color: Colors.black45, blurRadius: 4)],
  );
}

class _ActiveGatedVideo extends StatelessWidget {
  const _ActiveGatedVideo({
    required this.url,
    required this.cardIndex,
    required this.activeCardIndex,
  });

  final String url;
  final int cardIndex;
  final ValueNotifier<int> activeCardIndex;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: activeCardIndex,
      builder: (context, active, _) => SkidooVideoPlayer(
        url: url,
        isActive: active == cardIndex,
        autoPlay: true,
        loop: true,
        fit: BoxFit.cover,
        showControls: true,
        backgroundColor: Colors.black,
        listenToPauseNotifier: true,
      ),
    );
  }
}
