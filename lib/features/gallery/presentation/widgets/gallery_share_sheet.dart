import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/di/service_locator.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/features/chat/domain/usecases/chat_usecases.dart';
import 'package:skidoo_app/features/chat/presentation/pages/chat_room_page.dart';
import 'package:skidoo_app/features/photographers/data/datasources/photographer_remote_data_source.dart';
import 'package:skidoo_app/models/photographer/photographerModel.dart';

/// Bottom sheet that lets the user search for a photographer and share a
/// photo to their DM room.
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
  List<PhotographerModel> _results = [];
  bool _loading = false;
  String? _error;
  String? _sendingTo;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    setState(() { _loading = true; _error = null; });
    try {
      final ds = sl<PhotographerRemoteDataSource>();
      final results = query.isEmpty
          ? await ds.getPhotographers()
          : await ds.searchPhotographers(query);
      if (mounted) setState(() { _results = results; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _sendTo(PhotographerModel photographer) async {
    if (_sendingTo != null) return;
    setState(() => _sendingTo = photographer.id);
    try {
      final room = await sl<GetOrCreateDirectRoomUseCase>().call(
        recipientId: photographer.id,
        recipientRole: 'photographer',
        localDisplayName: photographer.name,
      );
      if (!mounted) return;
      Navigator.of(context).pop(); // close the share sheet
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
              'Share to…',
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
              style: TextStyle(color: ext.greetingColor, fontSize: 14.sp),
              decoration: InputDecoration(
                hintText: 'Search photographers…',
                hintStyle: TextStyle(color: ext.searchHintColor),
                prefixIcon: Icon(Icons.search_rounded,
                    color: ext.searchHintColor, size: 20.sp),
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
              onChanged: (q) => _search(q.trim()),
            ),
          ),

          SizedBox(height: 8.h),

          Divider(height: 1, color: ext.searchHintColor.withValues(alpha: 0.12)),

          // Results
          Expanded(
            child: _loading
                ? Center(
                    child: CircularProgressIndicator(color: ext.accentGold,
                        strokeWidth: 2))
                : _error != null
                    ? Center(
                        child: Text(_error!,
                            style: TextStyle(
                                color: ext.searchHintColor, fontSize: 13.sp),
                            textAlign: TextAlign.center))
                    : _results.isEmpty
                        ? Center(
                            child: Text('No photographers found.',
                                style: TextStyle(
                                    color: ext.searchHintColor, fontSize: 13.sp)))
                        : ListView.builder(
                            padding: EdgeInsets.symmetric(vertical: 8.h),
                            itemCount: _results.length,
                            itemBuilder: (_, i) {
                              final p = _results[i];
                              final isSending = _sendingTo == p.id;
                              return ListTile(
                                leading: CircleAvatar(
                                  radius: 22.r,
                                  backgroundColor:
                                      ext.accentGold.withValues(alpha: 0.15),
                                  backgroundImage: p.imageUrl != null
                                      ? NetworkImage(p.imageUrl!)
                                      : null,
                                  child: p.imageUrl == null
                                      ? Icon(Icons.person_rounded,
                                          color: ext.accentGold, size: 20.sp)
                                      : null,
                                ),
                                title: Text(p.name,
                                    style: TextStyle(
                                        color: ext.greetingColor,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14.sp)),
                                subtitle: Text(p.email,
                                    style: TextStyle(
                                        color: ext.searchHintColor,
                                        fontSize: 11.sp)),
                                trailing: isSending
                                    ? SizedBox(
                                        width: 22.w,
                                        height: 22.w,
                                        child: CircularProgressIndicator(
                                            color: ext.accentGold,
                                            strokeWidth: 2))
                                    : Icon(Icons.send_rounded,
                                        color: ext.accentGold, size: 20.sp),
                                onTap: isSending ? null : () => _sendTo(p),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
