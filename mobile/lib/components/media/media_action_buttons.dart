import 'package:jperg_app/core/cache/comment_counts.dart';
import 'dart:convert' show base64Encode;
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:jperg_app/components/media/media_rail_action.dart';
import 'package:jperg_app/components/media/share_target_sheet.dart';
import 'package:jperg_app/core/config/app_links_config.dart';
import 'package:jperg_app/core/deep_links/deep_link.dart';
import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/core/utils/snackbar_utils.dart';
import 'package:jperg_app/features/gallery/data/saved_photos.dart';
import 'package:jperg_app/features/gallery/domain/usecases/get_overlay_usecase.dart';
import 'package:jperg_app/features/photo_comments/data/picture_like_service.dart';
import 'package:jperg_app/features/photo_comments/presentation/pages/photo_comment_sheet.dart';
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';

/// The two outward actions on a photo, which no longer work the same way:
///
///  • **Share** hands the OS share sheet *text only* — the event name, its
///    description and a URL that opens the thing in the app. No image travels.
///    A link previews as a card in every messaging app, keeps working when the
///    text is truncated, and costs nothing to produce, so the share sheet opens
///    instantly instead of after a round-trip.
///  • **Download** still fetches the creator-branded overlay image and writes a
///    real file, because there is nothing to save otherwise.
///
/// This is THE external-share routine for the whole app — every card's "share
/// to other apps" icon (discovery page, Home "Feed"/"Following", the Found tab,
/// the event-pictures feed) calls this exact function so the behaviour never
/// diverges between screens. Also used internally by [MediaActionButtons]'s own
/// Share/Download buttons.
///
/// To go back to sharing the rendered file, delete the early return in the
/// share branch below: the download path underneath already does exactly that,
/// and passing `text` to it is the whole difference.
///
/// [imageId] is the picture's `id` (matches the existing `imageId:` param
/// convention already used by every [MediaActionButtons] call site) — NOT
/// the separate `imageId` field on [EventPicture]/`Photo`, which is a
/// different value. Every call site must pass `pic.id` here, not
/// `pic.imageId`.
/// [link] is what makes the share worth anything: without it the message is a
/// name and a caption with no way back to the event, the photographer, or the
/// app. Every share call site should pass one.
///
/// [description] is trimmed to a couple of lines: share sheets and the apps
/// they hand off to truncate long text unpredictably, and the URL is the part
/// that must survive.
Future<void> shareOverlayPhotoExternally(
  BuildContext context, {
  required String imageId,
  required String photographerName,
  String eventName = '',
  bool isDownload = false,
  Rect? shareOrigin,
  DeepLink? link,
  String description = '',
}) async {
  final subject = eventName.isNotEmpty ? eventName : 'Photo';
  final origin = _resolveShareOrigin(context, shareOrigin);

  // ── Share: the link and its context, nothing fetched ────────────────────
  if (!isDownload) {
    await Share.share(
      _shareMessage(
        eventName: eventName,
        description: description,
        photographerName: photographerName,
        link: link,
      ),
      subject: subject,
      sharePositionOrigin: origin,
    );
    return;
  }

  // ── Download: needs the actual bytes ────────────────────────────────────
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.transparent,
    builder: (_) => const _ProcessingOverlay(label: 'Preparing download…'),
  );

  try {
    final result =
        await sl<GetOverlayImageUseCase>()(imageId, photographerName);
    if (!context.mounted) return;
    _dismissProcessingDialog(context);

    final safeId = imageId.replaceAll('/', '_').replaceAll('\\', '_');
    final filename = 'overlay_$safeId.${result.fileExtension}';

    if (kIsWeb) {
      // ── Web: use in-memory XFile — no temp file writes ──────────────────
      final xFile = XFile.fromData(
        result.bytes,
        mimeType: result.contentType,
        name: filename,
      );
      try {
        await Share.shareXFiles([xFile], subject: subject);
      } catch (_) {
        // Browser doesn't support Web Share API Level 2 — fall back to
        // triggering a browser download via a data URI.
        final dataUri =
            'data:${result.contentType};base64,${base64Encode(result.bytes)}';
        await launchUrl(Uri.parse(dataUri), mode: LaunchMode.externalApplication);
      }
      return;
    }

    // ── Mobile: write temp file → OS save/share sheet ────────────────────
    // No `text:` here — this is the Save path, and a caption riding along
    // with it would land in whatever app the user picks to save through.
    final dir = await getTemporaryDirectory();
    final filePath = '${dir.path}/$filename';
    await File(filePath).writeAsBytes(result.bytes, flush: true);

    await Share.shareXFiles(
      [XFile(filePath, mimeType: result.contentType)],
      subject: subject,
      sharePositionOrigin: origin,
    );

    // Clean up after the OS share sheet closes.
    try {
      await File(filePath).delete();
    } catch (_) {}
  } catch (e) {
    if (context.mounted) {
      _dismissProcessingDialog(context);
      AppSnackBar.error(
        context,
        'Could not prepare file: $e',
        margin: const EdgeInsets.only(bottom: 80, left: 24, right: 24),
      );
    }
  }
}

