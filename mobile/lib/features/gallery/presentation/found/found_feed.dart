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
import 'package:jperg_app/features/gallery/presentation/found/widgets/face_gate_prompt.dart';
import 'package:jperg_app/features/gallery/presentation/found/models/found_album.dart';
import 'package:jperg_app/features/gallery/presentation/found/models/found_empty_state.dart';
import 'package:jperg_app/features/gallery/presentation/found/models/found_filters.dart';
import 'package:jperg_app/features/gallery/presentation/found/pages/event_scan_result_page.dart';
import 'package:jperg_app/features/gallery/presentation/found/pages/found_album_page.dart';
import 'package:jperg_app/features/gallery/presentation/found/widgets/found_album_section.dart';
import 'package:jperg_app/features/gallery/presentation/found/widgets/found_filter_button.dart';
import 'package:jperg_app/features/gallery/presentation/found/widgets/found_filter_sheet.dart';
import 'package:jperg_app/features/gallery/presentation/found/widgets/found_header.dart';
import 'package:jperg_app/features/gallery/data/repositories/found_review_repository.dart';
import 'package:jperg_app/features/gallery/presentation/found/pages/review_found_photos_page.dart';
import 'package:jperg_app/features/gallery/presentation/found/widgets/found_review_banner.dart';
import 'package:jperg_app/services/auth_service.dart';
import 'package:jperg_app/features/gallery/presentation/found/widgets/found_scanning_state.dart';
import 'package:jperg_app/features/home/presentation/pages/qr_scan_page.dart';

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
    if (visible && !_wasVisible) _checkAccess();
    _wasVisible = visible;
  }

  @override
  void dispose() {
    AuthService.hasAddedFaces.removeListener(_checkAccess);
    super.dispose();
  }

  /// Found needs an account *and* a face on file. Re-run after sign-up or
  /// face capture so the gate clears without the user having to leave the tab.
  Future<void> _checkAccess() async {
    final access = await resolveFoundAccess();
    if (!mounted) return;
    setState(() => _access = access);
    if (access == FoundAccess.ready) {
      context.read<FoundBloc>().add(const FoundPhotosRequested());
    } else {
      // Signed out, or the face data was just deleted from the account page.
      // Nothing can be pending against a face the server no longer has, and a
      // dot pointing at a tab that now shows a sign-up gate is a lie.
      FoundFeed.pendingCount.value = 0;
    }
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
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(builder: (_) => const QrScanPage()),
    );
    if (!mounted || code == null || code.isEmpty) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EventScanResultPage(code: code),
      ),
    );
    // Whatever they confirmed in there belongs in this list.
    if (mounted) {
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

    // Same panel either way; only the destination differs. A guest signs up
    // and continues straight into face capture, so both routes end in the
    // same place — the gate is about what's missing, not who they are.
    if (_access != FoundAccess.ready) {
      return Padding(
        padding: EdgeInsets.only(top: widget.topPadding),
        child: FaceGatePrompt(
          reason: _access == FoundAccess.signedOut
              ? FaceGateReason.signedOut
              : FaceGateReason.noFaceAdded,
          onPrimaryAction: () async {
            if (_access == FoundAccess.signedOut) {
              await promptSignUp(
                context,
                onAuthenticated: () async {
                  if (!mounted) return;
                  // Sign-up runs its own face step, so asking again here would
                  // be a second capture for anyone who completed it. Only
                  // follow up when they skipped it in the wizard.
                  if (!AuthService.hasAddedFaces.value) {
                    await startFaceCapture(context);
                  }
                  await _checkAccess();
                },
              );
            } else {
              // Already onboarded — a face is the only thing missing, so this
              // goes straight to capture and straight back here.
              await startFaceCapture(context);
            }
            await _checkAccess();
          },
          onSignIn: _access == FoundAccess.signedOut
              ? () => openSignIn(context, onAuthenticated: _checkAccess)
              : null,
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
        if (empty == FoundEmptyState.scanning) {
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
