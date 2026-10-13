import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/common/widgets/profile_pill_button.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/follow/data/follow_repository.dart';
import 'package:jperg_app/services/auth_service.dart';

/// What a profile you are looking at lets you do about it.
///
/// One widget for both profile screens, because "which buttons does a profile
/// carry" is one question and it was being answered in two places that had
/// already drifted apart. A creator's profile offered Follow and Message but
/// *dropped* Message entirely when the person was not taking new conversations,
/// and drew nothing at all until an ownership check came back from storage; a
/// person's profile offered Follow and Message unconditionally and waited for
/// the profile fetch before drawing either. So the same account could be
/// reached two ways and offer two different things, and the commonest report
/// was the honest reading of it: "there is no Message button on this
/// photographer".
///
/// Three rules, and they hold on every surface that opens a profile — search
/// (any chip), a comment thread, the feed, Following, a deep link:
///
///  1. **Your own profile offers nothing.** Following yourself is refused by
///     the API and messaging yourself has nowhere to go.
///  2. **A creator gets Follow and Message. A person gets Message alone.**
///     Following is a creator relationship — it feeds the Following tab, which
///     exists to show you work — so following somebody who posts nothing
///     subscribes you to nothing. See [isCreator].
///  3. **Message is always drawn, and dimmed when it would fail.** It is never
///     removed: absent is indistinguishable from still-loading, which is what
///     made a creator with DMs switched off look like a bug.
///
/// All of it on the first frame. Nothing here waits on a request — ownership
/// comes from the id the session already holds, and the follow state from the
/// set [FollowRepository] keeps — so the buttons do not arrive a beat after the
/// name, and are never drawn and then taken away.
class ProfileActions extends StatefulWidget {
  const ProfileActions({
    super.key,
    required this.userId,
    required this.ext,
    required this.isCreator,
    required this.onMessage,
    this.canMessage,
    this.isFollowedByMe,
    this.onFollowChanged,
  });

  /// Whose profile this is.
  final String userId;

  final AppThemeExtension ext;

  /// Whether this account is a creator, and so has a Follow button at all —
  /// rule 2 above. The caller knows: [CreatorProfilePage] is only ever opened
  /// for one, [PublicProfilePage] only ever for a person.
  final bool isCreator;

  final VoidCallback onMessage;

  /// The can-message check, or null while it is in flight.
  ///
  /// Null reads as *allowed*: the check is the common case answering yes, and a
  /// button that starts dimmed and brightens a moment later draws the eye to
  /// the one state nobody needs to notice. A refusal dims it when it lands.
  final bool? canMessage;

  /// The server's view of whether the viewer follows this creator, when the
  /// payload carried one. [FollowRepository]'s own set wins once it has an
  /// opinion — it is what every other follow control in the app reads.
  final bool? isFollowedByMe;

  /// Fires after a follow or unfollow settles, so a screen holding a follower
  /// count can move it.
  final ValueChanged<bool>? onFollowChanged;

  @override
  State<ProfileActions> createState() => _ProfileActionsState();
}

class _ProfileActionsState extends State<ProfileActions> {
  final _repo = FollowRepository();

  late bool _following = widget.isFollowedByMe ??
      FollowRepository.followedIds.contains(widget.userId);

  /// Stops a second tap from racing the first, which would post a follow and
  /// an unfollow for one intention.
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Following the same person from two screens at once is ordinary — the
    // feed card behind this one has its own button, and so does the creator
    // list.
    FollowRepository.followedRevision.addListener(_onFollowedChanged);
  }

  @override
  void dispose() {
    FollowRepository.followedRevision.removeListener(_onFollowedChanged);
    super.dispose();
  }

  void _onFollowedChanged() {
    final following = FollowRepository.followedIds.contains(widget.userId);
    if (mounted && following != _following) {
      setState(() => _following = following);
    }
  }

  /// Optimistic, and rolled back on failure: the button is the only feedback
  /// there is, so it has to answer on the tap.
  Future<void> _toggleFollow() async {
    if (_busy) return;
    final wasFollowing = _following;
    setState(() {
      _following = !wasFollowing;
      _busy = true;
    });
    try {
      wasFollowing
          ? await _repo.unfollow(widget.userId)
          : await _repo.follow(widget.userId);
      widget.onFollowChanged?.call(!wasFollowing);
    } catch (e) {
      debugPrint('[ProfileActions] follow ERROR: $e');
      if (mounted) setState(() => _following = wasFollowing);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Your own profile, decided from the id the session already holds rather
  /// than from the server's `isMe`.
  ///
  /// That is what makes rule 1 hold on the first frame. Waiting for a fetch
  /// means either drawing Follow on your own profile and removing it — a tap
  /// in that window posts a follow of yourself, which the API refuses — or
  /// drawing nothing on everybody's profile until the answer lands, which is
  /// the delay this replaced.
  bool get _isMe {
    final me = AuthService.userId.value;
    return me.isNotEmpty && me == widget.userId;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.userId.isEmpty || _isMe) return const SizedBox.shrink();

    final message = ProfilePillButton(
      ext: widget.ext,
      icon: Icons.chat_bubble_outline_rounded,
      label: 'Message',
      // Null is allowed — see [ProfileActions.canMessage].
      enabled: widget.canMessage ?? true,
      onTap: widget.onMessage,
    );

    // A person: Message alone, and centred. Stretched across the full width it
    // reads as the top half of a form whose other half failed to load; held to
    // half the width on one side it looks like a missing twin. Centred, it is
    // simply the one thing there is to do.
    if (!widget.isCreator) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(width: 0.5.sw, child: message),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: ProfilePillButton(
            ext: widget.ext,
            icon: _following
                ? Icons.person_remove_alt_1_outlined
                : Icons.person_add_alt_1_outlined,
            label: _following ? 'Following' : 'Follow',
            filled: _following,
            onTap: _toggleFollow,
          ),
        ),
        SizedBox(width: AppSpacing.md.w),
        Expanded(child: message),
      ],
    );
  }
}
