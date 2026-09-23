import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/common/widgets/app_widgets.dart';
import 'package:jperg_app/core/config/chat_config.dart';
import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/core/error/exceptions.dart';
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/theme/app_typography.dart';
import 'package:jperg_app/core/utils/number_format.dart';
import 'package:jperg_app/core/utils/snackbar_utils.dart';
import 'package:jperg_app/features/chat/domain/usecases/chat_usecases.dart';
import 'package:jperg_app/features/chat/presentation/bloc/rooms/chat_rooms_bloc.dart';
import 'package:jperg_app/features/chat/presentation/pages/chat_room_page.dart';
import 'package:jperg_app/features/follow/data/follow_repository.dart';
import 'package:jperg_app/features/user_profile/data/repositories/public_profile_repository.dart';

/// Somebody else's profile — the screen the People chip in search opens.
///
/// The plain counterpart to [CreatorProfilePage]. A creator's profile is a
/// shopfront: a portfolio, rates, reviews, a banner. A person has none of
/// that, and dressing this screen up with the same furniture empty would read
/// as an unfinished creator rather than as somebody who simply isn't selling
/// anything. So it is a face, a name, two figures and the two things there are
/// to do here — follow them, or say something.
///
/// Photos are absent on purpose and not for want of a grid: a person's photos
/// are the ones they were recognised in, which belong to the events holding
/// them and are private to the person in them. There is nothing of theirs to
/// show that is theirs to give.
class PublicProfilePage extends StatefulWidget {
  const PublicProfilePage({super.key, required this.profile});

  /// The seed from whatever was tapped — see [PublicProfile.seed]. The screen
  /// refetches everything from the id; this is what it draws meanwhile.
  final PublicProfile profile;

  @override
  State<PublicProfilePage> createState() => _PublicProfilePageState();
}

class _PublicProfilePageState extends State<PublicProfilePage> {
  final _repo = PublicProfileRepository();
  final _follows = FollowRepository();

  late PublicProfile _p = widget.profile;

  /// Null until the first fetch lands, which is what tells the actions row
  /// apart from "this is you" — both of which draw no Follow button, and only
  /// one of which should ever start drawing one.
  bool? _loaded;
  String? _error;