/// The rect iOS hangs the share sheet off.
///
/// UIActivityViewController throws on a zero rect rather than falling back to
/// anything sensible — `sharePositionOrigin: argument must be set, {{0, 0},
/// {0, 0}} must be non-zero`. A null origin reaches it as exactly that, so
/// every call site would otherwise have to remember to measure its own button.
/// The ones that share from a whole card rather than a specific control (the
/// discovery cards) have no button to measure, so resolve it here instead:
/// caller's rect if it gave one, else the widget that triggered the share,
/// else the middle of the screen.
///
/// Android ignores this entirely; it only matters on iPad, where the sheet is
/// a popover that needs somewhere real to point, and on iPhone, where an empty
/// rect is still rejected outright.
Rect _resolveShareOrigin(BuildContext context, Rect? provided) {
  final screen = Offset.zero & MediaQuery.sizeOf(context);

  var candidate = provided;
  if (candidate == null || candidate.isEmpty) {
    final box = context.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      candidate = box.localToGlobal(Offset.zero) & box.size;
    }
  }

  // Clamped to the screen: the rect must sit inside the source view or iOS
  // rejects it just as it rejects a zero one, and a card half-scrolled off
  // the top reports a perfectly valid rect that starts above y = 0.
  if (candidate != null && !candidate.isEmpty) {
    final clamped = candidate.intersect(screen);
    if (!clamped.isEmpty) return clamped;
  }

  return Rect.fromCenter(center: screen.center, width: 1, height: 1);
}

/// The text that travels beside the photo.
///
/// Ordered so the important part survives truncation: what it is, then who
/// shot it, then the description, then the link. Messaging apps cut long text
/// from the end, but they lift a URL out into a preview card wherever it sits,
/// so the link keeps working even when the rest is clipped.
String _shareMessage({
  required String eventName,
  required String description,
  required String photographerName,
  DeepLink? link,
}) {
  final lines = <String>[
    if (eventName.isNotEmpty) eventName else 'Check out this photo!',
    if (photographerName.isNotEmpty) 'Photos by $photographerName',
    if (description.trim().isNotEmpty) _trimForShare(description),
    if (link != null) AppLinksConfig.urlFor(link),
  ];
  return lines.join('\n');
}

/// Long captions get cut at a word boundary rather than mid-word, and only
/// when they are actually long — most are a line or two and pass through.
String _trimForShare(String value, {int max = 180}) {
  final text = value.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (text.length <= max) return text;
  final cut = text.lastIndexOf(' ', max);
  return '${text.substring(0, cut > 0 ? cut : max)}…';
}

/// Pops the [_ProcessingOverlay] dialog pushed at the top of
/// [shareOverlayPhotoExternally]. Guarded with `canPop()` + try/catch: if
/// the route is already gone for any reason (user backed out, a hot-reload
/// reassemble raced with the in-flight request, etc.), this becomes a
/// no-op instead of hitting Flutter's `_history.isNotEmpty` assertion from
/// popping a Navigator with nothing left on its stack.
void _dismissProcessingDialog(BuildContext context) {
  try {
    final navigator = Navigator.of(context, rootNavigator: true);
    if (navigator.canPop()) navigator.pop();
  } catch (_) {}
}

