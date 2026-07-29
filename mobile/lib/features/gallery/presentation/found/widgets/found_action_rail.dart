import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/components/media/media_action_buttons.dart';
import 'package:skidoo_app/components/media/media_rail_action.dart';
import 'package:skidoo_app/core/di/service_locator.dart';
import 'package:skidoo_app/core/theme/app_spacing.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/features/gallery/presentation/found/found_access.dart';
import 'package:skidoo_app/features/gallery/presentation/widgets/gallery_share_sheet.dart';
import 'package:skidoo_app/features/photo_comments/data/picture_like_service.dart';
import 'package:skidoo_app/features/photo_comments/presentation/pages/photo_comment_sheet.dart';
import 'package:skidoo_app/models/photos/Photo.dart';

/// The Found viewer's right-hand action rail.
///
/// Deliberately the same control and the same icon set as the home feed's
/// full-bleed card — like, comment, bookmark, send — built on the shared
/// [MediaRailAction] rather than the glassy [MediaActionButtons] used
/// elsewhere, because that's what the design shows on both screens.
class FoundActionRail extends StatefulWidget {
  const FoundActionRail({super.key, required this.photo});

  final Photo photo;

  @override
  State<FoundActionRail> createState() => _FoundActionRailState();
}

class _FoundActionRailState extends State<FoundActionRail> {
  late bool _liked = widget.photo.isLikedByUser;
  late int _likeCount = widget.photo.likeCount;
  bool _saving = false;

  final _bookmarkKey = GlobalKey();

  @override
  void didUpdateWidget(FoundActionRail old) {
    super.didUpdateWidget(old);
    // The rail is rebuilt for each page of the viewer; resync when the photo
    // under it changes.
    if (old.photo.id != widget.photo.id) {
      _liked = widget.photo.isLikedByUser;
      _likeCount = widget.photo.likeCount;
    }
  }

  void _toggleLike() {
    HapticFeedback.lightImpact();
    final nowLiked = !_liked;
    setState(() {
      _liked = nowLiked;
      _likeCount = (_likeCount + (nowLiked ? 1 : -1)).clamp(0, 999999999);
    });
    if (widget.photo.id.isEmpty) return;
    // Fire-and-forget, then reconcile against the server's own count.
    sl<PictureLikeService>().toggleLike(widget.photo.id).then((r) {
      if (!mounted) return;
      setState(() {
        _liked = r.isLiked;
        _likeCount = r.likes;
      });
    });
  }

  void _openComments() => PhotoCommentSheet.show(
        context,
        pictureId: widget.photo.id,
        imageUrl: widget.photo.url,
      );

  /// Saves the photo to the device via the branded-overlay pipeline every
  /// other "download" in the app uses.
  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);

    final box = _bookmarkKey.currentContext?.findRenderObject() as RenderBox?;
    final origin = (box != null && box.hasSize)
        ? box.localToGlobal(Offset.zero) & box.size
        : null;

    await shareOverlayPhotoExternally(
      context,
      imageId: widget.photo.id,
      photographerName: widget.photo.photographerName,
      eventName: widget.photo.eventName,
      isDownload: true,
      shareOrigin: origin,
    );
    if (mounted) setState(() => _saving = false);
  }

  void _send() => GalleryShareSheet.show(
        context,
        imageUrl: widget.photo.url,
        photoLabel: widget.photo.eventName,
      );

  /// Counts are only rendered where the record actually carries one — a
  /// hardcoded "0" under an action with no count behind it would be a lie.
  static String? _count(int value) => value > 0 ? '$value' : null;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final gap = SizedBox(height: AppSpacing.lg.h);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        MediaRailAction(
          icon: Icons.favorite_rounded,
          iconColor: _liked ? ext.likeRed : Colors.white,
          label: '$_likeCount',
          semanticLabel: _liked ? 'Unlike' : 'Like',
          onTap: () => _gated(_toggleLike),
        ),
        gap,
        MediaRailAction(
          icon: Icons.mode_comment_rounded,
          label: '${widget.photo.commentCount}',
          semanticLabel: 'Comments',
          onTap: () => _gated(_openComments),
        ),
        gap,
        MediaRailAction(
          key: _bookmarkKey,
          icon: Icons.bookmark_rounded,
          label: _count(0),
          busy: _saving,
          semanticLabel: 'Save photo',
          onTap: () => _gated(_save),
        ),
        gap,
        MediaRailAction(
          icon: Icons.near_me_rounded,
          semanticLabel: 'Send',
          onTap: () => _gated(_send),
        ),
      ],
    );
  }

  /// Every engagement action is account-gated: a guest is routed to sign-up
  /// under "Join to get the full experience" and the tap is replayed once the
  /// account exists, so the like/save they intended still lands.
  void _gated(VoidCallback action) =>
      requireAccount(context, action: action);
}
