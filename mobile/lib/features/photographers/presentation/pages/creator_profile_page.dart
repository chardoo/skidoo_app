import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:jperg_app/core/common/widgets/app_back_button.dart';
import 'package:jperg_app/core/common/widgets/app_section_label.dart';
import 'package:jperg_app/core/config/chat_config.dart';
import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/core/error/exceptions.dart';
import 'package:jperg_app/core/navigation/app_page_routes.dart';
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/utils/snackbar_utils.dart';
import 'package:jperg_app/core/utils/web_wrap.dart';
import 'package:jperg_app/core/widgets/jperg_image.dart';
import 'package:jperg_app/core/widgets/media_grid.dart';
import 'package:jperg_app/features/ads/models/ad_media.dart';
import 'package:jperg_app/features/chat/data/datasources/chat_rest_data_source.dart'
    show CanMessageResult;
import 'package:jperg_app/features/chat/domain/usecases/chat_usecases.dart';
import 'package:jperg_app/features/chat/presentation/bloc/rooms/chat_rooms_bloc.dart';
import 'package:jperg_app/features/chat/presentation/pages/chat_room_page.dart';
import 'package:jperg_app/features/follow/data/follow_repository.dart';
import 'package:jperg_app/features/gallery/presentation/found/pages/found_photo_viewer_page.dart';
import 'package:jperg_app/features/photographers/data/repositories/reviews_repository.dart';
import 'package:jperg_app/features/photographers/domain/usecases/get_photographer_events_usecase.dart';
import 'package:jperg_app/features/photographers/domain/usecases/photographer_profile_usecases.dart';
import 'package:jperg_app/features/photographers/domain/usecases/get_photographer_samples_usecase.dart';
import 'package:jperg_app/features/photographers/presentation/pages/reviews_pages.dart';
import 'package:jperg_app/features/photographers/presentation/widgets/photographer_meta.dart';
import 'package:jperg_app/features/search/presentation/pages/search_event_photos_page.dart';
import 'package:jperg_app/models/photographer/photographer_event.dart';
import 'package:jperg_app/models/photos/Photo.dart';
import 'package:jperg_app/services/auth_service.dart';

/// Everything the header states about a creator.
///
/// One shape, two sources. The request board already carries all of it on the
/// interest row it fetched, so opening a photographer from there paints
/// immediately; a tap anywhere else has only an id and fills this in from
/// `/photographer/profile/{id}`. Keeping the shape common is what lets the two
/// entry points share a screen instead of drifting into two designs of the
/// same page — which is what they had been.
class CreatorProfile {
  const CreatorProfile({
    required this.id,
    required this.name,
    this.photoUrl,
    this.bannerUrl,
    this.bio,
    this.location,
    this.specialties = const [],
    this.rating,
    this.ratingCount = 0,
    this.followerCount = 0,
    this.verified = false,
  });

  final String id;
  final String name;
  final String? photoUrl;

  /// The studio shot across the top.
  final String? bannerUrl;
  final String? bio;
  final String? location;
  final List<String> specialties;
  final double? rating;
  final int ratingCount;

  /// "3 followers", under the name. The request board has it on the row it
  /// fetched; everywhere else the page asks the follow service.
  final int followerCount;
  final bool verified;

  factory CreatorProfile.fromJson(String id, Map<String, dynamic> j) {
    final data = j['data'] is Map<String, dynamic>
        ? j['data'] as Map<String, dynamic>
        : j;
    return CreatorProfile(
      id: data['id'] as String? ?? id,
      name: (data['name'] as String?)?.trim().isNotEmpty == true
          ? (data['name'] as String).trim()
          : 'Photographer',
      photoUrl: data['profile_url'] as String?,
      bannerUrl: data['studio_image_url'] as String?,
      bio: data['bio'] as String?,
      location: data['location'] as String?,
      specialties: (data['specialties'] as List<dynamic>? ?? [])
          .whereType<String>()
          .toList(),
      rating: (data['rating'] as num?)?.toDouble(),
      ratingCount: (data['rating_count'] as num?)?.toInt() ?? 0,
      followerCount: (data['follower_count'] as num?)?.toInt() ?? 0,
      verified: data['verified_by_admin'] as bool? ?? false,
    );
  }