/// Reusable **Like / Download / Share / Comment** action buttons for any media item.
///
/// [axis] controls layout:
///   • [Axis.vertical]   → TikTok-style sidebar (event pictures page).
///   • [Axis.horizontal] → flat row with dividers  (fullscreen page).
///
/// The buttons themselves are [MediaRailAction]s — the same control the
/// [MediaReactionRail] draws — so the glyph set, the shadow that keeps a white
/// icon legible over a photo and the press-scale match the feed card and the
/// Found viewer. Only the layout differs: this one is a row across the bottom
/// of the frame rather than a column down its edge. Download is the one action
/// here that no rail offers.
///
/// Provide [pictureId] (defaults to [imageId]) to show the Comment button.
///
/// [onLikeToggled] is called with the new liked state after an optimistic UI
/// update.  The callback is responsible for syncing the like to the server
/// (e.g. via a photo-room WebSocket).  When omitted the update is local-only.
class MediaActionButtons extends StatefulWidget {
  const MediaActionButtons({
    super.key,
    required this.imageId,
    required this.imageUrl,
    this.photographerName = '',
    this.eventName = '',
    this.axis = Axis.vertical,
    this.buttonSize,
    this.iconSize,
    this.initialLikeCount = 0,
    this.initialCommentCount = 0,
    this.initiallyLiked = false,
    this.showLike = true,
    this.showSave = true,
    this.showDownload = false,
    this.showComment = true,
    this.onLikeToggled,
    this.onSend,
    this.link,
    this.description = '',
    String? pictureId,
  }) : pictureId = pictureId ?? imageId;

  final String imageId;
  final String imageUrl;
  final String photographerName;
  final String eventName;
  final Axis axis;
  final double? buttonSize;
  final double? iconSize;
  final int initialLikeCount;
  final int initialCommentCount;
  final bool initiallyLiked;

  /// Whether to show the like button. Set to false in contexts where
  /// liking is not applicable (e.g. the personal gallery fullscreen view).
  final bool showLike;

  /// Whether to show the bookmark button — adds the photo to the user's saved
  /// items. A different action from [showDownload], which writes the file to
  /// the device; this row had only the latter, so a single photo could be
  /// downloaded but never bookmarked.
  final bool showSave;

  /// Whether to show the download button.
  ///
  /// Off unless a caller asks for it, and no caller does. Writing a photo to
  /// the phone is offered in exactly one place in the app — the Found you
  /// viewer, on a photo the person has paid for — because that is the only
  /// place a purchase stands behind it. Anywhere else the photo belongs to the
  /// photographer who took it, so the button would be handing out their work.
  /// See FoundPhotoActions.
  final bool showDownload;

  /// Whether to show the Comment button. Set to false when comment
  /// interaction is not applicable (e.g. the personal gallery fullscreen view).
  final bool showComment;

  /// Called after the optimistic like/unlike update with the new [liked] value.
  /// The callback owns server-sync responsibility.
  final void Function(bool liked)? onLikeToggled;

  /// When provided, shows a Send button for in-app DM sharing.
  /// Independent of [showComment] — both can appear at the same time.
  final VoidCallback? onSend;

  /// Where a share should point. Share now sends a link rather than a file,
  /// so without this the message carries no way back into the app — pass the
  /// event the photo came from wherever it is known.
  final DeepLink? link;

  /// Event blurb that travels with the link. Optional; omitted when empty.
  final String description;

  /// The picture ID used for comments and likes. Defaults to [imageId].
  final String pictureId;

  @override
  State<MediaActionButtons> createState() => _MediaActionButtonsState();
}

class _MediaActionButtonsState extends State<MediaActionButtons> {
  late bool _liked;
  late int _likeCount;
  late int _commentCount;
  bool _downloading = false;
  bool _sharing = false;

  final SavedPhotos? _saved = savedPhotosOrNull();

  /// Whether to draw the bookmark: asked for, and a store to back it.
  bool get _canSave => widget.showSave && _saved != null;

  final _downloadKey = GlobalKey();
  final _shareKey = GlobalKey();

