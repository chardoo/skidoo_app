import 'dart:async';

import 'package:flutter/material.dart';
import 'package:jperg_app/core/navigation/app_page_routes.dart';
import 'package:jperg_app/core/utils/responsive.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/common/widgets/app_widgets.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/gallery/presentation/found/bloc/found_bloc.dart';
import 'package:jperg_app/features/gallery/presentation/found/found_access.dart';
import 'package:jperg_app/features/gallery/presentation/found/pages/found_results_viewer_page.dart';
import 'package:jperg_app/features/gallery/presentation/found/pages/easy_search_page.dart';
import 'package:jperg_app/features/gallery/presentation/found/models/found_album.dart';
import 'package:jperg_app/features/gallery/presentation/found/models/found_empty_state.dart';
import 'package:jperg_app/features/gallery/presentation/found/models/found_filters.dart';
import 'package:jperg_app/features/gallery/presentation/found/pages/event_scan_result_page.dart';
import 'package:jperg_app/features/gallery/presentation/found/pages/found_album_page.dart';
import 'package:jperg_app/features/gallery/presentation/found/widgets/found_album_section.dart';
import 'package:jperg_app/features/gallery/presentation/found/widgets/found_filter_button.dart';
import 'package:jperg_app/features/gallery/presentation/found/widgets/found_filter_sheet.dart';
import 'package:jperg_app/features/gallery/presentation/found/widgets/found_header.dart';
import 'package:jperg_app/features/gallery/presentation/found/widgets/found_join_prompt.dart';
import 'package:jperg_app/features/home/presentation/widgets/unlock_photos_sheet.dart';
import 'package:jperg_app/features/gallery/data/repositories/found_review_repository.dart';
import 'package:jperg_app/features/gallery/presentation/found/pages/review_found_photos_page.dart';
import 'package:jperg_app/features/gallery/presentation/found/widgets/found_review_banner.dart';
import 'package:jperg_app/services/auth_service.dart';
import 'package:jperg_app/features/gallery/presentation/found/widgets/found_scanning_state.dart';

/// "Found" tab — the photos the user was face-recognized in, grouped by event
/// into album sections with a six-tile preview each.
///
/// Everything server-side lives in [FoundBloc] / `GET /client/my-photos`
/// (the ImageIdentification list — NOT `/client/dashboard`, which is the
/// separate purchased-photos gallery): the endpoint does the grouping
/// (`groupBy=event`), the paging, and the filtering, and reports the totals.
/// This widget only decides how to lay that out.
class FoundFeed extends StatefulWidget {
  const FoundFeed({super.key, this.topPadding = 0});

  /// How many photos are waiting to be confirmed as this person — what the
  /// dot on the Found tab is drawn from.
  ///
  /// Published here because this is where it is already known: the tab checks
  /// for pending matches on mount, and the home IndexedStack mounts it whether
  /// or not it is the tab on screen. So the dot is there before Found is ever
  /// opened, which is the only time it is any use.
  ///
  /// Same signal as the "You were found" banner inside the tab, so the two
  /// appear together and clear together.
  static final pendingCount = ValueNotifier<int>(0);

  /// Space reserved for the floating Found/Feed/Following header that
  /// overlays this tab.
  final double topPadding;

  @override
  State<FoundFeed> createState() => _FoundFeedState();
}

class _FoundFeedState extends State<FoundFeed> {
  bool _sheetOpen = false;

  /// Null until the first check resolves — the tab renders its loader
  /// meanwhile rather than flashing a gate at someone who has full access.
  FoundAccess? _access;

  /// Whether this tab was on screen at the last dependency change — see
  /// [didChangeDependencies].
  bool _wasVisible = false;

  /// Whether the code sheet has already been offered this visit.
  ///
  /// Reset when the tab comes back on screen, not never: coming back to Found
  /// later is a fresh intention to find something, and the offer should stand
  /// again. Within one visit it is once, or a sheet raised from a build would
  /// reopen the moment it was dismissed.
  bool _codePrompted = false;

  /// Photos found of this person that they have not answered for. Empty until
  /// the first check, so the banner appears rather than reserving space for
  /// something that may not be there.
  PendingFound _pending = PendingFound.none;

  @override
  void initState() {
    super.initState();
    // The face flag can be cleared from the account page ("Delete my face
    // data") while this tab sits alive in the home IndexedStack. Without this
    // it would keep showing matches for a face the server no longer has, until
    // the next app launch.
    AuthService.hasAddedFaces.addListener(_checkAccess);
    _loadPending();
  }

