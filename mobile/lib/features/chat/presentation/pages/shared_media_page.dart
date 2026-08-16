import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/common/widgets/app_widgets.dart';
import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/utils/web_wrap.dart';
import 'package:jperg_app/core/widgets/jperg_image.dart';
import 'package:jperg_app/features/chat/domain/usecases/chat_usecases.dart';
import 'package:jperg_app/models/chat/shared_media.dart';

/// Every photo and video shared in a room, newest first, in a three-column
/// grid.
class SharedMediaPage extends StatefulWidget {
  const SharedMediaPage({super.key, required this.roomId});

  final String roomId;

  @override
  State<SharedMediaPage> createState() => _SharedMediaPageState();
}

class _SharedMediaPageState extends State<SharedMediaPage> {
  static const _pageSize = 60;

  final _getMedia = sl<GetRoomMediaUseCase>();
  final _scrollController = ScrollController();

  final List<SharedMediaItem> _items = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = false;
  int _page = 1;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _isLoadingMore || _isLoading) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 400) {
      _loadMore();
    }
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final page = await _getMedia(widget.roomId, page: 1, limit: _pageSize);
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(page.items);
        _hasMore = page.hasMore;
        _page = 1;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Could not load shared media.';
      });
    }
  }

  Future<void> _loadMore() async {
    setState(() => _isLoadingMore = true);
    try {
      final next = _page + 1;
      final page = await _getMedia(widget.roomId, page: next, limit: _pageSize);
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _hasMore = page.hasMore;
        _page = next;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      // Keep what is already on screen and stop paging — a failed page should
      // not empty the grid the user is looking at.
      setState(() {
        _isLoadingMore = false;
        _hasMore = false;
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
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: AppBackButton(onPressed: () => Navigator.of(context).pop()),
        title: Text(
          'Shared Media',
          style: TextStyle(
            color: ext.greetingColor,
            fontWeight: FontWeight.bold,
            fontSize: 17.sp,
          ),
        ),
      ),
      body: _buildBody(ext),
    );
    return webWrap(page, backgroundColor: ext.homeBackground);
  }

  Widget _buildBody(AppThemeExtension ext) {
    if (_isLoading) return const AppLoadingIndicator();

    if (_error != null) {
      return AppErrorView(
        message: _error!,
        icon: Icons.photo_library_outlined,
        onRetry: _load,
      );
    }

    if (_items.isEmpty) {
      return const AppEmptyState(
        icon: Icons.photo_library_outlined,
        message: 'No photos or videos have been shared here yet.',
      );
    }

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: GridView.builder(
          controller: _scrollController,
          padding: EdgeInsets.all(AppSpacing.md.w),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 6.w,
            crossAxisSpacing: 6.w,
          ),
          itemCount: _items.length + (_isLoadingMore ? 3 : 0),
          itemBuilder: (context, index) {
            if (index >= _items.length) {
              return ColoredBox(
                color: ext.searchFieldFill,
                child: const SizedBox.expand(),
              );
            }
            return _MediaCell(item: _items[index]);
          },
        ),
      ),
    );
  }
}

class _MediaCell extends StatelessWidget {
  const _MediaCell({required this.item});

  final SharedMediaItem item;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return ClipRRect(
      borderRadius: BorderRadius.circular(4.r),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: ext.searchFieldFill),
          // A video's URL points at the file, not a still, so the thumbnail
          // slot shows the play badge over the placeholder rather than a frame.
          if (!item.isVideo)
            JpergImage(
              imageUrl: item.url,
              fit: BoxFit.cover,
            ),
          if (item.isVideo)
            Center(
              child: Icon(Icons.play_circle_outline_rounded,
                  color: ext.greetingColor, size: 28.sp),
            ),
        ],
      ),
    );
  }
}