  /// Follow is optimistic; this keeps a second tap from racing the first.
  bool _busyFollowing = false;
  bool _openingChat = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final fetched = await _repo.getProfile(widget.profile.id);
      if (!mounted) return;
      setState(() {
        _p = _p.mergedWith(fetched);
        _loaded = true;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      // The seed already names the person, so a failure only costs the bio and
      // the counts — unless there is no profile at all, which is the one case
      // worth taking the screen over.
      final gone = e is NotFoundException;
      setState(() {
        _loaded = !gone;
        _error = gone ? e.message : null;
      });
    }
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _toggleFollow() async {
    if (_busyFollowing) return;
    final wasFollowing = _p.isFollowedByMe;
    setState(() {
      _busyFollowing = true;
      _p = _withFollow(!wasFollowing, wasFollowing ? -1 : 1);
    });
    try {
      wasFollowing
          ? await _follows.unfollowClient(_p.id)
          : await _follows.followClient(_p.id);
    } catch (e) {
      if (!mounted) return;
      setState(() => _p = _withFollow(wasFollowing, wasFollowing ? 1 : -1));
      AppSnackBar.error(
        context,
        wasFollowing ? 'Could not unfollow.' : 'Could not follow.',
      );
    } finally {
      if (mounted) setState(() => _busyFollowing = false);
    }
  }

  /// The button and the figure under it move together — a Follow that left the
  /// count behind reads as a tap that did not register.
  PublicProfile _withFollow(bool following, int delta) => PublicProfile(
        id: _p.id,
        name: _p.name,
        username: _p.username,
        photoUrl: _p.photoUrl,
        bio: _p.bio,
        location: _p.location,
        verified: _p.verified,
        followers: (_p.followers + delta).clamp(0, 1 << 31),
        following: _p.following,
        isFollowedByMe: following,
        isMe: _p.isMe,
      );

  Future<void> _openDirectChat() async {
    if (_openingChat) return;
    setState(() => _openingChat = true);

    ChatRoomsBloc? roomsBloc;
    try {
      roomsBloc = context.read<ChatRoomsBloc>();
    } catch (_) {}

    try {
      final room = await sl<GetOrCreateDirectRoomUseCase>().call(
        recipientId: _p.id,
        recipientRole: ChatConfig.roleClient,
        localDisplayName: _p.name,
      );
      if (!mounted) return;
      setState(() => _openingChat = false);
      roomsBloc?.add(const ChatRoomsLoadRequested());
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ChatRoomPage(room: room)),
      );
      if (mounted) roomsBloc?.add(const ChatRoomsLoadRequested());
    } catch (e) {
      if (!mounted) return;
      setState(() => _openingChat = false);
      // The use case already asked whether this person takes messages; this is
      // the answer changing underneath, or the network.
      final code = e is ApiException ? e.code : null;
      AppSnackBar.error(
        context,
        code == 'RECIPIENT_NOT_ACCEPTING_DMS' || code == 'USER_BLOCKED'
            ? 'This person is not accepting new conversations.'
            : 'Could not open chat. Try again.',
      );
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return Scaffold(
      backgroundColor: ext.homeBackground,
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        leading: const AppBackButton(),
        title: Text(
          _p.name,
          style: TextStyle(
            color: ext.greetingColor,
            fontWeight: FontWeight.w700,
            fontFamily: AppTypography.displayFontFamily,
            fontSize: 16.sp,
          ),
        ),
      ),
      body: _error != null
          ? AppErrorView(message: _error!, onRetry: _load)
          : ListView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg.w,
                AppSpacing.lg.h,
                AppSpacing.lg.w,
                AppSpacing.xxl.h,
              ),
              children: [
                _Identity(profile: _p, ext: ext),
                SizedBox(height: AppSpacing.lg.h),
                _Stats(profile: _p, ext: ext),
                // Hidden until the fetch says whose profile this is: a Follow
                // button that appears and then vanishes on your own profile is
                // worse than one that arrives a moment late.
                if (_loaded == true && !_p.isMe) ...[
                  SizedBox(height: AppSpacing.lg.h),
                  Row(
                    children: [
                      Expanded(
                        child: _PillButton(
                          ext: ext,
                          icon: _p.isFollowedByMe
                              ? Icons.person_remove_alt_1_outlined
                              : Icons.person_add_alt_1_outlined,
                          label: _p.isFollowedByMe ? 'Following' : 'Follow',
                          filled: _p.isFollowedByMe,
                          onTap: _toggleFollow,
                        ),
                      ),
                      SizedBox(width: AppSpacing.md.w),
                      Expanded(
                        child: _PillButton(
                          ext: ext,
                          icon: Icons.chat_bubble_outline_rounded,
                          label: 'Message',
                          filled: false,
                          onTap: _openDirectChat,
                        ),
                      ),
                    ],
                  ),
                ],
                if (_p.bio.isNotEmpty) ...[
                  SizedBox(height: AppSpacing.xl.h),
                  const AppSectionLabel('Bio'),
                  SizedBox(height: AppSpacing.sm.h),
                  Text(
                    _p.bio,
                    style: TextStyle(
                      color: ext.searchHintColor,
                      fontSize: 13.sp,
                      height: 1.45,
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

// ── Header ───────────────────────────────────────────────────────────────────

/// Face, name, handle and location, stacked and centred.
///
/// Centred rather than the creator profile's left-aligned row: that row is
/// balanced by a rating pill on the right, and without one a left-aligned
/// avatar leaves the top of the screen lopsided.
class _Identity extends StatelessWidget {
  const _Identity({required this.profile, required this.ext});

  final PublicProfile profile;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      if (profile.username.isNotEmpty) '@${profile.username}',
      if (profile.location.isNotEmpty) profile.location,
    ].join(' · ');

    return Column(
      children: [
        UserAvatar(
          initial: profile.name,
          imageUrl: profile.photoUrl,
          radius: 40,
        ),
        SizedBox(height: AppSpacing.md.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                profile.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: ext.greetingColor,
                  fontFamily: AppTypography.displayFontFamily,
                  fontSize: 19.sp,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            if (profile.verified) ...[
              SizedBox(width: 4.w),
              Icon(Icons.verified_rounded, size: 16.r, color: ext.infoBlue),
            ],
          ],
        ),
        if (subtitle.isNotEmpty) ...[
          SizedBox(height: 4.h),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: ext.searchHintColor, fontSize: 13.sp),
          ),
        ],
      ],
    );
  }
}

/// Followers and Following, side by side with a hairline between them.
class _Stats extends StatelessWidget {
  const _Stats({required this.profile, required this.ext});

  final PublicProfile profile;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _Figure(value: profile.followers, label: 'Followers', ext: ext),
        Container(
          width: 0.7,
          height: 28.h,
          margin: EdgeInsets.symmetric(horizontal: AppSpacing.xl.w),
          color: ext.searchHintColor.withValues(alpha: 0.25),
        ),
        _Figure(value: profile.following, label: 'Following', ext: ext),
      ],
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.value, required this.label, required this.ext});

  final int value;
  final String label;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$value $label',
      child: Column(
        children: [
          Text(
            // Same abbreviation as every other count in the app — 1.2K, not
            // 1200.
            compactCount(value),
            style: TextStyle(
              color: ext.greetingColor,
              fontSize: 16.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            label,
            style: TextStyle(color: ext.searchHintColor, fontSize: 12.sp),
          ),
        ],
      ),
    );
  }
}

/// The same outlined pill the creator profile uses for Follow and Message, so
/// the two profiles do not grow different buttons for the same two actions.
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

  /// Filled marks the state you are already in — following.
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
