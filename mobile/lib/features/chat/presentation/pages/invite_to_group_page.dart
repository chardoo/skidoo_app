import 'package:flutter/material.dart';
import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/core/utils/snackbar_utils.dart';
import 'package:jperg_app/features/chat/domain/usecases/chat_usecases.dart';
import 'package:jperg_app/features/chat/presentation/widgets/member_picker.dart';
import 'package:jperg_app/models/chat/chat_room.dart';
import 'package:jperg_app/models/chat/shareable_user.dart';

/// Lets an existing group member search for and invite new users to [room].
///
/// The same screen as the first step of creating a group — see [MemberPicker] —
/// but the group already exists, so the confirm action is "Add" rather than
/// "Next" and sending the invites is the last thing it does. Pops the number of
/// people invited so Group Info can say so.
class InviteToGroupPage extends StatelessWidget {
  const InviteToGroupPage({super.key, required this.room});

  final ChatRoom room;

  /// Nobody already in the room can be picked, invited-but-not-yet-joined
  /// included: the server rejects a second invite, and the member list is
  /// already showing them as Pending.
  Set<String> get _alreadyInRoom =>
      room.participants.map((p) => p.userId).toSet();

  Future<void> _invite(BuildContext context, List<ShareableUser> users) async {
    final inviteUseCase = sl<InviteToRoomUseCase>();
    final navigator = Navigator.of(context);

    final failed = <String>[];
    await Future.wait(users.map((user) async {
      try {
        await inviteUseCase(
          roomId: room.id,
          inviteeId: user.id,
          inviteeRole: user.role,
          inviteeName: user.name,
        );
        debugPrint('[InviteToGroup] invited ${user.id} to ${room.id}');
      } catch (e) {
        debugPrint('[InviteToGroup] failed to invite ${user.id}: $e');
        failed.add(user.name);
      }
    }));

    if (!context.mounted) return;

    if (failed.isEmpty) {
      navigator.pop(users.length);
    } else {
      // Left on screen with the picks intact, so a retry doesn't mean finding
      // everyone again.
      AppSnackBar.error(context, 'Could not invite: ${failed.join(', ')}');
    }
  }

  @override
  Widget build(BuildContext context) => MemberPicker(
        actionLabel: 'Add',
        excludedUserIds: _alreadyInRoom,
        onSubmit: (users) => _invite(context, users),
      );
}
