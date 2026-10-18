import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/common/widgets/app_widgets.dart';
import 'package:jperg_app/core/config/chat_config.dart';
import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/core/error/exceptions.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/theme/app_typography.dart';
import 'package:jperg_app/core/utils/snackbar_utils.dart';
import 'package:jperg_app/features/chat/data/datasources/chat_rest_data_source.dart'
    show CanMessageResult;
import 'package:jperg_app/features/chat/domain/usecases/chat_usecases.dart';
import 'package:jperg_app/features/chat/presentation/bloc/rooms/chat_rooms_bloc.dart';
import 'package:jperg_app/features/chat/presentation/pages/chat_room_page.dart';
import 'package:jperg_app/features/user_profile/data/repositories/public_profile_repository.dart';
import 'package:jperg_app/features/user_profile/presentation/widgets/profile_actions.dart';
import 'package:jperg_app/features/user_profile/presentation/widgets/profile_more_options_sheet.dart';
import 'package:jperg_app/core/common/widgets/verified_badge.dart';

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

  late PublicProfile _p = widget.profile;

  String? _error;

  /// The can-message answer, or null while it is in flight.
  ///
  /// This screen never asked, so its Message button could not be dimmed for
  /// somebody who takes no DMs — it was drawn live and failed on the tap with
  /// a snackbar. The creator profile had asked all along; asking here is what
  /// makes the two agree.
  CanMessageResult? _canMsg;

  bool _openingChat = false;

  @override
  void initState() {
    super.initState();
    _load();
    _checkCanMessage();
  }

  /// Asked before the button is drawn rather than after it is pressed. The
  /// server's error codes stay the authority — the setting can change in
  /// between — which is what [_openDirectChat] still reports on.
  Future<void> _checkCanMessage() async {
    try {
      final result = await sl<CanMessageUseCase>().call(widget.profile.id);
      if (mounted) setState(() => _canMsg = result);
    } catch (_) {
      // Allowed: a check that could not be made must not take the button away.
      if (mounted) setState(() => _canMsg = CanMessageResult.allowed());
    }
  }

  Future<void> _load() async {
    try {
      final fetched = await _repo.getProfile(widget.profile.id);
      if (!mounted) return;
      setState(() {
        _p = _p.mergedWith(fetched);
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      // The seed already names the person, so a failure only costs the bio and
      // the counts — unless there is no profile at all, which is the one case
      // worth taking the screen over.
      final gone = e is NotFoundException;
      setState(() => _error = gone ? e.message : null);
    }
  }

  // ── Actions ────────────────────────────────────────────────────────────────


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
        // Block and Report. Not on your own profile — see
        // [ProfileOverflowButton].
        actions: [
          ProfileOverflowButton(ext: ext, userId: _p.id, name: _p.name),
        ],
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
                // Message alone, centred, from the first frame — and no
                // Follow and no follower figures, which is the one way this
                // screen differs from a creator's. Following is a creator
                // relationship: it feeds the Following tab, which exists to
                // show you work, so following somebody who posts nothing
                // subscribes you to nothing and the two zeroes under their
                // name were a scoreboard for a game they are not playing.
                //
                // It used to wait on `_loaded == true`, so every button on
                // every profile arrived a beat after the rest of the page.
                // [ProfileActions] knows whose profile this is without asking
                // anybody. See the rules on it.
                ProfileActions(
                  userId: _p.id,
                  ext: ext,
                  isCreator: false,
                  canMessage: _canMsg?.canMessage,
                  onMessage: _openDirectChat,
                ),
                if (_p.bio.isNotEmpty) ...[
                  SizedBox(height: AppSpacing.xl.h),
                  const AppSectionLabel('Bio'),
                  SizedBox(height: AppSpacing.sm.h),
                  Text(
                    _p.bio,
                    style: TextStyle(
                      color: ext.searchHintColor,
                      fontSize: 14.sp,
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
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (profile.verified) ...[
              SizedBox(width: 4.w),
              const VerifiedBadge(),
            ],
          ],
        ),
        if (subtitle.isNotEmpty) ...[
          SizedBox(height: 4.h),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: ext.searchHintColor, fontSize: 14.sp),
          ),
        ],
      ],
    );
  }
}
