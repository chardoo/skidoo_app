import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/common/widgets/app_section_label.dart';
import 'package:jperg_app/core/common/widgets/user_avatar.dart';
import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/utils/snackbar_utils.dart';
import 'package:jperg_app/core/utils/web_wrap.dart';
import 'package:jperg_app/features/chat/data/datasources/user_search_data_source.dart';
import 'package:jperg_app/features/chat/domain/usecases/chat_usecases.dart';
import 'package:jperg_app/features/chat/presentation/chat_error_text.dart';
import 'package:jperg_app/features/chat/presentation/pages/create_group_page.dart';
import 'package:jperg_app/features/chat/presentation/widgets/chat_search_field.dart';
import 'package:jperg_app/models/chat/chat_room.dart';
import 'package:jperg_app/models/chat/shareable_user.dart';

/// Pick someone to message, or start a group.
///
/// Pops the [ChatRoom] to open, so the caller decides how to navigate to it.
class NewChatPage extends StatefulWidget {
  const NewChatPage({super.key});

  @override
  State<NewChatPage> createState() => _NewChatPageState();
}

class _NewChatPageState extends State<NewChatPage> {
  final _controller = TextEditingController();
  final _userSearch = sl<UserSearchDataSource>();
  final _openDirect = sl<GetOrCreateDirectRoomUseCase>();

  List<ShareableUser> _results = [];
  bool _isSearching = false;
  String _query = '';
  String? _openingUserId;
  Timer? _debounce;

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    setState(() => _query = value);
    if (value.trim().isEmpty) {
      setState(() {
        _results = [];
        _isSearching = false;
      });
      return;
    }
    setState(() => _isSearching = true);
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(value));
  }

  Future<void> _search(String query) async {
    final page = await _userSearch.search(query.trim());
    if (!mounted || query != _controller.text) return;
    setState(() {
      _results = page.users;
      _isSearching = false;
    });
  }

  Future<void> _openChatWith(ShareableUser user) async {
    if (_openingUserId != null) return;
    setState(() => _openingUserId = user.id);
    try {
      final room = await _openDirect(
        recipientId: user.id,
        recipientRole: user.role,
        localDisplayName: user.name,
      );
      if (!mounted) return;
      Navigator.of(context).pop(room);
    } catch (e) {
      if (!mounted) return;
      setState(() => _openingUserId = null);
      AppSnackBar.error(
        context,
        chatErrorText(e, fallback: 'Could not open this chat.'),
      );
    }
  }

  Future<void> _createGroup() async {
    final room = await Navigator.of(context).push<ChatRoom>(
      MaterialPageRoute(builder: (_) => const CreateGroupPage()),
    );
    if (room != null && mounted) Navigator.of(context).pop(room);
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    final page = Scaffold(
      backgroundColor: ext.homeBackground,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ChatSearchField(
                  controller: _controller,
                  hint: 'Search for people',
                  onChanged: _onChanged,
                  onCancel: () => Navigator.of(context).pop(),
                ),

                _CreateGroupCard(onTap: _createGroup),

                Expanded(child: _buildResults(ext)),
              ],
            ),
          ),
        ),
      ),
    );
    return webWrap(page, backgroundColor: ext.homeBackground);
  }

  Widget _buildResults(AppThemeExtension ext) {
    if (_query.trim().isEmpty) return const SizedBox.shrink();

    if (_isSearching) {
      return Center(
        child: SizedBox(
          width: 22.w,
          height: 22.w,
          child: CircularProgressIndicator(
              color: ext.accentGold, strokeWidth: 2),
        ),
      );
    }

    if (_results.isEmpty) {
      return Center(
        child: Text(
          'No results for ‘${_query.trim()}’',
          style: TextStyle(color: ext.searchHintColor, fontSize: 14.sp),
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.only(top: AppSpacing.xs.h, bottom: AppSpacing.xxl.h),
      itemCount: _results.length + 1,
      separatorBuilder: (_, index) => index == 0
          ? const SizedBox.shrink()
          : Padding(
              padding: EdgeInsets.only(left: 64.w, right: AppSpacing.lg.w),
              child: Divider(
                height: 1,
                thickness: 1,
                color: ext.searchHintColor.withValues(alpha: 0.14),
              ),
            ),
      itemBuilder: (_, index) {
        if (index == 0) {
          return AppSectionLabel(
            'Users',
            padding: EdgeInsets.fromLTRB(AppSpacing.lg.w, AppSpacing.sm.h,
                AppSpacing.lg.w, AppSpacing.xs.h),
          );
        }
        final user = _results[index - 1];
        return _UserRow(
          user: user,
          isOpening: _openingUserId == user.id,
          onTap: () => _openChatWith(user),
        );
      },
    );
  }
}

class _CreateGroupCard extends StatelessWidget {
  const _CreateGroupCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.md.w),
      child: Semantics(
        button: true,
        label: 'Create group',
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.lg.r),
          child: Container(
            padding: EdgeInsets.all(AppSpacing.md.w),
            decoration: BoxDecoration(
              color: ext.accentGold.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppRadius.lg.r),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22.r,
                  backgroundColor: ext.accentGold,
                  child: Icon(Icons.forum_rounded,
                      color: Colors.white, size: 20.sp),
                ),
                SizedBox(width: AppSpacing.md.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Create Group',
                        style: TextStyle(
                          color: ext.accentGold,
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        'Start a message with multiple people',
                        style: TextStyle(
                          color: ext.searchHintColor,
                          fontSize: 12.sp,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UserRow extends StatelessWidget {
  const _UserRow({
    required this.user,
    required this.isOpening,
    required this.onTap,
  });

  final ShareableUser user;
  final bool isOpening;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return InkWell(
      onTap: isOpening ? null : onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.lg.w, vertical: 10.h),
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
            if (isOpening)
              SizedBox(
                width: 16.w,
                height: 16.w,
                child: CircularProgressIndicator(
                    color: ext.accentGold, strokeWidth: 2),
              ),
          ],
        ),
      ),
    );
  }
}
