import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/utils/snackbar_utils.dart';
import 'package:jperg_app/features/chat/domain/usecases/chat_usecases.dart'
    show BlockUserUseCase, UnblockUserUseCase, GetBlockedUsersUseCase;
import 'package:jperg_app/features/discovery/presentation/widgets/report_sheet.dart';
import 'package:jperg_app/services/auth_service.dart';

/// The three dots in a profile's app bar, and the only thing that opens
/// [ProfileMoreOptionsSheet].
///
/// Draws nothing on your own profile, decided from the id the session already
/// holds rather than from a fetch — the same rule, for the same reason, that
/// [ProfileActions] follows: blocking or reporting yourself is refused by the
/// server, so the control must never be there to press, not even for the beat
/// before an answer lands.
class ProfileOverflowButton extends StatelessWidget {
  const ProfileOverflowButton({
    super.key,
    required this.ext,
    required this.userId,
    required this.name,
  });

  final AppThemeExtension ext;
  final String userId;
  final String name;

  @override
  Widget build(BuildContext context) {
    final me = AuthService.userId.value;
    if (userId.isEmpty || (me.isNotEmpty && me == userId)) {
      return const SizedBox.shrink();
    }
    return Semantics(
      button: true,
      label: 'More options',
      child: IconButton(
        icon: Icon(Icons.more_vert_rounded, color: ext.greetingColor, size: 20.sp),
        onPressed: () => ProfileMoreOptionsSheet.show(
          context,
          ext: ext,
          userId: userId,
          name: name,
        ),
      ),
    );
  }
}

/// What you can do *about* a person, as opposed to with them.
///
/// Block and Report, from the three-dot menu on either profile screen. Both
/// already existed in parts and neither could be reached from here: blocking
/// lived inside a direct conversation, so blocking somebody meant opening a
/// chat with them first — and reporting could only be aimed at a thing they
/// posted, never at the account. App Review guideline 1.2 asks for both on
/// user-generated content, and a reviewer looks for them on a profile.
///
/// The block state is read when the sheet opens rather than carried in: a
/// profile is reached from eight places and none of them knows it, and a
/// *wrong* label here is worse than a late one — it offers to block somebody
/// who is already blocked. Until the answer arrives the tile says so.
class ProfileMoreOptionsSheet extends StatefulWidget {
  const ProfileMoreOptionsSheet({
    super.key,
    required this.ext,
    required this.userId,
    required this.name,
  });

  final AppThemeExtension ext;

  /// Whose profile this is. Never your own — the caller does not draw the menu
  /// on it, the same rule [ProfileActions] follows.
  final String userId;

  /// Their name, so the sheet can name who is being blocked rather than ask
  /// "block this user?" of a screen that has already left.
  final String name;

  static void show(
    BuildContext context, {
    required AppThemeExtension ext,
    required String userId,
    required String name,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          ProfileMoreOptionsSheet(ext: ext, userId: userId, name: name),
    );
  }

  @override
  State<ProfileMoreOptionsSheet> createState() =>
      _ProfileMoreOptionsSheetState();
}

class _ProfileMoreOptionsSheetState extends State<ProfileMoreOptionsSheet> {
  /// Null until the block list has answered.
  bool? _blocked;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    _loadBlockState();
  }

  Future<void> _loadBlockState() async {
    try {
      final blocked = await sl<GetBlockedUsersUseCase>().call();
      if (!mounted) return;
      setState(() => _blocked = blocked.contains(widget.userId));
    } catch (_) {
      // Left null, and the tile stays unavailable rather than guessing. The
      // request is the only thing that knows, and offering "Block" over a
      // failed read is how you end up unblocking somebody who asked to block.
      if (mounted) setState(() => _blocked = null);
    }
  }

  Future<void> _toggleBlock() async {
    final wasBlocked = _blocked;
    if (wasBlocked == null || _working) return;
    setState(() => _working = true);
    try {
      if (wasBlocked) {
        await sl<UnblockUserUseCase>().call(widget.userId);
      } else {
        await sl<BlockUserUseCase>().call(widget.userId);
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      AppSnackBar.success(
        context,
        wasBlocked
            ? '${widget.name} is unblocked.'
            : '${widget.name} is blocked. They can no longer message you.',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _working = false);
      // Read from before the attempt, so a failed block cannot report itself
      // as a failed unblock.
      AppSnackBar.error(
        context,
        'Could not ${wasBlocked ? 'unblock' : 'block'} ${widget.name}. Try again.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = widget.ext;
    final blocked = _blocked;

    return Container(
      decoration: BoxDecoration(
        color: ext.homeBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      // ListTile ink paints on the nearest Material ancestor; this decorated
      // Container sits between the sheet's Material and the tiles and would
      // swallow it (and assert in debug). A transparency Material paints
      // nothing and just gives the ink somewhere to land.
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: EdgeInsets.symmetric(vertical: AppSpacing.md.h),
                width: 36.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: ext.searchHintColor.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),

              // ── Block / Unblock ──────────────────────────────────────────
              ListTile(
                leading: Container(
                  width: 40.w,
                  height: 40.w,
                  decoration: BoxDecoration(
                    color: ext.searchFieldFill,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.block_rounded,
                      color: ext.greetingColor, size: 20.sp),
                ),
                title: Text(
                  blocked == null
                      ? 'Block'
                      : (blocked ? 'Unblock ${widget.name}' : 'Block ${widget.name}'),
                  style: TextStyle(
                    color: blocked == null
                        ? ext.searchHintColor
                        : ext.greetingColor,
                    fontWeight: FontWeight.w500,
                    fontSize: 15.sp,
                  ),
                ),
                subtitle: Text(
                  blocked == null
                      ? 'Checking…'
                      : (blocked
                          ? 'They will be able to message you again'
                          : "They won't be able to message you"),
                  style: TextStyle(color: ext.searchHintColor, fontSize: 12.sp),
                ),
                trailing: _working
                    ? SizedBox(
                        width: 16.w,
                        height: 16.w,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: ext.searchHintColor,
                        ),
                      )
                    : null,
                // Dead until the state is known, which is the honest state of
                // it — see [_loadBlockState].
                onTap: blocked == null || _working ? null : _toggleBlock,
              ),

              Divider(
                  height: 1, color: ext.searchHintColor.withValues(alpha: 0.1)),

              // ── Report ───────────────────────────────────────────────────
              ListTile(
                leading: Container(
                  width: 40.w,
                  height: 40.w,
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.flag_outlined,
                      color: Colors.redAccent, size: 20.sp),
                ),
                title: Text(
                  'Report account',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w500,
                    fontSize: 15.sp,
                  ),
                ),
                subtitle: Text(
                  'Harassment, impersonation or harmful behaviour',
                  style: TextStyle(color: ext.searchHintColor, fontSize: 12.sp),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  // The account itself, not any one thing on it — which is
                  // the whole point of having it here. See the "user" branch
                  // in the report router.
                  ReportSheet.show(
                    context,
                    ext: ext,
                    assetType: 'user',
                    assetId: widget.userId,
                  );
                },
              ),

              SizedBox(height: AppSpacing.sm.h),
            ],
          ),
        ),
      ),
    );
  }
}
