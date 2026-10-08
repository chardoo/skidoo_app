import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/cache/session_cache.dart';
import 'package:jperg_app/core/common/widgets/app_empty_state.dart';
import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/theme/app_typography.dart';
import 'package:jperg_app/core/utils/snackbar_utils.dart';
import 'package:jperg_app/l10n/app_localizations.dart';
import 'package:jperg_app/features/discovery/data/datasources/client_saved_data_source.dart';
import 'package:jperg_app/features/discovery/data/datasources/discovery_remote_data_source.dart';
import 'package:jperg_app/features/discovery/presentation/bloc/discovery_bloc.dart';
import 'package:jperg_app/features/discovery/presentation/pages/event_pictures_page.dart';
import 'package:jperg_app/features/gallery/presentation/found/pages/found_photo_viewer_page.dart';
import 'package:jperg_app/models/photos/Photo.dart';
import 'package:jperg_app/models/event_discovery/event_discovery.dart';
import 'package:jperg_app/core/widgets/animations/app_animations.dart';
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/widgets/jperg_image.dart';
import 'package:jperg_app/core/common/widgets/app_back_button.dart';
import 'package:jperg_app/core/common/widgets/app_error_view.dart';
import 'package:jperg_app/core/theme/app_icons.dart';

class SavedItemsPage extends StatefulWidget {
  static const routeName = '/saved-items';
  const SavedItemsPage({super.key});

  @override
  State<SavedItemsPage> createState() => _SavedItemsPageState();
}

/// The list as it was last fetched, plus the event names resolving it cost.
///
/// This screen is pushed fresh from Account every time, and opening it ran the
/// list request and then one request per event whose name was not already in
/// DiscoveryBloc — so every visit rebuilt the same rows from scratch behind a
/// spinner. Bookmarking anywhere bumps [AppCacheSignals.saves], which is what
/// makes the next open fetch again.
class _SavedSnapshot {
  const _SavedSnapshot(this.items, this.names);
  final List<SavedItem> items;
  final Map<String, String> names;
}

final _savedCache = SessionCache<_SavedSnapshot>(
  'savedItems',
  signal: AppCacheSignals.saves,
);

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
    final cached = _savedCache.isFresh ? _savedCache.value : null;
    if (cached != null) {
      _items = cached.items;
      _resolvedNames.addAll(cached.names);
      _loading = false;
    } else {
      _load();
    }
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
      // Cached before the names resolve so a quick second visit still skips the
      // list request; _resolveEventNames writes the names in as they land.
      _savedCache.save(_SavedSnapshot(items, _resolvedNames));
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

  /// Opens a saved item: an album at its first photo, a photo at itself.
  ///
  /// A bookmarked picture used to be a tap that did nothing. The guard below
  /// returned on anything that was not an event, and the app does save
  /// pictures — the bookmark on a photo rail writes `assetType: 'picture'`
  /// (see [ApiSavedPhotoStore]) — so the one kind of saved item somebody is
  /// most likely to have was the kind this screen ignored.
  ///
  /// A photo opens *inside its own album*, at itself, rather than dropping
  /// somebody at the top of a grid to go looking for the thing they just
  /// tapped. That is what the profile's liked and bookmarked grids already do
  /// — see `UserProfilePage._openTile` — and this reuses the same two moves:
  /// fetch the parent event, find the photo in it by id.
  Future<void> _openEvent(SavedItem item) async {
    debugPrint(
        '[SavedItems] tap assetType="${item.assetType}" assetId="${item.assetId}" title="${item.title}"');

    final type = item.assetType.toLowerCase();
    if (type == 'picture') {
      await _openPicture(item);
      return;
    }
    if (type != 'event') {
      // Requests and campaigns are savable server-side but have no screen
      // here. Silence was the old behaviour for *everything*, which is how
      // pictures went unnoticed; say so rather than letting a tap die.
      debugPrint('[SavedItems] no screen for assetType "${item.assetType}"');
      if (mounted) {
        AppSnackBar.error(context, 'That item cannot be opened here.');
      }
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

  /// A bookmarked photo, opened at itself inside its own album.
  ///
  /// The album is what makes this better than showing the one photo alone:
  /// swiping from a saved photo should walk the event it came from, the way
  /// it does everywhere else a photo is opened.
  ///
  /// `parentEventId` comes from the saved record — the server hydrates a
  /// saved picture with its `eventId` and always has; the client simply was
  /// not reading it. Without it there is no album to open, so the photo is
  /// shown on its own rather than refusing the tap.
  Future<void> _openPicture(SavedItem item) async {
    final eventId = item.parentEventId;

    if (eventId == null || eventId.isEmpty) {
      debugPrint('[SavedItems] picture has no parent event — opening alone');
      _openPhotoAlone(item);
      return;
    }

    setState(() => _loading = true);
    try {
      final event = await _remoteDs.getEventById(eventId);
      final photos = photosOfEvent(event);
      if (!mounted) return;

      // The album came back without the photo in it: it may have been taken
      // down, or made private since it was saved. Its own URL still works, so
      // that is what opens.
      final index = photos.indexWhere((p) => p.id == item.assetId);
      if (photos.isEmpty || index < 0) {
        debugPrint('[SavedItems] photo not in its album — opening alone');
        _openPhotoAlone(item);
        return;
      }

      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => FoundPhotoViewerPage(photos: photos, initialIndex: index),
      ));
    } catch (e) {
      debugPrint('[SavedItems] could not open the album: $e');
      if (!mounted) return;
      // The album could not be fetched; the photo itself still opens. Same
      // fallback UserProfilePage makes, and for the same reason: a tap that
      // does nothing is the worst answer available.
      _openPhotoAlone(item);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// The saved photo by itself, when its album cannot be reached.
  void _openPhotoAlone(SavedItem item) {
    final url = item.thumbnailUrl;
    if (url == null || url.isEmpty) {
      if (mounted) AppSnackBar.error(context, 'Could not open that photo.');
      return;
    }
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => FoundPhotoViewerPage(
        photos: [
          Photo(
            item.assetId, // id
            item.title ?? '', // eventName
            item.assetId, // imageId
            url,
            '', // userId — unknown without the album
            0, // price
            '', // eventDate
            null, // identification
            // Saved from somewhere it was visible, and shown to the person who
            // saved it. The badge is about who else can see it, and without
            // the album there is nothing truthful to say — so it claims
            // nothing rather than claiming public.
            false,
          ),
        ],
      ),
    ));
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
      // Tells the profile's Bookmarked tab, which no longer refetches on its
      // own. Re-saving straight after is what keeps this screen's own copy
      // current rather than stale on the strength of its own edit.
      AppCacheSignals.saves.bump();
      final items = _items;
      if (items != null) {
        _savedCache.save(_SavedSnapshot(items, _resolvedNames));
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
            fontFamily: AppTypography.displayFontFamily,
            fontSize: 18.sp,
          ),
        ),
        leading: const AppBackButton(),
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
    return page;
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
      // Pull-to-refresh on the empty branch too. The list branch below has it,
      // and a saved list that has just been emptied on another device is
      // exactly when somebody pulls to check.
      return RefreshIndicator(
        onRefresh: _load,
        color: ext.accentGold,
        child: const ScrollableEmptyState(
          child: AppEmptyState(
            icon: AppIcons.emptySaved,
            message: 'No saved items yet',
            hint: 'Bookmark events to find them here.',
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
          fontWeight: FontWeight.w500,
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
