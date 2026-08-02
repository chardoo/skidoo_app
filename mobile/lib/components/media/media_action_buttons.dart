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
import 'package:skidoo_app/components/media/media_rail_action.dart';
import 'package:skidoo_app/core/di/service_locator.dart';
import 'package:skidoo_app/core/utils/snackbar_utils.dart';
import 'package:skidoo_app/features/gallery/domain/usecases/get_overlay_usecase.dart';
import 'package:skidoo_app/features/photo_comments/data/picture_like_service.dart';
import 'package:skidoo_app/features/photo_comments/presentation/pages/photo_comment_sheet.dart';
import 'package:skidoo_app/core/theme/app_radius.dart';
import 'package:skidoo_app/core/theme/app_spacing.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';

/// Fetches the creator-branded overlay image and hands it to the native OS
/// share sheet. This is THE external-share routine for the whole app — every
/// card's "share to other apps" icon (discovery page, Home "Feed"/
/// "Following", the Found tab, the event-pictures feed) calls this exact
/// function so the branding behaviour never diverges between screens. Also
/// used internally by [MediaActionButtons]'s own Share/Download buttons.
///
/// [imageId] is the picture's `id` (matches the existing `imageId:` param
/// convention already used by every [MediaActionButtons] call site) — NOT
/// the separate `imageId` field on [EventPicture]/`Photo`, which is a
/// different value. Every call site must pass `pic.id` here, not
/// `pic.imageId`.
/// [isDownload] only changes the loading copy and the shared "text" (kept
/// null for downloads on web, matching the prior behaviour) — the actual
/// action is the same OS share/save sheet either way, since there is no
/// permission-free direct gallery-write API in this app.
Future<void> shareOverlayPhotoExternally(
  BuildContext context, {
  required String imageId,
  required String photographerName,
  String eventName = '',
  bool isDownload = false,
  Rect? shareOrigin,
}) async {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.transparent,
    builder: (_) => _ProcessingOverlay(
      label: isDownload ? 'Preparing download…' : 'Preparing to share…',
    ),
  );

  try {
    final result =
        await sl<GetOverlayImageUseCase>()(imageId, photographerName);
    if (!context.mounted) return;
    _dismissProcessingDialog(context);

    final safeId = imageId.replaceAll('/', '_').replaceAll('\\', '_');
    final filename = 'overlay_$safeId.${result.fileExtension}';
    final subject = eventName.isNotEmpty ? eventName : 'Photo';
    final text =
        eventName.isNotEmpty ? 'Check out $eventName!' : 'Check out this photo!';

    if (kIsWeb) {
      // ── Web: use in-memory XFile — no temp file writes ──────────────────
      final xFile = XFile.fromData(
        result.bytes,
        mimeType: result.contentType,
        name: filename,
      );
      try {
        await Share.shareXFiles(
          [xFile],
          subject: subject,
          text: isDownload ? null : text,
        );
      } catch (_) {
        // Browser doesn't support Web Share API Level 2 — fall back to
        // triggering a browser download via a data URI.
        final dataUri =
            'data:${result.contentType};base64,${base64Encode(result.bytes)}';
        await launchUrl(Uri.parse(dataUri), mode: LaunchMode.externalApplication);
      }
      return;
    }

    // ── Mobile: write temp file → OS share sheet ─────────────────────────
    final dir = await getTemporaryDirectory();
    final filePath = '${dir.path}/$filename';
    await File(filePath).writeAsBytes(result.bytes, flush: true);

    await Share.shareXFiles(
      [XFile(filePath, mimeType: result.contentType)],
      subject: subject,
      text: text,
      sharePositionOrigin: shareOrigin,
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
    this.showDownload = true,
    this.showComment = true,
    this.onLikeToggled,
    this.onSend,
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

  /// Whether to show the download button. Only shown in the gallery.
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

  final _downloadKey = GlobalKey();
  final _shareKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _liked = widget.initiallyLiked;
    _likeCount = widget.initialLikeCount;
    _commentCount = widget.initialCommentCount;
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
      if (widget.showDownload)
        btn(
          key: _downloadKey,
          icon: Icons.download_outlined,
          color: ext.accentGold,
          busy: _downloading,
          semanticLabel: 'Download',
          onTap: () => _handleAction(isDownload: true),
        ),
      btn(
        key: _shareKey,
        icon: Icons.ios_share_rounded,
        busy: _sharing,
        semanticLabel: 'Share photo',
        onTap: () => _handleAction(isDownload: false),
      ),
      if (widget.onSend != null)
        btn(
          icon: Icons.near_me_outlined,
          semanticLabel: 'Send',
          onTap: widget.onSend!,
        ),
      if (widget.showComment)
        btn(
          icon: Icons.mode_comment_outlined,
          label: _fmt(_commentCount),
          semanticLabel: 'Comments',
          onTap: () => PhotoCommentSheet.show(
            context,
            pictureId: widget.pictureId,
            imageUrl: widget.imageUrl,
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
