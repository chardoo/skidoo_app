import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:skidoo_app/core/common/widgets/app_widgets.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/features/gallery/presentation/bloc/gallery_bloc.dart';
import 'package:skidoo_app/features/gallery/presentation/widgets/found_photo_card.dart';

/// "Found" tab — vertically-paged feed of photos the user was found in via
/// face-match. Reuses the existing [GalleryBloc]/`GET /client/dashboard`
/// data (previously only shown on the standalone "Gallery" bottom-nav tab)
/// through the same page-per-item mechanism as the "For You"/"Following"
/// tabs. `GalleryBloc` only supports a single load (no page/limit params
/// wired up beyond the datasource's hardcoded first page), so unlike the
/// other two tabs this one doesn't support infinite scroll yet.
class FoundFeed extends StatefulWidget {
  const FoundFeed({super.key, this.topPadding = 0});

  final double topPadding;

  @override
  State<FoundFeed> createState() => _FoundFeedState();
}

class _FoundFeedState extends State<FoundFeed> {
  final _activeCardIndex = ValueNotifier<int>(0);
  final _pageCtrl = PageController();

  @override
  void initState() {
    super.initState();
    context.read<GalleryBloc>().add(const GalleryLoadRequested());
  }

  @override
  void dispose() {
    _activeCardIndex.dispose();
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return BlocBuilder<GalleryBloc, GalleryState>(
      builder: (context, state) {
        if (state.isLoading && state.photos.isEmpty) {
          return const AppLoadingIndicator();
        }
        if (state.errorMessage != null && state.photos.isEmpty) {
          return AppErrorView(
            message: state.errorMessage!,
            icon: Icons.wifi_off_outlined,
            onRetry: () =>
                context.read<GalleryBloc>().add(const GalleryLoadRequested()),
          );
        }
        if (state.photos.isEmpty) {
          return const AppEmptyState(
            icon: Icons.face_retouching_natural_outlined,
            message: "We're still scanning event photos for your face — "
                "check back soon.",
          );
        }

        return RefreshIndicator(
          onRefresh: () async =>
              context.read<GalleryBloc>().add(const GalleryLoadRequested()),
          color: ext.accentGold,
          child: Padding(
            padding: EdgeInsets.only(top: widget.topPadding),
            child: PageView.builder(
              controller: _pageCtrl,
              scrollDirection: Axis.vertical,
              // AlwaysScrollable so pull-to-refresh works and the header
              // can always be dragged back into view, even when the feed
              // (no pagination here — see class doc) is too short to
              // naturally overscroll on its own.
              physics: kIsWeb
                  ? const AlwaysScrollableScrollPhysics(
                      parent: ClampingScrollPhysics(),
                    )
                  : const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
              itemCount: state.photos.length,
              onPageChanged: (i) => _activeCardIndex.value = i,
              itemBuilder: (_, i) => FoundPhotoCard(
                key: ValueKey('found_${state.photos[i].id}'),
                photo: state.photos[i],
                cardIndex: i,
                activeCardIndex: _activeCardIndex,
              ),
            ),
          ),
        );
      },
    );
  }
}
