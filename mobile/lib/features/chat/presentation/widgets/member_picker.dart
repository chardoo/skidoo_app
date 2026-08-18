import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/common/widgets/app_section_label.dart';
import 'package:jperg_app/core/common/widgets/search_field.dart';
import 'package:jperg_app/core/common/widgets/user_avatar.dart';
import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/utils/web_wrap.dart';
import 'package:jperg_app/features/chat/data/datasources/user_search_data_source.dart';
import 'package:jperg_app/models/chat/shareable_user.dart';

/// Search-and-tick screen for choosing people: the "Add Members" step of
/// creating a group, and adding members to a group that already exists.
///
/// One widget for both, because they are the same screen in the designs and the
/// only difference is what the confirm button says and does — "Next" carries the
/// picks to the naming step, "Add" invites them there and then. Keeping them
/// apart is what let the two drift: the add-member screen had grown a back arrow
/// where the mock has Cancel, chips above the search field instead of below, and
/// neither the section label nor the tick circles.
class MemberPicker extends StatefulWidget {
  const MemberPicker({
    super.key,
    required this.actionLabel,
    required this.onSubmit,
    this.title = 'Add Members',
    this.excludedUserIds = const <String>{},
  });

  /// The confirm action's label — 'Next' when a step follows, 'Add' when this
  /// screen is the last one.
  final String actionLabel;

  /// Called with the picked users. Awaited, so the action can show a spinner
  /// while it runs: inviting is a network round-trip, opening step two isn't.
  /// Whatever navigation the caller wants is the caller's to do.
  final Future<void> Function(List<ShareableUser> selected) onSubmit;

  final String title;

  /// People who cannot be picked — already in the group, or already invited.
  /// Filtered out of results rather than shown ticked, since tapping them would
  /// do nothing.
  final Set<String> excludedUserIds;

  @override
  State<MemberPicker> createState() => _MemberPickerState();
}

class _MemberPickerState extends State<MemberPicker> {
  final _searchController = TextEditingController();
  final _userSearch = sl<UserSearchDataSource>();