  /// What a tap knows before anything is fetched — a name and a face, so the
  /// screen opens on the person rather than on a spinner.
  factory CreatorProfile.seed({
    required String id,
    required String name,
    String? photoUrl,
  }) =>
      CreatorProfile(
        id: id,
        name: name.trim().isNotEmpty ? name.trim() : 'Photographer',
        photoUrl: photoUrl,
      );

  CreatorProfile mergedWith(CreatorProfile fresh) => CreatorProfile(
        id: fresh.id.isNotEmpty ? fresh.id : id,
        name: fresh.name,
        photoUrl: fresh.photoUrl ?? photoUrl,
        bannerUrl: fresh.bannerUrl ?? bannerUrl,
        bio: fresh.bio ?? bio,
        location: fresh.location ?? location,
        specialties:
            fresh.specialties.isNotEmpty ? fresh.specialties : specialties,
        rating: fresh.rating ?? rating,
        ratingCount: fresh.ratingCount > 0 ? fresh.ratingCount : ratingCount,
        followerCount:
            fresh.followerCount > 0 ? fresh.followerCount : followerCount,
        verified: fresh.verified || verified,
      );
}

/// A creator, wherever you tapped them.
///
/// There were two of these. One opened from every avatar in the app and had
/// Follow and Message; the other lived inside the request flow, looked far
/// better — banner, rating pill, specialties, a real portfolio — and could not
/// be reached from anywhere else. The same person had two profiles, and the
/// good one was the one nobody could get to.
///
/// This is that screen, made general. The request flow mounts it with its
/// Select button through [footer]; everywhere else mounts it with an id.
class CreatorProfilePage extends StatefulWidget {
  const CreatorProfilePage({
    super.key,
    required this.profile,
    this.footer,
    this.note,
    this.fetchProfile = true,
  });

  /// What is known at the point of tapping. Filled in from the server unless
  /// [fetchProfile] is false.
  final CreatorProfile profile;

  /// Actions belonging to the flow that opened this — the request board's
  /// "Select photographer" and its way back to the list. Null everywhere else:
  /// a profile opened from a feed has nothing to choose.
  final Widget? footer;

  /// The note this person sent with their answer, on the request flow only.
  final Widget? note;

  /// False when the caller already holds a complete profile and a fetch would
  /// only re-state it.
  final bool fetchProfile;

  @override
  State<CreatorProfilePage> createState() => _CreatorProfilePageState();
}

class _CreatorProfilePageState extends State<CreatorProfilePage> {
  final _reviewsRepo = ReviewsRepository();

  late CreatorProfile _p = widget.profile;

  int _tab = 0;
  ReviewPage? _reviews;
  bool _loadingReviews = false;

  /// null while the checks are in flight. Not false: on the first paint a
  /// `false` would draw a Follow button on the viewer's own profile, and
  /// tapping it posts a follow of themselves, which the API refuses.
  bool? _isOwner;
  CanMessageResult? _canMsg;

  List<AdMedia> _portfolio = const [];
  bool _loadingPortfolio = true;

  int get _reviewCount => _reviews?.count ?? _p.ratingCount;

  @override
  void initState() {
    super.initState();
    if (widget.fetchProfile) {
      _loadProfile();
      _loadFollowers();
    }
    _loadPortfolio();
    _checkOwner();
    _checkCanMessage();
  }

  Future<void> _loadProfile() async {
    try {
      final json = await sl<GetPhotographerProfileUseCase>().call(_p.id);
      if (!mounted || json.isEmpty) return;
      setState(() => _p = _p.mergedWith(CreatorProfile.fromJson(_p.id, json)));
    } catch (e) {
      // The seed already names the person; a failed fetch costs the bio and
      // the banner, not the screen.
      debugPrint('[CreatorProfile] profile ERROR: $e');
    }
  }

