import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/di/service_locator.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/features/discovery/data/datasources/client_saved_data_source.dart';

class SavedItemsPage extends StatefulWidget {
  static const routeName = '/saved-items';
  const SavedItemsPage({super.key});

  @override
  State<SavedItemsPage> createState() => _SavedItemsPageState();
}

class _SavedItemsPageState extends State<SavedItemsPage> {
  final _ds = sl<ClientSavedDataSource>();
  List<SavedItem>? _items;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _ds.listSaved();
      if (mounted) setState(() { _items = items; _loading = false; });
    } catch (_) {
      if (mounted) {
        setState(() { _error = 'Could not load saved items.'; _loading = false; });
      }
    }
  }

  Future<void> _unsave(SavedItem item) async {
    try {
      if (item.savedItemId.isNotEmpty) {
        await _ds.unsaveById(item.savedItemId);
      } else {
        await _ds.unsaveByAsset(assetType: item.assetType, assetId: item.assetId);
      }
      if (mounted) {
        setState(() =>
            _items?.removeWhere((i) => i.savedItemId == item.savedItemId));
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to remove item.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    return Scaffold(
      backgroundColor: ext.homeBackground,
      appBar: AppBar(
        backgroundColor: ext.homeBackground,
        elevation: 0,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Saved',
          style: TextStyle(
            color: ext.greetingColor,
            fontWeight: FontWeight.w700,
            fontSize: 18.sp,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: ext.greetingColor, size: 18.sp),
          onPressed: () => Navigator.of(context).pop(),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(
            height: 1,
            thickness: 0.5,
            color: ext.searchHintColor.withValues(alpha: 0.12),
          ),
        ),
      ),
      body: _buildBody(ext),
    );
  }

  Widget _buildBody(AppThemeExtension ext) {
    if (_loading) {
      return Center(
        child: CircularProgressIndicator(color: ext.accentGold),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_outlined,
                  size: 48.sp, color: ext.searchHintColor),
              SizedBox(height: 12.h),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: ext.searchHintColor, fontSize: 14.sp)),
              SizedBox(height: 16.h),
              TextButton(
                onPressed: _load,
                child: Text('Retry',
                    style: TextStyle(
                        color: ext.accentGold, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      );
    }

    final items = _items ?? [];
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(32.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bookmark_border_rounded,
                  size: 56.sp, color: ext.searchHintColor),
              SizedBox(height: 14.h),
              Text(
                'No saved items yet',
                style: TextStyle(
                  color: ext.greetingColor,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 6.h),
              Text(
                'Bookmark events to find them here.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: ext.searchHintColor, fontSize: 13.sp),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: ext.accentGold,
      child: ListView.separated(
        padding: EdgeInsets.symmetric(vertical: 8.h),
        itemCount: items.length,
        separatorBuilder: (_, __) => Divider(
          height: 1,
          thickness: 0.5,
          color: ext.searchHintColor.withValues(alpha: 0.1),
        ),
        itemBuilder: (_, i) => _SavedItemTile(
          item: items[i],
          ext: ext,
          onUnsave: () => _unsave(items[i]),
        ),
      ),
    );
  }
}

// ── Saved item tile ────────────────────────────────────────────────────────────

class _SavedItemTile extends StatelessWidget {
  const _SavedItemTile({
    required this.item,
    required this.ext,
    required this.onUnsave,
  });
  final SavedItem item;
  final AppThemeExtension ext;
  final VoidCallback onUnsave;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding:
          EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8.r),
        child: item.thumbnailUrl != null
            ? Image.network(
                item.thumbnailUrl!,
                width: 56.w,
                height: 56.w,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _thumb(ext),
              )
            : _thumb(ext),
      ),
      title: Text(
        item.title ?? item.assetType,
        style: TextStyle(
          color: ext.greetingColor,
          fontWeight: FontWeight.w600,
          fontSize: 14.sp,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        item.assetType,
        style: TextStyle(color: ext.searchHintColor, fontSize: 12.sp),
      ),
      trailing: IconButton(
        icon: Icon(Icons.bookmark_remove_rounded,
            color: ext.accentGold, size: 22.sp),
        tooltip: 'Unsave',
        onPressed: onUnsave,
      ),
    );
  }

  Widget _thumb(AppThemeExtension ext) => Container(
        width: 56.w,
        height: 56.w,
        decoration: BoxDecoration(
          color: ext.searchFieldFill,
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Icon(Icons.photo_outlined,
            color: ext.searchHintColor, size: 24.sp),
      );
}
