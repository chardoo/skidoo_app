import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/common/widgets/app_widgets.dart';
import 'package:skidoo_app/core/di/service_locator.dart';
import 'package:skidoo_app/core/theme/app_spacing.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/core/utils/web_wrap.dart';
import 'package:skidoo_app/features/gallery/presentation/found/pages/found_photo_viewer_page.dart';
import 'package:skidoo_app/features/photographers/presentation/pages/photographer_profile_page.dart';
import 'package:skidoo_app/features/search/domain/entities/search_models.dart';
import 'package:skidoo_app/features/search/presentation/bloc/search_bloc.dart';
import 'package:skidoo_app/features/search/presentation/pages/search_event_photos_page.dart';
import 'package:skidoo_app/features/search/presentation/pages/search_tag_page.dart';
import 'package:skidoo_app/features/search/presentation/widgets/load_more_listener.dart';
import 'package:skidoo_app/features/search/presentation/widgets/search_idle_view.dart';
import 'package:skidoo_app/features/search/presentation/widgets/search_results_list.dart';
import 'package:skidoo_app/features/search/presentation/widgets/search_top_bar.dart';
import 'package:skidoo_app/features/search/presentation/widgets/search_type_chips.dart';
import 'package:skidoo_app/models/photographer/photographerModel.dart';
import 'package:skidoo_app/models/photos/Photo.dart';

/// One text box over three result types, with the photo grid that fills the
/// idle state behind it.
///
/// Everything server-side lives in [SearchBloc] / `GET /client/search/*`: the
/// endpoint does the matching, the ranking, the typo retry and the paging.
/// This page only decides how to lay that out.
class SearchPage extends StatelessWidget {
  const SearchPage({super.key, this.initialQuery});

  static const routeName = '/search';

  /// Pre-fills the field — an access code handed over from the unlock sheet,
  /// or a recent search reopened from elsewhere.
  final String? initialQuery;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<SearchBloc>(
      create: (_) => sl<SearchBloc>()
        ..add(const SearchRecentsRequested())
        ..add(const SearchYouMayLikeRequested()),
      child: _SearchView(initialQuery: initialQuery),
    );
  }
}

class _SearchView extends StatefulWidget {
  const _SearchView({this.initialQuery});

  final String? initialQuery;

