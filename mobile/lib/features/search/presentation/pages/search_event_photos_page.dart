import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/common/widgets/app_widgets.dart';
import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/utils/number_format.dart';
import 'package:jperg_app/core/utils/web_wrap.dart';
import 'package:jperg_app/features/gallery/presentation/found/pages/found_photo_viewer_page.dart';
import 'package:jperg_app/features/search/domain/entities/search_models.dart';
import 'package:jperg_app/features/search/domain/usecases/search_usecase.dart';
import 'package:jperg_app/core/purchase/photo_checkout.dart';
import 'package:jperg_app/core/purchase/photo_purchase_bar.dart';
import 'package:jperg_app/core/purchase/photo_selection.dart';
import 'package:jperg_app/features/search/presentation/bloc/event_photos_bloc.dart';
import 'package:jperg_app/features/search/presentation/widgets/load_more_listener.dart';
import 'package:jperg_app/features/search/presentation/widgets/search_detail_app_bar.dart';
import 'package:jperg_app/features/search/presentation/widgets/search_photo_grid.dart';

/// An event's photos, reached by tapping an Events result.
///
/// The title comes from the row the user tapped so the app bar is correct on
/// the first frame, then hands over to the event block the response carries —
/// which is also the only source when the page is opened from an access code.
class SearchEventPhotosPage extends StatelessWidget {
  const SearchEventPhotosPage({
    super.key,
    required this.eventId,
    this.event,
    this.openPictureId,
  });

  /// The event id **or** its access code — the endpoint accepts either.
  final String eventId;

  /// The row this page was opened from, when there was one.
  final SearchEventRow? event;

  /// Open this photo as soon as the grid has it, as though it were tapped.
  ///
  /// A shared `/p/{id}` link is a link to one photo, but a photo only makes
  /// sense inside its album — that is where the swipe, the count and Back all
  /// come from. So the link opens the album and then this opens the photo, and
  /// the viewer gets the whole list rather than a single-item one: a shared
  /// photo should behave exactly like one you tapped, including swiping on to
  /// the next.
  final String? openPictureId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<EventPhotosBloc>(
      create: (_) => EventPhotosBloc(
        searchUseCase: sl<SearchUseCase>(),
        eventId: eventId,
      )..add(EventPhotosRequested(around: openPictureId)),
      child: _EventPhotosView(
        fallbackEvent: event,
        openPictureId: openPictureId,
      ),
    );
  }
}

class _EventPhotosView extends StatefulWidget {
  const _EventPhotosView({this.fallbackEvent, this.openPictureId});

  final SearchEventRow? fallbackEvent;
  final String? openPictureId;

  @override
  State<_EventPhotosView> createState() => _EventPhotosViewState();
}

class _EventPhotosViewState extends State<_EventPhotosView> {
  /// Guards the one-shot open. Paging emits repeatedly and the viewer must not
  /// be pushed again each time — nor re-pushed when the person comes back to
  /// the grid from the photo they were sent.
  bool _handledOpenRequest = false;

  /// Opt-in: this album is being browsed, not reviewed, so nothing is chosen
  /// until it is tapped. See [PhotoSelection].
  final _selection = PhotoSelection();

  bool _checkingOut = false;

  @override
  void dispose() {
    _selection.dispose();
    super.dispose();
  }

  Future<void> _checkout(BuildContext context) async {
    setState(() => _checkingOut = true);
    try {
      await runPhotoCheckout(context, _selection);
    } finally {
      if (mounted) setState(() => _checkingOut = false);
    }
  }

  SearchEventRow? get fallbackEvent => widget.fallbackEvent;

