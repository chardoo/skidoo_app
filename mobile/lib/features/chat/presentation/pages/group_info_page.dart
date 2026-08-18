import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/common/widgets/app_back_button.dart';
import 'package:jperg_app/core/common/widgets/app_button.dart';
import 'package:jperg_app/core/common/widgets/app_confirm_dialog.dart';
import 'package:jperg_app/core/common/widgets/app_text_field.dart';
import 'package:jperg_app/core/common/widgets/user_avatar.dart';
import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/utils/snackbar_utils.dart';
import 'package:jperg_app/core/validators/media_validator.dart';
import 'package:jperg_app/core/utils/web_panel_route.dart';
import 'package:jperg_app/core/utils/web_wrap.dart';
import 'package:jperg_app/features/chat/data/datasources/chat_media_limits.dart';
import 'package:jperg_app/features/chat/domain/usecases/chat_usecases.dart';
import 'package:jperg_app/features/chat/presentation/bloc/room/chat_room_bloc.dart';
import 'package:jperg_app/features/chat/presentation/chat_error_text.dart';
import 'package:jperg_app/features/chat/presentation/pages/invite_to_group_page.dart';
import 'package:jperg_app/features/chat/presentation/pages/shared_media_page.dart';
import 'package:jperg_app/features/chat/presentation/widgets/chat_settings_tile.dart';
import 'package:jperg_app/models/chat/chat_room.dart';

/// Details for a group: its photo and name, shared media, mute, who is in it,
/// and the admin controls.
///
/// Requires [ChatRoomBloc] in scope (passed via BlocProvider.value from the
/// parent [ChatRoomPage]).
class GroupInfoPage extends StatelessWidget {
  const GroupInfoPage({super.key});

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
          'Group Info',
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
            p.isMuted != c.isMuted ||
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

