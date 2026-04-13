import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/di/service_locator.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/features/chat/data/datasources/user_search_data_source.dart';
import 'package:skidoo_app/features/chat/domain/usecases/chat_usecases.dart';
import 'package:skidoo_app/features/chat/presentation/pages/chat_room_page.dart';
import 'package:skidoo_app/models/chat/shareable_user.dart';

/// Bottom sheet that lets the user search any app user (client or photographer)
/// and share a photo to their DM room.
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

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
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
      setState(() { _results = []; _error = null; _loading = false; _hasMore = false; _page = 1; });
      return;
    }
    setState(() { _loading = true; _error = null; _page = 1; });
    try {
      final page = await sl<UserSearchDataSource>().search(query.trim(), page: 1);
      if (mounted) {
        setState(() {
          _results = page.users;
          _hasMore = page.hasMore;
          _page = 1;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
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
      Navigator.of(context).pop();
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatRoomPage(room: room, shareUrl: widget.imageUrl),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _sendingTo = null);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not open chat: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
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
              margin: EdgeInsets.symmetric(vertical: 12.h),
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
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
              style: TextStyle(color: ext.greetingColor, fontSize: 14.sp),
              decoration: InputDecoration(
                hintText: 'Search by name…',
                hintStyle: TextStyle(color: ext.searchHintColor),
                prefixIcon: Icon(Icons.search_rounded,
                    color: ext.searchHintColor, size: 20.sp),
                suffixIcon: _loading
                    ? Padding(
                        padding: EdgeInsets.all(12.r),
                        child: SizedBox(
                          width: 16.w,
                          height: 16.w,
                          child: CircularProgressIndicator(
                              color: ext.accentGold, strokeWidth: 2),
                        ),
                      )
                    : null,
                filled: true,
                fillColor: ext.searchFieldFill,
                border: OutlineInputBorder(
                  borderSide: BorderSide.none,
                  borderRadius: BorderRadius.circular(14.r),
                ),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                isDense: true,
              ),
              onChanged: (q) => _search(q),
            ),
          ),

          SizedBox(height: 8.h),
          Divider(height: 1, color: ext.searchHintColor.withValues(alpha: 0.12)),

          // Results
          Expanded(
            child: _error != null
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
                        padding: EdgeInsets.symmetric(vertical: 8.h),
                        itemCount: _results.length + (_loadingMore ? 1 : 0),
                        itemBuilder: (_, i) {
                          if (i == _results.length) {
                            return Padding(
                              padding: EdgeInsets.symmetric(vertical: 16.h),
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
                                    borderRadius: BorderRadius.circular(4.r),
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
                                SizedBox(width: 6.w),
                                Expanded(
                                  child: Text(u.email,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          color: ext.searchHintColor,
                                          fontSize: 11.sp)),
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
}
