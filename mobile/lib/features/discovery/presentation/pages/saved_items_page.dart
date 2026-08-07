import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/utils/snackbar_utils.dart';
import 'package:jperg_app/l10n/app_localizations.dart';
import 'package:jperg_app/features/discovery/data/datasources/client_saved_data_source.dart';
import 'package:jperg_app/features/discovery/data/datasources/discovery_remote_data_source.dart';
import 'package:jperg_app/features/discovery/presentation/bloc/discovery_bloc.dart';
import 'package:jperg_app/features/discovery/presentation/pages/event_pictures_page.dart';
import 'package:jperg_app/models/event_discovery/event_discovery.dart';
import 'package:jperg_app/core/utils/web_wrap.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:jperg_app/core/widgets/animations/app_animations.dart';
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/widgets/jperg_image.dart';
import 'package:jperg_app/core/common/widgets/app_back_button.dart';
import 'package:jperg_app/core/common/widgets/app_error_view.dart';

class SavedItemsPage extends StatefulWidget {
  static const routeName = '/saved-items';
  const SavedItemsPage({super.key});

  @override
  State<SavedItemsPage> createState() => _SavedItemsPageState();
}

class _SavedItemsPageState extends State<SavedItemsPage> {
  final _ds = sl<ClientSavedDataSource>();
  final _remoteDs = sl<DiscoveryRemoteDataSource>();
  List<SavedItem>? _items;

  /// eventId → resolved event name (populated after load).
  final Map<String, String> _resolvedNames = {};
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
      _resolvedNames.clear();
    });
    try {
      final items = await _ds.listSaved();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
      // Resolve event names in background — no spinner needed.
      _resolveEventNames(items);
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Could not load saved items.';
          _loading = false;
        });
      }
    }
  }

  /// Populate [_resolvedNames] for every event-type saved item.
  /// Tries DiscoveryBloc first (zero network cost), then fetches from
  /// the backend for any whose name is still unknown.
  Future<void> _resolveEventNames(List<SavedItem> items) async {
    final eventItems =
        items.where((i) => i.assetType.toLowerCase() == 'event').toList();
    if (eventItems.isEmpty) return;

    // 1 — Synchronous lookup in DiscoveryBloc state.
    final missing = <SavedItem>[];
    try {
      final knownEvents = context.read<DiscoveryBloc>().state.events;
      for (final item in eventItems) {
        final ev = knownEvents.where((e) => e.id == item.assetId).firstOrNull;
        if (ev != null && ev.eventName.isNotEmpty) {
          _resolvedNames[item.assetId] = ev.eventName;
        } else {
          missing.add(item);
        }
      }
    } catch (_) {
      missing.addAll(eventItems);
    }

    if (missing.isEmpty) {
      if (mounted) setState(() {});
      return;
    }

    // 2 — Flush DiscoveryBloc hits to UI immediately.
    if (mounted) setState(() {});

    // 3 — Fetch remaining names from backend in parallel.
    await Future.wait(missing.map((item) async {
      try {
        final ev = await _remoteDs.getEventById(item.assetId);
        if (ev.eventName.isNotEmpty) {
          _resolvedNames[item.assetId] = ev.eventName;
        }
      } catch (_) {
        // Leave this item without a resolved name — the fallback shows.
      }
    }));

    if (mounted) setState(() {});
  }

  Future<void> _openEvent(SavedItem item) async {
    debugPrint(
        '[SavedItems] tap assetType="${item.assetType}" assetId="${item.assetId}" title="${item.title}"');
    // Only handle event assets.
    if (item.assetType.toLowerCase() != 'event') {
      debugPrint('[SavedItems] skipping — assetType is not event');
      return;
    }
    final eventId = item.assetId;

    // Check if the event is already loaded in DiscoveryBloc state.
    EventDiscovery? event;
    try {
      final discoveryState = context.read<DiscoveryBloc>().state;
      event = discoveryState.events.where((e) => e.id == eventId).firstOrNull;
      debugPrint(
          '[SavedItems] DiscoveryBloc lookup eventId=$eventId → found=${event != null} name=${event?.eventName}');
    } catch (e) {
      debugPrint('[SavedItems] DiscoveryBloc not accessible: $e');
    }

    if (event == null) {
      // Fetch from backend.
      if (!mounted) return;
      setState(() => _loading = true);
      try {
        event = await sl<DiscoveryRemoteDataSource>().getEventById(eventId);
        debugPrint(
            '[SavedItems] fetched eventId=$eventId name=${event.eventName} pics=${event.pictures.length}');
      } catch (e) {
        debugPrint('[SavedItems] fetch failed: $e');
        if (mounted) {
          setState(() => _loading = false);
          AppSnackBar.error(context,
              AppLocalizations.of(context)!.savedItemsCouldNotLoadEvent);
        }
        return;
      }
      if (!mounted) return;
      setState(() => _loading = false);
    }

    // If the fetched event has no name, patch from already-resolved names.
    if (event.eventName.isEmpty) {
      final fallback = _resolvedNames[item.assetId] ?? item.title;
      if (fallback != null && fallback.isNotEmpty) {
        event = EventDiscovery(
          id: event.id,
          eventName: fallback,
          photographerName: event.photographerName,
          photographerId: event.photographerId,
          pictures: event.pictures,
          likes: event.likes,
          dislikes: event.dislikes,
          commentCount: event.commentCount,
          userReaction: event.userReaction,
        );
      }
    }

    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => EventPicturesPage(event: event!),
        ),
      );
    }
  }

  Future<void> _unsave(SavedItem item) async {
    try {
      if (item.savedItemId.isNotEmpty) {
        await _ds.unsaveById(item.savedItemId);
      } else {
        await _ds.unsaveByAsset(
            assetType: item.assetType, assetId: item.assetId);
      }
      if (mounted) {
        setState(() =>
            _items?.removeWhere((i) => i.savedItemId == item.savedItemId));
      }
    } catch (_) {
      if (!mounted) return;
      AppSnackBar.error(
          context, AppLocalizations.of(context)!.savedItemsFailedToRemove);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final page = Scaffold(
      backgroundColor: ext.homeBackground,
      appBar: AppBar(
        backgroundColor: ext.homeBackground,
        elevation: 0,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
        title: Text(
          AppLocalizations.of(context)!.savedItemsTitle,
          style: TextStyle(
            color: ext.greetingColor,
            fontWeight: FontWeight.w700,
            fontSize: 18.sp,
          ),
        ),
        leading: kIsWeb
            ? null
            : AppBackButton(onPressed: () => Navigator.of(context).pop()),
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
    return webWrap(page, backgroundColor: ext.homeBackground);
  }

  Widget _buildBody(AppThemeExtension ext) {
    if (_loading) {
      return Center(
        child: CircularProgressIndicator(color: ext.accentGold),
      );
    }

    if (_error != null) {
      return AppErrorView(
        message: _error!,
        icon: Icons.cloud_off_outlined,
        onRetry: _load,
      );
    }

    final items = _items ?? [];
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xxxl.w),
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
                style: TextStyle(color: ext.searchHintColor, fontSize: 13.sp),
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
        padding: EdgeInsets.symmetric(vertical: AppSpacing.sm.h),
        itemCount: items.length,
        separatorBuilder: (_, __) => Divider(
          height: 1,
          thickness: 0.5,
          color: ext.searchHintColor.withValues(alpha: 0.1),
        ),
        itemBuilder: (_, i) {
          final item = items[i];
          final resolvedName = _resolvedNames[item.assetId] ?? item.title;
          return Reveal(
            delay: AppMotion.stagger * (i < 8 ? i : 0),
            offset: const Offset(0, 16),
            child: _SavedItemTile(
              item: item,
              ext: ext,
              resolvedName: resolvedName,
              onTap: () => _openEvent(item),
              onUnsave: () => _unsave(item),
            ),
          );
        },
      ),
    );
  }
}