  Future<void> _toggleSave() async {
    final saved = _saved;
    if (saved == null || widget.pictureId.isEmpty) return;
    HapticFeedback.lightImpact();
    try {
      await saved.toggle(widget.pictureId);
    } catch (_) {
      if (!mounted) return;
      // The glyph has already been rolled back by SavedPhotos.
      AppSnackBar.error(context, 'Could not update your saved photos.');
    }
  }

  @override
  void initState() {
    super.initState();
    _liked = widget.initiallyLiked;
    _likeCount = widget.initialLikeCount;
    _commentCount = widget.initialCommentCount;
    if (_canSave) _saved!.ensureLoaded();
  }

  /// Null for a count of zero — the shared button then draws the glyph alone
  /// rather than an empty caption slot under it.
  static String? _fmt(int n) {
    if (n <= 0) return null;
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(n >= 10000 ? 0 : 1)}K';
    return '$n';
  }

  double get _btnSize =>
      widget.buttonSize ??
      (widget.axis == Axis.vertical ? 44.w : 52.w);

  double get _icnSize =>
      widget.iconSize ??
      (widget.axis == Axis.vertical ? 20.sp : 22.sp);

  // ── Core: fetch overlay → share / download ───────────────────────────────

  Future<void> _handleAction({required bool isDownload}) async {
    if (_downloading || _sharing) return;
    setState(() {
      if (isDownload) _downloading = true; else _sharing = true;
    });

    // Capture the button's screen rect BEFORE any await so iOS knows where
    // to anchor the share popover (required by share_plus on iPhone/iPad).
    // On web the share popover is browser-native — no origin needed.
    final key = isDownload ? _downloadKey : _shareKey;
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    final shareOrigin = (!kIsWeb && box != null && box.hasSize)
        ? box.localToGlobal(Offset.zero) & box.size
        : null;

    await shareOverlayPhotoExternally(
      context,
      imageId: widget.imageId,
      photographerName: widget.photographerName,
      eventName: widget.eventName,
      isDownload: isDownload,
      shareOrigin: shareOrigin,
      link: widget.link,
      description: widget.description,
    );

    if (mounted) {
      setState(() { _downloading = false; _sharing = false; });
    }
  }

  void _toggleLike() {
    HapticFeedback.lightImpact();
    final nowLiked = !_liked;
    setState(() {
      _liked = nowLiked;
      _likeCount = (_likeCount + (nowLiked ? 1 : -1)).clamp(0, 999999999);
    });
    if (widget.onLikeToggled != null) {
      widget.onLikeToggled!(nowLiked);
    } else if (widget.pictureId.isNotEmpty) {
      // Default: hit REST endpoint; reconcile count from server response.
      sl<PictureLikeService>().toggleLike(widget.pictureId).then((r) {
        if (mounted) {
          setState(() {
            _liked = r.isLiked;
            _likeCount = r.likes;
          });
        }
      });
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Rebuilt whenever the saved set changes — including from a rail elsewhere
    // showing the same photo, so the bookmark cannot go stale behind a
    // navigation.
    return ValueListenableBuilder<int>(
      valueListenable: _saved?.revision ?? kNoSavedPhotos,
      builder: (context, _, __) => _buttons(context),
    );
  }

  Widget _buttons(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    Widget btn({
      Key? key,
      required IconData icon,
      required VoidCallback onTap,
      Color color = Colors.white,
      String? label,
      bool busy = false,
      String? semanticLabel,
    }) =>
        MediaRailAction(
          key: key,
          icon: icon,
          iconColor: color,
          label: label,
          busy: busy,
          semanticLabel: semanticLabel,
          iconSize: _icnSize,
          tapTargetSize: _btnSize,
          onTap: onTap,
        );

    final btns = <Widget>[
      if (widget.showLike)
        btn(
          icon: _liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          label: _fmt(_likeCount),
          color: _liked ? ext.likeRed : Colors.white,
          semanticLabel: _liked ? 'Unlike' : 'Like',
          onTap: _toggleLike,
        ),
      if (_canSave)
        btn(
          icon: _saved!.isSaved(widget.pictureId)
              ? Icons.bookmark_rounded
              : Icons.bookmark_border_rounded,
          color: ext.accentGold,
          busy: _saved!.isBusy(widget.pictureId),
          semanticLabel: _saved!.isSaved(widget.pictureId)
              ? 'Remove from saved'
              : 'Save',
          onTap: _toggleSave,
        ),
      if (widget.showDownload)
        btn(
          key: _downloadKey,
          icon: Icons.download_outlined,
          color: ext.accentGold,
          busy: _downloading,
          semanticLabel: 'Download to device',
          onTap: () => _handleAction(isDownload: true),
        ),
      // One share button. Where the photo is going — to someone in the app or
      // out of it — is asked in [ShareTargetSheet] rather than by two
      // near-identical glyphs sitting next to each other. With no [onSend]
      // there is no in-app route to choose, so it goes straight out.
      btn(
        key: _shareKey,
        icon: Icons.near_me_outlined,
        busy: _sharing,
        semanticLabel: 'Share photo',
        onTap: widget.onSend == null
            ? () => _handleAction(isDownload: false)
            : () => ShareTargetSheet.show(
                  context,
                  onInApp: widget.onSend!,
                  onExternal: () => _handleAction(isDownload: false),
                ),
      ),
      if (widget.showComment)
        // `_commentCount` is seeded once from the caller and never moves
        // again, so posting a comment left this label a step behind for as
        // long as the sheet's parent stayed alive. It is the fallback now, not
        // the source.
        LiveCommentCount(
          targetId: widget.pictureId,
          fallback: _commentCount,
          builder: (context, liveCount) => btn(
            icon: Icons.mode_comment_outlined,
            label: _fmt(liveCount),
            semanticLabel: 'Comments',
            onTap: () => PhotoCommentSheet.show(
              context,
              pictureId: widget.pictureId,
              imageUrl: widget.imageUrl,
            ),
          ),
        ),
    ];

    if (widget.axis == Axis.vertical) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: btns
            .map((b) =>
                Padding(padding: EdgeInsets.only(bottom: 14.h), child: b))
            .toList(),
      );
    }

    // Horizontal mode: each button gets equal space via Expanded so the row
    // fills its parent width evenly regardless of button count.
    final divider = Container(
      width: 1,
      height: 32.h,
      color: Colors.white24,
    );
    final withDividers = <Widget>[];
    for (var i = 0; i < btns.length; i++) {
      withDividers.add(Expanded(child: Center(child: btns[i])));
      if (i < btns.length - 1) withDividers.add(divider);
    }
    return Row(
      mainAxisSize: MainAxisSize.max,
      children: withDividers,
    );
  }
}