  /// Quiet: the grid below does not wait on it, and a failure just means no
  /// banner this time rather than an error over someone's photos.
  Future<void> _loadPending() async {
    try {
      final pending = await FoundReviewRepository().getPending();
      FoundFeed.pendingCount.value = pending.total;
      if (mounted) setState(() => _pending = pending);
    } catch (e) {
      debugPrint('[FoundFeed] pending review check failed: $e');
    }
  }

  Future<void> _openReview() async {
    final answered = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ReviewFoundPhotosPage(pending: _pending),
      ),
    );
    if (!mounted) return;
    if (answered == true) {
      // Rejections leave the grid and confirmations stay, so the list below
      // has changed either way.
      FoundFeed.pendingCount.value = 0;
      setState(() => _pending = PendingFound.none);
      _reload();
      unawaited(_loadPending());
    }
  }

  /// Re-resolves the gate every time the tab comes back on screen.
  ///
  /// The listener above catches a deletion made inside this app, but not one
  /// that happened anywhere else — another device, or an admin action — and
  /// the tab stays mounted in the home IndexedStack for the whole session, so
  /// nothing else would ever ask again. Checking on each activation means the
  /// tab is right whenever it is actually being looked at.
  ///
  /// The home page wraps each tab in `TickerMode(enabled: selected == …)`, so
  /// that is the visibility signal, and it changes exactly when the user
  /// switches tabs. Hosts that don't gate this way (the guest shell) see
  /// `true` and get the initial check on mount, which is the same behaviour as
  /// before.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = TickerMode.valuesOf(context).enabled;
    if (visible && !_wasVisible) {
      // A fresh visit, so the code offer stands again.
      _codePrompted = false;
      _checkAccess();
    }
    _wasVisible = visible;
  }

  @override
  void dispose() {
    AuthService.hasAddedFaces.removeListener(_checkAccess);
    super.dispose();
  }

  /// Found needs an account. It does **not** need a face on file to *read*.
  ///
  /// That distinction is the whole of this method. `GET /client/my-photos`
  /// lists ImageIdentification rows, and those outlive the face that produced
  /// them — somebody who enrolled, was matched, and later deleted their face
  /// data still has every photo that was found of them. This used to fetch
  /// only when a face was present, so that person opened Found and was asked
  /// to add a face while the photos they already had sat behind the gate.
  ///
  /// So: signed in means fetch. What is missing only decides what to do about
  /// an *empty* answer, which is [_promptForCodeIfNothingToShow]'s job.
  Future<void> _checkAccess() async {
    final access = await resolveFoundAccess();
    if (!mounted) return;
    setState(() => _access = access);
    if (access == FoundAccess.signedOut) {
      // No account, so nothing can be pending and nothing can be listed. A dot
      // pointing at a tab that now shows a sign-up prompt is a lie.
      FoundFeed.pendingCount.value = 0;
      return;
    }
    context.read<FoundBloc>().add(const FoundPhotosRequested());
  }

  /// Raise the code sheet, if [shouldOfferCodeSheet] says this is the moment.
  ///
  /// Once per visit. It is decided during a build, and a sheet that reopened
  /// on every rebuild could not be dismissed.
  void _promptForCodeIfNothingToShow(FoundEmptyState empty) {
    final access = _access;
    if (_codePrompted ||
        access == null ||
        !shouldOfferCodeSheet(access: access, empty: empty)) {
      return;
    }
    _codePrompted = true;
    // Out of the build it was decided in.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scanCode(context);
    });
  }

  void _reload() => context.read<FoundBloc>().add(const FoundPhotosRequested());

  /// Scan a photographer's code, then run the same live search the unlock
  /// sheet runs.
  ///
  /// This link is shown to people with no matches, which is exactly the case
  /// the live scan exists for: an event uploaded before they had an account
  /// has no stored identifications, so the listing behind this screen can only
  /// ever answer "nothing". Popping the raw code back here — what this used to
  /// do — left the person holding a code and no way to spend it.
  Future<void> _scanCode(BuildContext context) async {
    // The sheet, not the raw scanner: it carries both ways in — the camera
    // preview and the typed code — and typing is the one that works when the
    // code is on a poster across the room or in a message.
    setState(() => _sheetOpen = true);
    final String? code;
    try {
      code = await UnlockPhotosSheet.show(context);
    } finally {
      if (mounted) setState(() => _sheetOpen = false);
    }
    if (!mounted || code == null || code.trim().isEmpty) return;

    // With no face on file there is nothing to match against, so the stored
    // listing behind EventScanResultPage can only ever answer "nothing". Easy
    // search is the route that works: it carries the selfies with the request.
    // The code goes with them, so the scan they just performed is not thrown
    // away and asked for again.
    if (_access == FoundAccess.noFaceAdded) {
      await EasySearchPage.push(context, code: code.trim());
    } else {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => EventScanResultPage(code: code!.trim()),
        ),
      );
    }

    // Whatever they confirmed in there belongs in this list — and if they
    // enrolled on the way through, the gate has moved too.
    if (mounted) {
      await _checkAccess();
      if (!mounted) return;
      _reload();
      unawaited(_loadPending());
    }
  }

  Future<void> _openFilters(FoundFilters current) async {
    setState(() => _sheetOpen = true);
    final applied = await FoundFilterSheet.show(context, initial: current);
    if (!mounted) return;
    setState(() => _sheetOpen = false);
    if (applied != null && applied != current) {
      context.read<FoundBloc>().add(FoundPhotosRequested(filters: applied));
    }
  }

  /// Starts the next page one viewport ahead of the bottom so a fast scroll
  /// doesn't hit a wall. The bloc drops the request if a page is already in
  /// flight or the list is exhausted, so firing eagerly is safe.
  bool _onScroll(ScrollNotification notification, FoundState state) {
    if (!state.hasMore || state.isLoadingMore || state.isLoading) return false;
    final metrics = notification.metrics;
    if (metrics.pixels >= metrics.maxScrollExtent - metrics.viewportDimension) {
      context.read<FoundBloc>().add(const FoundPhotosRequested(loadMore: true));
    }
    return false;
  }

  void _openAlbum(FoundAlbum album, FoundFilters filters) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FoundAlbumPage(album: album, filters: filters),
      ),
    );
  }

  /// Open a photo, into as much as the grid was actually showing.
  ///
  /// Which is not the same question in the two states this screen has:
  ///
  /// * **Filtering.** The grid is a set of matches, grouped by event only
  ///   incidentally — what the person asked for is everything on the screen.
  ///   The viewer swipes all of it, across events, or the results they just
  ///   filtered for would be unreachable from the one they opened.
  /// * **Not filtering.** The sections are the structure, and a photo tapped
  ///   under an event belongs to that event. The viewer stays in it.
  ///
  /// The seed is what is already loaded so the picture is under the finger
  /// that tapped it rather than after a round trip; [FoundResultsViewerPage]
  /// swaps in the server's own list when it lands. Unfiltered that seed is
  /// only the section's preview slice — six tiles of a forty-photo event —
  /// which is exactly why the viewer fetches rather than trusting it.
  void _openPhoto(
    List<FoundAlbum> albums,
    FoundAlbum album,
    int index,
    FoundFilters filters,
  ) {
    if (index < 0 || index >= album.photos.length) return;

    final acrossEvents = filters.isActive;

    Navigator.of(context).push(
      NoSwipeBackPageRoute<void>(
        builder: (_) => FoundResultsViewerPage(
          seed: acrossEvents
              ? [for (final a in albums) ...a.photos]
              : album.photos,
          initialPhotoId: album.photos[index].id,
          filters: filters,
          eventId: acrossEvents ? null : album.id,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    if (_access == null) return const AppLoadingIndicator();

    // A guest has nothing to list and no way to search: easy search reads who
    // you are from the token. So the only thing to offer is an account — not
    // a code sheet, which would ask them to scan something the server would
    // refuse to search.
    if (_access == FoundAccess.signedOut) {
      return Padding(
        padding: EdgeInsets.only(top: widget.topPadding),
        child: FoundJoinPrompt(
          onJoin: () => promptSignUp(context, onAuthenticated: _checkAccess),
          onSignIn: () => openSignIn(context, onAuthenticated: _checkAccess),
        ),
      );
    }

    return BlocBuilder<FoundBloc, FoundState>(
      builder: (context, state) {
        if (state.isLoading && state.albums.isEmpty) {
          return const AppLoadingIndicator();
        }
        if (state.errorMessage != null && state.albums.isEmpty) {
          return AppErrorView(
            message: state.errorMessage!,
            icon: Icons.wifi_off_outlined,
            onRetry: _reload,
          );
        }
        // Which empty state applies, and why — see [foundEmptyState]. The
        // pending case is the one that used to be missed, and missing it
        // deadlocked the feature.
        final empty = foundEmptyState(
          hasAlbums: state.albums.isNotEmpty,
          pendingCount: _pending.total,
          filtersActive: state.filters.isActive,
        );
        // Decided here because this is where the answer is known — the sheet
        // depends on the list having come back empty, not just on the account.
        _promptForCodeIfNothingToShow(empty);

        if (empty == FoundEmptyState.scanning) {
          // Stays behind the sheet above, so dismissing it leaves a way back
          // in rather than a blank tab.
          return FoundScanningState(
            onEnterCode: () => _scanCode(context),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            _reload();
            await _loadPending();
          },
          color: ext.accentGold,
          backgroundColor: ext.homeBackground,
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) => _onScroll(n, state),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.md.w,
                    widget.topPadding + AppSpacing.sm.h,
                    AppSpacing.md.w,
                    AppSpacing.md.h,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // `totals.photos` for the current filter set — the
                        // server counts it over the predicate it selects rows
                        // with, so it covers every page rather than what's
                        // scrolled in, and it narrows with the chips.
                        //
                        // Null at zero rather than "0 found": the empty state
                        // below already says why the grid is empty, and beside
                        // a review banner announcing new photos a "0 found"
                        // reads as a contradiction.
                        FoundHeader(
                          count: (state.totalPhotos ?? 0) > 0
                              ? state.totalPhotos
                              : null,
                        ),
                        if (!_pending.isEmpty) ...[
                          SizedBox(height: AppSpacing.md.h),
                          FoundReviewBanner(
                            pending: _pending,
                            ext: ext,
                            onTap: _openReview,
                          ),
                        ],
                        SizedBox(height: AppSpacing.md.h),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: FoundFilterButton(
                            activeCount: state.filters.activeCount,
                            isOpen: _sheetOpen,
                            onTap: () => _openFilters(state.filters),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (state.albums.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _NoMatches(
                      // Only offer to clear filters when filters are what
                      // emptied it. In the pending case nothing was filtered
                      // out, and pointing at a setting that is already off
                      // sends the reader nowhere.
                      filtered: empty == FoundEmptyState.filteredOut,
                      onClear: () => context.read<FoundBloc>().add(
                          const FoundPhotosRequested(
                              filters: FoundFilters.none)),
                    ),
                  )
                else
                  SliverPadding(
                    padding: EdgeInsets.symmetric(horizontal: AppSpacing.md.w),
                    sliver: SliverList.separated(
                      itemCount: state.albums.length,
                      separatorBuilder: (_, __) =>
                          SizedBox(height: AppSpacing.xl.h),
                      itemBuilder: (_, i) {
                        final album = state.albums[i];
                        return FoundAlbumSection(
                          key: ValueKey('album_${album.id}'),
                          album: album,
                          // Filtered = untitled grid of the matches; see the
                          // FilterActive screen in the design.
                          expanded: state.filters.isActive,
                          onOpenAlbum: () => _openAlbum(album, state.filters),
                          onPhotoTap: (index) => _openPhoto(
                              state.albums, album, index, state.filters),
                        );
                      },
                    ),
                  ),
                // Next-page spinner, then the run-out that clears the floating
                // bottom nav bar. Measured rather than a fixed 96: the bar is
                // its own height plus the home indicator, so the number that
                // cleared it on one phone left the last row under it on
                // another.
                if (state.isLoadingMore)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(top: AppSpacing.xl.h),
                      child: const AppLoadingIndicator(),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: SizedBox(
                      height: AppSpacing.md.h + bottomBarClearance(context)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Shown when the filters exclude everything — distinct from the "no photos
/// found yet" empty state, and offers the one action that fixes it.
class _NoMatches extends StatelessWidget {
  const _NoMatches({required this.onClear, this.filtered = true});

  /// Whether the grid is empty *because of* the filters.
  ///
  /// False when the only matches are still awaiting the person's answer: the
  /// review banner is above asking about them, and the photos appear here once
  /// they are confirmed. Saying "no photos match these filters" there sends
  /// the reader to clear filters that were never on.
  final bool filtered;

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return Padding(
      padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.xxl.w, vertical: AppSpacing.huge.h),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            filtered
                ? Icons.filter_alt_off_outlined
                : Icons.how_to_reg_outlined,
            size: 40.sp,
            color: ext.searchHintColor,
          ),
          SizedBox(height: AppSpacing.md.h),
          Text(
            filtered
                ? 'No photos match these filters.'
                : 'Confirm the matches above and your photos appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: ext.searchHintColor,
              fontSize: 14.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (filtered) ...[
            SizedBox(height: AppSpacing.sm.h),
            AppButton(
              label: 'Clear filters',
              variant: AppButtonVariant.text,
              onPressed: onClear,
            ),
          ],
        ],
      ),
    );
  }
}