  /// The follow service owns this number, not the profile payload.
  Future<void> _loadFollowers() async {
    try {
      final stats = await FollowRepository().getStats(_p.id);
      if (!mounted || stats.followers == 0) return;
      setState(() => _p = _p.mergedWith(
            CreatorProfile(
              id: _p.id,
              name: _p.name,
              followerCount: stats.followers,
            ),
          ));
    } catch (e) {
      debugPrint('[CreatorProfile] followers ERROR: $e');
    }
  }

  /// The portfolio is the photographer's samples — the same rows the request
  /// board reads, so the two screens cannot show different work for one person.
  Future<void> _loadPortfolio() async {
    try {
      final samples = await sl<GetPhotographerSamplesUseCase>().call(_p.id);
      if (!mounted) return;
      setState(() {
        _portfolio = [
          for (final s in samples)
            AdMedia(
              id: s.id,
              url: s.url,
              mediaType: s.isVideo ? 'video' : 'image',
              width: s.width,
              height: s.height,
            ),
        ];
        _loadingPortfolio = false;
      });
    } catch (e) {
      debugPrint('[CreatorProfile] portfolio ERROR: $e');
      if (mounted) setState(() => _loadingPortfolio = false);
    }
  }

  Future<void> _checkOwner() async {
    try {
      final myId = await sl<AuthService>().getUserId();
      if (mounted) setState(() => _isOwner = myId == _p.id);
    } catch (e) {
      // Left unknown rather than assumed: the buttons stay hidden, which is
      // the safe way to be wrong.
      debugPrint('[CreatorProfile] ownership ERROR: $e');
    }
  }

  /// Asked before the button is drawn, so it reflects the recipient's settings
  /// rather than failing after a tap. The server's error codes remain the
  /// authority — the setting can change in between.
  Future<void> _checkCanMessage() async {
    try {
      final result = await sl<CanMessageUseCase>().call(_p.id);
      if (mounted) setState(() => _canMsg = result);
    } catch (_) {
      if (mounted) setState(() => _canMsg = CanMessageResult.allowed());
    }
  }

  Future<void> _loadReviews() async {
    if (_reviews != null || _loadingReviews) return;
    setState(() => _loadingReviews = true);
    try {
      final page = await _reviewsRepo.list(_p.id, limit: 2);
      if (mounted) setState(() => _reviews = page);
    } catch (e) {
      debugPrint('[CreatorProfile] reviews ERROR: $e');
      if (mounted) setState(() => _reviews = ReviewPage.empty);
    } finally {
      if (mounted) setState(() => _loadingReviews = false);
    }
  }

