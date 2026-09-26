import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/deep_links/deep_link.dart';
import 'package:jperg_app/core/navigation/external_link.dart';
import 'package:jperg_app/core/purchase/paid_photo_watermark.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/widgets/jperg_image.dart';

/// What a message is *about*, when it is about something the app can open.
///
/// Sharing an event into a chat used to send `event.pictures.first` and
/// nothing else: the recipient got a photograph with no album name, no count,
/// and no way to reach the event it came from — tapping it opened the
/// full-screen image viewer, which is the one place the event is not.
///
/// So a shared event travels as a picture *and* a body: the album's name on
/// one line, its link on the next. This reads that back. The link is taken
/// from the last line because that is where the sheet puts it, and anything
/// above the title is what the sender typed.
class SharedLinkContent {
  const SharedLinkContent({
    required this.url,
    required this.link,
    required this.title,
    this.leadingText,
  });

  /// The address as written, handed to [ExternalLink.open] on tap so a shared
  /// card and a link somebody typed behave identically.
  final String url;

  /// What [url] resolves to — used for the label, not for navigating.
  final DeepLink link;

  /// The line above the link: the album's name.
  final String title;

  /// Anything the sender typed above that.
  final String? leadingText;

  /// The body a share sends: the title, then the link, in that order.
  ///
  /// The counterpart to [parse], and here so the two cannot drift — the share
  /// sheet writes this and the bubble reads it, and they are in different
  /// features. Returns null when there is no link to carry, which is what a
  /// shared photograph is.
  static String? compose({required String title, required String url}) {
    final trimmedUrl = url.trim();
    if (trimmedUrl.isEmpty) return null;
    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) return trimmedUrl;
    return '$trimmedTitle\n$trimmedUrl';
  }

  /// Null when this message is not about anything openable.
  static SharedLinkContent? parse(String content) {
    final lines = content.trimRight().split('\n');
    if (lines.length < 2) return null;

    final url = lines.last.trim();
    final uri = Uri.tryParse(url);
    // Both questions, in this order — see [ExternalLink.open]. On a link
    // somebody else wrote, the path alone is not evidence of anything:
    // instagram.com/p/{id} is our photo path and flickr.com/photos/{u} is our
    // my-photos path.
    if (uri == null || !ExternalLink.isOurs(uri)) return null;
    final link = parseDeepLink(uri);
    if (link == null) return null;

    final title = lines[lines.length - 2].trim();
    if (title.isEmpty) return null;

    final rest = lines.sublist(0, lines.length - 2).join('\n').trim();
    return SharedLinkContent(
      url: url,
      link: link,
      title: title,
      leadingText: rest.isEmpty ? null : rest,
    );
  }

  /// What the card calls the thing under its title.
  String get kindLabel => switch (link.kind) {
        DeepLinkKind.event => 'Event',
        DeepLinkKind.picture => 'Photo',
        DeepLinkKind.photographer => 'Photographer',
        DeepLinkKind.request => 'Request',
        _ => 'Open in Jperg',
      };
}

/// A shared thing, drawn as a preview of itself: a cover, its name, and what
/// it is.
///
/// **A preview, not the asset.** The band is a fixed shape and the image is
/// cropped into it — this is a reference to a photograph or an album, the way
/// a link card is a reference to a page, and a full-height copy of the picture
/// sitting in the thread is the thing it replaces. [JpergImage] fetches at the
/// width it is drawn at, so what crosses the network is a thumbnail.
///
/// **The whole card opens the real thing.** It draws its own cover rather than
/// wrapping the bubble's media, and that is deliberate: the bubble's image
/// carries a tap of its own that opens a full-screen zoom viewer, and nested
/// inside a card the deeper gesture wins — so the card would have looked like
/// an event and behaved like a photograph.
class SharedLinkCard extends StatelessWidget {
  const SharedLinkCard({
    super.key,
    required this.shared,
    required this.imageUrl,
    required this.textColor,
    this.paidPreview = false,
  });

  /// Wide enough to read as a preview strip rather than as the photograph.
  static const double coverAspect = 16 / 9;

  final SharedLinkContent shared;
  final String imageUrl;

  /// The bubble's own foreground — the card sits inside a bubble that is
  /// tinted differently for the sender and the recipient, and a fixed colour
  /// here would disappear into one of them.
  final Color textColor;

  /// Whether the cover is a photo that costs money and has not been bought.
  /// The mark belongs on every copy, and a preview is a copy.
  final bool paidPreview;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${shared.kindLabel}: ${shared.title}',
      child: GestureDetector(
        // Straight to [ExternalLink.open], which asks whether the link is ours
        // and routes it through [DeepLinkService.follow] if it is — the same
        // path an address typed into a message takes, so there is one answer
        // to "what does tapping this do".
        onTap: () => ExternalLink.open(context, shared.url),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(
              aspectRatio: coverAspect,
              child: PaidPhotoWatermark(
                price: paidPreview ? 1 : 0,
                isPurchased: false,
                child: JpergImage(
                  imageUrl: imageUrl,
                  // Cropped into the band on purpose: every card is the same
                  // shape, so a thread of them reads as a list rather than as
                  // a column of differently-sized photographs.
                  fit: BoxFit.cover,
                  semanticLabel: shared.title,
                  placeholder: (_, __) => const JpergImagePlaceholder(),
                  errorWidget: (_, __, ___) => const JpergImagePlaceholder(),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                  AppSpacing.md.w, AppSpacing.sm.h, AppSpacing.md.w, AppSpacing.xs.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    shared.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        shared.kindLabel,
                        style: TextStyle(
                          color: textColor.withValues(alpha: 0.65),
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(width: 3.w),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 16.sp,
                        color: textColor.withValues(alpha: 0.65),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
