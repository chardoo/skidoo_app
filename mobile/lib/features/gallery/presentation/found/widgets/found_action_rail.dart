import 'package:jperg_app/core/cache/comment_counts.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jperg_app/components/media/media_action_buttons.dart';
import 'package:jperg_app/components/media/media_reaction_rail.dart';
import 'package:jperg_app/components/media/share_target_sheet.dart';
import 'package:jperg_app/core/deep_links/deep_link.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/features/gallery/presentation/widgets/gallery_share_sheet.dart';
import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/core/utils/snackbar_utils.dart';
import 'package:jperg_app/features/gallery/data/saved_photos.dart';
import 'package:jperg_app/features/gallery/presentation/found/found_access.dart';
import 'package:jperg_app/features/gallery/presentation/found/models/found_photo_actions.dart';
import 'package:jperg_app/features/photo_comments/data/picture_like_service.dart';
import 'package:jperg_app/features/photo_comments/presentation/pages/photo_comment_sheet.dart';
import 'package:jperg_app/models/photos/Photo.dart';

/// The Found viewer's right-hand action rail.
///
/// Literally the same control as the home feed's full-bleed card: both are a
/// [MediaReactionRail], and the glyphs, the active fill and the spacing come
/// from there. This widget only decides *which* reactions the Found viewer
/// offers and what each one does.
///
/// Two actions past like and comment: bookmark adds the photo to the user's
/// saved items, and share passes it on — to someone in the app or out of it,
/// chosen in [ShareTargetSheet].
///
/// The download used to be a third and is not any more: it moved to the bar
/// across the bottom of the photo, beside the photographer's name. Everything
/// left here is something you do with a photo *on* the platform; the download
/// is the one action that takes the file off it, so it sits with the name of
/// whoever took it.
///
/// *Which* of them a given photo gets is [FoundPhotoActions]' business.
class FoundActionRail extends StatefulWidget {
  const FoundActionRail({
    super.key,
    required this.photo,
    this.purchaseGated = false,
    this.axis = Axis.vertical,
  });

  final Photo photo;

  /// Whether this photo's price and visibility decide what the rail offers —
  /// true only in Found you, where the photo is of the viewer and might not be
  /// theirs yet. See [FoundPhotoActions].
  final bool purchaseGated;

  /// Which way the actions run. Vertical down the right edge of the photo, or
  /// horizontal along the bottom bar — see
  /// [FoundPhotoActions.engagementsAtBottom] for which photos get which.
  ///
  /// The same widget either way on purpose: every handler here — the optimistic
  /// like, the share sheet, the bookmark and its rollback — is the same work
  /// wherever the glyphs are drawn, and a second widget would be that logic
  /// twice.
  final Axis axis;

  /// What [photo] would be offered. The stage asks before building a rail so a
  /// photo with nothing on offer gets no rail rather than an empty one.
  ///
  /// Covers the bottom bar's two actions as well as this rail's — one photo has
  /// one set of permissions, and splitting the question in two is how the two
  /// surfaces would start disagreeing about the same photo.
  static FoundPhotoActions actionsFor(
    Photo photo, {
    required bool gated,
    bool saved = false,
  }) =>
      gated
          ? FoundPhotoActions.forFoundPhoto(photo, saved: saved)
          : FoundPhotoActions.unrestricted(
              commentsEnabled: photo.commentsEnabled,
              isPublic: photo.isPublic);

  @override
  State<FoundActionRail> createState() => _FoundActionRailState();
}

class _FoundActionRailState extends State<FoundActionRail> {
  late bool _liked = widget.photo.isLikedByUser;
  late int _likeCount = widget.photo.likeCount;
  bool _sharing = false;

  final SavedPhotos? _saved = savedPhotosOrNull();

