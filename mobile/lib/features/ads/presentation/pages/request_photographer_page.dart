import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/common/widgets/app_widgets.dart';
import 'package:skidoo_app/core/theme/app_radius.dart';
import 'package:skidoo_app/core/theme/app_spacing.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/core/utils/number_format.dart';
import 'package:skidoo_app/core/utils/web_wrap.dart';
import 'package:skidoo_app/features/ads/data/models/feed_request_model.dart';
import 'package:skidoo_app/features/ads/models/ad_media.dart';
import 'package:skidoo_app/features/gallery/presentation/found/pages/found_photo_viewer_page.dart';
import 'package:skidoo_app/models/photos/Photo.dart';

/// One photographer who answered a request: who they are, what they have shot,
/// and what they said.
///
/// The button is the point of the screen. Choosing here closes the request to
/// everyone else, so the confirmation says so in as many words before it
/// happens.
class RequestPhotographerPage extends StatelessWidget {
  const RequestPhotographerPage({
    super.key,
    required this.photographer,
    required this.requestTitle,
    required this.onSelect,
    this.alreadySelected = false,
  });

  final RequestInterest photographer;
  final String requestTitle;

  /// Runs after the confirmation, and pops with true when it succeeds.
  final Future<bool> Function() onSelect;
  final bool alreadySelected;

  String get _displayName =>
      (photographer.name?.trim().isNotEmpty ?? false)
          ? photographer.name!.trim()
          : 'Photographer';

  /// "Accra | 132 events | 1.2K followers | 4.7" — with the parts that have no
  /// answer left out rather than shown empty.
  String get _meta {
    final parts = <String>[
      if (photographer.location?.isNotEmpty ?? false) photographer.location!,
      if (photographer.eventCount > 0)
        '${compactCount(photographer.eventCount)} events',
      '${compactCount(photographer.followerCount)} followers',
    ];
    return parts.join(' | ');
  }

  Future<void> _confirm(BuildContext context, AppThemeExtension ext) async {
    final agreed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _ConfirmSheet(
        name: _displayName,
        requestTitle: requestTitle,
        ext: ext,
      ),
    );
    if (agreed != true) return;
    final ok = await onSelect();
    if (ok && context.mounted) Navigator.of(context).pop(true);
  }

  void _openPortfolio(BuildContext context, int index) {
    if (photographer.portfolio.isEmpty) return;
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => FoundPhotoViewerPage(
        photos: [
          for (final media in photographer.portfolio)
            Photo(media.id, _displayName, '', media.url, photographer.id, 0, '',
                null, true,
                width: media.width, height: media.height,
                photographerName: _displayName,
                photographerAvatarUrl: photographer.profileUrl ?? ''),
        ],
        initialIndex: index,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    final page = Scaffold(
      backgroundColor: ext.homeBackground,
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        leading: kIsWeb
            ? null
            : AppBackButton(onPressed: () => Navigator.of(context).pop()),
        title: Text(
          _displayName,
          style: TextStyle(
            color: ext.greetingColor,
            fontWeight: FontWeight.w700,
            fontSize: 16.sp,
          ),
        ),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg.w, 0, AppSpacing.lg.w, AppSpacing.xxl.h,
        ),
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22.r,
                backgroundColor: ext.avatarBackground,
                backgroundImage: (photographer.profileUrl?.isNotEmpty ?? false)
                    ? NetworkImage(photographer.profileUrl!)
                    : null,
                child: (photographer.profileUrl?.isNotEmpty ?? false)
                    ? null
                    : Text(
                        _displayName[0].toUpperCase(),
                        style: TextStyle(color: ext.avatarForeground),
                      ),
              ),
              SizedBox(width: AppSpacing.md.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _displayName,
                      style: TextStyle(
                        color: ext.greetingColor,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            _meta,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: ext.searchHintColor, fontSize: 12.sp,
                            ),
                          ),
                        ),
                        // No star at all until someone has rated them —
                        // an empty one reads as a bad score.
                        if (photographer.rating != null) ...[
                          SizedBox(width: 6.w),
                          Icon(Icons.star_rounded,
                              size: 13.r, color: ext.accentGold),
                          Text(
                            photographer.rating!.toStringAsFixed(1),
                            style: TextStyle(
                              color: ext.searchHintColor, fontSize: 12.sp,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (photographer.bio?.isNotEmpty ?? false) ...[
            SizedBox(height: AppSpacing.lg.h),
            Text(
              photographer.bio!,
              style: TextStyle(
                color: ext.searchHintColor, fontSize: 13.sp, height: 1.45,
              ),
            ),
          ],
          if (photographer.portfolio.isNotEmpty) ...[
            SizedBox(height: AppSpacing.xl.h),
            _SectionLabel(text: 'Portfolio', ext: ext),
            SizedBox(height: AppSpacing.sm.h),
            _Portfolio(
              media: photographer.portfolio,
              ext: ext,
              onTap: (i) => _openPortfolio(context, i),
            ),
          ],
          if (photographer.message?.isNotEmpty ?? false) ...[
            SizedBox(height: AppSpacing.xl.h),
            _SectionLabel(text: 'Additional Message', ext: ext),
            SizedBox(height: AppSpacing.sm.h),
            Text(
              photographer.message!,
              style: TextStyle(
                color: ext.searchHintColor, fontSize: 13.sp, height: 1.45,
              ),
            ),
          ],
          SizedBox(height: AppSpacing.xxl.h),
          SizedBox(
            height: 48.h,
            child: ElevatedButton(
              onPressed:
                  alreadySelected ? null : () => _confirm(context, ext),
              style: ElevatedButton.styleFrom(
                backgroundColor: ext.accentGold,
                disabledBackgroundColor: ext.accentGold.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999.r),
                ),
              ),
              child: Text(
                alreadySelected ? 'Selected' : 'Select photographer',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          SizedBox(height: AppSpacing.md.h),
          Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'View more profiles',
                style: TextStyle(color: ext.searchHintColor, fontSize: 13.sp),
              ),
            ),
          ),
        ],
      ),
    );

    return webWrap(page, backgroundColor: ext.homeBackground);
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text, required this.ext});

  final String text;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
          color: ext.greetingColor,
          fontSize: 13.sp,
          fontWeight: FontWeight.w700,
        ),
      );
}

