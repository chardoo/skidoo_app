import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/common/widgets/app_widgets.dart';
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/utils/snackbar_utils.dart';
import 'package:jperg_app/core/utils/web_wrap.dart';
import 'package:jperg_app/features/photographers/data/repositories/reviews_repository.dart';
import 'package:jperg_app/features/photographers/presentation/widgets/photographer_meta.dart';

/// Everything a client says about a photographer, and the screen where they
/// say it.
///
/// Kept together because they are two halves of one thing: the list is only
/// worth reading because leaving one is this easy, and leaving one is only
/// worth doing because the list is read.

// ── Reading them ────────────────────────────────────────────────────────────
class PhotographerReviewsPage extends StatefulWidget {
  const PhotographerReviewsPage({
    super.key,
    required this.photographerId,
    this.initialCount = 0,
  });

  final String photographerId;

  /// Shown in the title until the first page lands, so the header does not
  /// count up from zero in front of the reader.
  final int initialCount;

  @override
  State<PhotographerReviewsPage> createState() =>
      _PhotographerReviewsPageState();
}

class _PhotographerReviewsPageState extends State<PhotographerReviewsPage> {
  final _repo = ReviewsRepository();

  ReviewPage _page = ReviewPage.empty;
  int? _stars;
  String _sort = 'recent';
  bool _loading = true;
  String? _errorMessage;

  static const _sortLabels = {
    'recent': 'Most Recent',
    'oldest': 'Oldest',
    'highest': 'Highest Rated',
    'lowest': 'Lowest Rated',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final page = await _repo.list(
        widget.photographerId, stars: _stars, sort: _sort,
      );
      if (mounted) setState(() => _page = page);
    } catch (e) {
      debugPrint('[Reviews] load ERROR: $e');
      if (mounted) setState(() => _errorMessage = 'Could not load reviews.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final count = _page.count > 0 ? _page.count : widget.initialCount;

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
          'Reviews ($count)',
          style: TextStyle(
            color: ext.greetingColor,
            fontWeight: FontWeight.w700,
            fontSize: 16.sp,
          ),
        ),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 44.h,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.md.w),
              children: [
                _Chip(
                  label: 'All',
                  selected: _stars == null,
                  ext: ext,
                  onTap: () {
                    setState(() => _stars = null);
                    _load();
                  },
                ),
                // Only the ratings that exist. A chip for a star nobody gave
                // is a chip that leads to an empty screen.
                for (final star in [5, 4, 3, 2, 1])
                  if ((_page.breakdown[star] ?? 0) > 0)
                    _Chip(
                      label: '$star Stars',
                      selected: _stars == star,
                      ext: ext,
                      onTap: () {
                        setState(() => _stars = star);
                        _load();
                      },
                    ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.lg.w, vertical: AppSpacing.xs.h,
            ),
            child: Row(
              children: [
                Text(
                  'Showing ${_page.filteredTotal} review'
                  '${_page.filteredTotal == 1 ? '' : 's'}',
                  style: TextStyle(
                    color: ext.greetingColor,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                DropdownButton<String>(
                  value: _sort,
                  underline: const SizedBox.shrink(),
                  isDense: true,
                  style: TextStyle(color: ext.greetingColor, fontSize: 13.sp),
                  dropdownColor: ext.cardSurface,
                  items: [
                    for (final entry in _sortLabels.entries)
                      DropdownMenuItem(
                        value: entry.key,
                        child: Text('Sort: ${entry.value}'),
                      ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _sort = value);
                    _load();
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(
                        child: Text(_errorMessage!,
                            style: TextStyle(color: ext.searchHintColor)),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        color: ext.accentGold,
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          padding: EdgeInsets.fromLTRB(
                            AppSpacing.md.w, 0, AppSpacing.md.w, AppSpacing.xxl.h,
                          ),
                          itemCount: _page.reviews.length,
                          itemBuilder: (_, i) =>
                              ReviewCard(review: _page.reviews[i], ext: ext),
                        ),
                      ),
          ),
        ],
      ),
    );
    return webWrap(page, backgroundColor: ext.homeBackground);
  }
}

/// One review, wherever it is shown — the two previews on a photographer's
/// profile and the full list are the same card.
class ReviewCard extends StatelessWidget {
  const ReviewCard({
    super.key,
    required this.review,
    required this.ext,
    this.bordered = true,
  });