  /// The share sheet is anchored to this button on iPad/macOS, where a popover
  /// has to originate from something.
  final _shareKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // Cheap and shared: the id set is fetched once per session, so every rail
    // can ask without any of them costing a request.
    _saved?.ensureLoaded();
    // A listener rather than a wrapper widget: MediaReaction is a value the
    // rail renders, not a widget slot something can be inserted around.
    CommentCounts.instance.addListener(_onCommentCountsChanged);
  }

  @override
  void dispose() {
    CommentCounts.instance.removeListener(_onCommentCountsChanged);
    super.dispose();
  }

  void _onCommentCountsChanged() {
    if (mounted) setState(() {});
  }

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

  /// Bookmarks the photo into the user's saved items, or takes it out again.
  ///
  /// This is what the glyph has always claimed to do and never did — it ran
  /// [_download] instead.
  Future<void> _toggleSave() async {
    final saved = _saved;
    if (saved == null || widget.photo.id.isEmpty) return;
    HapticFeedback.lightImpact();
    try {
      await saved.toggle(widget.photo.id);
    } catch (_) {
      if (!mounted) return;
      // SavedPhotos has already rolled the glyph back, so the message is the
      // only thing left to say.
      AppSnackBar.error(context, 'Could not update your saved photos.');
    }
  }

  /// Asks where the photo is going, then goes there.
  ///
  /// The rail carries one share button; [ShareTargetSheet] is where in-app and
  /// external part company, named rather than left to two similar glyphs.
  void _openShareTargets() => ShareTargetSheet.show(
        context,
        onInApp: _send,
        onExternal: _shareExternally,
      );

  /// Hands the photo to the OS share sheet — other apps, Messages, AirDrop.
  ///
  /// Goes through the branded-overlay pipeline, so a photo leaving the app is
  /// watermarked however it leaves. [_toggleSave] is not in that family at all
  /// — a bookmark moves no pixels anywhere.
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
      // The photo itself. Never /my-photos — that opens the *recipient's*
      // photos, not the one being shared. A /p/ link opens the album with this
      // photo already showing, so the context comes for free.
      link: widget.photo.id.isNotEmpty
          ? DeepLink(DeepLinkKind.picture, id: widget.photo.id)
          : null,
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
    final offered = FoundActionRail.actionsFor(
      widget.photo,
      gated: widget.purchaseGated,
      saved: _saved?.isSaved(widget.photo.id) ?? false,
    );

    // Rebuilt whenever the saved set changes, including from another rail
    // showing the same photo.
    return ValueListenableBuilder<int>(
      valueListenable: _saved?.revision ?? kNoSavedPhotos,
      builder: (context, _, __) => _rail(offered),
    );
  }

  Widget _rail(FoundPhotoActions offered) {
    final photoId = widget.photo.id;

    return MediaReactionRail(
      axis: widget.axis,
      // Tighter along the bottom, where the row shares its line with the
      // photographer's name and the download. The vertical rail has the whole
      // edge to itself and keeps its own spacing.
      gap: widget.axis == Axis.horizontal ? AppSpacing.md : null,
      actions: [
        // The heart does not follow the comment switch. Closing the thread is
        // the owner declining a conversation, not declining reactions — see
        // [FoundPhotoActions.like]. Where they have closed it the comment glyph
        // stays, drawn unavailable — see [MediaReaction.commentsDisabled].
        if (offered.like)
          MediaReaction.like(
            liked: _liked,
            count: _likeCount,
            onTap: () => _requireAccount(_toggleLike),
          ),
        if (offered.comment)
          MediaReaction.comment(
            // Live, so the rail corrects itself the moment a comment is
            // posted instead of showing the count the photo was fetched with.
            count: CommentCounts.instance.countFor(widget.photo.id) ??
                widget.photo.commentCount,
            onTap: () => _requireAccount(_openComments),
          ),
        if (offered.commentsDisabled)
          MediaReaction.commentsDisabled(
            count: CommentCounts.instance.countFor(widget.photo.id) ??
                widget.photo.commentCount,
          ),
        // Neither the bookmark nor the download has a count behind it, so the
        // rail renders the glyph alone rather than a fake "0".
        if (offered.save && _saved != null)
          MediaReaction.bookmark(
            saved: _saved!.isSaved(photoId),
            busy: _saved!.isBusy(photoId),
            onTap: () => _requireAccount(_toggleSave),
          ),
        if (offered.share)
          MediaReaction.share(
            anchorKey: _shareKey,
            busy: _sharing,
            onTap: () => _requireAccount(_openShareTargets),
          ),
        // The download is not here. It is drawn by [FoundPhotoQuickActions] in
        // the bar across the bottom of the photo: everything on this rail is
        // something you do with a photo *on* the platform, and the download is
        // the one action that takes the file off it.
      ],
    );
  }

  /// Every engagement action is account-gated: a guest is routed to sign-up
  /// under "Join to get the full experience" and the tap is replayed once the
  /// account exists, so the like/save they intended still lands.
  ///
  /// Named apart from the *purchase* gate above — that one decides whether an
  /// action is on the rail at all, this one decides who may press it.
  void _requireAccount(VoidCallback action) =>
      requireAccount(context, action: action);
}
