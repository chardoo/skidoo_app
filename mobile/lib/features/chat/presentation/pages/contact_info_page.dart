import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/common/widgets/app_back_button.dart';
import 'package:jperg_app/core/common/widgets/user_avatar.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/utils/web_panel_route.dart';
import 'package:jperg_app/core/utils/web_wrap.dart';
import 'package:jperg_app/features/chat/presentation/bloc/room/chat_room_bloc.dart';
import 'package:jperg_app/features/chat/presentation/pages/shared_media_page.dart';
import 'package:jperg_app/features/chat/presentation/widgets/chat_settings_tile.dart';
import 'package:jperg_app/models/chat/chat_room.dart';

/// Details for a one-to-one conversation: who it is with, shared media, mute,
/// and blocking.
///
/// Requires [ChatRoomBloc] in scope — pushed with a BlocProvider.value from
/// [ChatRoomPage], so mute reflects and updates the same state the room holds.
class ContactInfoPage extends StatelessWidget {
  const ContactInfoPage({
    super.key,
    required this.isBlocked,
    required this.canBlock,
    required this.onToggleBlock,
  });

  /// Listened to rather than read once: this page is a separate route from the
  /// conversation that owns the block state, so a plain bool would freeze at
  /// whatever it was when the page was pushed.
  final ValueListenable<bool> isBlocked;

  /// False for the super admin's account, which is never blockable.
  final bool canBlock;
  final VoidCallback onToggleBlock;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    final page = Scaffold(
      backgroundColor: ext.homeBackground,
      appBar: AppBar(
        backgroundColor: ext.homeBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: const AppBackButton(),
        title: Text(
          'Contact Info',
          style: TextStyle(
            color: ext.greetingColor,
            fontWeight: FontWeight.bold,
            fontSize: 17.sp,
          ),
        ),
      ),
      body: BlocBuilder<ChatRoomBloc, ChatRoomState>(
        buildWhen: (p, c) =>
            p.room != c.room || p.isMuted != c.isMuted || p.myUserId != c.myUserId,
        builder: (context, state) {
          final room = state.room;
          if (room == null) {
            return Center(
              child: Text('No contact data.',
                  style:
                      TextStyle(color: ext.searchHintColor, fontSize: 14.sp)),
            );
          }

          final peer = room.othersFor(state.myUserId).firstOrNull;

          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: ListView(
                padding: EdgeInsets.only(bottom: AppSpacing.xxxl.h),
                children: [
                  SizedBox(height: AppSpacing.lg.h),
                  _ContactHeader(
                    name: room.displayNameFor(state.myUserId),
                    imageUrl: peer?.userImage,
                    subtitle: _roleLabel(peer),
                  ),
                  SizedBox(height: AppSpacing.xxl.h),

                  const ChatSettingsLabel(label: 'CHAT SETTINGS'),
                  SizedBox(height: AppSpacing.sm.h),
                  ChatSettingsCard(
                    children: [
                      ChatSettingsTile(
                        label: 'Shared Media',
                        trailing: Icon(Icons.chevron_right_rounded,
                            color: ext.searchHintColor, size: 22.sp),
                        onTap: () => _openSharedMedia(context, room),
                      ),
                      ChatSettingsTile(
                        label: 'Mute Notifications',
                        trailing: Switch(
                          value: state.isMuted,
                          activeThumbColor: Colors.white,
                          activeTrackColor: ext.accentGold,
                          onChanged: (value) => context
                              .read<ChatRoomBloc>()
                              .add(ChatRoomMuteToggled(value)),
                        ),
                      ),
                      if (canBlock)
                        ValueListenableBuilder<bool>(
                          valueListenable: isBlocked,
                          builder: (_, blocked, __) => ChatSettingsTile(
                            label: blocked ? 'Unblock User' : 'Block User',
                            labelColor: ext.errorRed,
                            onTap: onToggleBlock,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    return webWrap(page, backgroundColor: ext.homeBackground);
  }

  void _openSharedMedia(BuildContext context, ChatRoom room) {
    showWebPanelPage<void>(context, SharedMediaPage(roomId: room.id));
  }

  /// The designs show a location here. The chat service has no profile data, so
  /// the participant's role is what is actually knowable at this point.
  static String? _roleLabel(ChatParticipant? peer) {
    final role = peer?.userRole ?? '';
    if (role.isEmpty) return null;
    if (role == 'photographer') return 'Photographer';
    if (role == 'admin' || role == 'superAdmin') return 'Jperg Admin';
    return null;
  }
}

class _ContactHeader extends StatelessWidget {
  const _ContactHeader({
    required this.name,
    required this.imageUrl,
    required this.subtitle,
  });

  final String name;
  final String? imageUrl;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return Column(
      children: [
        UserAvatar(imageUrl: imageUrl, initial: name, radius: 48),
        SizedBox(height: AppSpacing.md.h),
        Text(
          name,
          style: TextStyle(
            color: ext.greetingColor,
            fontSize: 19.sp,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        if (subtitle != null) ...[
          SizedBox(height: 2.h),
          Text(
            subtitle!,
            style: TextStyle(color: ext.searchHintColor, fontSize: 13.sp),
          ),
        ],
      ],
    );
  }
}