// ── Saved item tile ────────────────────────────────────────────────────────────

class _SavedItemTile extends StatelessWidget {
  const _SavedItemTile({
    required this.item,
    required this.ext,
    this.resolvedName,
    required this.onTap,
    required this.onUnsave,
  });
  final SavedItem item;
  final AppThemeExtension ext;
  final String? resolvedName;
  final VoidCallback onTap;
  final VoidCallback onUnsave;

  @override
  Widget build(BuildContext context) {
    final displayName = resolvedName ?? item.title ?? 'Saved Event';
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.symmetric(
          horizontal: AppSpacing.lg.w, vertical: AppSpacing.xs.h),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.sm.r),
        child: item.thumbnailUrl != null
            ? JpergImage(
                imageUrl: item.thumbnailUrl!,
                semanticLabel: 'Saved item',
                width: 56.w,
                height: 56.w,
                fit: BoxFit.cover,
                placeholder: (_, __) => _thumb(ext),
                errorWidget: (_, __, ___) => _thumb(ext),
              )
            : _thumb(ext),
      ),
      title: Text(
        displayName,
        style: TextStyle(
          color: ext.greetingColor,
          fontWeight: FontWeight.w600,
          fontSize: 14.sp,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        'Event',
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
          borderRadius: BorderRadius.circular(AppRadius.sm.r),
        ),
        child:
            Icon(Icons.photo_outlined, color: ext.searchHintColor, size: 24.sp),
      );
}
