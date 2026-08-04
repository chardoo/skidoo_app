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
import 'package:skidoo_app/features/photographers/data/repositories/reviews_repository.dart';
import 'package:skidoo_app/features/photographers/presentation/pages/reviews_pages.dart';
import 'package:skidoo_app/models/photos/Photo.dart';

/// One photographer who answered a request: who they are, what they have shot,
/// and what people say about them.
///
/// The button is the point of the screen. Choosing here closes the request to
/// everyone else, so the confirmation says so in as many words before it
/// happens.
class RequestPhotographerPage extends StatefulWidget {
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

  @override
  State<RequestPhotographerPage> createState() =>
      _RequestPhotographerPageState();
}

class _RequestPhotographerPageState extends State<RequestPhotographerPage> {
  final _reviewsRepo = ReviewsRepository();

  int _tab = 0;
  ReviewPage? _reviews;
  bool _loadingReviews = false;

  /// The photographer's own total. Known from the interest row before the
  /// reviews are fetched, so the tab does not count up from nothing.
  int get _reviewCount => _reviews?.count ?? _p.ratingCount;

  RequestInterest get _p => widget.photographer;

  String get _displayName => (_p.name?.trim().isNotEmpty ?? false)
      ? _p.name!.trim()
      : 'Photographer';

  /// "Accra, Ghana | 1.2K followers" — what the design puts under the name,
  /// with the location dropped rather than shown empty. The rating is not in
  /// here: it sits in its own pill to the right.
  String get _meta {
    final parts = <String>[
      if (_p.location?.isNotEmpty ?? false) _p.location!,
      '${compactCount(_p.followerCount)} followers',
    ];
    return parts.join('  |  ');
  }

  /// Only fetched when the Reviews tab is first opened — most requesters look
  /// at the pictures and decide.
  Future<void> _loadReviews() async {
    if (_reviews != null || _loadingReviews) return;
    setState(() => _loadingReviews = true);
    try {
      final page = await _reviewsRepo.list(_p.id, limit: 2);
      if (mounted) setState(() => _reviews = page);
    } catch (e) {
      debugPrint('[RequestPhotographer] reviews ERROR: $e');
      if (mounted) setState(() => _reviews = ReviewPage.empty);
    } finally {
      if (mounted) setState(() => _loadingReviews = false);
    }
  }