/// The portfolio as a swipeable card with dots, the way the design shows it —
/// one big photo at a time rather than a grid of thumbnails.
class _Portfolio extends StatefulWidget {
  const _Portfolio({
    required this.media,
    required this.ext,
    required this.onTap,
  });

  final List<AdMedia> media;
  final AppThemeExtension ext;
  final void Function(int) onTap;

  @override
  State<_Portfolio> createState() => _PortfolioState();
}

class _PortfolioState extends State<_Portfolio> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 260.h,
          child: PageView.builder(
            controller: _controller,
            onPageChanged: (i) => setState(() => _page = i),
            itemCount: widget.media.length,
            itemBuilder: (_, i) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => widget.onTap(i),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.md.r),
                child: ColoredBox(
                  color: widget.ext.avatarBackground,
                  child: Image.network(
                    widget.media[i].url,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.broken_image_outlined,
                      color: widget.ext.searchHintColor,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (widget.media.length > 1) ...[
          SizedBox(height: AppSpacing.sm.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < widget.media.length; i++)
                Container(
                  width: 6.r,
                  height: 6.r,
                  margin: EdgeInsets.symmetric(horizontal: 3.w),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i == _page
                        ? widget.ext.accentGold
                        : widget.ext.searchHintColor.withValues(alpha: 0.35),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ConfirmSheet extends StatelessWidget {
  const _ConfirmSheet({
    required this.name,
    required this.requestTitle,
    required this.ext,
  });

  final String name;
  final String requestTitle;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ext.homeBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xl.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36.w,
                height: 4.h,
                margin: EdgeInsets.only(bottom: AppSpacing.lg.h),
                decoration: BoxDecoration(
                  color: ext.searchHintColor.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
              Text(
                'Confirm photographer?',
                style: TextStyle(
                  color: ext.greetingColor,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: AppSpacing.sm.h),
              Text(
                // Said plainly, because it is the consequence people would
                // otherwise discover afterwards.
                'Confirm $name for $requestTitle? '
                "Others won't be able to apply after this.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: ext.searchHintColor, fontSize: 13.sp, height: 1.4,
                ),
              ),
              SizedBox(height: AppSpacing.xl.h),
              SizedBox(
                width: double.infinity,
                height: 46.h,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ext.accentGold,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999.r),
                    ),
                  ),
                  child: Text(
                    'Confirm',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: ext.searchHintColor, fontSize: 14.sp),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