          final members = [
            ...room.othersFor(state.myUserId),
          ];

          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: ListView(
                padding: EdgeInsets.only(bottom: AppSpacing.xxxl.h),
                children: [
                  SizedBox(height: AppSpacing.lg.h),
                  _GroupHeader(
                    room: room,
                    memberCount: members.length + 1,
                    // Changing the photo is a room setting, and the server
                    // only lets admins change those — so only they get the
                    // affordance rather than a tap that 403s.
                    canEditPhoto: state.amIAdmin,
                  ),
                  SizedBox(height: AppSpacing.xxl.h),

                  // ── Chat settings ─────────────────────────────────────────
                  const ChatSettingsLabel(label: 'CHAT SETTINGS'),
                  SizedBox(height: AppSpacing.sm.h),
                  ChatSettingsCard(
                    children: [
                      ChatSettingsTile(
                        label: 'Shared Media',
                        trailing: Icon(Icons.chevron_right_rounded,
                            color: ext.searchHintColor, size: 22.sp),
                        onTap: () => showWebPanelPage<void>(
                          context,
                          SharedMediaPage(roomId: room.id),
                        ),
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
                    ],
                  ),

                  // ── Admin-only controls ───────────────────────────────────
                  if (state.amIAdmin) ...[
                    SizedBox(height: AppSpacing.xl.h),
                    const ChatSettingsLabel(label: 'GROUP NAME'),
                    SizedBox(height: AppSpacing.sm.h),
                    _RenameSection(room: room),
                    SizedBox(height: AppSpacing.lg.h),
                    ChatSettingsCard(
                      children: [
                        ChatSettingsTile(
                          label: 'Only admins can send messages',
                          trailing: Switch(
                            value: room.adminOnly,
                            activeThumbColor: Colors.white,
                            activeTrackColor: ext.accentGold,
                            onChanged: (value) => context
                                .read<ChatRoomBloc>()
                                .add(ChatRoomUpdateSettingsRequested(
                                    adminOnly: value)),
                          ),
                        ),
                      ],
                    ),
                  ],

                  // ── Members ───────────────────────────────────────────────
                  SizedBox(height: AppSpacing.xl.h),
                  ChatSettingsLabel(
                    label: 'GROUP MEMBERS',
                    action: Semantics(
                      button: true,
                      label: 'Add member',
                      child: GestureDetector(
                        onTap: () => _addMembers(context, room),
                        child: Text(
                          'Add Member',
                          style: TextStyle(
                            color: ext.accentGold,
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: AppSpacing.sm.h),
                  for (int i = 0; i < members.length; i++) ...[
                    _MemberRow(
                      participant: members[i],
                      amIAdmin: state.amIAdmin,
                      onGrantAdmin: () => context.read<ChatRoomBloc>().add(
                          ChatRoomGrantAdminRequested(members[i].userId)),
                      onRevokeAdmin: () => context.read<ChatRoomBloc>().add(
                          ChatRoomRevokeAdminRequested(members[i].userId)),
                      onKick: () => context
                          .read<ChatRoomBloc>()
                          .add(ChatRoomKickRequested(members[i].userId)),
                    ),
                    if (i < members.length - 1)
                      Padding(
                        padding: EdgeInsets.only(
                            left: 68.w, right: AppSpacing.lg.w),
                        child: Divider(
                          height: 1,
                          thickness: 1,
                          color:
                              ext.searchHintColor.withValues(alpha: 0.14),
                        ),
                      ),
                  ],

                  // ── Destructive actions ───────────────────────────────────
                  SizedBox(height: AppSpacing.xxl.h),
                  _DestructiveRow(
                    label: state.isLeaving ? 'Leaving…' : 'Leave Group',
                    busy: state.isLeaving,
                    onTap: () => _confirmLeave(context),
                  ),
                  if (state.amIAdmin)
                    _DestructiveRow(
                      label: state.isDeleting ? 'Deleting…' : 'Delete Group',
                      busy: state.isDeleting,
                      onTap: () => _confirmDelete(context),
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

  Future<void> _addMembers(BuildContext context, ChatRoom room) async {
    final count = await showWebPanelPage<int>(
      context,
      InviteToGroupPage(room: room),
    );
    if (!context.mounted || count == null) return;
    AppSnackBar.success(
      context,
      '$count ${count == 1 ? 'person' : 'people'} invited',
    );
  }

  Future<void> _confirmLeave(BuildContext context) async {
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

  Future<void> _confirmDelete(BuildContext context) async {
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

class _GroupHeader extends StatefulWidget {
  const _GroupHeader({
    required this.room,
    required this.memberCount,
    required this.canEditPhoto,
  });

  final ChatRoom room;
  final int memberCount;
  final bool canEditPhoto;

  @override
  State<_GroupHeader> createState() => _GroupHeaderState();
}

class _GroupHeaderState extends State<_GroupHeader> {
  final _uploadImage = sl<UploadChatImageUseCase>();
  bool _isUploading = false;

  Future<void> _edit() async {
    final hasPhoto = (widget.room.imageUrl ?? '').isNotEmpty;
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _PhotoActionSheet(hasPhoto: hasPhoto),
    );
    if (!mounted || action == null) return;

    if (action == 'remove') {
      // "" clears it server-side; null would mean "leave it alone".
      context
          .read<ChatRoomBloc>()
          .add(const ChatRoomUpdateSettingsRequested(imageUrl: ''));
      return;
    }

    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null || !mounted) return;

    final limits = await sl<ChatMediaLimitsService>().get();
    final error = await MediaValidator.validate(picked,
        isVideo: false, maxBytes: limits.maxImageBytes);
    if (!mounted) return;
    if (error != null) {
      AppSnackBar.error(context, error);
      return;
    }

    setState(() => _isUploading = true);
    try {
      final url =
          await _uploadImage(File(picked.path), mimeType: picked.mimeType);
      if (!mounted) return;
      context
          .read<ChatRoomBloc>()
          .add(ChatRoomUpdateSettingsRequested(imageUrl: url));
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.error(context, uploadErrorText(e, isVideo: false));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final room = widget.room;

    return Column(
      children: [
        Semantics(
          button: widget.canEditPhoto,
          label: widget.canEditPhoto ? 'Change group photo' : null,
          child: GestureDetector(
            onTap: widget.canEditPhoto && !_isUploading ? _edit : null,
            child: Stack(
              alignment: Alignment.center,
              children: [
                UserAvatar(
                  imageUrl: room.imageUrl,
                  initial: room.displayName,
                  radius: 48,
                ),
                if (_isUploading)
                  Container(
                    width: 96.w,
                    height: 96.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.4),
                    ),
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: 22.w,
                      height: 22.w,
                      child: const CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    ),
                  )
                else if (widget.canEditPhoto)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: EdgeInsets.all(6.w),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: ext.accentGold,
                        border:
                            Border.all(color: ext.homeBackground, width: 2),
                      ),
                      child: Icon(Icons.camera_alt_rounded,
                          color: Colors.white, size: 14.sp),
                    ),
                  ),
              ],
            ),
          ),
        ),
        SizedBox(height: AppSpacing.md.h),
        Text(
          room.displayName,
          style: TextStyle(
            color: ext.greetingColor,
            fontSize: 19.sp,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 2.h),
        Text(
          '${widget.memberCount} '
          '${widget.memberCount == 1 ? 'member' : 'members'}',
          style: TextStyle(color: ext.searchHintColor, fontSize: 13.sp),
        ),
      ],
    );
  }
}

class _PhotoActionSheet extends StatelessWidget {
  const _PhotoActionSheet({required this.hasPhoto});

  final bool hasPhoto;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

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
          _SheetOption(
            icon: Icons.photo_library_outlined,
            label: hasPhoto ? 'Change photo' : 'Add photo',
            color: ext.accentGold,
            onTap: () => Navigator.of(context).pop('pick'),
          ),
          if (hasPhoto)
            _SheetOption(
              icon: Icons.delete_outline_rounded,
              label: 'Remove photo',
              color: ext.errorRed,
              onTap: () => Navigator.of(context).pop('remove'),
            ),
        ],
      ),
    );
  }
}

// ── Rename ────────────────────────────────────────────────────────────────────

class _RenameSection extends StatefulWidget {
  const _RenameSection({required this.room});