  Future<void> _confirm(AppThemeExtension ext) async {
    final agreed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ConfirmSheet(
        name: _displayName,
        requestTitle: widget.requestTitle,
        ext: ext,
      ),
    );
    if (agreed != true) return;
    final ok = await widget.onSelect();
    if (ok && mounted) Navigator.of(context).pop(true);
  }

  void _openPortfolio(int index) {
    if (_p.portfolio.isEmpty) return;
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => FoundPhotoViewerPage(
        photos: [
          for (final media in _p.portfolio)
            Photo(media.id, _displayName, '', media.url, _p.id, 0, '', null,
                true,
                width: media.width,
                height: media.height,
                photographerName: _displayName,
                photographerAvatarUrl: _p.profileUrl ?? ''),
        ],
        initialIndex: index,
      ),
    ));
  }

  void _openAllReviews() {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => PhotographerReviewsPage(
        photographerId: _p.id,
        initialCount: _reviewCount,
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
        padding: EdgeInsets.only(bottom: AppSpacing.xxl.h),
        children: [
          _Banner(photographer: _p, name: _displayName, ext: ext),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: AppSpacing.md.h),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  _displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: ext.greetingColor,
                                    fontSize: 18.sp,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ),
                              if (_p.verified) ...[
                                SizedBox(width: 4.w),
                                Icon(Icons.verified_rounded,
                                    size: 16.r, color: ext.infoBlue),
                              ],
                            ],
                          ),
                          SizedBox(height: 4.h),
                          Row(
                            children: [
                              if (_p.location?.isNotEmpty ?? false) ...[
                                Icon(Icons.place_outlined,
                                    size: 13.r, color: ext.searchHintColor),
                                SizedBox(width: 3.w),
                              ],
                              Flexible(
                                child: Text(
                                  _meta,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: ext.searchHintColor,
                                    fontSize: 12.sp,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // The rating gets its own pill rather than a place in the
                    // line above: it is the one number on this screen someone
                    // scans for. No pill at all until somebody has rated them —
                    // an empty one reads as a bad score.
                    if (_p.rating != null)
                      Container(
                        margin: EdgeInsets.only(left: AppSpacing.sm.w),
                        padding: EdgeInsets.symmetric(
                          horizontal: 10.w, vertical: 5.h,
                        ),
                        decoration: BoxDecoration(
                          color: ext.accentGold.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppRadius.sm.r),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star_rounded,
                                size: 14.r, color: ext.accentGold),
                            SizedBox(width: 3.w),
                            Text(
                              _p.rating!.toStringAsFixed(1),
                              style: TextStyle(
                                color: ext.accentGold,
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),

                if (_p.specialties.isNotEmpty ||
                    (_p.bio?.isNotEmpty ?? false)) ...[
                  SizedBox(height: AppSpacing.xl.h),
                  const AppSectionLabel('Specialties & bio'),
                  SizedBox(height: AppSpacing.sm.h),
                  if (_p.specialties.isNotEmpty)
                    Wrap(
                      spacing: AppSpacing.sm.w,
                      runSpacing: AppSpacing.xs.h,
                      children: [
                        for (final specialty in _p.specialties)
                          _Chip(label: specialty, ext: ext),
                      ],
                    ),
                  if (_p.bio?.isNotEmpty ?? false) ...[
                    SizedBox(height: AppSpacing.sm.h),
                    Text(
                      _p.bio!,
                      style: TextStyle(
                        color: ext.searchHintColor, fontSize: 13.sp, height: 1.45,
                      ),
                    ),
                  ],
                ],

                SizedBox(height: AppSpacing.xl.h),
                _Tabs(
                  ext: ext,
                  index: _tab,
                  labels: [
                    'Portfolio',
                    // The count is in the tab label, so the weight of the
                    // reviews is visible before anyone opens them.
                    if (_reviewCount > 0) 'Reviews ($_reviewCount)' else 'Reviews',
                  ],
                  onChanged: (i) {
                    setState(() => _tab = i);
                    if (i == 1) _loadReviews();
                  },
                ),
                SizedBox(height: AppSpacing.md.h),
              ],
            ),
          ),

          if (_tab == 0)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg.w),
              child: _p.portfolio.isEmpty
                  ? _Empty(text: 'No portfolio yet.', ext: ext)
                  : _Portfolio(
                      media: _p.portfolio,
                      ext: ext,
                      onTap: _openPortfolio,
                    ),
            )
          else
            Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg.w),
              child: _ReviewsPreview(
                page: _reviews,
                loading: _loadingReviews,
                ext: ext,
                onViewAll: _openAllReviews,
              ),
            ),

          if (_p.message?.isNotEmpty ?? false) ...[
            SizedBox(height: AppSpacing.xl.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppSectionLabel('Additional message'),
                  SizedBox(height: AppSpacing.sm.h),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(AppSpacing.md.w),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.md.r),
                      border: Border.all(
                        color: ext.searchHintColor.withValues(alpha: 0.25),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      _p.message!,
                      style: TextStyle(
                        color: ext.searchHintColor,
                        fontSize: 13.sp,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          SizedBox(height: AppSpacing.xxl.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg.w),
            child: SizedBox(
              height: 48.h,
              child: ElevatedButton(
                onPressed:
                    widget.alreadySelected ? null : () => _confirm(ext),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ext.accentGold,
                  disabledBackgroundColor: ext.accentGold.withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999.r),
                  ),
                ),
                child: Text(
                  widget.alreadySelected ? 'Selected' : 'Select photographer',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                  ),
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

/// The studio shot across the top with the avatar sitting on it. Falls back to
/// a plain tinted band rather than a broken image when there is no banner.
class _Banner extends StatelessWidget {
  const _Banner({
    required this.photographer,
    required this.name,
    required this.ext,
  });

  final RequestInterest photographer;
  final String name;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    final banner = photographer.studioImageUrl;
    return SizedBox(
      height: 150.h,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: (banner?.isNotEmpty ?? false)
                ? Image.network(
                    banner!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        ColoredBox(color: ext.avatarBackground),
                  )
                : ColoredBox(color: ext.accentGold.withValues(alpha: 0.15)),
          ),
          Positioned(
            left: AppSpacing.lg.w,
            bottom: -22.r,
            child: Container(
              padding: EdgeInsets.all(3.r),
              decoration: BoxDecoration(
                color: ext.homeBackground,
                shape: BoxShape.circle,
              ),
              child: CircleAvatar(
                radius: 30.r,
                backgroundColor: ext.avatarBackground,
                backgroundImage:
                    (photographer.profileUrl?.isNotEmpty ?? false)
                        ? NetworkImage(photographer.profileUrl!)
                        : null,
                child: (photographer.profileUrl?.isNotEmpty ?? false)
                    ? null
                    : Text(
                        name[0].toUpperCase(),
                        style: TextStyle(
                          color: ext.avatarForeground, fontSize: 20.sp,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({
    required this.ext,
    required this.index,
    required this.labels,
    required this.onChanged,
  });

  final AppThemeExtension ext;
  final int index;
  final List<String> labels;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(i),
              child: Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.sm.h),
                child: Column(
                  children: [
                    Text(
                      labels[i],
                      style: TextStyle(
                        color: i == index
                            ? ext.greetingColor
                            : ext.searchHintColor,
                        fontSize: 14.sp,
                        fontWeight:
                            i == index ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: AppSpacing.sm.h),
                    Container(
                      height: 2.h,
                      color: i == index
                          ? ext.accentGold
                          : ext.searchHintColor.withValues(alpha: 0.15),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.ext});

  final String label;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.symmetric(horizontal: 11.w, vertical: 5.h),
        decoration: BoxDecoration(
          color: ext.accentGold.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999.r),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: ext.accentGold,
            fontSize: 11.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
}

class _Empty extends StatelessWidget {
  const _Empty({required this.text, required this.ext});

  final String text;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xl.h),
        child: Center(
          child: Text(
            text,
            style: TextStyle(color: ext.searchHintColor, fontSize: 13.sp),
          ),
        ),
      );
}

/// The first couple of reviews with a way through to the rest — the profile is
/// for deciding, the reviews page is for reading.
class _ReviewsPreview extends StatelessWidget {
  const _ReviewsPreview({
    required this.page,
    required this.loading,
    required this.ext,
    required this.onViewAll,
  });

  final ReviewPage? page;
  final bool loading;
  final AppThemeExtension ext;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    if (loading && page == null) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xl.h),
        child: Center(
          child: SizedBox(
            width: 22.r,
            height: 22.r,
            child: CircularProgressIndicator(
              strokeWidth: 2, color: ext.accentGold,
            ),
          ),
        ),
      );
    }
    final data = page;
    if (data == null || data.reviews.isEmpty) {
      return _Empty(text: 'No reviews yet.', ext: ext);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final review in data.reviews.take(2))
          Padding(
            padding: EdgeInsets.only(bottom: AppSpacing.sm.h),
            child: ReviewCard(review: review, ext: ext),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: onViewAll,
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
            child: Text(
              'View all ${data.count} reviews  →',
              style: TextStyle(
                color: ext.accentGold,
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The portfolio as a swipeable card with a counter, the way the design shows
/// it — one big photo at a time rather than a grid of thumbnails.
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
          child: Stack(
            children: [
              PageView.builder(
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
              // "1 of 16" — how much more there is to swipe through, which the
              // dots stop telling you past a handful.
              Positioned(
                left: AppSpacing.sm.w,
                bottom: AppSpacing.sm.h,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(999.r),
                  ),
                  child: Text(
                    '${_page + 1} of ${widget.media.length}',
                    style: TextStyle(color: Colors.white, fontSize: 11.sp),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (widget.media.length > 1) ...[
          SizedBox(height: AppSpacing.sm.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < widget.media.length && i < 8; i++)
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