  void _openPortfolio(int index) {
    if (_portfolio.isEmpty) return;
    Navigator.of(context).push(NoSwipeBackPageRoute<void>(
      builder: (_) => FoundPhotoViewerPage(
        photos: [
          for (final media in _portfolio)
            Photo(media.id, _p.name, '', media.url, _p.id, 0, '', null, true,
                width: media.width,
                height: media.height,
                photographerName: _p.name,
                photographerAvatarUrl: _p.photoUrl ?? ''),
        ],
        initialIndex: index,
        // Somebody's work on show. There is nothing here to like, comment on
        // or save, and the rail would be acting on sample ids the picture
        // endpoints have never heard of.
        showSocialActions: false,
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

  Future<void> _openDirectChat() async {
    ChatRoomsBloc? roomsBloc;
    try {
      roomsBloc = context.read<ChatRoomsBloc>();
    } catch (_) {}

    try {
      final room = await sl<GetOrCreateDirectRoomUseCase>().call(
        recipientId: _p.id,
        recipientRole: ChatConfig.rolePhotographer,
        localDisplayName: _p.name,
      );
      if (!mounted) return;
      roomsBloc?.add(const ChatRoomsLoadRequested());
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ChatRoomPage(room: room)),
      );
      if (mounted) roomsBloc?.add(const ChatRoomsLoadRequested());
    } catch (e) {
      // The race between the upfront check and the send: the setting can
      // change in between, so the server's answer wins and the button catches
      // up with it.
      final code = e is ApiException ? e.code : null;
      final refused = code == 'RECIPIENT_NOT_ACCEPTING_DMS';
      if (refused && mounted) {
        setState(() => _canMsg = const CanMessageResult(
            canMessage: false, reason: 'RECIPIENT_NOT_ACCEPTING_DMS'));
      }
      if (!mounted) return;
      AppSnackBar.error(
        context,
        refused || code == 'USER_BLOCKED'
            ? 'This person is not accepting new conversations.'
            : 'Could not open chat. Try again.',
      );
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
        leading: kIsWeb ? null : const AppBackButton(),
        title: Text(
          _p.name,
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
          _Banner(url: _p.bannerUrl, ext: ext),
          _IdentityRow(profile: _p, ext: ext),
          SizedBox(height: AppSpacing.md.h),
          Divider(
            height: 1,
            thickness: 0.7,
            color: ext.searchHintColor.withValues(alpha: 0.15),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: AppSpacing.lg.h),

                // Follow and Message, on the profile itself rather than only on
                // the one this replaced. A profile you cannot act on is a
                // poster.
                if (_isOwner == false) ...[
                  _Actions(
                    profile: _p,
                    ext: ext,
                    canMessage: _canMsg?.canMessage ?? false,
                    onMessage: _openDirectChat,
                  ),
                  SizedBox(height: AppSpacing.lg.h),
                ],

                // Bio first, then the specialties — what they say about
                // themselves before the labels.
                if ((_p.bio?.isNotEmpty ?? false) ||
                    _p.specialties.isNotEmpty) ...[
                  const AppSectionLabel('Bio & specialties'),
                  SizedBox(height: AppSpacing.sm.h),
                  if (_p.bio?.isNotEmpty ?? false) ...[
                    Text(
                      _p.bio!,
                      style: TextStyle(
                        color: ext.searchHintColor,
                        fontSize: 13.sp,
                        height: 1.45,
                      ),
                    ),
                    if (_p.specialties.isNotEmpty)
                      SizedBox(height: AppSpacing.md.h),
                  ],
                  if (_p.specialties.isNotEmpty)
                    Wrap(
                      spacing: AppSpacing.sm.w,
                      runSpacing: AppSpacing.xs.h,
                      children: [
                        for (final specialty in _p.specialties)
                          _Chip(label: specialty, ext: ext),
                      ],
                    ),
                ],

                SizedBox(height: AppSpacing.xl.h),
                _Tabs(
                  ext: ext,
                  index: _tab,
                  labels: [
                    'Portfolio',
                    // The count is in the label, so the weight of the reviews
                    // is visible before anyone opens them.
                    'Reviews ($_reviewCount)',
                    'Events',
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
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg.w),
            child: switch (_tab) {
              0 => _loadingPortfolio
                  ? Padding(
                      padding: EdgeInsets.all(AppSpacing.xl.h),
                      child: Center(
                        child: CircularProgressIndicator(
                            color: ext.searchHintColor, strokeWidth: 2),
                      ),
                    )
                  : _portfolio.isEmpty
                      ? _Empty(text: 'No portfolio yet.', ext: ext)
                      : _Portfolio(
                          media: _portfolio,
                          ext: ext,
                          onTap: _openPortfolio,
                        ),
              1 => _ReviewsPreview(
                  page: _reviews,
                  loading: _loadingReviews,
                  ext: ext,
                  onViewAll: _openAllReviews,
                ),
              // Their albums. Opening one is opening an event, exactly as it is
              // everywhere else — no scan, no face gate: this is browsing
              // somebody's work, not asking whether you are in it.
              _ => CreatorEventsTab(photographerId: _p.id, ext: ext),
            },
          ),
          if (widget.note != null) ...[
            SizedBox(height: AppSpacing.xl.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg.w),
              child: widget.note!,
            ),
          ],
          if (widget.footer != null) ...[
            SizedBox(height: AppSpacing.xxl.h),
            widget.footer!,
          ],
        ],
      ),
    );

    return webWrap(page, backgroundColor: ext.homeBackground);
  }
}