  final Review review;
  final AppThemeExtension ext;
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    final name = (review.clientName?.trim().isNotEmpty ?? false)
        ? review.clientName!.trim()
        : 'Someone';

    return Container(
      margin: EdgeInsets.only(bottom: AppSpacing.sm.h),
      padding: EdgeInsets.all(AppSpacing.lg.w),
      decoration: BoxDecoration(
        color: bordered ? ext.cardSurface : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.md.r),
        border: bordered
            ? Border.all(
                color: ext.searchHintColor.withValues(alpha: 0.12), width: 0.8)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 16.r,
                backgroundColor: ext.avatarBackground,
                backgroundImage: (review.clientPhotoUrl?.isNotEmpty ?? false)
                    ? NetworkImage(review.clientPhotoUrl!)
                    : null,
                child: (review.clientPhotoUrl?.isNotEmpty ?? false)
                    ? null
                    : Text(name[0].toUpperCase(),
                        style: TextStyle(
                            color: ext.avatarForeground, fontSize: 12.sp)),
              ),
              SizedBox(width: AppSpacing.sm.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        color: ext.greetingColor,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Stars(rating: review.rating, ext: ext, size: 13),
                  ],
                ),
              ),
              Text(
                review.age,
                style: TextStyle(color: ext.searchHintColor, fontSize: 11.sp),
              ),
            ],
          ),
          if (review.comment?.isNotEmpty ?? false) ...[
            SizedBox(height: AppSpacing.sm.h),
            Text(
              review.comment!,
              style: TextStyle(
                color: ext.searchHintColor, fontSize: 13.sp, height: 1.45,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Five stars, filled to the rating. Always five: how many were not given is
/// as much of the score as how many were.
class Stars extends StatelessWidget {
  const Stars({
    super.key,
    required this.rating,
    required this.ext,
    this.size = 14,
  });

  final int rating;
  final AppThemeExtension ext;
  final double size;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var star = 1; star <= 5; star++)
            Icon(
              star <= rating ? Icons.star_rounded : Icons.star_outline_rounded,
              size: size.r,
              color: star <= rating
                  ? ext.accentGold
                  : ext.searchHintColor.withValues(alpha: 0.5),
            ),
        ],
      );
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.ext,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final AppThemeExtension ext;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(right: 8.w),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            alignment: Alignment.center,
            padding: EdgeInsets.symmetric(horizontal: 14.w),
            decoration: BoxDecoration(
              color: selected
                  ? ext.accentGold.withValues(alpha: 0.15)
                  : ext.searchFieldFill,
              borderRadius: BorderRadius.circular(999.r),
              border: Border.all(
                color: selected
                    ? ext.accentGold
                    : ext.searchHintColor.withValues(alpha: 0.2),
                width: 0.9,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: selected ? ext.accentGold : ext.searchHintColor,
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      );
}

// ── Writing one ─────────────────────────────────────────────────────────────
class WriteReviewPage extends StatefulWidget {
  const WriteReviewPage({
    super.key,
    required this.photographerId,
    required this.photographerName,
    required this.requestTitle,
    this.requestId,
    this.photographerPhotoUrl,
    this.photographerLocation,
    this.photographerFollowers = 0,
    this.photographerRating,
  });

  final String photographerId;
  final String photographerName;

  /// Named at the top — "Naomi's Bridal Event Review" — because someone may
  /// have hired the same photographer more than once.
  final String requestTitle;
  final String? requestId;
  final String? photographerPhotoUrl;

  // The same three facts every other screen in the flow shows under a name.
  // This one used to take a pre-joined string and was only ever handed the
  // location, so the composer alone showed neither followers nor rating.
  final String? photographerLocation;
  final int photographerFollowers;
  final double? photographerRating;

  @override
  State<WriteReviewPage> createState() => _WriteReviewPageState();
}

class _WriteReviewPageState extends State<WriteReviewPage> {
  final _repo = ReviewsRepository();
  final _comment = TextEditingController();
  int _rating = 0;
  bool _saving = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving || _rating == 0) return;
    setState(() => _saving = true);
    try {
      await _repo.leave(
        widget.photographerId,
        rating: _rating,
        comment: _comment.text.trim(),
        requestId: widget.requestId,
      );
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ReviewSubmittedPage()),
      );
    } catch (e) {
      debugPrint('[WriteReview] submit ERROR: $e');
      if (!mounted) return;
      setState(() => _saving = false);
      AppSnackBar.error(context, 'Could not publish your review.');
    }
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
          'Write a Review',
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
          AppSpacing.lg.w, AppSpacing.md.h, AppSpacing.lg.w, AppSpacing.xxl.h,
        ),
        children: [
          Text(
            '${widget.requestTitle} Review',
            style: TextStyle(
              color: ext.greetingColor,
              fontSize: 15.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: AppSpacing.md.h),
          Container(
            padding: EdgeInsets.all(AppSpacing.md.w),
            decoration: BoxDecoration(
              color: ext.cardSurface,
              borderRadius: BorderRadius.circular(AppRadius.md.r),
              border: Border(
                left: BorderSide(color: ext.accentGold, width: 3),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20.r,
                  backgroundColor: ext.avatarBackground,
                  backgroundImage:
                      (widget.photographerPhotoUrl?.isNotEmpty ?? false)
                          ? NetworkImage(widget.photographerPhotoUrl!)
                          : null,
                ),
                SizedBox(width: AppSpacing.md.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.photographerName,
                        style: TextStyle(
                          color: ext.greetingColor,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      PhotographerMeta(
                        ext: ext,
                        location: widget.photographerLocation,
                        followerCount: widget.photographerFollowers,
                        rating: widget.photographerRating,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: AppSpacing.xl.h),
          Text(
            'Rate your experience',
            style: TextStyle(
              color: ext.greetingColor,
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: AppSpacing.sm.h),
          Row(
            children: [
              for (var star = 1; star <= 5; star++)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _rating = star),
                  child: Padding(
                    padding: EdgeInsets.only(right: 8.w),
                    child: Icon(
                      star <= _rating
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 32.r,
                      color: star <= _rating
                          ? ext.accentGold
                          : ext.searchHintColor.withValues(alpha: 0.6),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: AppSpacing.xl.h),
          Text(
            'Review details',
            style: TextStyle(
              color: ext.greetingColor,
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: AppSpacing.sm.h),
          TextField(
            controller: _comment,
            maxLines: 6,
            maxLength: 1000,
            style: TextStyle(color: ext.greetingColor, fontSize: 14.sp),
            decoration: InputDecoration(
              hintText: 'Tell others about your experience…',
              hintStyle: TextStyle(color: ext.searchHintColor, fontSize: 14.sp),
              filled: true,
              fillColor: ext.searchFieldFill,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md.r),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          SizedBox(height: AppSpacing.lg.h),
          SizedBox(
            height: 52.h,
            child: ElevatedButton(
              // A review with no stars is not a review; the words are optional.
              onPressed: (_saving || _rating == 0) ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: ext.accentGold,
                disabledBackgroundColor: ext.accentGold.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999.r),
                ),
              ),
              child: _saving
                  ? SizedBox(
                      width: 18.r,
                      height: 18.r,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white,
                      ),
                    )
                  : Text(
                      'Submit Review',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
    return webWrap(page, backgroundColor: ext.homeBackground);
  }
}

class ReviewSubmittedPage extends StatelessWidget {
  const ReviewSubmittedPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    final page = Scaffold(
      backgroundColor: ext.homeBackground,
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        automaticallyImplyLeading: false,
        title: Text(
          'Review Submitted',
          style: TextStyle(
            color: ext.greetingColor,
            fontWeight: FontWeight.w700,
            fontSize: 16.sp,
          ),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.all(AppSpacing.xxl.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88.r,
              height: 88.r,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ext.accentGold.withValues(alpha: 0.12),
              ),
              child: Icon(Icons.check_rounded, color: ext.accentGold, size: 40.r),
            ),
            SizedBox(height: AppSpacing.xl.h),
            Text(
              'Thank You!',
              style: TextStyle(
                color: ext.greetingColor,
                fontSize: 20.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: AppSpacing.sm.h),
            Text(
              'Your review has been published. Feedback helps other clients in '
              'the community find great photographers.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: ext.searchHintColor, fontSize: 14.sp, height: 1.4,
              ),
            ),
            SizedBox(height: AppSpacing.xxl.h),
            SizedBox(
              width: double.infinity,
              height: 52.h,
              child: ElevatedButton(
                // Back to the request, not back to the composer.
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ext.accentGold,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999.r),
                  ),
                ),
                child: Text(
                  'Back to Requests',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return webWrap(page, backgroundColor: ext.homeBackground);
  }
}
