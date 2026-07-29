import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/common/widgets/app_button.dart';
import 'package:skidoo_app/core/common/widgets/app_confirm_dialog.dart';
import 'package:skidoo_app/core/common/widgets/app_text_field.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/core/utils/snackbar_utils.dart';
import 'package:skidoo_app/features/chat/presentation/bloc/room/chat_room_bloc.dart';
import 'package:skidoo_app/features/chat/presentation/pages/invite_to_group_page.dart';
import 'package:skidoo_app/models/chat/chat_room.dart';
import 'package:skidoo_app/core/utils/web_panel_route.dart';
import 'package:skidoo_app/core/utils/web_wrap.dart';
import 'package:skidoo_app/core/theme/app_radius.dart';
import 'package:skidoo_app/core/theme/app_spacing.dart';

/// WhatsApp-style group info page.
///
/// Requires [ChatRoomBloc] to be in scope (passed via BlocProvider.value
/// from the parent [ChatRoomPage]).
class GroupInfoPage extends StatelessWidget {
  const GroupInfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    final page = Scaffold(
      backgroundColor: ext.homeBackground,
      appBar: AppBar(
        backgroundColor: ext.homeBackground,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Back',
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
            p.room != c.room ||
            p.amIAdmin != c.amIAdmin ||
            p.isLeaving != c.isLeaving ||
            p.isDeleting != c.isDeleting,
        builder: (context, state) {
          final room = state.room;
          if (room == null) {
            return Center(
              child: Text('No group data.',
                  style:
                      TextStyle(color: ext.searchHintColor, fontSize: 14.sp)),
            );
          }

          final allParticipants = room.participants.toList()
            ..sort((a, b) {
              // Active before pending, then admins before members, then alpha.
              if (a.isPending != b.isPending) return a.isPending ? 1 : -1;
              if (a.isAdmin && !b.isAdmin) return -1;
              if (!a.isAdmin && b.isAdmin) return 1;
              return a.displayName.compareTo(b.displayName);
            });
          final activeCount =
              room.participants.where((p) => !p.isPending).length;
          final pendingCount =
              room.participants.where((p) => p.isPending).length;

          return ListView(
            padding: EdgeInsets.only(bottom: AppSpacing.xxxl.h),
            children: [
              // ── Header ─────────────────────────────────────────────────────
              _GroupHeader(room: room, ext: ext),

              SizedBox(height: AppSpacing.sm.h),

              // ── Admin-only mode toggle ──────────────────────────────────────
              if (state.amIAdmin) ...[
                _RenameSection(room: room, ext: ext),
                SizedBox(height: AppSpacing.sm.h),
                _SettingsSection(
                  adminOnly: room.adminOnly,
                  ext: ext,
                  onToggle: (value) => context
                      .read<ChatRoomBloc>()
                      .add(ChatRoomUpdateSettingsRequested(adminOnly: value)),
                ),
                SizedBox(height: AppSpacing.sm.h),
              ],

              // ── Participants list ───────────────────────────────────────────
              Padding(
                padding: EdgeInsets.fromLTRB(16.w, 10.h, 8.w, 4.h),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        pendingCount > 0
                            ? '$activeCount participant${activeCount == 1 ? '' : 's'} · $pendingCount pending'
                            : '$activeCount participant${activeCount == 1 ? '' : 's'}',
                        style: TextStyle(
                          color: ext.searchHintColor,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        // Open "add people" inside the same web panel; full
                        // page on mobile.
                        final count = await showWebPanelPage<int>(
                          context,
                          InviteToGroupPage(room: room),
                        );
                        if (!context.mounted || count == null) return;
                        AppSnackBar.success(
                          context,
                          '$count ${count == 1 ? 'person' : 'people'} invited',
                        );
                      },
                      icon: Icon(Icons.person_add_outlined,
                          size: 15.sp, color: ext.accentGold),
                      label: Text(
                        'Add',
                        style:
                            TextStyle(color: ext.accentGold, fontSize: 13.sp),
                      ),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm.w,
                            vertical: AppSpacing.xs.h),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ),

              Container(
                decoration: BoxDecoration(
                  color: ext.cardSurface,
                ),
                child: Column(
                  children: [
                    for (int i = 0; i < allParticipants.length; i++) ...[
                      _ParticipantTile(
                        participant: allParticipants[i],
                        isSelf: allParticipants[i].userId == state.myUserId,
                        amIAdmin: state.amIAdmin,
                        ext: ext,
                        onGrantAdmin: () => context.read<ChatRoomBloc>().add(
                            ChatRoomGrantAdminRequested(
                                allParticipants[i].userId)),
                        onRevokeAdmin: () => context.read<ChatRoomBloc>().add(
                            ChatRoomRevokeAdminRequested(
                                allParticipants[i].userId)),
                        onKick: () => context.read<ChatRoomBloc>().add(
                            ChatRoomKickRequested(allParticipants[i].userId)),
                      ),
                      if (i < allParticipants.length - 1)
                        Divider(
                          height: 1,
                          indent: 68.w,
                          color: ext.searchHintColor.withValues(alpha: 0.1),
                        ),
                    ],
                  ],
                ),
              ),

              // ── Leave / Delete group ───────────────────────────────────────
              SizedBox(height: AppSpacing.xxl.h),
              _LeaveGroupButton(
                isLeaving: state.isLeaving,
                ext: ext,
                onLeave: () => _confirmLeave(context, ext),
              ),
              if (state.amIAdmin) ...[
                SizedBox(height: AppSpacing.md.h),
                _DeleteGroupButton(
                  isDeleting: state.isDeleting,
                  ext: ext,
                  onDelete: () => _confirmDelete(context, ext),
                ),
              ],
              SizedBox(height: AppSpacing.sm.h),
            ],
          );
        },
      ),
    );
    return webWrap(page, backgroundColor: ext.homeBackground);
  }

  Future<void> _confirmLeave(
      BuildContext context, AppThemeExtension ext) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Leave group?',
      message: 'You will no longer receive messages from this group.',
      confirmLabel: 'Leave',
      isDestructive: true,
    );
    if (confirmed && context.mounted) {
      context.read<ChatRoomBloc>().add(const ChatRoomLeaveGroupRequested());
    }
  }

  Future<void> _confirmDelete(
      BuildContext context, AppThemeExtension ext) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Delete group?',
      message:
          'This will permanently delete the group and all its messages for everyone. This cannot be undone.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (confirmed && context.mounted) {
      context.read<ChatRoomBloc>().add(const ChatRoomDeleteRequested());
    }
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
      padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl.h),
      child: Column(
        children: [
          Container(
            width: 80.w,
            height: 80.w,
            decoration: BoxDecoration(
              color: ext.searchFieldFill,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(Icons.group_rounded,
                color: ext.greetingColor, size: 40.sp),
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
          SizedBox(height: AppSpacing.xs.h),
          Text(
            'Group',
            style: TextStyle(color: ext.searchHintColor, fontSize: 12.sp),
          ),
        ],
      ),
    );
  }
}