// ── Classy full-screen processing overlay ─────────────────────────────────────

class _ProcessingOverlay extends StatefulWidget {
  const _ProcessingOverlay({required this.label});
  final String label;

  @override
  State<_ProcessingOverlay> createState() => _ProcessingOverlayState();
}

class _ProcessingOverlayState extends State<_ProcessingOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  )..forward();

  late final Animation<double> _fade =
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
  late final Animation<double> _scale = Tween<double>(begin: 0.88, end: 1.0)
      .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: Material(
        color: Colors.black.withValues(alpha: 0.72),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Center(
            child: ScaleTransition(
              scale: _scale,
              child: Container(
                padding: EdgeInsets.symmetric(
                    horizontal: 36.w, vertical: AppSpacing.xxxl.h),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A).withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(AppRadius.xxl.r),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 40,
                      spreadRadius: 8,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Animated ring
                    SizedBox(
                      width: 56.w,
                      height: 56.w,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 56.w,
                            height: 56.w,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white.withValues(alpha: 0.15),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 56.w,
                            height: 56.w,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFF1D9E75),
                              ),
                            ),
                          ),
                          Icon(
                            Icons.auto_awesome_rounded,
                            color: const Color(0xFF1D9E75),
                            size: 22.sp,
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: AppSpacing.xl.h),

                    Text(
                      widget.label,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),

                    SizedBox(height: 6.h),

                    Text(
                      'Adding creator branding',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 11.sp,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
