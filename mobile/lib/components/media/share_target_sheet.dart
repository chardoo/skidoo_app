import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/theme/app_icons.dart';
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/theme/app_typography.dart';
import 'package:jperg_app/core/widgets/jperg_image.dart';

/// Where a photo is going, asked before the OS is involved.
///
/// ## Why this sheet exists at all
///
/// The rails used to carry two glyphs side by side — a paper plane for the
/// in-app DM picker and the OS share arrow. Two buttons for one intention, and
/// the difference between them carried entirely by two similar-looking icons:
/// from the outside, "send" and "share" name the same act.
///
/// ## Why it looks like this
///
/// It showed two circles labelled "In app" and "External", which had two
/// faults. **"External" was one word for two different acts** — a link goes
/// instantly and anybody can open it, while saving fetches the rendered file
/// and takes a moment — and the sheet charged the reader with guessing which
/// they were about to get. And **nothing said what was being shared**, which on
/// a feed of full-bleed photographs is a real question: the sheet opens over
/// the picture it is about and then hides it.
///
/// So: the photograph itself at the top, and one row per destination naming
/// what actually happens. The preview is the part that makes this read as
/// considered rather than as a menu — every share sheet worth copying shows
/// you what you are about to send, and it doubles as the confirmation that you
/// are sending the right one.
///
/// The accent is spent on the in-app row alone. Three rows in the same weight
/// is a list; one lit row and two quiet ones is a recommendation, and sending
/// inside the app is the one that keeps somebody here.
///
/// Every callback fires *after* this sheet has closed. Each route opens
/// something of its own — the DM picker, the OS sheet, a progress overlay —
/// and stacking one on another leaves the reader two pops from where they
/// started.
class ShareTargetSheet extends StatelessWidget {
  const ShareTargetSheet({
    super.key,
    required this.onInApp,
    required this.onExternal,
    this.onDownload,
    this.title = 'Share this photo',
    this.previewUrl,
    this.previewTitle,
    this.previewSubtitle,
  });

  /// Send it to somebody on jperg.
  final VoidCallback onInApp;

  /// The link, out through the OS share sheet.
  final VoidCallback onExternal;

  /// Save the rendered file to the device. Omitted where the surface has no
  /// download — the row is left out rather than shown disabled, because a
  /// greyed row invites a tap that will never work.
  final VoidCallback? onDownload;

  final String title;

  /// The photograph being shared. Without it the header collapses to the
  /// title alone rather than leaving a hole where a picture should be.
  final String? previewUrl;

  /// What it is — an event name — and who took it.
  final String? previewTitle;
  final String? previewSubtitle;

