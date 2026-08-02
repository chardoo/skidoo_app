import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/common/widgets/app_widgets.dart';
import 'package:skidoo_app/core/di/service_locator.dart';
import 'package:skidoo_app/core/theme/app_spacing.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/core/utils/number_format.dart';
import 'package:skidoo_app/core/utils/web_wrap.dart';
import 'package:skidoo_app/features/gallery/presentation/found/pages/found_photo_viewer_page.dart';
import 'package:skidoo_app/features/search/domain/entities/search_models.dart';
import 'package:skidoo_app/features/search/domain/usecases/search_usecase.dart';
import 'package:skidoo_app/features/search/presentation/bloc/event_photos_bloc.dart';
import 'package:skidoo_app/features/search/presentation/widgets/load_more_listener.dart';
import 'package:skidoo_app/features/search/presentation/widgets/search_detail_app_bar.dart';
import 'package:skidoo_app/features/search/presentation/widgets/search_photo_grid.dart';

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
  });

  /// The event id **or** its access code — the endpoint accepts either.
  final String eventId;

  /// The row this page was opened from, when there was one.
  final SearchEventRow? event;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<EventPhotosBloc>(
      create: (_) => EventPhotosBloc(
        searchUseCase: sl<SearchUseCase>(),
        eventId: eventId,
      )..add(const EventPhotosRequested()),
      child: _EventPhotosView(fallbackEvent: event),
    );
  }
}

class _EventPhotosView extends StatelessWidget {
  const _EventPhotosView({this.fallbackEvent});

  final SearchEventRow? fallbackEvent;

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
      body: SafeArea(
        bottom: false,
        child: BlocBuilder<EventPhotosBloc, EventPhotosState>(
          builder: (context, state) {
            final count = _count(state);
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
              ],
            );
          },
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
            padding: EdgeInsets.fromLTRB(
                AppSpacing.md.w, AppSpacing.sm.h, AppSpacing.md.w, 0),
            onPhotoTap: (index) => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => FoundPhotoViewerPage(
                  photos: state.photos,
                  initialIndex: index,
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
