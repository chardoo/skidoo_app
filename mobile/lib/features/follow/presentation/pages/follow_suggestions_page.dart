import 'package:jperg_app/core/widgets/jperg_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/auth/presentation/widgets/onboarding_step_scaffold.dart';
import 'package:jperg_app/features/follow/data/follow_repository.dart';
import 'package:jperg_app/features/auth/presentation/pages/onboarding_complete_page.dart';
import 'package:jperg_app/features/home/presentation/bloc/home_bloc.dart';
import 'package:jperg_app/features/photographers/presentation/pages/photographer_profile_page.dart';
import 'package:jperg_app/models/photographer/photographerModel.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';

/// Final onboarding step — "Creators to follow" (4/4), the same for every
/// role. Photographer-only portfolio setup + verification no longer happen
/// automatically here — they're done later, on demand, from the Account
/// page's Portfolio card (see `portfolio_edit_page.dart`). Shows a handful
/// of recommended photographers (via
/// `FollowRepository.getSuggestedPhotographers`) with a Follow/Following
/// toggle for each; following anyone here is entirely optional.
class FollowSuggestionsPage extends StatefulWidget {
  const FollowSuggestionsPage({super.key});

  @override
  State<FollowSuggestionsPage> createState() => _FollowSuggestionsPageState();
}

class _FollowSuggestionsPageState extends State<FollowSuggestionsPage> {
  final _repo = FollowRepository();

  List<SuggestedPhotographer> _suggestions = [];
  final Set<String> _pending = {};
  bool _loading = true;
  bool _hadError = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _hadError = false;
    });
    try {
      final results = await _repo.getSuggestedPhotographers(limit: 20);
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
      // FollowRepository already reverts its internal cache on failure —
      // nothing extra to do here besides letting the UI re-read it below.
    } finally {
      if (mounted) setState(() => _pending.remove(id));
    }
  }

  void _finish() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const OnboardingCompletePage()),
    );
  }

  // Onboarding has no HomeBloc in its ancestor tree, so it's read
  // defensively and only re-provided to the pushed page when present —
  // same pattern used to open a photographer's profile from the Discovery
  // feed (event_discovery_card.dart).
  void _openProfile(SuggestedPhotographer s) {
    final photographer = PhotographerModel(
      s.id,
      s.email,
      s.name,
      s.contact,
      imageUrl: s.profileUrl,
    );
    HomeBloc? homeBloc;
    try {
      homeBloc = context.read<HomeBloc>();
    } catch (_) {}

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => homeBloc != null
            ? BlocProvider.value(
                value: homeBloc,
                child: PhotographerProfilePage(photographer: photographer),
              )
            : PhotographerProfilePage(photographer: photographer),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    return OnboardingStepScaffold(
      currentStep: 4,
      totalSteps: 4,
      title: 'Creators to follow',
      subtitle: 'Follow a few photographers to personalise your feed.',
      primaryLabel: 'Continue',
      onPrimaryPressed: _finish,
      onSkip: _finish,
      child: _buildBody(ext),
    );
  }

  Widget _buildBody(AppThemeExtension ext) {
    if (_loading) {
      return Center(child: CircularProgressIndicator(color: ext.accentGold));
    }
    if (_suggestions.isEmpty) {
      return Center(
        child: Text(
          _hadError
              ? "We couldn't load suggestions right now."
              : 'No suggestions available yet.',
          textAlign: TextAlign.center,
          style: TextStyle(color: ext.searchHintColor, fontSize: 14.sp),
        ),
      );
    }
    // A plain Column, not a ListView — OnboardingStepScaffold already makes
    // its content scrollable, and nesting a second Scrollable inside it
    // (even a non-scrolling one via shrinkWrap+NeverScrollableScrollPhysics)
    // crashes on long-press inside this app's app-wide SelectionArea
    // (`!_selectionStartsInScrollable` assertion, flutter/flutter#111690) —
    // the ambient SelectionArea's Scrollable-aware selection delegate gets
    // confused by the nested Scrollable.
    return Column(
      children: [
        for (var i = 0; i < _suggestions.length; i++) ...[
          if (i > 0) SizedBox(height: AppSpacing.md.h),
          _SuggestionCard(
            suggestion: _suggestions[i],
            following: FollowRepository.followedIds.contains(_suggestions[i].id),
            pending: _pending.contains(_suggestions[i].id),
            onToggle: () => _toggleFollow(_suggestions[i].id),
            onOpenProfile: () => _openProfile(_suggestions[i]),
          ),
        ],
      ],
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({
    required this.suggestion,
    required this.following,
    required this.pending,
    required this.onToggle,
    required this.onOpenProfile,
  });

  final SuggestedPhotographer suggestion;
  final bool following;
  final bool pending;
  final VoidCallback onToggle;
  final VoidCallback onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: ext.cardSurface,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: ext.searchHintColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              button: true,
              label: "Open ${suggestion.name}'s profile",
              child: InkWell(
                borderRadius: BorderRadius.circular(10.r),
                onTap: onOpenProfile,
                child: Row(
                  children: [
                    _SuggestionAvatar(suggestion: suggestion, ext: ext),
                    SizedBox(width: AppSpacing.md.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            suggestion.name,
                            style: TextStyle(
                              color: ext.greetingColor,
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            '${suggestion.followerCount} follower${suggestion.followerCount == 1 ? '' : 's'}',
                            style: TextStyle(
                                color: ext.searchHintColor, fontSize: 12.sp),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(width: AppSpacing.sm.w),
          SizedBox(
            height: 34.h,
            child: Semantics(
              button: true,
              label: following ? 'Following' : 'Follow',
              child: OutlinedButton(
                onPressed: pending ? null : onToggle,
                style: OutlinedButton.styleFrom(
                  backgroundColor:
                      following ? Colors.transparent : ext.accentGold,
                  foregroundColor: following ? ext.greetingColor : Colors.white,
                  side: BorderSide(
                    color: following
                        ? ext.searchHintColor.withValues(alpha: 0.4)
                        : ext.accentGold,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg.w),
                ),
                child: pending
                    ? SizedBox(
                        width: 14.w,
                        height: 14.w,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: following ? ext.greetingColor : Colors.white,
                        ),
                      )
                    : Text(
                        following ? 'Following' : 'Follow',
                        style: TextStyle(
                            fontSize: 12.sp, fontWeight: FontWeight.w600),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestionAvatar extends StatelessWidget {
  const _SuggestionAvatar({required this.suggestion, required this.ext});

  final SuggestedPhotographer suggestion;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    final size = 44.r;
    final fallback = CircleAvatar(
      radius: size / 2,
      backgroundColor: ext.avatarBackground,
      child: Text(
        suggestion.name.isNotEmpty ? suggestion.name[0].toUpperCase() : '?',
        style: TextStyle(
          color: ext.avatarForeground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    final url = suggestion.profileUrl;
    if (url == null) return fallback;

    return ClipOval(
      child: JpergImage(
        imageUrl: url,
        width: size,
        height: size,
        logicalWidth: size,
        fit: BoxFit.cover,
        placeholder: (_, __) => fallback,
        errorWidget: (_, __, ___) => fallback,
      ),
    );
  }
}