  static Future<void> show(
    BuildContext context, {
    required VoidCallback onInApp,
    required VoidCallback onExternal,
    VoidCallback? onDownload,
    String title = 'Share this photo',
    String? previewUrl,
    String? previewTitle,
    String? previewSubtitle,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => ShareTargetSheet(
        onInApp: onInApp,
        onExternal: onExternal,
        onDownload: onDownload,
        title: title,
        previewUrl: previewUrl,
        previewTitle: previewTitle,
        previewSubtitle: previewSubtitle,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    void close(VoidCallback then) {
      Navigator.of(context).pop();
      then();
    }

    return Container(
      decoration: BoxDecoration(
        color: ext.homeBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      // The rows' ink needs a Material to paint on, and this decorated
      // Container would otherwise swallow it.
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          top: false,
          // Scrollable, though it rarely scrolls.
          //
          // A bottom sheet is capped at a fraction of the screen, and this one
          // is three rows taller than the two circles it replaced. At an
          // ordinary text size it fits with room to spare; at a large
          // accessibility scale the rows grow and the last one would be cut
          // off — which on this sheet means the save route simply vanishing.
          // `shrinkWrap` keeps it the height of its contents the rest of the
          // time, so nothing moves in the common case.
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: EdgeInsets.only(
                    top: AppSpacing.md.h,
                    bottom: AppSpacing.lg.h,
                  ),
                  width: 36.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: ext.searchHintColor.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
                _Preview(
                  ext: ext,
                  url: previewUrl,
                  title: previewTitle,
                  subtitle: previewSubtitle,
                  fallbackTitle: title,
                ),
                SizedBox(height: AppSpacing.lg.h),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: ext.searchHintColor.withValues(alpha: 0.12),
                ),
                SizedBox(height: AppSpacing.sm.h),
                _Destination(
                  ext: ext,
                  icon: Icons.near_me_rounded,
                  title: 'Send in jperg',
                  detail: 'To someone you are chatting with',
                  semanticLabel: 'Send to someone in the app',
                  featured: true,
                  onTap: () => close(onInApp),
                ),
                _Destination(
                  ext: ext,
                  icon: AppIcons.systemShare,
                  // Design's own mark rather than the platform's share glyph.
                  //
                  // [AppIcons.systemShare] draws the OS's own symbol so a bare
                  // button can say which sheet is coming — on Android, three
                  // connected dots. That argument does not apply to a row that
                  // says "Share a link" in words and explains itself on the
                  // line below: nothing here is left to the glyph, and the
                  // dots were the one mark on this sheet from outside the set.
                  assetIcon: AppIcons.externalLink,
                  title: 'Share a link',
                  // Says the two things somebody weighs before sending one: it
                  // is instant, and it works for anyone.
                  detail: 'Anyone with the link can open it',
                  semanticLabel: 'Share a link outside the app',
                  onTap: () => close(onExternal),
                ),
                if (onDownload != null)
                  _Destination(
                    ext: ext,
                    icon: Icons.download_rounded,
                    title: 'Save the photo',
                    // The wait and the watermark, said before the tap rather
                    // than discovered after it — both are surprises otherwise.
                    detail: 'Watermarked, to your device',
                    semanticLabel: 'Save the photo to this device',
                    onTap: () => close(onDownload!),
                  ),
                SizedBox(height: AppSpacing.md.h),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// What is being shared, shown rather than described.
///
/// The thing that makes this a share sheet and not a menu. It sits over the
/// photograph it is about — which it covers — so the picture has to come back
/// somewhere, and it doubles as the check that this is the right one.
class _Preview extends StatelessWidget {
  const _Preview({
    required this.ext,
    required this.url,
    required this.title,
    required this.subtitle,
    required this.fallbackTitle,
  });

  final AppThemeExtension ext;
  final String? url;
  final String? title;
  final String? subtitle;

  /// Shown when the caller named no event — "Share this photo" is still a
  /// truthful heading, and a sheet with no words at all is worse.
  final String fallbackTitle;

  @override
  Widget build(BuildContext context) {
    final heading =
        (title?.trim().isNotEmpty ?? false) ? title! : fallbackTitle;
    final hasImage = url?.isNotEmpty ?? false;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl.w),
      child: Row(
        children: [
          if (hasImage) ...[
            // A generous corner rather than a circle: this is a photograph,
            // and a circle crops the subject out of most of them.
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md.r),
              child: SizedBox(
                width: 56.w,
                height: 56.w,
                child: JpergImage(
                  imageUrl: url!,
                  fit: BoxFit.cover,
                  logicalWidth: 56,
                  placeholder: (_, __) =>
                      ColoredBox(color: ext.searchFieldFill),
                  errorWidget: (_, __, ___) => ColoredBox(
                    color: ext.searchFieldFill,
                    child: Icon(
                      Icons.image_outlined,
                      color: ext.searchHintColor,
                      size: 20.sp,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: AppSpacing.md.w),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Syne 16/bold is [AppTypography.title] exactly — the same
                // numbers this spelled out by hand. Through the tier so the
                // sheet's heading moves when the scale does.
                Text(
                  heading,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.title.copyWith(color: ext.greetingColor),
                ),
                if (subtitle?.trim().isNotEmpty ?? false) ...[
                  SizedBox(height: 2.h),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        AppTypography.body.copyWith(color: ext.searchHintColor),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One destination: what it is, and what happens if you pick it.
///
/// A row rather than a circle in a grid. Circles were what this sheet had, and
/// they left no room for the second line — which is where the whole difference
/// between these options lives: one sends a link that opens anywhere, one
/// fetches a watermarked file and takes a moment. A grid of glyphs makes the
/// reader guess that; a row can simply say it.
class _Destination extends StatelessWidget {
  const _Destination({
    required this.ext,
    required this.icon,
    required this.title,
    required this.detail,
    required this.semanticLabel,
    required this.onTap,
    this.assetIcon,
    this.featured = false,
  });

  final AppThemeExtension ext;
  final IconData icon;

  /// Design's artwork for this row, drawn instead of [icon] where the set has
  /// it — see [AppIcons]. The font glyph stays required as the fallback.
  final String? assetIcon;

  final String title;
  final String detail;

  /// The whole sentence, for a screen reader. The title alone is two words
  /// and the detail is the half that answers "and then what?".
  final String semanticLabel;

  final VoidCallback onTap;

  /// Draws the tile in the accent rather than the quiet fill. Exactly one row
  /// should carry it — a sheet where everything is emphasised is a sheet where
  /// nothing is.
  final bool featured;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      // One node carrying the whole sentence. Without this the row announces
      // three times — the label, the title, the detail — and the repetition
      // says less than the sentence did.
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.xl.w,
            vertical: AppSpacing.md.h,
          ),
          child: Row(
            children: [
              Container(
                width: 44.w,
                height: 44.w,
                decoration: BoxDecoration(
                  color: featured ? ext.accentGold : ext.searchFieldFill,
                  borderRadius: BorderRadius.circular(AppRadius.md.r),
                ),
                child: Center(
                  child: assetIcon != null
                      ? AppSvgIcon(
                          assetIcon!,
                          size: 20.sp,
                          color: featured ? Colors.white : ext.accentGold,
                        )
                      : Icon(
                          icon,
                          color: featured ? Colors.white : ext.accentGold,
                          size: 20.sp,
                        ),
                ),
              ),
              SizedBox(width: AppSpacing.md.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // The tiers, not hand-typed numbers. This row is the app's
                    // label-and-subtitle list row — see `SettingsRow`, which is
                    // 15/medium over 12 — and it was 15/**bold** over 14, a
                    // weight no 15 tier has and a detail line nearly the size
                    // of the title above it. That is the whole of why the sheet
                    // read as not quite ours.
                    Text(
                      title,
                      style: AppTypography.subtitle
                          .copyWith(color: ext.greetingColor),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption
                          .copyWith(color: ext.searchHintColor),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: ext.searchHintColor.withValues(alpha: 0.7),
                size: 20.sp,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
