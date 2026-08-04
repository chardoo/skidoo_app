import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/common/widgets/search_field.dart';
import 'package:skidoo_app/core/di/service_locator.dart';
import 'package:skidoo_app/core/utils/snackbar_utils.dart';
import 'package:skidoo_app/l10n/app_localizations.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/features/chat/data/datasources/user_search_data_source.dart';
import 'package:skidoo_app/features/chat/domain/usecases/chat_usecases.dart';
import 'package:skidoo_app/features/chat/presentation/chat_error_text.dart';
import 'package:skidoo_app/features/chat/presentation/pages/chat_room_page.dart';
import 'package:skidoo_app/features/chat/presentation/widgets/room_tile.dart';
import 'package:skidoo_app/features/follow/data/follow_repository.dart';
import 'package:skidoo_app/models/chat/chat_room.dart';
import 'package:skidoo_app/models/chat/shareable_user.dart';
import 'package:skidoo_app/services/auth_service.dart';
import 'package:skidoo_app/core/theme/app_radius.dart';
import 'package:skidoo_app/core/theme/app_spacing.dart';
import 'package:skidoo_app/core/common/widgets/app_section_label.dart';

/// Bottom sheet with an in-app user search to send a photo directly to
/// another app user's DM room. The native OS share sheet is a separate,
/// direct icon on the card itself (see `shareOverlayPhotoExternally` in
/// `media_action_buttons.dart`) — not nested inside this sheet.
class GalleryShareSheet {
  static void show(
    BuildContext context, {
    required String imageUrl,
    required String photoLabel,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (ctx) => _ShareSheetContent(
        imageUrl: imageUrl,
        photoLabel: photoLabel,
      ),
    );
  }
}

// ── Sheet content ─────────────────────────────────────────────────────────────

class _ShareSheetContent extends StatefulWidget {
  const _ShareSheetContent({
    required this.imageUrl,
    required this.photoLabel,
  });

  final String imageUrl;
  final String photoLabel;

  @override
  State<_ShareSheetContent> createState() => _ShareSheetContentState();
}

class _ShareSheetContentState extends State<_ShareSheetContent> {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  List<ShareableUser> _results = [];
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = false;
  int _page = 1;
  String? _error;
  String? _sendingTo;

