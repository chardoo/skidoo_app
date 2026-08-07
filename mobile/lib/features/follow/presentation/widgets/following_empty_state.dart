import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/follow/data/follow_repository.dart';
import 'package:jperg_app/features/follow/presentation/widgets/suggested_creators_list.dart';
import 'package:jperg_app/core/common/widgets/app_section_label.dart';

/// What the Following tab shows before the user follows anyone.
///
/// An empty tab that only says "nothing here" leaves the user to find the
/// follow button themselves, so this doubles as the way out: the suggested
/// creators are right underneath the message, each with its own Follow
/// button, and the row opens the creator's profile.
///
/// Following someone deliberately does *not* swap this view out from under
/// the user mid-list — a first follow doesn't mean they're done following.
/// Pull-to-refresh (or coming back to the tab) is what fetches the new feed.
class FollowingEmptyState extends StatefulWidget {
  const FollowingEmptyState({
    super.key,
    this.topPadding = 0,
    this.onRefresh,
    this.loadSuggestions,
  });

  /// Clears the floating top bar the feed sits behind.
  final double topPadding;

  /// Reloads the feed itself. Runs alongside this widget's own reload when
  /// the user pulls down.
  final Future<void> Function()? onRefresh;

  /// Overrides where the suggestions come from. Only for tests — production
  /// leaves it null and goes to [FollowRepository].
  final Future<List<SuggestedPhotographer>> Function()? loadSuggestions;

  @override
  State<FollowingEmptyState> createState() => _FollowingEmptyStateState();
}

class _FollowingEmptyStateState extends State<FollowingEmptyState> {
  // Built on first use so a widget test can drive this through
  // [FollowingEmptyState.loadSuggestions] without an HTTP client existing.
  late final _repo = FollowRepository();

  List<SuggestedPhotographer> _suggestions = [];
  bool _loading = true;
  bool _hadError = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _hadError = false;
      });
    }
    try {
      final results = widget.loadSuggestions != null
          ? await widget.loadSuggestions!()
          : await _repo.getSuggestedPhotographers(limit: 20);
      if (!mounted) return;
      setState(() {
        _suggestions = results;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _hadError = true;
      });
    }
  }

  Future<void> _onPull() async {
    await Future.wait([
      _load(),
      if (widget.onRefresh != null) widget.onRefresh!(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return RefreshIndicator(
      onRefresh: _onPull,
      color: ext.accentGold,
      backgroundColor: ext.cardSurface,
      child: ListView(
        // Always scrollable so the pull gesture works even when the list is
        // short enough to fit.
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(
          top: widget.topPadding + AppSpacing.xl.h,
          bottom: AppSpacing.huge.h,
        ),
        children: [
          _Headline(ext: ext),
          SizedBox(height: AppSpacing.xl.h),
          const AppSectionLabel('Suggested creators',
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg)),
          SizedBox(height: AppSpacing.sm.h),
          ..._buildSuggestions(ext),
        ],
      ),
    );
  }

  List<Widget> _buildSuggestions(AppThemeExtension ext) {
    if (_loading) {
      return [
        Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.xl.h),
          child: Center(
            child: SizedBox(
              width: 22.w,
              height: 22.w,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: ext.accentGold),
            ),
          ),
        ),
      ];
    }

    if (_suggestions.isEmpty) {
      // An empty list has two meanings, and the endpoint can't tell them
      // apart for us — it simply omits everyone the user already follows. So
      // whether the user has followed anyone is what decides the wording:
      // "there's no one to suggest" reads as a fault, and it isn't one when
      // the reason is that they've followed every creator we had.
      final String message;
      if (_hadError) {
        message =
            "We couldn't load suggestions right now. Pull down to try again.";
      } else if (FollowRepository.followedIds.isNotEmpty) {
        message = "You're following everyone we can suggest for now. "
            'Pull down to load their work.';
      } else {
        message = 'No suggestions available yet.';
      }

      return [
        Padding(
          padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.lg.w, vertical: AppSpacing.lg.h),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: ext.searchHintColor, fontSize: 13.sp),
          ),
        ),
      ];
    }

    return [SuggestedCreatorsList(suggestions: _suggestions)];
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Headline extends StatelessWidget {
  const _Headline({required this.ext});

  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // The empty-state mark. [searchFieldFill] is the app's neutral slot
        // colour, so it reads as a soft disc on the page in either theme
        // rather than the hole a fixed dark grey would punch in light mode.
        Container(
          width: 120.r,
          height: 120.r,
          decoration: BoxDecoration(
            color: ext.searchFieldFill,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.people_alt_rounded,
            size: 46.sp,
            color: ext.searchHintColor.withValues(alpha: 0.5),
          ),
        ),
        SizedBox(height: AppSpacing.lg.h),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl.w),
          child: Text(
            'Follow creators to see their works here',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: ext.greetingColor,
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