// ── Header ───────────────────────────────────────────────────────────────────

/// The studio shot across the top. A tinted band rather than a broken image
/// when there is none — the identity row sits below it either way, so nothing
/// depends on this having loaded.
class _Banner extends StatelessWidget {
  const _Banner({required this.url, required this.ext});

  final String? url;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 140.h,
      width: double.infinity,
      child: (url?.isNotEmpty ?? false)
          ? JpergImage(
              imageUrl: url!,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) =>
                  ColoredBox(color: ext.avatarBackground),
            )
          : ColoredBox(color: ext.accentGold.withValues(alpha: 0.15)),
    );
  }
}

/// Avatar, name and location on the left; the rating in its own pill on the
/// right.
class _IdentityRow extends StatelessWidget {
  const _IdentityRow({required this.profile, required this.ext});

  final CreatorProfile profile;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    final photo = profile.photoUrl;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg.w,
        AppSpacing.md.h,
        AppSpacing.lg.w,
        0,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26.r,
            backgroundColor: ext.avatarBackground,
            backgroundImage: (photo?.isNotEmpty ?? false)
                ? boundedNetworkImage(context, photo!, diameter: 52.r)
                : null,
            child: (photo?.isNotEmpty ?? false)
                ? null
                : Text(
                    profile.name[0].toUpperCase(),
                    style:
                        TextStyle(color: ext.avatarForeground, fontSize: 18.sp),
                  ),
          ),
          SizedBox(width: AppSpacing.md.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        profile.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: ext.greetingColor,
                          fontSize: 17.sp,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    if (profile.verified) ...[
                      SizedBox(width: 4.w),
                      Icon(Icons.verified_rounded,
                          size: 15.r, color: ext.infoBlue),
                    ],
                  ],
                ),
                SizedBox(height: 3.h),
                PhotographerMeta(
                  ext: ext,
                  location: profile.location,
                  followerCount: profile.followerCount,
                  variant: PhotographerMetaVariant.header,
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.only(left: AppSpacing.sm.w),
            child: RatingPill(ext: ext, rating: profile.rating),
          ),
        ],
      ),
    );
  }
}

/// Follow and Message, side by side.
///
/// A matched pair rather than the feed's little follow pill: on a profile these
/// are the two things there are to do, and the design gives them equal weight.
///
/// Message disappears rather than failing when the person is not taking new
/// conversations — a button that always errors is worse than no button.
class _Actions extends StatefulWidget {
  const _Actions({
    required this.profile,
    required this.ext,
    required this.canMessage,
    required this.onMessage,
  });

  final CreatorProfile profile;
  final AppThemeExtension ext;
  final bool canMessage;
  final VoidCallback onMessage;

  @override
  State<_Actions> createState() => _ActionsState();
}

class _ActionsState extends State<_Actions> {
  final _repo = FollowRepository();

