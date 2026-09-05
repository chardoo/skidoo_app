import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/components/media/media_action_buttons.dart';
import 'package:jperg_app/components/media/media_rail_action.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/features/gallery/data/saved_photos.dart';
import 'package:jperg_app/features/gallery/presentation/found/found_access.dart';
import 'package:jperg_app/features/gallery/presentation/found/models/found_photo_actions.dart';
import 'package:jperg_app/models/photos/Photo.dart';

/// The download, at the right-hand end of the photo's bottom bar.
///
/// It used to sit at the foot of the vertical rail with the reactions. The
/// design moves it here, beside the photographer's name, and that is where it
/// belongs: everything left on the rail — the heart, the thread, the bookmark,
/// passing the photo on — is something you do with a photo *on* the platform.
/// The download is the one action that takes the file off it, so it stands
/// apart, next to the name of whoever took it.
///
/// Sharing stays on the rail on a public photo — it is an engagement like the
/// rest of them, and splitting the reactions across two surfaces would be for
/// nothing. On a private photo it comes down here with them, because there is
/// no rail left worth drawing; see [FoundPhotoActions.engagementsAtBottom].
///
/// Drawn as a bare glyph, the same [MediaRailAction] the reactions are — no
/// disc behind it, no outline. It used to be a white-at-18% circle with a
/// border, which was a way of separating a white icon from a bright photo
/// before the glyphs learned to do that themselves; they carry their own drop
/// shadow now, and the circle was left behind doing nothing but drawing
/// attention to one action over every other.
///
/// It matters more since a private photo's engagements moved down here beside
/// it — see [FoundPhotoActions.engagementsAtBottom]. A disc around the
/// download and nothing around the share sitting next to it reads as two
/// different kinds of control, which they are not.
///
/// The tap target is kept at the size the circle used to imply: the glyph is
/// 24 points and a finger is not, so [MediaRailAction.tapTargetSize] pads it
/// back out to 40 rather than shrinking what can be pressed.
///
/// Whether the button appears at all is [FoundPhotoActions]' business. It is
/// only ever offered on a photo the viewer owns — bought if it had a price,
/// bookmarked if it did not.
class FoundPhotoQuickActions extends StatefulWidget {
  const FoundPhotoQuickActions({
    super.key,
    required this.photo,
    this.purchaseGated = false,
  });

  final Photo photo;

  /// Whether this photo's price and visibility decide what is offered — true
  /// only in Found you, where the photo is of the viewer and might not be
  /// theirs yet.
  final bool purchaseGated;

  @override
  State<FoundPhotoQuickActions> createState() => _FoundPhotoQuickActionsState();
}

class _FoundPhotoQuickActionsState extends State<FoundPhotoQuickActions> {
  bool _downloading = false;

  final SavedPhotos? _saved = savedPhotosOrNull();

  /// The OS save dialog is anchored to this on iPad/macOS, where a popover has
  /// to originate from something.
  final _downloadKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // Cheap and shared: the id set is fetched once per session, so asking here
    // costs no request. It decides whether a free photo may be downloaded.
    _saved?.ensureLoaded();
  }

  /// Writes the file to the device via the branded-overlay pipeline every other
  /// download in the app uses.
  Future<void> _download() async {
    if (_downloading) return;
    setState(() => _downloading = true);

    final box = _downloadKey.currentContext?.findRenderObject() as RenderBox?;
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
    if (mounted) setState(() => _downloading = false);
  }

  /// Every action here is account-gated: a guest is routed to sign-up and the
  /// tap is replayed once the account exists.
  void _require(VoidCallback action) => requireAccount(context, action: action);

  FoundPhotoActions get _offered => widget.purchaseGated
      ? FoundPhotoActions.forFoundPhoto(
          widget.photo,
          saved: _saved?.isSaved(widget.photo.id) ?? false,
        )
      : FoundPhotoActions.unrestricted(
          commentsEnabled: widget.photo.commentsEnabled,
          isPublic: widget.photo.isPublic,
        );

  @override
  Widget build(BuildContext context) {
    // Rebuilt whenever the saved set changes: bookmarking a free photo is what
    // earns it a download, and the button has to appear when it happens rather
    // than the next time the viewer is opened.
    return ValueListenableBuilder<int>(
      valueListenable: _saved?.revision ?? kNoSavedPhotos,
      builder: (context, _, __) {
        final offered = _offered;
        // `download`, not `anyInBar`. The bar now carries the engagements of a
        // private photo as well — see [FoundPhotoActions.anyInBar] — and this
        // widget draws exactly one of the things in it.
        //
        // Zero width, not an empty box with a gap beside it: the name block
        // next to this takes every pixel this does not, and on a photo with no
        // download that is all of them.
        if (!offered.download) return const SizedBox.shrink();

        return Padding(
          // The gap belongs to the button, so it disappears with it.
          padding: EdgeInsets.only(left: AppSpacing.sm.w),
          child: MediaRailAction(
            key: _downloadKey,
            icon: Icons.download_rounded,
            // No count under it — the download has no number behind it, and a
            // hardcoded zero is worse than nothing. `semanticLabel` carries
            // what the missing text would have said.
            semanticLabel: 'Download photo',
            busy: _downloading,
            tapTargetSize: 40.r,
            onTap: () => _require(_download),
          ),
        );
      },
    );
  }
}