  @override
  State<_SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<_SearchView> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialQuery ?? '');
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    final seed = widget.initialQuery?.trim() ?? '';
    if (seed.isNotEmpty) {
      // Post-frame: the bloc is provided by the widget above this one, so it
      // isn't reachable from `context` until the first build has run.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.read<SearchBloc>().add(SearchRequested.query(seed));
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  SearchBloc get _bloc => context.read<SearchBloc>();

  // ── Query ──────────────────────────────────────────────────────────────────

  void _onQueryChanged(String query) {
    if (query.trim().isEmpty) {
      _bloc.add(const SearchCleared());
      return;
    }
    _bloc.add(SearchRequested.query(query));
  }

  void _onSubmitted(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    _bloc.add(SearchRecentSaved(trimmed));
    _bloc.add(SearchRequested.query(trimmed));
  }

  void _runRecent(String query) {
    _controller.value = TextEditingValue(
      text: query,
      selection: TextSelection.collapsed(offset: query.length),
    );
    _focusNode.unfocus();
    _bloc.add(SearchRecentSaved(query));
    _bloc.add(SearchRequested.query(query));
  }

  /// The idle grid and the results list page off the same gesture, so they
  /// share one listener and it dispatches whichever the screen is showing.
  bool _canLoadMore(SearchState state) => state.isIdle
      ? state.canLoadMoreYouMayLike
      : (state.hasResults && state.activeSection.canLoadMore);

  void _loadMore(SearchState state) {
    if (state.isIdle) {
      _bloc.add(const SearchYouMayLikeMoreRequested());
    } else {
      _bloc.add(SearchSectionMoreRequested(state.query, state.activeType));
    }
  }

  // ── Navigation ─────────────────────────────────────────────────────────────

  /// Every result the user opens becomes a recent search — the query earned
  /// its place by leading somewhere, which typing alone does not.
  void _rememberQuery() {
    final query = _controller.text.trim();
    if (query.isNotEmpty) _bloc.add(SearchRecentSaved(query));
  }

  void _openEvent(SearchEventRow event) {
    _rememberQuery();
    _focusNode.unfocus();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SearchEventPhotosPage(
          eventId: event.id.isNotEmpty ? event.id : event.accessCode,
          event: event,
        ),
      ),
    );
  }

  void _openPhotographer(SearchPhotographerRow photographer) {
    _rememberQuery();
    _focusNode.unfocus();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PhotographerProfilePage(
          // The profile page refetches everything it needs from the id; the
          // rest of the model is what it renders while that is in flight.
          photographer: PhotographerModel(
            photographer.id,
            '',
            photographer.name,
            '',
            imageUrl: photographer.profileUrl.isEmpty
                ? null
                : photographer.profileUrl,
          ),
        ),
      ),
    );
  }

  void _openTag(SearchTagRow tag) {
    _rememberQuery();
    _focusNode.unfocus();
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => SearchTagPage(tag: tag)),
    );
  }

  void _openPhoto(List<Photo> photos, int index) {
    _focusNode.unfocus();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            FoundPhotoViewerPage(photos: photos, initialIndex: index),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    final page = Scaffold(
      backgroundColor: ext.homeBackground,
      body: SafeArea(
        bottom: false,
        child: BlocBuilder<SearchBloc, SearchState>(
          builder: (context, state) {
            return Column(
              children: [
                SearchTopBar(
                  controller: _controller,
                  focusNode: _focusNode,
                  onChanged: _onQueryChanged,
                  onSubmitted: _onSubmitted,
                  onBack: () => Navigator.of(context).maybePop(),
                ),
                // The chips belong to the results, so they appear with them and
                // vanish with the `No results` state — never as an empty row.
                if (!state.isIdle && state.hasResults)
                  SearchTypeChips(
                    types: state.visibleTypes,
                    selected: state.activeType,
                    onSelected: (type) =>
                        _bloc.add(SearchRequested.type(state.query, type)),
                  ),
                Expanded(
                  child: LoadMoreListener(
                    enabled: _canLoadMore(state),
                    onLoadMore: () => _loadMore(state),
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
    SearchState state,
  ) {
    if (state.isIdle) {
      return SearchIdleView(
        state: state,
        onRecentTap: _runRecent,
        onRecentRemove: (query) => _bloc.add(SearchRecentRemoved(query)),
        onRefresh: () =>
            _bloc.add(const SearchYouMayLikeRequested(refresh: true)),
        onPhotoTap: _openPhoto,
      );
    }

    // Only the first request for a query blocks the screen; paging keeps the
    // rows on show and puts its spinner in the list's footer.
    if (state.status == SearchStatus.loading && !state.hasResults) {
      return const AppLoadingIndicator();
    }

    if (state.status == SearchStatus.failure && !state.hasResults) {
      return AppErrorView(
        message: state.errorMessage ?? 'Search failed. Please try again.',
        onRetry: () => _bloc.add(SearchRequested.query(state.query)),
      );
    }

    if (state.isEmptyResult) return _NoResults(query: state.query, ext: ext);

    return SearchResultsList(
      state: state,
      onEventTap: _openEvent,
      onPhotographerTap: _openPhotographer,
      onTagTap: _openTag,
    );
  }
}

/// The design's one-line empty state — no icon, no illustration, just the
/// query back at the user so they can see the typo.
class _NoResults extends StatelessWidget {
  const _NoResults({required this.query, required this.ext});

  final String query;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.xxl.w, vertical: AppSpacing.xl.h),
        child: Text(
          "No results for '$query'",
          textAlign: TextAlign.center,
          style: TextStyle(color: ext.searchHintColor, fontSize: 14.sp),
        ),
      ),
    );
  }
}