  List<ShareableUser> _results = [];
  final List<ShareableUser> _selected = [];
  bool _isSearching = false;
  bool _isSubmitting = false;
  Timer? _debounce;

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _isSearching = false;
      });
      return;
    }
    setState(() => _isSearching = true);
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(query));
  }

  Future<void> _search(String query) async {
    try {
      final page = await _userSearch.search(query.trim());
      if (!mounted || query != _searchController.text) return;
      setState(() {
        _results = page.users
            .where((u) => !widget.excludedUserIds.contains(u.id))
            .toList();
        _isSearching = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSearching = false);
    }
  }

  void _toggle(ShareableUser user) {
    setState(() {
      final index = _selected.indexWhere((u) => u.id == user.id);
      if (index >= 0) {
        _selected.removeAt(index);
      } else {
        _selected.add(user);
      }
    });
  }

  Future<void> _submit() async {
    if (_selected.isEmpty || _isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      await widget.onSubmit(List.of(_selected));
    } finally {
      // The callback usually navigates away, so this widget is often gone by
      // now — re-enabling the button only matters when it failed and left us
      // on screen.
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final canSubmit = _selected.isNotEmpty && !_isSubmitting;

    final page = Scaffold(
      backgroundColor: ext.homeBackground,
      appBar: AppBar(
        backgroundColor: ext.homeBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        leadingWidth: 84.w,
        leading: TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: TextStyle(color: ext.searchHintColor, fontSize: 15.sp),
          ),
        ),
        title: Text(
          widget.title,
          style: TextStyle(
            color: ext.greetingColor,
            fontWeight: FontWeight.bold,
            fontSize: 17.sp,
          ),
        ),
        actions: [
          TextButton(
            // Nothing picked, nothing to confirm — and a group of one is a DM,
            // which the New Chat screen already does.
            onPressed: canSubmit ? _submit : null,
            child: _isSubmitting
                ? SizedBox(
                    width: 18.w,
                    height: 18.w,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: ext.accentGold),
                  )
                : Text(
                    widget.actionLabel,
                    style: TextStyle(
                      color: canSubmit
                          ? ext.accentGold
                          : ext.searchHintColor.withValues(alpha: 0.5),
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(AppSpacing.md.w, AppSpacing.sm.h,
                    AppSpacing.md.w, AppSpacing.sm.h),
                child: SearchField(
                  controller: _searchController,
                  hint: 'Search for people',
                  onChanged: _onSearchChanged,
                  onClear: () {
                    _searchController.clear();
                    _onSearchChanged('');
                  },
                ),
              ),
              if (_selected.isNotEmpty)
                _SelectedStrip(users: _selected, onRemove: _toggle),
              Expanded(child: _buildResults(ext)),
            ],
          ),
        ),
      ),
    );
    return webWrap(page, backgroundColor: ext.homeBackground);
  }

  Widget _buildResults(AppThemeExtension ext) {
    if (_isSearching) {
      return Center(
        child: SizedBox(
          width: 22.w,
          height: 22.w,
          child:
              CircularProgressIndicator(color: ext.accentGold, strokeWidth: 2),
        ),
      );
    }

    if (_results.isEmpty) {
      return Center(
        child: Text(
          _searchController.text.trim().isEmpty
              ? 'Search for people to add'
              : 'No users found.',
          style: TextStyle(color: ext.searchHintColor, fontSize: 14.sp),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.only(bottom: AppSpacing.xxl.h),
      itemCount: _results.length + 1,
      itemBuilder: (_, index) {
        if (index == 0) {
          return AppSectionLabel(
            'Users',
            padding: EdgeInsets.fromLTRB(AppSpacing.lg.w, AppSpacing.sm.h,
                AppSpacing.lg.w, AppSpacing.xs.h),
          );
        }
        final user = _results[index - 1];
        return _SelectableUserRow(
          user: user,
          selected: _selected.any((u) => u.id == user.id),
          onTap: () => _toggle(user),
        );
      },
    );
  }
}

/// Horizontal strip of who's been picked so far, each removable.
class _SelectedStrip extends StatelessWidget {
  const _SelectedStrip({required this.users, required this.onRemove});

  final List<ShareableUser> users;
  final ValueChanged<ShareableUser> onRemove;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: AppSpacing.md.w),
      padding: EdgeInsets.symmetric(vertical: AppSpacing.md.h),
      decoration: BoxDecoration(
        color: ext.accentGold.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.lg.r),
      ),
      child: SizedBox(
        height: 76.h,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.md.w),
          itemCount: users.length,
          separatorBuilder: (_, __) => SizedBox(width: AppSpacing.md.w),
          itemBuilder: (_, i) {
            final user = users[i];
            return SizedBox(
              width: 56.w,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      UserAvatar(
                        imageUrl: user.imageUrl,
                        initial: user.name,
                        radius: 22,
                      ),
                      Positioned(
                        top: -2,
                        right: -2,
                        child: Semantics(
                          button: true,
                          label: 'Remove ${user.name}',
                          child: GestureDetector(
                            onTap: () => onRemove(user),
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: ext.cardSurface,
                              ),
                              padding: EdgeInsets.all(1.w),
                              child: Icon(Icons.cancel,
                                  size: 16.sp, color: ext.searchHintColor),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    _firstName(user.name),
                    style: TextStyle(color: ext.greetingColor, fontSize: 11.sp),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  static String _firstName(String full) {
    final trimmed = full.trim();
    if (trimmed.isEmpty) return '';
    final space = trimmed.indexOf(' ');
    return space == -1 ? trimmed : trimmed.substring(0, space);
  }
}

class _SelectableUserRow extends StatelessWidget {
  const _SelectableUserRow({
    required this.user,
    required this.selected,
    required this.onTap,
  });

  final ShareableUser user;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return Semantics(
      selected: selected,
      button: true,
      label: user.name,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding:
              EdgeInsets.symmetric(horizontal: AppSpacing.lg.w, vertical: 10.h),
          child: Row(
            children: [
              UserAvatar(
                imageUrl: user.imageUrl,
                initial: user.name,
                radius: 18,
              ),
              SizedBox(width: AppSpacing.md.w),
              Expanded(
                child: Text(
                  user.name,
                  style: TextStyle(color: ext.greetingColor, fontSize: 15.sp),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (selected)
                Icon(Icons.check_circle, color: ext.accentGold, size: 22.sp)
              else
                Icon(Icons.circle_outlined,
                    color: ext.searchHintColor.withValues(alpha: 0.5),
                    size: 22.sp),
            ],
          ),
        ),
      ),
    );
  }
}
