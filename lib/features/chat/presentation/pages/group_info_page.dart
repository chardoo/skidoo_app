import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/core/utils/snackbar_utils.dart';
import 'package:skidoo_app/features/chat/presentation/bloc/room/chat_room_bloc.dart';
import 'package:skidoo_app/models/chat/chat_room.dart';

/// WhatsApp-style group info page.
///
/// Requires [ChatRoomBloc] to be in scope (passed via BlocProvider.value
/// from the parent [ChatRoomPage]).
class GroupInfoPage extends StatelessWidget {
  const GroupInfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return Scaffold(
      backgroundColor: ext.homeBackground,
      appBar: AppBar(
        backgroundColor: ext.homeBackground,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded,
              color: ext.greetingColor, size: 18.sp),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Group info',
          style: TextStyle(
            color: ext.greetingColor,
            fontWeight: FontWeight.bold,
            fontSize: 17.sp,
          ),
        ),
      ),
      body: BlocConsumer<ChatRoomBloc, ChatRoomState>(
        listenWhen: (p, c) => p.errorMessage != c.errorMessage,
        listener: (context, state) {
          if (state.errorMessage != null) {
            AppSnackBar.error(context, state.errorMessage!);
          }
        },
        buildWhen: (p, c) =>
            p.room != c.room || p.amIAdmin != c.amIAdmin,
        builder: (context, state) {
          final room = state.room;
          if (room == null) {
            return Center(
              child: Text('No group data.',
                  style: TextStyle(
                      color: ext.searchHintColor, fontSize: 14.sp)),
            );
          }

          final activeParticipants = room.participants
              .where((p) => !p.isPending)
              .toList()
            ..sort((a, b) {
              if (a.isAdmin && !b.isAdmin) return -1;
              if (!a.isAdmin && b.isAdmin) return 1;
              return a.displayName.compareTo(b.displayName);
            });

          return ListView(
            padding: EdgeInsets.only(bottom: 32.h),
            children: [
              // ── Header ─────────────────────────────────────────────────────
              _GroupHeader(room: room, ext: ext),

              SizedBox(height: 8.h),

              // ── Admin-only mode toggle ──────────────────────────────────────
              if (state.amIAdmin)
                _SettingsSection(
                  adminOnly: room.adminOnly,
                  ext: ext,
                  onToggle: (value) => context
                      .read<ChatRoomBloc>()
                      .add(ChatRoomUpdateSettingsRequested(value)),
                ),

              if (state.amIAdmin) SizedBox(height: 8.h),

              // ── Participants list ───────────────────────────────────────────
              Padding(
                padding:
                    EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                child: Text(
                  '${activeParticipants.length} participant${activeParticipants.length == 1 ? '' : 's'}',
                  style: TextStyle(
                    color: ext.accentGold,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                  ),
                ),
              ),

              Container(
                decoration: BoxDecoration(
                  color: ext.cardSurface,
                ),
                child: Column(
                  children: [
                    for (int i = 0; i < activeParticipants.length; i++) ...[
                      _ParticipantTile(
                        participant: activeParticipants[i],
                        isSelf: activeParticipants[i].userId ==
                            state.myUserId,
                        amIAdmin: state.amIAdmin,
                        ext: ext,
                        onGrantAdmin: () => context
                            .read<ChatRoomBloc>()
                            .add(ChatRoomGrantAdminRequested(
                                activeParticipants[i].userId)),
                        onRevokeAdmin: () => context
                            .read<ChatRoomBloc>()
                            .add(ChatRoomRevokeAdminRequested(
                                activeParticipants[i].userId)),
                        onKick: () => context
                            .read<ChatRoomBloc>()
                            .add(ChatRoomKickRequested(
                                activeParticipants[i].userId)),
                      ),
                      if (i < activeParticipants.length - 1)
                        Divider(
                          height: 1,
                          indent: 68.w,
                          color:
                              ext.searchHintColor.withValues(alpha: 0.1),
                        ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.room, required this.ext});

  final ChatRoom room;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ext.cardSurface,
      padding: EdgeInsets.symmetric(vertical: 24.h),
      child: Column(
        children: [
          Container(
            width: 80.w,
            height: 80.w,
            decoration: BoxDecoration(
              color: ext.accentGold.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(Icons.group_rounded,
                color: ext.accentGold, size: 40.sp),
          ),
          SizedBox(height: 14.h),
          Text(
            room.displayName,
            style: TextStyle(
              color: ext.greetingColor,
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 4.h),
          Text(
            'Group',
            style:
                TextStyle(color: ext.searchHintColor, fontSize: 12.sp),
          ),
        ],
      ),
    );
  }
}

// ── Settings section ──────────────────────────────────────────────────────────

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.adminOnly,
    required this.ext,
    required this.onToggle,
  });

  final bool adminOnly;
  final AppThemeExtension ext;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ext.cardSurface,
      child: SwitchListTile(
        contentPadding:
            EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
        title: Text(
          'Only admins can send messages',
          style:
              TextStyle(color: ext.greetingColor, fontSize: 14.sp),
        ),
        subtitle: Text(
          adminOnly
              ? 'Only admins can send messages in this group.'
              : 'All members can send messages.',
          style: TextStyle(
              color: ext.searchHintColor, fontSize: 12.sp),
        ),
        value: adminOnly,
        activeThumbColor: ext.accentGold,
        activeTrackColor: ext.accentGold.withValues(alpha: 0.4),
        onChanged: onToggle,
      ),
    );
  }
}

// ── Participant tile ──────────────────────────────────────────────────────────

class _ParticipantTile extends StatelessWidget {
  const _ParticipantTile({
    required this.participant,
    required this.isSelf,
    required this.amIAdmin,
    required this.ext,
    required this.onGrantAdmin,
    required this.onRevokeAdmin,
    required this.onKick,
  });

  final ChatParticipant participant;
  final bool isSelf;
  final bool amIAdmin;
  final AppThemeExtension ext;
  final VoidCallback onGrantAdmin;
  final VoidCallback onRevokeAdmin;
  final VoidCallback onKick;

  String get _initial {
    final name = participant.displayName;
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  void _showOptions(BuildContext context) {
    if (!amIAdmin || isSelf) return;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ParticipantOptionsSheet(
        participant: participant,
        ext: ext,
        onGrantAdmin: () {
          Navigator.pop(context);
          onGrantAdmin();
        },
        onRevokeAdmin: () {
          Navigator.pop(context);
          onRevokeAdmin();
        },
        onKick: () {
          Navigator.pop(context);
          onKick();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: amIAdmin && !isSelf ? () => _showOptions(context) : null,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22.r,
              backgroundColor: ext.accentGold.withValues(alpha: 0.15),
              child: Text(
                _initial,
                style: TextStyle(
                  color: ext.accentGold,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          participant.displayName,
                          style: TextStyle(
                            color: ext.greetingColor,
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isSelf) ...[
                        SizedBox(width: 6.w),
                        Text(
                          '(you)',
                          style: TextStyle(
                              color: ext.searchHintColor,
                              fontSize: 12.sp),
                        ),
                      ],
                    ],
                  ),
                  // Only show role as subtitle when a real name is present —
                  // otherwise displayName already shows the capitalised role.
                  if (participant.userName != null &&
                      participant.userName!.isNotEmpty)
                    Text(
                      _capitalise(participant.userRole),
                      style: TextStyle(
                          color: ext.searchHintColor, fontSize: 12.sp),
                    ),
                ],
              ),
            ),
            if (participant.isAdmin)
              Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: ext.accentGold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6.r),
                ),
                child: Text(
                  'Admin',
                  style: TextStyle(
                    color: ext.accentGold,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Participant options sheet ──────────────────────────────────────────────────

class _ParticipantOptionsSheet extends StatelessWidget {
  const _ParticipantOptionsSheet({
    required this.participant,
    required this.ext,
    required this.onGrantAdmin,
    required this.onRevokeAdmin,
    required this.onKick,
  });

  final ChatParticipant participant;
  final AppThemeExtension ext;
  final VoidCallback onGrantAdmin;
  final VoidCallback onRevokeAdmin;
  final VoidCallback onKick;

  String get _initial {
    final name = participant.displayName;
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 36.h),
      decoration: BoxDecoration(
        color: ext.cardSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 36.w,
              height: 4.h,
              margin: EdgeInsets.only(bottom: 18.h),
              decoration: BoxDecoration(
                color: ext.searchHintColor.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
          ),

          // ── Participant header ─────────────────────────────────────────────
          Row(
            children: [
              CircleAvatar(
                radius: 24.r,
                backgroundColor: ext.accentGold.withValues(alpha: 0.15),
                child: Text(
                  _initial,
                  style: TextStyle(
                    color: ext.accentGold,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(width: 14.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    participant.displayName,
                    style: TextStyle(
                      color: ext.greetingColor,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (participant.userName != null &&
                      participant.userName!.isNotEmpty)
                    Text(
                      _capitalise(participant.userRole),
                      style: TextStyle(
                          color: ext.searchHintColor, fontSize: 12.sp),
                    ),
                ],
              ),
            ],
          ),

          SizedBox(height: 16.h),
          Divider(color: ext.searchHintColor.withValues(alpha: 0.12)),
          SizedBox(height: 4.h),

          // ── Admin toggle ───────────────────────────────────────────────────
          if (!participant.isAdmin)
            _SheetOption(
              icon: Icons.shield_rounded,
              label: 'Make group admin',
              color: ext.accentGold,
              onTap: onGrantAdmin,
            )
          else
            _SheetOption(
              icon: Icons.shield_outlined,
              label: 'Remove as admin',
              color: Colors.orangeAccent,
              onTap: onRevokeAdmin,
            ),

          // ── Kick ──────────────────────────────────────────────────────────
          _SheetOption(
            icon: Icons.person_remove_outlined,
            label: 'Remove from group',
            color: Colors.redAccent,
            onTap: onKick,
          ),
        ],
      ),
    );
  }
}

String _capitalise(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

class _SheetOption extends StatelessWidget {
  const _SheetOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 4.w),
        child: Row(
          children: [
            Container(
              width: 40.w,
              height: 40.w,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10.r),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: color, size: 20.sp),
            ),
            SizedBox(width: 14.w),
            Text(
              label,
              style: TextStyle(
                color: ext.greetingColor,
                fontSize: 15.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
