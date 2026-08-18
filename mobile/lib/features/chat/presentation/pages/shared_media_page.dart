import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/common/widgets/app_widgets.dart';
import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/utils/web_wrap.dart';
import 'package:jperg_app/core/widgets/jperg_image.dart';
import 'package:jperg_app/core/widgets/video_player/jperg_video_player.dart';
import 'package:jperg_app/core/widgets/zoomable_photo.dart';
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
        leading: const AppBackButton(),
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

  void _open(BuildContext context) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => item.isVideo
            ? _MediaVideoView(url: item.url)
            : _MediaPhotoView(url: item.url),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return Semantics(
      button: true,
      label: item.isVideo ? 'Open video' : 'Open photo',
      child: GestureDetector(
        onTap: () => _open(context),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4.r),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: ext.searchFieldFill),
              // Videos get a poster too. JpergImage recognises a video URL and
              // renders its still frame; only a video it cannot derive one for
              // falls back to the empty slot. This cell used to skip the image
              // entirely for anything video, so every clip in the grid was a
              // grey square with a play icon and no way to tell them apart.
              JpergImage(imageUrl: item.url, fit: BoxFit.cover),
              if (item.isVideo)
                Center(
                  child: Icon(
                    Icons.play_circle_fill_rounded,
                    color: Colors.white.withValues(alpha: 0.9),
                    size: 28.sp,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full-screen photo opened from the grid.
class _MediaPhotoView extends StatelessWidget {
  const _MediaPhotoView({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: ZoomablePhoto(imageUrl: url, semanticLabel: 'Shared photo'),
          ),
          const _CloseButton(),
        ],
      ),
    );
  }
}

/// Full-screen video opened from the grid.
class _MediaVideoView extends StatelessWidget {
  const _MediaVideoView({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: JpergVideoPlayer(
              url: url,
              fit: BoxFit.contain,
              autoPlay: true,
              loop: false,
            ),
          ),
          const _CloseButton(),
        ],
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      right: 12,
      child: Semantics(
        button: true,
        label: 'Close',
        child: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.black54,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.close_rounded, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
