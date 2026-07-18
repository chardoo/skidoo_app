import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/common/widgets/app_text_field.dart';
import 'package:skidoo_app/core/common/widgets/search_field.dart';
import 'package:skidoo_app/core/di/service_locator.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/features/chat/data/datasources/user_search_data_source.dart';
import 'package:skidoo_app/features/chat/domain/usecases/chat_usecases.dart';
import 'package:skidoo_app/models/chat/shareable_user.dart';
import 'package:skidoo_app/core/utils/web_wrap.dart';

class CreateGroupPage extends StatefulWidget {
  const CreateGroupPage({super.key});

  @override
  State<CreateGroupPage> createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends State<CreateGroupPage> {
  final _nameController = TextEditingController();
  final _searchController = TextEditingController();
  final _userSearch = sl<UserSearchDataSource>();
  final _createGroup = sl<CreateGroupRoomUseCase>();

  List<ShareableUser> _searchResults = [];
  final List<ShareableUser> _selected = [];
  bool _isSearching = false;
  bool _isCreating = false;
  String? _error;
  Timer? _debounce;

  @override
  void dispose() {
    _nameController.dispose();
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
    final page = await _userSearch.search(query.trim());
    if (!mounted) return;
    setState(() {
      _searchResults = page.users
          .where((u) => !_selected.any((s) => s.id == u.id))
          .toList();
      _isSearching = false;
    });
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

  Future<void> _create() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Group name is required.');
      return;
    }
    final inviteeIds = _selected.map((u) => u.id).toList();
    // {user_id: name} so invitees show their name before they connect.
    final inviteeNames = {
      for (final u in _selected)
        if (u.name.trim().isNotEmpty) u.id: u.name.trim(),
    };
    debugPrint('[CreateGroup] starting — name="$name" invitees=${inviteeIds.length}: $inviteeIds');
    setState(() {
      _isCreating = true;
      _error = null;
    });
    try {
      final room = await _createGroup(
        name: name,
        inviteeIds: inviteeIds,
        inviteeNames: inviteeNames,
      );
      debugPrint('[CreateGroup] success — roomId=${room.id} type=${room.type.toApiString()}');
      if (!mounted) return;
      Navigator.of(context).pop(room);
    } catch (e, st) {
      debugPrint('[CreateGroup] error — $e\n$st');
      if (!mounted) return;
      setState(() {
        _isCreating = false;
        _error = 'Could not create group. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    final page = Scaffold(
      backgroundColor: ext.homeBackground,
      appBar: AppBar(
        backgroundColor: ext.homeBackground,
        elevation: 0,
        title: Text(
          'New Group',
          style: TextStyle(
            color: ext.greetingColor,
            fontWeight: FontWeight.bold,
            fontSize: 18.sp,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isCreating ? null : _create,
            child: _isCreating
                ? SizedBox(
                    width: 18.w,
                    height: 18.h,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: ext.accentGold),
                  )
                : Text(
                    'Create',
                    style: TextStyle(
                      color: ext.accentGold,
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
          _GroupNameField(controller: _nameController),
          if (_error != null)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Text(_error!,
                  style: TextStyle(color: Colors.red, fontSize: 12.sp)),
            ),
          if (_selected.isNotEmpty) _SelectedChips(users: _selected, ext: ext, onRemove: _removeSelected),
          _SearchField(controller: _searchController, onChanged: _onSearchChanged),
          Expanded(
            child: _isSearching
                ? Center(child: CircularProgressIndicator(color: ext.searchHintColor))
                : _searchResults.isEmpty && _searchController.text.trim().isNotEmpty
                    ? Center(
                        child: Text('No users found.',
                            style: TextStyle(
                                color: ext.searchHintColor, fontSize: 14.sp)),
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
    return webWrap(page, backgroundColor: ext.homeBackground);
  }
}

class _GroupNameField extends StatelessWidget {
  const _GroupNameField({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 8.h),
      child: AppTextField(
        controller: controller,
        hint: 'Group name',
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 8.h),
      child: SearchField(
        controller: controller,
        onChanged: onChanged,
        hint: 'Search people to add...',
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
      padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 8.h),
      child: Wrap(
        spacing: 6.w,
        runSpacing: 4.h,
        children: users
            .map((u) => Chip(
                  label: Text(u.name,
                      style: TextStyle(
                          color: ext.greetingColor, fontSize: 12.sp)),
                  backgroundColor: ext.accentGold.withValues(alpha: 0.15),
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
          style:
              TextStyle(color: ext.greetingColor, fontSize: 14.sp)),
      // subtitle: Text(user.email,
      //     style: TextStyle(color: ext.searchHintColor, fontSize: 12.sp),
      //     maxLines: 1,
      //     overflow: TextOverflow.ellipsis),
      trailing: Icon(Icons.add_circle_outline_rounded,
          color: ext.accentGold, size: 22.sp),
    );
  }
}