  final ChatRoom room;

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
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.md.w),
      child: Row(
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
            // Scaled, and tall enough to sit level with the dense field beside
            // it, which Flutter clamps to the 48 dp minimum touch target.
            width: 84.w,
            height: 48.h,
            onPressed: () => _save(context),
          ),
        ],
      ),
    );
  }
}

// ── Member row ────────────────────────────────────────────────────────────────

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.participant,
    required this.amIAdmin,
    required this.onGrantAdmin,
    required this.onRevokeAdmin,
    required this.onKick,
  });

  final ChatParticipant participant;
  final bool amIAdmin;
  final VoidCallback onGrantAdmin;
  final VoidCallback onRevokeAdmin;
  final VoidCallback onKick;

  void _showOptions(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _MemberOptionsSheet(
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
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return Semantics(
      button: amIAdmin,
      label: participant.displayName,
      child: InkWell(
        onTap: amIAdmin ? () => _showOptions(context) : null,
        child: Padding(
          padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.lg.w, vertical: 10.h),
          child: Row(
            children: [
              UserAvatar(
                imageUrl: participant.userImage,
                initial: participant.displayName,
                radius: 18,
              ),
              SizedBox(width: AppSpacing.md.w),
              Expanded(
                child: Text(
                  participant.displayName,
                  style:
                      TextStyle(color: ext.greetingColor, fontSize: 15.sp),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (participant.isPending)
                Text(
                  'Pending',
                  style: TextStyle(
                    color: ext.searchHintColor,
                    fontSize: 12.sp,
                    fontStyle: FontStyle.italic,
                  ),
                )
              else if (participant.isAdmin)
                Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: 10.w, vertical: 3.h),
                  decoration: BoxDecoration(
                    color: ext.accentGold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadius.xl.r),
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
      ),
    );
  }
}

class _MemberOptionsSheet extends StatelessWidget {
  const _MemberOptionsSheet({
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
          Row(
            children: [
              UserAvatar(
                imageUrl: participant.userImage,
                initial: participant.displayName,
                radius: 24,
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Text(
                  participant.displayName,
                  style: TextStyle(
                    color: ext.greetingColor,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.lg.h),
          Divider(color: ext.searchHintColor.withValues(alpha: 0.12)),
          SizedBox(height: AppSpacing.xs.h),

          // Admin rights don't apply to a pending invite — they aren't a
          // member yet.
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
                color: ext.publicAmber,
                onTap: onRevokeAdmin,
              ),
          ],

          // For a pending invite this revokes it, so they can no longer join.
          _SheetOption(
            icon: Icons.person_remove_outlined,
            label:
                participant.isPending ? 'Cancel invite' : 'Remove from group',
            color: ext.errorRed,
            onTap: onKick,
          ),
        ],
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
      ),
    );
  }
}

/// Leave / delete, styled as a plain destructive row rather than a button —
/// they sit at the end of a list, not in a form.
class _DestructiveRow extends StatelessWidget {
  const _DestructiveRow({
    required this.label,
    required this.busy,
    required this.onTap,
  });

  final String label;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return InkWell(
      onTap: busy ? null : onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.lg.w, vertical: 14.h),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                color: ext.errorRed,
                fontSize: 15.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (busy) ...[
              SizedBox(width: AppSpacing.sm.w),
              SizedBox(
                width: 14.w,
                height: 14.w,
                child: CircularProgressIndicator(
                    color: ext.errorRed, strokeWidth: 2),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