  // ── Recent rooms + recommended people — shown before any search happens,
  // so sharing into an existing chat doesn't require searching for it. ────
  String _myUserId = '';
  List<ChatRoom> _rooms = [];
  bool _loadingRooms = true;
  List<SuggestedPhotographer> _recommended = [];
  bool _loadingRecommended = true;
  String? _sendingRoomId;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _loadRoomsAndRecommendations();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRoomsAndRecommendations() async {
    _myUserId = await sl<AuthService>().getUserId();

    // Cached rooms first — instant, so the sheet never opens to a blank
    // "recent chats" section while waiting on the network.
    try {
      final cached = await sl<GetCachedRoomsUseCase>().call();
      if (mounted) {
        setState(() {
          _rooms = cached.where((r) => !r.hasPendingInvite(_myUserId)).toList();
          _loadingRooms = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingRooms = false);
    }

    // Then refresh from the server in the background.
    try {
      final fresh = await sl<GetMyRoomsUseCase>().call();
      if (mounted) {
        setState(() {
          _rooms = fresh.where((r) => !r.hasPendingInvite(_myUserId)).toList();
          _loadingRooms = false;
        });
      }
    } catch (_) {
      // Cached list (if any) stays — a failed refresh isn't worth surfacing
      // an error for in a share sheet.
    }

    try {
      final suggested =
          await FollowRepository().getSuggestedPhotographers(limit: 10);
      if (mounted) {
        setState(() {
          _recommended = suggested;
          _loadingRecommended = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingRecommended = false);
    }
  }

  void _onScroll() {
    if (_loadingMore || !_hasMore) return;
    final pos = _scrollCtrl.position;
    if (pos.pixels >= pos.maxScrollExtent - 120) {
      _loadMore();
    }
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _error = null;
        _loading = false;
        _hasMore = false;
        _page = 1;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _page = 1;
    });
    try {
      final page =
          await sl<UserSearchDataSource>().search(query.trim(), page: 1);
      if (mounted) {
        setState(() {
          _results = page.users;
          _hasMore = page.hasMore;
          _page = 1;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _error = e.toString();
          _loading = false;
        });
    }
  }

  Future<void> _loadMore() async {
    final query = _searchCtrl.text.trim();
    if (query.isEmpty || _loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final next = _page + 1;
      final page = await sl<UserSearchDataSource>().search(query, page: next);
      if (mounted) {
        setState(() {
          _results = [..._results, ...page.users];
          _hasMore = page.hasMore;
          _page = next;
          _loadingMore = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _sendTo(ShareableUser user) async {
    if (_sendingTo != null) return;
    setState(() => _sendingTo = user.id);
    try {
      final room = await sl<GetOrCreateDirectRoomUseCase>().call(
        recipientId: user.id,
        recipientRole: user.role,
        localDisplayName: user.name,
      );
      if (!mounted) return;
      _openRoom(room);
    } catch (e) {
      if (mounted) {
        setState(() => _sendingTo = null);
        AppSnackBar.error(
          context,
          chatErrorText(
            e,
            fallback: AppLocalizations.of(context)!
                .shareSheetCouldNotOpenChat(e.toString()),
          ),
        );
      }
    }
  }

  /// A recommended creator tapped before any DM room exists with them yet —
  /// same flow as [_sendTo], just fed from [_recommended] instead of search.
  Future<void> _sendToRecommended(SuggestedPhotographer p) async {
    if (_sendingTo != null) return;
    setState(() => _sendingTo = p.id);
    try {
      final room = await sl<GetOrCreateDirectRoomUseCase>().call(
        recipientId: p.id,
        recipientRole: 'photographer',
        localDisplayName: p.name,
      );
      if (!mounted) return;
      _openRoom(room);
    } catch (e) {
      if (mounted) {
        setState(() => _sendingTo = null);
        AppSnackBar.error(
          context,
          chatErrorText(
            e,
            fallback: AppLocalizations.of(context)!
                .shareSheetCouldNotOpenChat(e.toString()),
          ),
        );
      }
    }
  }

  /// A room the user is already in — shares straight into it, no
  /// get-or-create round trip needed since it already exists.
  Future<void> _shareToRoom(ChatRoom room) async {
    if (_sendingRoomId != null) return;
    setState(() => _sendingRoomId = room.id);
    _openRoom(room);
  }

  void _openRoom(ChatRoom room) {
    if (!mounted) return;
    Navigator.of(context).pop();
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => ChatRoomPage(room: room, shareUrl: widget.imageUrl),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return Container(
      height: MediaQuery.sizeOf(context).height * 0.75,
      decoration: BoxDecoration(
        color: ext.homeBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: EdgeInsets.symmetric(vertical: AppSpacing.md.h),
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: ext.searchHintColor.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
          ),

          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 12.h),
            child: Text(
              'Send to…',
              style: TextStyle(
                color: ext.greetingColor,
                fontWeight: FontWeight.bold,
                fontSize: 17.sp,
              ),
            ),
          ),

          // Search field
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg.w),
            child: SearchField(
              controller: _searchCtrl,
              hint: 'Search by name…',
              // No autofocus — the sheet opens to recent chats/suggestions
              // to browse, not straight to the keyboard.
              autofocus: false,
              loading: _loading,
              onChanged: (q) => _search(q),
            ),
          ),

          SizedBox(height: AppSpacing.sm.h),
          Divider(
              height: 1, color: ext.searchHintColor.withValues(alpha: 0.12)),

          // Results
          Expanded(
            child: _searchCtrl.text.trim().isEmpty
                ? _buildBrowseList(ext)
                : _error != null
                ? Center(
                    child: Text(_error!,
                        style: TextStyle(
                            color: ext.searchHintColor, fontSize: 13.sp),
                        textAlign: TextAlign.center))
                : _results.isEmpty && !_loading
                    ? Center(
                        child: Text(
                          _searchCtrl.text.isEmpty
                              ? 'Type a name to search'
                              : 'No users found.',
                          style: TextStyle(
                              color: ext.searchHintColor, fontSize: 13.sp),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: EdgeInsets.symmetric(vertical: AppSpacing.sm.h),
                        itemCount: _results.length + (_loadingMore ? 1 : 0),
                        itemBuilder: (_, i) {
                          if (i == _results.length) {
                            return Padding(
                              padding: EdgeInsets.symmetric(vertical: AppSpacing.lg.h),
                              child: Center(
                                child: SizedBox(
                                  width: 20.w,
                                  height: 20.w,
                                  child: CircularProgressIndicator(
                                      color: ext.accentGold, strokeWidth: 2),
                                ),
                              ),
                            );
                          }
                          final u = _results[i];
                          final isSending = _sendingTo == u.id;
                          return ListTile(
                            leading: CircleAvatar(
                              radius: 22.r,
                              backgroundColor:
                                  ext.accentGold.withValues(alpha: 0.15),
                              backgroundImage: u.imageUrl != null
                                  ? NetworkImage(u.imageUrl!)
                                  : null,
                              child: u.imageUrl == null
                                  ? Icon(Icons.person_rounded,
                                      color: ext.accentGold, size: 20.sp)
                                  : null,
                            ),
                            title: Text(u.name,
                                style: TextStyle(
                                    color: ext.greetingColor,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14.sp)),
                            subtitle: Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 6.w, vertical: 2.h),
                                  decoration: BoxDecoration(
                                    color: (u.role == 'photographer'
                                            ? ext.accentGold
                                            : Colors.blueAccent)
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(AppRadius.xs.r),
                                  ),
                                  child: Text(
                                    u.role == 'photographer'
                                        ? 'Creator'
                                        : 'User',
                                    style: TextStyle(
                                      color: u.role == 'photographer'
                                          ? ext.accentGold
                                          : Colors.blueAccent,
                                      fontSize: 10.sp,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            trailing: isSending
                                ? SizedBox(
                                    width: 22.w,
                                    height: 22.w,
                                    child: CircularProgressIndicator(
                                        color: ext.accentGold, strokeWidth: 2))
                                : Icon(Icons.send_rounded,
                                    color: ext.accentGold, size: 20.sp),
                            onTap: isSending ? null : () => _sendTo(u),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  /// Default view before the user types anything: existing chats first
  /// (tapping shares straight into that room), then a handful of
  /// recommended creators to start a new chat with. Falls back to the
  /// search results once there's a query.
  Widget _buildBrowseList(AppThemeExtension ext) {
    if (_loadingRooms && _loadingRecommended) {
      return Center(
        child: CircularProgressIndicator(color: ext.accentGold, strokeWidth: 2),
      );
    }
    if (_rooms.isEmpty && _recommended.isEmpty && !_loadingRooms && !_loadingRecommended) {
      return Center(
        child: Text(
          'Type a name to search',
          style: TextStyle(color: ext.searchHintColor, fontSize: 13.sp),
        ),
      );
    }

    return ListView(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.sm.h),
      children: [
        if (_rooms.isNotEmpty) ...[
          AppSectionLabel('Recent chats',
              padding: EdgeInsets.fromLTRB(AppSpacing.lg.w, AppSpacing.sm.h,
                  AppSpacing.lg.w, AppSpacing.xs.h)),
          for (final room in _rooms)
            RoomTile(
              room: room,
              currentUserId: _myUserId,
              onTap: _sendingRoomId != null ? () {} : () => _shareToRoom(room),
            ),
          SizedBox(height: AppSpacing.xs.h),
        ],
        if (_recommended.isNotEmpty) ...[
          AppSectionLabel('Suggested',
              padding: EdgeInsets.fromLTRB(AppSpacing.lg.w, AppSpacing.sm.h,
                  AppSpacing.lg.w, AppSpacing.xs.h)),
          for (final p in _recommended)
            ListTile(
              leading: CircleAvatar(
                radius: 22.r,
                backgroundColor: ext.accentGold.withValues(alpha: 0.15),
                backgroundImage:
                    p.profileUrl != null ? NetworkImage(p.profileUrl!) : null,
                child: p.profileUrl == null
                    ? Icon(Icons.person_rounded,
                        color: ext.accentGold, size: 20.sp)
                    : null,
              ),
              title: Text(p.name,
                  style: TextStyle(
                      color: ext.greetingColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 14.sp)),
              subtitle: Container(
                margin: const EdgeInsets.only(top: 2),
                padding:
                    EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: ext.accentGold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.xs.r),
                ),
                child: Text(
                  'Creator',
                  style: TextStyle(
                    color: ext.accentGold,
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              trailing: _sendingTo == p.id
                  ? SizedBox(
                      width: 22.w,
                      height: 22.w,
                      child: CircularProgressIndicator(
                          color: ext.accentGold, strokeWidth: 2))
                  : Icon(Icons.send_rounded,
                      color: ext.accentGold, size: 20.sp),
              onTap: _sendingTo != null ? null : () => _sendToRecommended(p),
            ),
        ],
      ],
    );
  }
}

