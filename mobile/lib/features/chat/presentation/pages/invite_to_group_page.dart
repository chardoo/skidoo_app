import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/di/service_locator.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/core/utils/snackbar_utils.dart';
import 'package:skidoo_app/features/chat/data/datasources/user_search_data_source.dart';
import 'package:skidoo_app/features/chat/domain/usecases/chat_usecases.dart';
import 'package:skidoo_app/models/chat/chat_room.dart';
import 'package:skidoo_app/models/chat/shareable_user.dart';

/// Lets an existing group member search for and invite new users to [room].
class InviteToGroupPage extends StatefulWidget {
  const InviteToGroupPage({super.key, required this.room});

  final ChatRoom room;

  @override
  State<InviteToGroupPage> createState() => _InviteToGroupPageState();
}

class _InviteToGroupPageState extends State<InviteToGroupPage> {
  final _searchController = TextEditingController();
  final _userSearch = sl<UserSearchDataSource>();
  final _inviteUseCase = sl<InviteToRoomUseCase>();

  List<ShareableUser> _searchResults = [];
  final List<ShareableUser> _selected = [];
  bool _isSearching = false;
  bool _isInviting = false;
  Timer? _debounce;

  /// User IDs of people already in the room (active members, not pending).
  late final Set<String> _existingMemberIds = widget.room.participants
      .where((p) => !p.isPending)
      .map((p) => p.userId)
      .toSet();

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(query));
  }

  Future<void> _search(String query) async {
    setState(() => _isSearching = true);
    try {
      final page = await _userSearch.search(query.trim());
      if (!mounted) return;
      setState(() {
        _searchResults = page.users
            .where((u) =>
                !_existingMemberIds.contains(u.id) &&
                !_selected.any((s) => s.id == u.id))
            .toList();
        _isSearching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSearching = false);
    }
  }

  void _toggleUser(ShareableUser user) {
    setState(() {
      if (_selected.any((u) => u.id == user.id)) {
        _selected.removeWhere((u) => u.id == user.id);
      } else {
        _selected.add(user);
      }
      _searchResults.removeWhere((u) => u.id == user.id);
    });
  }

  void _removeSelected(ShareableUser user) {
    setState(() => _selected.removeWhere((u) => u.id == user.id));
  }

  Future<void> _invite() async {
    if (_selected.isEmpty) return;
    setState(() => _isInviting = true);

    final errors = <String>[];
    await Future.wait(_selected.map((user) async {
      try {
        await _inviteUseCase(
          roomId: widget.room.id,
          inviteeId: user.id,
          inviteeRole: user.role,
        );
        debugPrint('[InviteToGroup] invited ${user.id} to ${widget.room.id}');
      } catch (e) {
        debugPrint('[InviteToGroup] failed to invite ${user.id}: $e');
        errors.add(user.name);
      }
    }));

    if (!mounted) return;

    if (errors.isEmpty) {
      final count = _selected.length;
      Navigator.of(context).pop(count);
    } else {
      setState(() => _isInviting = false);
      final failed = errors.join(', ');
      AppSnackBar.error(context, 'Could not invite: $failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final canInvite = _selected.isNotEmpty && !_isInviting;

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
          'Add People',
          style: TextStyle(
            color: ext.greetingColor,
            fontWeight: FontWeight.bold,
            fontSize: 18.sp,
          ),
        ),
        actions: [
          TextButton(
            onPressed: canInvite ? _invite : null,
            child: _isInviting
                ? SizedBox(
                    width: 18.w,
                    height: 18.h,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: ext.accentGold),
                  )
                : Text(
                    'Invite',
                    style: TextStyle(
                      color: canInvite
                          ? ext.accentGold
                          : ext.searchHintColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 15.sp,
                    ),
                  ),
          ),
          SizedBox(width: 8.w),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_selected.isNotEmpty)
            _SelectedChips(
                users: _selected, ext: ext, onRemove: _removeSelected),
          _SearchField(
            controller: _searchController,
            ext: ext,
            onChanged: _onSearchChanged,
          ),
          Expanded(
            child: _isSearching
                ? Center(
                    child:
                        CircularProgressIndicator(color: ext.accentGold))
                : _searchResults.isEmpty &&
                        _searchController.text.trim().isNotEmpty
                    ? Center(
                        child: Text(
                          'No users found.',
                          style: TextStyle(
                              color: ext.searchHintColor, fontSize: 14.sp),
                        ),
                      )
                    : _searchResults.isEmpty
                        ? Center(
                            child: Text(
                              'Search for people to add.',
                              style: TextStyle(
                                  color: ext.searchHintColor,
                                  fontSize: 14.sp),
                            ),
                          )
                        : ListView.builder(
                            padding: EdgeInsets.only(top: 4.h, bottom: 24.h),
                            itemCount: _searchResults.length,
                            itemBuilder: (_, i) => _UserTile(
                              user: _searchResults[i],
                              ext: ext,
                              onTap: () => _toggleUser(_searchResults[i]),
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField(
      {required this.controller,
      required this.ext,
      required this.onChanged});
  final TextEditingController controller;
  final AppThemeExtension ext;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 8.h),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        autofocus: true,
        style: TextStyle(color: ext.greetingColor, fontSize: 14.sp),
        decoration: InputDecoration(
          hintText: 'Search people...',
          hintStyle: TextStyle(color: ext.searchHintColor),
          prefixIcon: Icon(Icons.search_rounded,
              color: ext.searchHintColor, size: 20.sp),
          filled: true,
          fillColor: ext.cardSurface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.r),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
        ),
      ),
    );
  }
}

class _SelectedChips extends StatelessWidget {
  const _SelectedChips(
      {required this.users, required this.ext, required this.onRemove});
  final List<ShareableUser> users;
  final AppThemeExtension ext;
  final ValueChanged<ShareableUser> onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 4.h),
      child: Wrap(
        spacing: 6.w,
        runSpacing: 4.h,
        children: users
            .map((u) => Chip(
                  label: Text(u.name,
                      style: TextStyle(
                          color: ext.greetingColor, fontSize: 12.sp)),
                  backgroundColor:
                      ext.accentGold.withValues(alpha: 0.15),
                  deleteIcon: Icon(Icons.close_rounded,
                      size: 14.sp, color: ext.greetingColor),
                  onDeleted: () => onRemove(u),
                  side: BorderSide.none,
                  padding: EdgeInsets.symmetric(horizontal: 4.w),
                ))
            .toList(),
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile(
      {required this.user, required this.ext, required this.onTap});
  final ShareableUser user;
  final AppThemeExtension ext;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        radius: 20.r,
        backgroundColor: ext.accentGold.withValues(alpha: 0.2),
        backgroundImage:
            user.imageUrl != null ? NetworkImage(user.imageUrl!) : null,
        child: user.imageUrl == null
            ? Text(
                user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                style: TextStyle(color: ext.accentGold, fontSize: 14.sp),
              )
            : null,
      ),
      title: Text(user.name,
          style: TextStyle(color: ext.greetingColor, fontSize: 14.sp)),
      // subtitle: Text(user.email,
      //     style: TextStyle(color: ext.searchHintColor, fontSize: 12.sp),
      //     maxLines: 1,
      //     overflow: TextOverflow.ellipsis),
      trailing: Icon(Icons.person_add_outlined,
          color: ext.accentGold, size: 22.sp),
    );
  }
}
