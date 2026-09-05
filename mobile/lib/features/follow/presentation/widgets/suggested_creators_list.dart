import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/utils/number_format.dart';
import 'package:jperg_app/features/follow/data/follow_repository.dart';
import 'package:jperg_app/features/discovery/presentation/utils/open_photographer_profile.dart';
import 'package:jperg_app/core/common/widgets/user_avatar.dart';

/// A run of suggested creators, each with its own Follow button.
///
/// Shared by the two places suggestions appear — the empty Following tab and
/// the cards dealt between feed posts — because the interesting part is the
/// same in both: following someone here has to survive the round trip, the
/// row must not disappear from under the thumb that tapped it, and the count
/// beside it has to agree with the button next to it.
///
/// Renders as a plain [Column] so the caller decides on scrolling.
class SuggestedCreatorsList extends StatefulWidget {
  const SuggestedCreatorsList({
    super.key,
    required this.suggestions,
    this.onFollowRepository,
  });

  final List<SuggestedPhotographer> suggestions;

  /// Injection seam for tests — production leaves it null and talks to a real
  /// [FollowRepository].
  final FollowRepository? onFollowRepository;

  @override
  State<SuggestedCreatorsList> createState() => _SuggestedCreatorsListState();
}

class _SuggestedCreatorsListState extends State<SuggestedCreatorsList> {
  late final _repo = widget.onFollowRepository ?? FollowRepository();

  final Set<String> _pending = {};

  /// Creators followed from this list since it was drawn.
  ///
  /// `follower_count` is a snapshot from whenever the suggestions were
  /// fetched, so it can't include the follow the user just made — these rows
  /// show it +1, which is what the next fetch will say anyway.
  final Set<String> _followedHere = {};

  @override
  void didUpdateWidget(SuggestedCreatorsList old) {
    super.didUpdateWidget(old);
    // Fresh suggestions carry fresh counts, which already include the user's
    // own follows; keeping the local adjustment would double-count them.
    if (!identical(old.suggestions, widget.suggestions)) _followedHere.clear();
  }

  Future<void> _toggleFollow(String id) async {
    final wasFollowing = FollowRepository.followedIds.contains(id);
    setState(() => _pending.add(id));
    try {
      if (wasFollowing) {
        await _repo.unfollow(id);
      } else {
        await _repo.follow(id);
      }
    } catch (_) {
      // FollowRepository reverts its own cache on failure; re-reading it
      // below is all this needs to do.
    } finally {
      if (!mounted) return;
      setState(() {
        _pending.remove(id);
        // Read back off the repository rather than off `wasFollowing`, so a
        // failed call — which reverts that cache — leaves the count alone.
        if (FollowRepository.followedIds.contains(id)) {
          _followedHere.add(id);
        } else {
          _followedHere.remove(id);
        }
      });
    }
  }

  /// Through the one helper every creator tap goes through.
  void _openProfile(SuggestedPhotographer suggestion) {
    openPhotographerProfile(
      context,
      photographerId: suggestion.id,
      photographerName: suggestion.name,
      photographerProfileUrl: suggestion.profileUrl,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final suggestion in widget.suggestions)
          SuggestedCreatorRow(
            key: ValueKey('suggested_creator_${suggestion.id}'),
            suggestion: suggestion,
            following: FollowRepository.followedIds.contains(suggestion.id),
            pending: _pending.contains(suggestion.id),
            extraFollowers: _followedHere.contains(suggestion.id) ? 1 : 0,
            onToggle: () => _toggleFollow(suggestion.id),
            onOpenProfile: () => _openProfile(suggestion),
          ),
      ],
    );
  }
}

// ── One creator ───────────────────────────────────────────────────────────────

class SuggestedCreatorRow extends StatelessWidget {
  const SuggestedCreatorRow({
    super.key,
    required this.suggestion,
    required this.following,
    required this.pending,
    required this.onToggle,
    required this.onOpenProfile,
    this.extraFollowers = 0,
  });

  final SuggestedPhotographer suggestion;
  final bool following;
  final bool pending;
  final VoidCallback onToggle;
  final VoidCallback onOpenProfile;

  /// Follows the server's count doesn't know about yet — the user's own,
  /// made after this list was fetched. Counting it here is what stops a row
  /// reading "Following" beside a total that never moved.
  final int extraFollowers;

  /// "Events & Nature · 1.2K followers", or just the count where the creator
  /// has no category on record.
  String get _subtitle {
    final followers =
        countLabel(suggestion.followerCount + extraFollowers, 'follower');
    final category = suggestion.category;
    return (category == null || category.isEmpty)
        ? followers
        : '$category · $followers';
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return Semantics(
      button: true,
      label: "Open ${suggestion.name}'s profile",
      child: InkWell(
        onTap: onOpenProfile,
        child: Padding(
          padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.lg.w, vertical: AppSpacing.sm.h),
          child: Row(
            children: [
              UserAvatar(
                initial: suggestion.name,
                imageUrl: suggestion.profileUrl,
                radius: 21,
              ),
              SizedBox(width: AppSpacing.md.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      suggestion.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: ext.greetingColor,
                        fontSize: 14.5.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      _subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: ext.searchHintColor,
                        fontSize: 11.5.sp,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: AppSpacing.md.w),
              _FollowButton(
                following: following,
                pending: pending,
                onToggle: onToggle,
                ext: ext,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The outlined pill from the design: accent while it's an invitation, and
/// dropping back to a plain neutral outline once the user has followed —
/// "Following" is a state, not a call to action.
class _FollowButton extends StatelessWidget {
  const _FollowButton({
    required this.following,
    required this.pending,
    required this.onToggle,
    required this.ext,
  });

  final bool following;
  final bool pending;
  final VoidCallback onToggle;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    final foreground = following ? ext.searchHintColor : ext.accentGold;

    return Semantics(
      button: true,
      label: following ? 'Following' : 'Follow',
      child: SizedBox(
        height: 32.h,
        child: OutlinedButton(
          onPressed: pending ? null : onToggle,
          style: OutlinedButton.styleFrom(
            foregroundColor: foreground,
            side: BorderSide(
              color: following
                  ? ext.searchHintColor.withValues(alpha: 0.4)
                  : ext.accentGold,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.pill.r),
            ),
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg.w),
            visualDensity: VisualDensity.compact,
          ),
          child: pending
              ? SizedBox(
                  width: 13.w,
                  height: 13.w,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: foreground),
                )
              : Text(
                  following ? 'Following' : 'Follow',
                  style:
                      TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600),
                ),
        ),
      ),
    );
  }
}

