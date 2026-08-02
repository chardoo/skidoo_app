import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:skidoo_app/components/media/media_action_buttons.dart';
import 'package:skidoo_app/components/media/media_reaction_rail.dart';
import 'package:skidoo_app/core/di/service_locator.dart';
import 'package:skidoo_app/features/gallery/presentation/found/found_access.dart';
import 'package:skidoo_app/features/gallery/presentation/widgets/gallery_share_sheet.dart';
import 'package:skidoo_app/features/photo_comments/data/picture_like_service.dart';
import 'package:skidoo_app/features/photo_comments/presentation/pages/photo_comment_sheet.dart';
import 'package:skidoo_app/models/photos/Photo.dart';

/// The Found viewer's right-hand action rail.
///
/// Literally the same control as the home feed's full-bleed card: both are a
/// [MediaReactionRail], and the glyphs, the active fill and the spacing come
/// from there. This widget only decides *which* reactions the Found viewer
/// offers and what each one does.
///
/// The three outbound actions are distinct and all three earn their place:
/// bookmark saves to the device, share hands off to the OS sheet, send opens
/// the in-app DM picker.
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
  bool _sharing = false;

  final _bookmarkKey = GlobalKey();

  /// The share sheet is anchored to this button on iPad/macOS, where a popover
  /// has to originate from something.
  final _shareKey = GlobalKey();

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

  /// Hands the photo to the OS share sheet — other apps, Messages, AirDrop.
  ///
  /// Not the same action as either neighbour: [_save] writes the file to the
  /// device and [_send] opens the in-app DM picker. All three go through the
  /// branded-overlay pipeline, so a photo leaving the app is watermarked
  /// however it leaves.
  Future<void> _shareExternally() async {
    if (_sharing) return;
    setState(() => _sharing = true);

    final box = _shareKey.currentContext?.findRenderObject() as RenderBox?;
    final origin = (box != null && box.hasSize)
        ? box.localToGlobal(Offset.zero) & box.size
        : null;

    await shareOverlayPhotoExternally(
      context,
      imageId: widget.photo.id,
      photographerName: widget.photo.photographerName,
      eventName: widget.photo.eventName,
      shareOrigin: origin,
    );
    if (mounted) setState(() => _sharing = false);
  }

  void _send() => GalleryShareSheet.show(
        context,
        imageUrl: widget.photo.url,
        photoLabel: widget.photo.eventName,
      );

  @override
  Widget build(BuildContext context) {
    return MediaReactionRail(
      actions: [
        // Like and comment follow the owner's engagement switch for this
        // picture; send and save stay available either way.
        if (widget.photo.commentsEnabled) ...[
          MediaReaction.like(
            liked: _liked,
            count: _likeCount,
            onTap: () => _gated(_toggleLike),
          ),
          MediaReaction.comment(
            count: widget.photo.commentCount,
            onTap: () => _gated(_openComments),
          ),
        ],
        // Saving writes the file to the device, so there is no count behind
        // this one — the rail renders the glyph alone rather than a fake "0".
        MediaReaction.bookmark(
          anchorKey: _bookmarkKey,
          busy: _saving,
          semanticLabel: 'Save photo',
          onTap: () => _gated(_save),
        ),
        MediaReaction.shareExternally(
          anchorKey: _shareKey,
          busy: _sharing,
          onTap: () => _gated(_shareExternally),
        ),
        MediaReaction.send(onTap: () => _gated(_send)),
      ],
    );
  }

  /// Every engagement action is account-gated: a guest is routed to sign-up
  /// under "Join to get the full experience" and the tap is replayed once the
  /// account exists, so the like/save they intended still lands.
  void _gated(VoidCallback action) => requireAccount(context, action: action);
}
