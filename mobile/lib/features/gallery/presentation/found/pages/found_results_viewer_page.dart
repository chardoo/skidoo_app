import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/features/gallery/domain/usecases/get_found_photos_usecase.dart';
import 'package:jperg_app/features/gallery/presentation/found/bloc/found_album_bloc.dart';
import 'package:jperg_app/features/gallery/presentation/found/models/found_filters.dart';
import 'package:jperg_app/features/gallery/presentation/found/pages/found_photo_viewer_page.dart';
import 'package:jperg_app/models/photos/Photo.dart';

/// The Found feed's photo viewer: every photo matching the current filters,
/// not just the ones from the section that was tapped.
///
/// The feed is grouped by event, so a tap used to hand the viewer one album's
/// slice — six photos, or eighteen when filtered. Filter down to twelve
/// results, see all twelve in the grid, open one, and you could swipe through
/// only the handful that shared its event. The rest of what you had just
/// filtered for was unreachable without going back.
///
/// So this fetches the flat, ungrouped read of the same query the grid is
/// showing (`groupBy=none`, the whole result set, paged) and swipes through
/// that instead.
///
/// It opens on [seed] — the photos already on screen — so the picture appears
/// under the finger that tapped it rather than after a round trip, and swaps in
/// the server's full list when it lands. The swap keeps the photo being looked
/// at and re-finds its place; see [FoundPhotoViewerPage.photos].
class FoundResultsViewerPage extends StatelessWidget {
  const FoundResultsViewerPage({
    super.key,
    required this.seed,
    required this.initialPhotoId,
    this.filters = FoundFilters.none,
  });

  /// What the grid had loaded, flattened in the order it is displayed in.
  /// Never empty: it contains at least the tapped photo.
  final List<Photo> seed;

  /// The photo that was tapped, followed across the swap to the server's list.
  final String initialPhotoId;

  /// The grid's filters, passed through unchanged — the viewer shows the
  /// result set the person is actually looking at, not everything they own.
  final FoundFilters filters;

  /// First page big enough to hold the tapped photo in the ordinary case.
  ///
  /// The two orderings differ — the grid clusters by event, the flat list runs
  /// newest first across all of them — so the tapped photo's position here is
  /// not its position there. A page that does not reach it means the swap is
  /// declined and the person keeps the grid's photos, which is the old
  /// behaviour rather than a broken one.
  static const pageSize = 100;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => FoundAlbumBloc(
        getFoundPhotosUseCase: sl<GetFoundPhotosUseCase>(),
        filters: filters,
        pageSize: pageSize,
      )..add(const FoundAlbumPhotosRequested()),
      child: _ResultsViewer(seed: seed, initialPhotoId: initialPhotoId),
    );
  }
}

class _ResultsViewer extends StatefulWidget {
  const _ResultsViewer({required this.seed, required this.initialPhotoId});

  final List<Photo> seed;
  final String initialPhotoId;

  @override
  State<_ResultsViewer> createState() => _ResultsViewerState();
}

class _ResultsViewerState extends State<_ResultsViewer> {
  /// What the viewer is showing: the grid's photos until the server's list
  /// arrives and is found to contain the photo on screen.
  late List<Photo> _photos = widget.seed;

  /// True once the swap has happened, so later pages are appended to the
  /// server's list rather than re-deciding.
  bool _adopted = false;

  late int _index = _indexOf(widget.initialPhotoId, widget.seed);

  /// How close to the end a swipe has to get before the next page is asked
  /// for. Three photos is about a second of swiping at any pace anyone reads
  /// at, which is enough for the request to land unnoticed.
  static const _prefetchWithin = 3;

  static int _indexOf(String id, List<Photo> photos) {
    final at = photos.indexWhere((p) => p.id == id);
    return at < 0 ? 0 : at;
  }

  /// Take the server's list if it holds the photo being looked at.
  ///
  /// Declining is a real outcome, not a failure: with hundreds of matches the
  /// first page may not reach a photo that sat far down the grid. The viewer
  /// then keeps what the grid gave it, which is what it would have had anyway.
  void _onPhotos(FoundAlbumState state) {
    if (state.photos.isEmpty) return;

    if (_adopted) {
      if (state.photos.length > _photos.length) {
        setState(() => _photos = state.photos);
      }
      return;
    }

    final current = _photos[_index.clamp(0, _photos.length - 1)];
    final at = state.photos.indexWhere((p) => p.id == current.id);
    if (at < 0) {
      // Not on this page. One more page is worth asking for; past that the
      // grid's own set is the honest answer.
      if (state.hasMore && state.page < 2) {
        context
            .read<FoundAlbumBloc>()
            .add(const FoundAlbumPhotosRequested(loadMore: true));
      }
      return;
    }

    setState(() {
      _photos = state.photos;
      _index = at;
      _adopted = true;
    });
  }

  void _onIndexChanged(int index) {
    _index = index;
    if (!_adopted) return;

    final state = context.read<FoundAlbumBloc>().state;
    if (!state.hasMore || state.isLoadingMore) return;
    if (index < _photos.length - _prefetchWithin) return;

    context
        .read<FoundAlbumBloc>()
        .add(const FoundAlbumPhotosRequested(loadMore: true));
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<FoundAlbumBloc, FoundAlbumState>(
      listenWhen: (p, c) => p.photos != c.photos,
      listener: (_, state) => _onPhotos(state),
      child: FoundPhotoViewerPage(
        photos: _photos,
        initialIndex: _index,
        purchaseGated: true,
        onIndexChanged: _onIndexChanged,
      ),
    );
  }
}
