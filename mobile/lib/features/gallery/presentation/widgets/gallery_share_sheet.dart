import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:jperg_app/core/widgets/jperg_image.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/common/widgets/search_field.dart';
import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/core/utils/snackbar_utils.dart';
import 'package:jperg_app/l10n/app_localizations.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/chat/data/datasources/user_search_data_source.dart';
import 'package:jperg_app/features/chat/domain/usecases/chat_usecases.dart';
import 'package:jperg_app/features/chat/presentation/chat_error_text.dart';
import 'package:jperg_app/features/chat/presentation/pages/chat_room_page.dart';
import 'package:jperg_app/features/chat/presentation/widgets/room_tile.dart';
import 'package:jperg_app/features/follow/data/follow_repository.dart';
import 'package:jperg_app/models/chat/chat_room.dart';
import 'package:jperg_app/models/chat/shareable_user.dart';
import 'package:jperg_app/services/auth_service.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/common/widgets/app_section_label.dart';

/// Bottom sheet with an in-app user search to send a photo directly to
/// another app user's DM room. The native OS share sheet is a separate,
/// direct icon on the card itself (see `shareOverlayPhotoExternally` in
/// `media_action_buttons.dart`) — not nested inside this sheet.
class GalleryShareSheet {
  static void show(
    BuildContext context, {
    required String imageUrl,
    required String photoLabel,
    /// Whether this photo costs money and the sender has not bought it.
    ///
    /// Required, not defaulted. It defaulted to false and two of the four
    /// callers never passed it, so sharing from the feed sent an unmarked
    /// message and the omission was invisible — a compile error is the only
    /// thing that catches the next one.
    required bool paidPreview,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (ctx) => _ShareSheetContent(
        imageUrl: imageUrl,
        photoLabel: photoLabel,
        paidPreview: paidPreview,
      ),
    );
  }
}

// ── Sheet content ─────────────────────────────────────────────────────────────

class _ShareSheetContent extends StatefulWidget {
  const _ShareSheetContent({
    required this.imageUrl,
    required this.photoLabel,
    this.paidPreview = false,
  });

  final String imageUrl;
  final String photoLabel;

  /// Whether this photo costs money and the sender has not bought it. Travels
  /// with the message so the recipient's bubble can mark it — see
  /// [ChatMessage.paidPreview].
  final bool paidPreview;

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
          _rooms = cached
              .where((r) =>
                  r.type.isShareTarget && !r.hasPendingInvite(_myUserId))
              .toList();
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
          _rooms = fresh
              .where((r) =>
                  r.type.isShareTarget && !r.hasPendingInvite(_myUserId))
              .toList();
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
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
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
      MaterialPageRoute(
        builder: (_) => ChatRoomPage(
          room: room,
          shareUrl: widget.imageUrl,
          sharePaidPreview: widget.paidPreview,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    // The sheet has to give the keyboard its room back.
    //
    // It was a flat 75% of the screen with nothing watching `viewInsets`, and
    // this sheet's whole purpose is to type a name into: tapping the search
    // field raised the keyboard over the bottom third of it, so the results
    // being searched for were behind the keyboard and the send button could
    // not be reached. `isScrollControlled: true` allows a taller sheet; it does
    // not make one shrink.
    //
    // So: still 75% when there is no keyboard, and never taller than the space
    // actually left above one. The padding moves the sheet up; the height stops
    // it being clipped at the top.
    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom;
    final available = media.size.height - keyboard - media.padding.top;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: keyboard),
      child: Container(
      height: math.min(media.size.height * 0.75, available),
      decoration: BoxDecoration(
        color: ext.homeBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      // ListTile ink paints on the nearest Material ancestor; this decorated
      // Container sits between the sheet's Material and the tiles below and
      // would swallow it (and assert in debug). A transparency Material paints
      // nothing and just gives the ink somewhere to land.
      child: Material(
        type: MaterialType.transparency,
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
                // Says "or email" because it is the only way to reach someone
                // who has hidden their profile — they are out of search by
                // name on purpose, and an exact address still finds them.
                // From l10n rather than hardcoded: the string already existed
                // there and the two had drifted apart.
                hint: AppLocalizations.of(context)!.shareSheetSearchByName,
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
                                    color: ext.searchHintColor,
                                    fontSize: 13.sp),
                              ),
                            )
                          : ListView.builder(
                              controller: _scrollCtrl,
                              padding: EdgeInsets.symmetric(
                                  vertical: AppSpacing.sm.h),
                              itemCount:
                                  _results.length + (_loadingMore ? 1 : 0),
                              itemBuilder: (_, i) {
                                if (i == _results.length) {
                                  return Padding(
                                    padding: EdgeInsets.symmetric(
                                        vertical: AppSpacing.lg.h),
                                    child: Center(
                                      child: SizedBox(
                                        width: 20.w,
                                        height: 20.w,
                                        child: CircularProgressIndicator(
                                            color: ext.accentGold,
                                            strokeWidth: 2),
                                      ),
                                    ),
                                  );
                                }
                                final u = _results[i];
                                return _personTile(
                                  ext,
                                  name: u.name,
                                  imageUrl: u.imageUrl,
                                  sending: _sendingTo == u.id,
                                  onTap: () => _sendTo(u),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
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
    if (_rooms.isEmpty &&
        _recommended.isEmpty &&
        !_loadingRooms &&
        !_loadingRecommended) {
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
            _personTile(
              ext,
              name: p.name,
              imageUrl: p.profileUrl,
              sending: _sendingTo == p.id,
              onTap: () => _sendToRecommended(p),
            ),
        ],
      ],
    );
  }

  /// One row of the person list: picture, name, send.
  ///
  /// Both lists used to carry a "Creator"/"User" badge under the name. Which
  /// kind of account someone has changes nothing about sharing a photo with
  /// them, so it was colour and a second line of text spent on a distinction
  /// the sheet never acts on — and it was the only thing making the search
  /// rows and the suggested rows two different tiles.
  Widget _personTile(
    AppThemeExtension ext, {
    required String name,
    required String? imageUrl,
    required bool sending,
    required VoidCallback onTap,
  }) =>
      ListTile(
        leading: CircleAvatar(
          radius: 22.r,
          backgroundColor: ext.accentGold.withValues(alpha: 0.15),
          backgroundImage: imageUrl != null
              ? boundedNetworkImage(context, imageUrl, diameter: 44.r)
              : null,
          child: imageUrl == null
              ? Icon(Icons.person_rounded, color: ext.accentGold, size: 20.sp)
              : null,
        ),
        title: Text(name,
            style: TextStyle(
                color: ext.greetingColor,
                fontWeight: FontWeight.w600,
                fontSize: 14.sp)),
        trailing: sending
            ? SizedBox(
                width: 22.w,
                height: 22.w,
                child: CircularProgressIndicator(
                    color: ext.accentGold, strokeWidth: 2))
            : Icon(Icons.send_rounded, color: ext.accentGold, size: 20.sp),
        // A send already in flight owns the sheet — tapping a second person
        // would open a second room out from under the first.
        onTap: _sendingTo != null ? null : onTap,
      );
}