// ── Rename section ────────────────────────────────────────────────────────────

class _RenameSection extends StatefulWidget {
  const _RenameSection({required this.room, required this.ext});

  final ChatRoom room;
  final AppThemeExtension ext;

  @override
  State<_RenameSection> createState() => _RenameSectionState();
}

class _RenameSectionState extends State<_RenameSection> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.room.name ?? '');
  }

  @override
  void didUpdateWidget(_RenameSection old) {
    super.didUpdateWidget(old);
    // Sync when a WS update changes the name from outside.
    if (old.room.name != widget.room.name) {
      _ctrl.text = widget.room.name ?? '';
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _save(BuildContext context) {
    final trimmed = _ctrl.text.trim();
    if (trimmed.isEmpty || trimmed == (widget.room.name ?? '')) return;
    context
        .read<ChatRoomBloc>()
        .add(ChatRoomUpdateSettingsRequested(name: trimmed));
  }

  @override
  Widget build(BuildContext context) {
    final ext = widget.ext;
    return Container(
      color: ext.cardSurface,
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 16.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'GROUP NAME',
            style: TextStyle(
              color: ext.searchHintColor,
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(height: 10.h),
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  controller: _ctrl,
                  dense: true,
                  hint: 'Enter group name',
                  onFieldSubmitted: (_) => _save(context),
                ),
              ),
              SizedBox(width: 10.w),
              AppButton(
                label: 'Save',
                width: 80,
                height: 40,
                onPressed: () => _save(context),
              ),
            ],
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
    // Material rather than a coloured Container — SwitchListTile paints its
    // background and ink onto the nearest Material ancestor, which a plain
    // ColoredBox in between would hide (and assert about in debug).
    return Material(
      color: ext.cardSurface,
      child: SwitchListTile(
        contentPadding: EdgeInsets.symmetric(
            horizontal: AppSpacing.lg.w, vertical: AppSpacing.xs.h),
        title: Text(
          'Only admins can send messages',
          style: TextStyle(color: ext.greetingColor, fontSize: 14.sp),
        ),
        subtitle: Text(
          adminOnly
              ? 'Only admins can send messages in this group.'
              : 'All members can send messages.',
          style: TextStyle(color: ext.searchHintColor, fontSize: 12.sp),
        ),
        value: adminOnly,
        activeThumbColor: ext.greetingColor,
        activeTrackColor: ext.searchHintColor.withValues(alpha: 0.4),
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
    return Semantics(
        button: true,
        label: 'Show options',
        child: InkWell(
          onTap: amIAdmin && !isSelf ? () => _showOptions(context) : null,
          child: Padding(
            padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.lg.w, vertical: 10.h),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22.r,
                  backgroundColor: ext.searchFieldFill,
                  child: Text(
                    _initial,
                    style: TextStyle(
                      color: ext.greetingColor,
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
                                  color: ext.searchHintColor, fontSize: 12.sp),
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
                if (participant.isPending)
                  Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm.w, vertical: 3.h),
                    decoration: BoxDecoration(
                      color: ext.searchHintColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                    child: Text(
                      'Pending',
                      style: TextStyle(
                        color: ext.searchHintColor,
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )
                else if (participant.isAdmin)
                  Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm.w, vertical: 3.h),
                    decoration: BoxDecoration(
                      color: ext.infoBlue.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                    child: Text(
                      'Admin',
                      style: TextStyle(
                        color: ext.infoBlue,
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ));
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
                backgroundColor: ext.searchFieldFill,
                child: Text(
                  _initial,
                  style: TextStyle(
                    color: ext.greetingColor,
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

          SizedBox(height: AppSpacing.lg.h),
          Divider(color: ext.searchHintColor.withValues(alpha: 0.12)),
          SizedBox(height: AppSpacing.xs.h),

          // ── Admin toggle — doesn't apply to a pending invite, since
          // they're not a member yet. ─────────────────────────────────────
          if (!participant.isPending) ...[
            if (!participant.isAdmin)
              _SheetOption(
                icon: Icons.shield_rounded,
                label: 'Make group admin',
                color: ext.infoBlue,
                onTap: onGrantAdmin,
              )
            else
              _SheetOption(
                icon: Icons.shield_outlined,
                label: 'Remove as admin',
                color: Colors.orangeAccent,
                onTap: onRevokeAdmin,
              ),
          ],

          // ── Kick — for a pending invite this revokes it, so they can no
          // longer join at all. ────────────────────────────────────────────
          _SheetOption(
            icon: Icons.person_remove_outlined,
            label:
                participant.isPending ? 'Cancel invite' : 'Remove from group',
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

class _LeaveGroupButton extends StatelessWidget {
  const _LeaveGroupButton({
    required this.isLeaving,
    required this.ext,
    required this.onLeave,
  });

  final bool isLeaving;
  final AppThemeExtension ext;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg.w),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.redAccent,
            side: const BorderSide(color: Colors.redAccent),
            padding: EdgeInsets.symmetric(vertical: 14.h),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md.r),
            ),
          ),
          onPressed: isLeaving ? null : onLeave,
          icon: isLeaving
              ? SizedBox(
                  width: 18.w,
                  height: 18.w,
                  child: const CircularProgressIndicator(
                    color: Colors.redAccent,
                    strokeWidth: 2,
                  ),
                )
              : Icon(Icons.exit_to_app_rounded, size: 20.sp),
          label: Text(
            isLeaving ? 'Leaving…' : 'Leave group',
            style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

class _DeleteGroupButton extends StatelessWidget {
  const _DeleteGroupButton({
    required this.isDeleting,
    required this.ext,
    required this.onDelete,
  });

  final bool isDeleting;
  final AppThemeExtension ext;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg.w),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.redAccent,
            side: const BorderSide(color: Colors.redAccent),
            padding: EdgeInsets.symmetric(vertical: 14.h),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md.r),
            ),
          ),
          onPressed: isDeleting ? null : onDelete,
          icon: isDeleting
              ? SizedBox(
                  width: 18.w,
                  height: 18.w,
                  child: const CircularProgressIndicator(
                    color: Colors.redAccent,
                    strokeWidth: 2,
                  ),
                )
              : Icon(Icons.delete_forever_rounded, size: 20.sp),
          label: Text(
            isDeleting ? 'Deleting…' : 'Delete group',
            style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

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
    return Semantics(
        button: true,
        label: label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md.r),
          child: Padding(
            padding: EdgeInsets.symmetric(
                vertical: AppSpacing.md.h, horizontal: AppSpacing.xs.w),
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
        ));
  }
}