  /// Opens the requested photo once the page containing it has arrived.
  ///
  /// The first request asks for the page holding it (`around`), so normally it
  /// is in the very first response and this opens immediately.
  void _maybeOpenRequestedPhoto(BuildContext context, EventPhotosState state) {
    final wanted = widget.openPictureId;
    if (wanted == null || wanted.isEmpty || _handledOpenRequest) return;
    if (state.photos.isEmpty) return;

    final index = state.photos.indexWhere((p) => p.id == wanted);
    if (index < 0) {
      // Only reachable against a server that does not know `around` — an app
      // updated ahead of the backend. Fall back to what this did before:
      // page forward until the photo turns up. One round trip per 30 photos,
      // which is why the parameter exists.
      if (state.hasNext && !state.isLoadingMore) {
        context.read<EventPhotosBloc>().add(const EventPhotosMoreRequested());
      }
      return;
    }

    _handledOpenRequest = true;
    // After the frame: this runs from a build, and pushing during build marks
    // the Navigator's Overlay dirty mid-build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: 'deeplink/photo'),
          builder: (_) => FoundPhotoViewerPage(
            photos: state.photos,
            initialIndex: index,
          ),
        ),
      );
    });
  }

  String _title(EventPhotosState state) {
    if (state.event.eventName.isNotEmpty) return state.event.eventName;
    return fallbackEvent?.eventName ?? 'Event photos';
  }

  /// The photo count the header shows: the server's total once paging has
  /// reported one, otherwise what the search row already knew.
  int _count(EventPhotosState state) {
    if (state.total > 0) return state.total;
    if (state.photos.isNotEmpty) return state.photos.length;
    return fallbackEvent?.photoCount ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    final page = Scaffold(
      backgroundColor: ext.homeBackground,
      body: PhotoCheckoutListener(
        onSuccess: _selection.clear,
        child: SafeArea(
          bottom: false,
          child: BlocConsumer<EventPhotosBloc, EventPhotosState>(
            // A shared photo link opens the album, then this opens the photo —
            // once the page holding it has loaded.
            listener: _maybeOpenRequestedPhoto,
            builder: (context, state) {
              final count = _count(state);
              // Keeps the bar's total honest as more photos page in. After the
              // frame, because this runs during build.
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _selection.updatePhotos(state.photos);
              });
              return Column(
                children: [
                  SearchDetailAppBar(
                    title: _title(state),
                    subtitle: count > 0 ? countLabel(count, 'photo') : null,
                  ),
                  Expanded(
                    child: LoadMoreListener(
                      enabled: state.hasNext && !state.isLoadingMore,
                      onLoadMore: () => context
                          .read<EventPhotosBloc>()
                          .add(const EventPhotosMoreRequested()),
                      child: _buildBody(context, ext, state),
                    ),
                  ),
                  PhotoPurchaseBar(
                    selection: _selection,
                    isBusy: _checkingOut,
                    onCheckout: () => _checkout(context),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );

    return webWrap(page, backgroundColor: ext.homeBackground);
  }

  Widget _buildBody(
    BuildContext context,
    AppThemeExtension ext,
    EventPhotosState state,
  ) {
    if (state.isLoading && state.photos.isEmpty) {
      return const AppLoadingIndicator();
    }

    if (state.errorMessage != null && state.photos.isEmpty) {
      return AppErrorView(
        message: state.errorMessage!,
        onRetry: () =>
            context.read<EventPhotosBloc>().add(const EventPhotosRequested()),
      );
    }

    if (state.isEmpty) {
      return const AppEmptyState(
        icon: Icons.photo_library_outlined,
        message: 'No photos in this event yet.',
      );
    }

    return RefreshIndicator(
      color: ext.accentGold,
      backgroundColor: ext.homeBackground,
      onRefresh: () async {
        final bloc = context.read<EventPhotosBloc>()
          ..add(const EventPhotosRequested());
        await bloc.stream.firstWhere((s) => !s.isLoading);
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SearchPhotoGridSliver(
            photos: state.photos,
            selection: _selection,
            padding: EdgeInsets.fromLTRB(
                AppSpacing.md.w, AppSpacing.sm.h, AppSpacing.md.w, 0),
            onPhotoTap: (index) => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => FoundPhotoViewerPage(
                  photos: state.photos,
                  initialIndex: index,
                  title: _title(state),
                  selection: _selection,
                  onCheckout: () => _checkout(context),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.xl.h),
              child: state.isLoadingMore
                  ? Center(
                      child: SizedBox(
                        width: 20.w,
                        height: 20.w,
                        child: CircularProgressIndicator(
                            color: ext.accentGold, strokeWidth: 2),
                      ),
                    )
                  : SizedBox(height: AppSpacing.xl.h),
            ),
          ),
        ],
      ),
    );
  }
}