  late bool _following =
      FollowRepository.followedIds.contains(widget.profile.id);
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Following the same person from two screens at once is ordinary — the
    // feed card behind this one has its own button.
    FollowRepository.followedRevision.addListener(_onFollowedChanged);
  }

  @override
  void dispose() {
    FollowRepository.followedRevision.removeListener(_onFollowedChanged);
    super.dispose();
  }

  void _onFollowedChanged() {
    final following = FollowRepository.followedIds.contains(widget.profile.id);
    if (mounted && following != _following) {
      setState(() => _following = following);
    }
  }

  Future<void> _toggle() async {
    if (_busy) return;
    final wasFollowing = _following;
    setState(() {
      _following = !wasFollowing;
      _busy = true;
    });
    try {
      wasFollowing
          ? await _repo.unfollow(widget.profile.id)
          : await _repo.follow(widget.profile.id);
    } catch (e) {
      debugPrint('[CreatorProfile] follow ERROR: $e');
      if (mounted) setState(() => _following = wasFollowing);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = widget.ext;
    return Row(
      children: [
        Expanded(
          child: _PillButton(
            ext: ext,
            icon: _following
                ? Icons.person_remove_alt_1_outlined
                : Icons.person_add_alt_1_outlined,
            label: _following ? 'Following' : 'Follow',
            filled: _following,
            onTap: _toggle,
          ),
        ),
        if (widget.canMessage) ...[
          SizedBox(width: AppSpacing.md.w),
          Expanded(
            child: _PillButton(
              ext: ext,
              icon: Icons.chat_bubble_outline_rounded,
              label: 'Message',
              filled: false,
              onTap: widget.onMessage,
            ),
          ),
        ],
      ],
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.ext,
    required this.icon,
    required this.label,
    required this.filled,
    required this.onTap,
  });

  final AppThemeExtension ext;
  final IconData icon;
  final String label;

  /// Filled marks the state you are already in — following. The action you
  /// have not taken is an outline, the same rule the reaction rail follows.
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 44.h,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: filled
                ? ext.searchHintColor.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.md.r),
            border: Border.all(
              color: ext.searchHintColor.withValues(alpha: 0.35),
              width: 0.9,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17.sp, color: ext.greetingColor),
              SizedBox(width: AppSpacing.sm.w),
              Text(
                label,
                style: TextStyle(
                  color: ext.greetingColor,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Tabs and their contents ──────────────────────────────────────────────────

/// Portfolio | Reviews (142) | Events.
///
/// Left-aligned and only as wide as their labels, with the rule under the
/// active word rather than a bar spanning the screen — tabs stretched across
/// the width read as buttons.
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
    // Scrollable, though it rarely needs to scroll. Two tabs always fitted;
    // three plus a four-figure review count is close enough to the edge on a
    // narrow phone that the row should bend rather than paint an overflow bar
    // across somebody's profile.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Padding(
              padding: EdgeInsets.only(right: AppSpacing.xl.w),
              child: Semantics(
                button: true,
                selected: i == index,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(i),
                  // IntrinsicWidth so the rule is exactly as wide as the word:
                  // inside a Row the column would otherwise be handed the whole
                  // remaining width to stretch into.
                  child: IntrinsicWidth(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          labels[i],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: i == index
                                ? ext.greetingColor
                                : ext.searchHintColor,
                            fontSize: 14.sp,
                            fontWeight:
                                i == index ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 6.h),
                        Container(
                          height: 2.h,
                          color:
                              i == index ? ext.accentGold : Colors.transparent,
                        ),
                      ],
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

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.ext});

  final String label;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: ext.accentGold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999.r),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: ext.accentGold,
          fontSize: 12.sp,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.text, required this.ext});

  final String text;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl.h),
      child: Center(
        child: Text(
          text,
          style: TextStyle(color: ext.searchHintColor, fontSize: 13.sp),
        ),
      ),
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
                      child: JpergImage(
                        imageUrl: widget.media[i].url,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorWidget: (_, __, ___) => Icon(
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

/// The first couple of reviews with a way through to the rest — a profile is
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
              strokeWidth: 2,
              color: ext.accentGold,
            ),
          ),
        ),
      );
    }

    final data = page;
    if (data == null || data.reviews.isEmpty) {
      return _Empty(text: 'No reviews yet.', ext: ext);
    }

    final preview = data.reviews.take(2).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // One bordered box holding both reviews and the way through to the
        // rest, as the design groups them — separate cards would read as two
        // unrelated things above a link.
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md.r),
            border: Border.all(
              color: ext.searchHintColor.withValues(alpha: 0.16),
              width: 0.8,
            ),
          ),
          child: Column(
            children: [
              for (var i = 0; i < preview.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    thickness: 0.7,
                    indent: AppSpacing.md.w,
                    endIndent: AppSpacing.md.w,
                    color: ext.searchHintColor.withValues(alpha: 0.16),
                  ),
                Padding(
                  padding: EdgeInsets.all(AppSpacing.md.w),
                  child: ReviewCard(
                    review: preview[i],
                    ext: ext,
                    bordered: false,
                  ),
                ),
              ],
              Divider(
                height: 1,
                thickness: 0.7,
                color: ext.searchHintColor.withValues(alpha: 0.16),
              ),
              InkWell(
                onTap: onViewAll,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(AppRadius.md.r),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.md.h),
                  child: Center(
                    child: Text(
                      'View all ${data.count} reviews  \u2192',
                      style: TextStyle(
                        color: ext.accentGold,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Events ───────────────────────────────────────────────────────────────────

/// The creator's albums, paginated.
///
/// Tapping one opens [SearchEventPhotosPage] — the same album a tap on an
/// event in search opens, which fetches the event from its id and needs
/// nothing carried in. It used to run the home search and push its results
/// page instead, which meant an event could only be opened from a profile that
/// happened to have the home bloc above it: from Following, where there is
/// none, the tap threw.
///
/// Deliberately *not* the scan flow either. That one asks "are there photos of
/// me in here?", needs a face on file, and preselects matches for review.
/// Browsing somebody's work is a different question, and putting a face gate
/// in front of it would stop a guest at the door of a public album.
class CreatorEventsTab extends StatefulWidget {
  const CreatorEventsTab({
    super.key,
    required this.photographerId,
    required this.ext,
  });

  final String photographerId;
  final AppThemeExtension ext;

  @override
  State<CreatorEventsTab> createState() => _CreatorEventsTabState();
}

class _CreatorEventsTabState extends State<CreatorEventsTab> {
  static const _limit = 10;

  final _events = <PhotographerEvent>[];

  int _page = 1;
  bool _loading = false;
  bool _hasMore = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await sl<GetPhotographerEventsUseCase>().call(
        photographerId: widget.photographerId,
        page: _page,
        limit: _limit,
      );
      if (!mounted) return;
      setState(() {
        _events.addAll(result.events);
        _page++;
        _hasMore = result.hasNext;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _open(PhotographerEvent event) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SearchEventPhotosPage(eventId: event.id),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final ext = widget.ext;

    if (_loading && _events.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(AppSpacing.xl.h),
        child: Center(
          child: CircularProgressIndicator(
              color: ext.searchHintColor, strokeWidth: 2),
        ),
      );
    }

    if (_error != null && _events.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl.h),
        child: Column(
          children: [
            Text(
              'Could not load events.',
              style: TextStyle(color: ext.searchHintColor, fontSize: 13.sp),
            ),
            TextButton(
              onPressed: _loadMore,
              child: Text('Retry', style: TextStyle(color: ext.accentGold)),
            ),
          ],
        ),
      );
    }

    if (_events.isEmpty) return _Empty(text: 'No events yet.', ext: ext);

    return Column(
      children: [
        MediaGrid(
          density: MediaGridDensity.cards,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _events.length,
          itemBuilder: (context, index) {
            final event = _events[index];
            return Semantics(
              button: true,
              label: 'Event',
              child: GestureDetector(
                onTap: () => _open(event),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14.r),
                  child: Container(
                    color: ext.cardSurface,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: event.url.isNotEmpty
                              ? JpergImage(
                                  imageUrl: event.url,
                                  semanticLabel: 'Event photo',
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) =>
                                      const JpergImagePlaceholder(),
                                  errorWidget: (_, __, ___) =>
                                      const JpergImagePlaceholder(),
                                )
                              : ColoredBox(
                                  color: ext.avatarBackground,
                                  child: Icon(Icons.event_rounded,
                                      color: ext.searchHintColor, size: 36.sp),
                                ),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: 10.w, vertical: AppSpacing.sm.h),
                          child: Text(
                            event.eventName,
                            style: TextStyle(
                              color: ext.greetingColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 13.sp,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        if (_hasMore)
          TextButton(
            onPressed: _loading ? null : _loadMore,
            child: Text(
              _loading ? 'Loading…' : 'Show more',
              style: TextStyle(color: ext.accentGold, fontSize: 13.sp),
            ),
          ),
      ],
    );
  }
}
