import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/common/widgets/app_widgets.dart';
import 'package:skidoo_app/core/di/service_locator.dart';
import 'package:skidoo_app/core/theme/app_spacing.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/core/utils/number_format.dart';
import 'package:skidoo_app/core/utils/web_wrap.dart';
import 'package:skidoo_app/features/search/domain/entities/search_models.dart';
import 'package:skidoo_app/features/search/domain/usecases/search_usecase.dart';
import 'package:skidoo_app/features/search/presentation/bloc/tag_events_bloc.dart';
import 'package:skidoo_app/features/search/presentation/pages/search_event_photos_page.dart';
import 'package:skidoo_app/features/search/presentation/widgets/load_more_listener.dart';
import 'package:skidoo_app/features/search/presentation/widgets/search_detail_app_bar.dart';
import 'package:skidoo_app/features/search/presentation/widgets/search_event_row_tile.dart';

/// The events behind a tag row — the drill-down from the Tags chip.
class SearchTagPage extends StatelessWidget {
  const SearchTagPage({super.key, required this.tag});

  final SearchTagRow tag;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<TagEventsBloc>(
      create: (_) => TagEventsBloc(
        searchUseCase: sl<SearchUseCase>(),
        tag: tag.tag,
      )..add(const TagEventsRequested()),
      child: _TagEventsView(row: tag),
    );
  }
}

class _TagEventsView extends StatelessWidget {
  const _TagEventsView({required this.row});

  /// The row the page was opened from — its label and counts fill the header
  /// until the response arrives, so it never opens on a blank bar.
  final SearchTagRow row;

  /// Posts and events, dropping whichever the server reported as zero.
  String _subtitle(TagEventsState state) {
    final posts = state.postCount > 0 ? state.postCount : row.postCount;
    final events = state.eventCount > 0 ? state.eventCount : row.eventCount;
    final parts = [
      if (posts > 0) countLabel(posts, 'post'),
      if (events > 0) countLabel(events, 'event'),
    ];
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    final page = Scaffold(
      backgroundColor: ext.homeBackground,
      body: SafeArea(
        bottom: false,
        child: BlocBuilder<TagEventsBloc, TagEventsState>(
          builder: (context, state) {
            return Column(
              children: [
                SearchDetailAppBar(
                  title: state.label.isNotEmpty ? state.label : row.label,
                  subtitle: _subtitle(state),
                ),
                Expanded(
                  child: LoadMoreListener(
                    enabled: state.hasNext && !state.isLoadingMore,
                    onLoadMore: () => context
                        .read<TagEventsBloc>()
                        .add(const TagEventsMoreRequested()),
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
    TagEventsState state,
  ) {
    if (state.isLoading && state.events.isEmpty) {
      return const AppLoadingIndicator();
    }

    if (state.errorMessage != null && state.events.isEmpty) {
      return AppErrorView(
        message: state.errorMessage!,
        onRetry: () =>
            context.read<TagEventsBloc>().add(const TagEventsRequested()),
      );
    }

    if (state.isEmpty) {
      return AppEmptyState(
        icon: Icons.tag_rounded,
        message: 'Nothing tagged ${row.label} yet.',
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(top: AppSpacing.sm.h, bottom: AppSpacing.huge.h),
      itemCount: state.events.length + (state.isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= state.events.length) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.lg.h),
            child: Center(
              child: SizedBox(
                width: 20.w,
                height: 20.w,
                child: CircularProgressIndicator(
                    color: ext.accentGold, strokeWidth: 2),
              ),
            ),
          );
        }

        final event = state.events[index];
        return SearchEventRowTile(
          key: ValueKey('tag_event_${event.id}'),
          event: event,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => SearchEventPhotosPage(
                eventId: event.id.isNotEmpty ? event.id : event.accessCode,
                event: event,
              ),
            ),
          ),
        );
      },
    );
  }
}
