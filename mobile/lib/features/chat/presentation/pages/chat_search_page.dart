import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/common/widgets/app_section_label.dart';
import 'package:jperg_app/core/common/widgets/user_avatar.dart';
import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/utils/snackbar_utils.dart';
import 'package:jperg_app/core/utils/web_wrap.dart';
import 'package:jperg_app/features/chat/data/datasources/user_search_data_source.dart';
import 'package:jperg_app/features/chat/domain/usecases/chat_usecases.dart';
import 'package:jperg_app/features/chat/presentation/bloc/rooms/chat_rooms_bloc.dart';
import 'package:jperg_app/features/chat/presentation/chat_error_text.dart';
import 'package:jperg_app/features/chat/presentation/widgets/chat_search_field.dart';
import 'package:jperg_app/features/chat/presentation/widgets/room_avatar.dart';
import 'package:jperg_app/models/chat/chat_room.dart';
import 'package:jperg_app/models/chat/shareable_user.dart';

/// Search from the inbox. Pops the [ChatRoom] to open.
///
/// Conversations the user already has are matched locally and shown first;
/// only when nothing local matches does it ask the server for people. That
/// ordering is deliberate — searching a name you have talked to before should
/// find that conversation, not offer to start a second one.
class ChatSearchPage extends StatefulWidget {
  const ChatSearchPage({super.key});

  @override
  State<ChatSearchPage> createState() => _ChatSearchPageState();
}

class _ChatSearchPageState extends State<ChatSearchPage> {
  final _controller = TextEditingController();
  final _userSearch = sl<UserSearchDataSource>();
  final _openDirect = sl<GetOrCreateDirectRoomUseCase>();

  String _query = '';
  List<ChatRoom> _localHits = [];
  List<ShareableUser> _remoteHits = [];
  bool _isSearchingRemote = false;
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
    final trimmed = value.trim();

    if (trimmed.isEmpty) {
      setState(() {
        _query = '';
        _localHits = [];
        _remoteHits = [];
        _isSearchingRemote = false;
      });
      return;
    }

    // Local matching is synchronous over a list already in memory, so it lands
    // on the current keystroke rather than after the debounce.
    final local = _matchLocal(trimmed);
    setState(() {
      _query = value;
      _localHits = local;
      _remoteHits = [];
      _isSearchingRemote = local.isEmpty;
    });

    if (local.isNotEmpty) return;
    _debounce =
        Timer(const Duration(milliseconds: 350), () => _searchRemote(value));
  }

  List<ChatRoom> _matchLocal(String query) {
    final state = context.read<ChatRoomsBloc>().state;
    final needle = query.toLowerCase();
    return state.rooms
        .where((r) => r.type.isConversation)
        .where((r) =>
            r.displayNameFor(state.currentUserId).toLowerCase().contains(needle))
        .toList();
  }

  Future<void> _searchRemote(String query) async {
    final page = await _userSearch.search(query.trim());
    if (!mounted || query != _controller.text) return;

    // Anyone already in a local hit is filtered out — offering to start a chat
    // with someone whose conversation is on screen just above is noise.
    final state = context.read<ChatRoomsBloc>().state;
    final known = <String>{
      for (final room in _localHits)
        for (final p in room.participants)
          if (p.userId != state.currentUserId) p.userId,
    };

    setState(() {
      _remoteHits = page.users.where((u) => !known.contains(u.id)).toList();
      _isSearchingRemote = false;
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
                  hint: 'Search',
                  onChanged: _onChanged,
                  onCancel: () => Navigator.of(context).pop(),
                ),
                Expanded(child: _buildBody(ext)),
              ],
            ),
          ),
        ),
      ),
    );
    return webWrap(page, backgroundColor: ext.homeBackground);
  }

  Widget _buildBody(AppThemeExtension ext) {
    if (_query.trim().isEmpty) return const SizedBox.shrink();

    if (_isSearchingRemote) {
      return Center(
        child: SizedBox(
          width: 22.w,
          height: 22.w,
          child:
              CircularProgressIndicator(color: ext.accentGold, strokeWidth: 2),
        ),
      );
    }

    final total = _localHits.length + _remoteHits.length;
    if (total == 0) {
      return Center(
        child: Text(
          'No results for ‘${_query.trim()}’',
          style: TextStyle(color: ext.searchHintColor, fontSize: 14.sp),
        ),
      );
    }

    final currentUserId = context.read<ChatRoomsBloc>().state.currentUserId;

    return ListView(
      padding: EdgeInsets.only(bottom: AppSpacing.xxl.h),
      children: [
        AppSectionLabel(
          'Search results ($total)',
          padding: EdgeInsets.fromLTRB(AppSpacing.lg.w, AppSpacing.sm.h,
              AppSpacing.lg.w, AppSpacing.xs.h),
        ),
        for (final room in _localHits)
          _ResultRow(
            avatar: RoomAvatar(
              room: room,
              currentUserId: currentUserId,
              radius: 18,
            ),
            label: room.displayNameFor(currentUserId),
            onTap: () => Navigator.of(context).pop(room),
          ),
        for (final user in _remoteHits)
          _ResultRow(
            avatar: UserAvatar(
              imageUrl: user.imageUrl,
              initial: user.name,
              radius: 18,
            ),
            label: user.name,
            isBusy: _openingUserId == user.id,
            onTap: () => _openChatWith(user),
          ),
      ],
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.avatar,
    required this.label,
    required this.onTap,
    this.isBusy = false,
  });

  final Widget avatar;
  final String label;
  final VoidCallback onTap;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return Column(
      children: [
        InkWell(
          onTap: isBusy ? null : onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.lg.w, vertical: 10.h),
            child: Row(
              children: [
                avatar,
                SizedBox(width: AppSpacing.md.w),
                Expanded(
                  child: Text(
                    label,
                    style:
                        TextStyle(color: ext.greetingColor, fontSize: 15.sp),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isBusy)
                  SizedBox(
                    width: 16.w,
                    height: 16.w,
                    child: CircularProgressIndicator(
                        color: ext.accentGold, strokeWidth: 2),
                  ),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.only(left: 64.w, right: AppSpacing.lg.w),
          child: Divider(
            height: 1,
            thickness: 1,
            color: ext.searchHintColor.withValues(alpha: 0.14),
          ),
        ),
      ],
    );
  }
}
