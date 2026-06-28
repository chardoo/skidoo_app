import 'dart:ui';

import 'package:skidoo_app/core/widgets/skidoo_image.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:skidoo_app/l10n/app_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:skidoo_app/core/di/service_locator.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/core/utils/responsive.dart';
import 'package:skidoo_app/core/utils/snackbar_utils.dart';
import 'package:skidoo_app/features/ads/presentation/pages/ads_checkout_page.dart';
import 'package:skidoo_app/features/cart/domain/repositories/cart_repository.dart';
import 'package:skidoo_app/features/home/presentation/bloc/home_bloc.dart';
import 'package:skidoo_app/features/home/presentation/pages/home_page.dart';
import 'package:skidoo_app/models/photos/Photo.dart';
import 'package:skidoo_app/services/auth_service.dart';
import 'package:skidoo_app/core/utils/web_wrap.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class SearchResultsPage extends StatefulWidget {
  static const routeName = '/searchresults';
  const SearchResultsPage({super.key});

  @override
  State<SearchResultsPage> createState() => _SearchResultsPageState();
}

class _SearchResultsPageState extends State<SearchResultsPage> {
  final Set<String> _selectedIds = {};
  bool _selectionMode = false;

  // Payment flow state
  bool _paymentLoading = false;

  // ── helpers ────────────────────────────────────────────────────────────────

  double _totalPriceOf(Iterable<Photo> photos) =>
      photos.fold(0.0, (sum, p) => sum + p.price);

  void _toggleSelection(Photo photo) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedIds.contains(photo.id)) {
        _selectedIds.remove(photo.id);
        if (_selectedIds.isEmpty) _selectionMode = false;
      } else {
        _selectedIds.add(photo.id);
      }
    });
  }

  void _enterSelectionMode(Photo photo) {
    HapticFeedback.mediumImpact();
    setState(() {
      _selectionMode = true;
      _selectedIds.add(photo.id);
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  void _selectAll(List<Photo> photos) {
    setState(() {
      _selectedIds.addAll(photos.map((p) => p.id));
    });
  }

  void _saveSelected(List<Photo> all) {
    final toSave = all.where((p) => _selectedIds.contains(p.id)).toList();
    if (toSave.isEmpty) return;
    context.read<HomeBloc>().add(HomeFreeImagesSaved(toSave));
    _exitSelectionMode();
  }

  void _saveAll(List<Photo> photos) {
    final free = photos.where((p) => p.price == 0).toList();
    if (free.isEmpty) return;
    context.read<HomeBloc>().add(HomeFreeImagesSaved(free));
  }

  // ── payment flow ──────────────────────────────────────────────────────────

  Future<void> _initPayment(List<Photo> photos) async {
    // Separate paid and free — payment only covers paid, but free ones should
    // also be saved automatically after a successful payment.
    final paidPhotos = photos.where((p) => p.price > 0).toList();
    final freePhotos = photos.where((p) => p.price == 0).toList();
    if (_paymentLoading || paidPhotos.isEmpty) return;
    setState(() => _paymentLoading = true);
    try {
      final authService = sl<AuthService>();
      final email = await authService.getEmail();
      final clientId = await authService.getUserId();

      final result = await sl<CartRepository>().initializeImages(
        email: email,
        clientId: clientId,
        // Flutter does not calculate total — backend derives it from pictureIds.
        pictureIds: paidPhotos.map((p) => p.id).toList(),
      );

      final authUrl = result['authorization_url'] as String?;
      final reference = result['reference'] as String?;
      final amount = (result['amount'] as num?)?.toDouble() ?? 0;

      if (authUrl == null || reference == null) {
        if (mounted) {
          _showSnack(context, 'Could not start payment. Please try again.',
              isError: true);
          setState(() => _paymentLoading = false);
        }
        return;
      }

      if (!mounted) return;
      setState(() => _paymentLoading = false);
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AdsCheckoutPage(
            authorizationUrl: authUrl,
            reference: reference,
            amountGhs: amount,
            onSuccess: () => _completePayment(reference, paidPhotos, freePhotos),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _paymentLoading = false);
        _showSnack(context, 'Payment failed. Please try again.', isError: true);
      }
    }
  }

  Future<void> _completePayment(
    String reference,
    List<Photo> paidPhotos,
    List<Photo> freePhotos,
  ) async {
    if (!mounted) return;
    setState(() => _paymentLoading = true);
    try {
      final clientId = await sl<AuthService>().getUserId();
      final pictures = paidPhotos
          .map((p) => {'pictureId': p.id, 'userId': p.userId})
          .toList();

      await sl<CartRepository>().completeImages(
        referenceId: reference,
        clientId: clientId,
        pictures: pictures,
      );

      if (!mounted) return;
      setState(() => _paymentLoading = false);

      // Auto-save any free photos that came along with the paid batch so the
      // user doesn't have to go back and save them separately.
      if (freePhotos.isNotEmpty) {
        context.read<HomeBloc>().add(HomeFreeImagesSaved(freePhotos));
      }

      // Request the bottom-nav to switch to Gallery, then pop back to home.
      HomePage.tabRequest.value = 2;
      Navigator.of(context)
          .popUntil(ModalRoute.withName(HomePage.routeName));
    } catch (e) {
      if (mounted) {
        setState(() => _paymentLoading = false);
        // If "amount does not match" error, the server is idempotent — user can retry.
        _showSnack(
          context,
          'Payment verification failed. If you were charged, contact support.',
          isError: true,
        );
      }
    }
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    final page = BlocListener<HomeBloc, HomeState>(
      listenWhen: (prev, curr) =>
          prev.savedFreeCount != curr.savedFreeCount ||
          prev.errorMessage != curr.errorMessage ||
          // Fire once when loading finishes and images arrive.
          (prev.isLoadingImages && !curr.isLoadingImages && curr.searchImages.isNotEmpty),
      listener: (context, state) {
        if (state.savedFreeCount != null) {
          _showSnack(
            context,
            AppLocalizations.of(context)!
                .searchResultsPhotosSaved(state.savedFreeCount!),
            isError: false,
          );
        } else if (state.errorMessage != null) {
          _showSnack(context, state.errorMessage!, isError: true);
        }

        // Debug dump — remove once price values are confirmed.
        if (!state.isLoadingImages && state.searchImages.isNotEmpty) {
          final photos = state.searchImages;
          debugPrint('[SearchResults] ${photos.length} photos loaded:');
          for (var i = 0; i < photos.length; i++) {
            final p = photos[i];
            debugPrint(
              '  [$i] id=${p.id} price=${p.price} '
              'userId=${p.userId} eventName="${p.eventName}" url=${p.url}',
            );
          }
          final total = photos.fold(0.0, (s, p) => s + p.price);
          debugPrint('[SearchResults] total price of all ${photos.length} photos = ${total.toStringAsFixed(2)}');
        }
      },
      child: Scaffold(
        backgroundColor: ext.homeBackground,
        appBar: _buildAppBar(ext, context),
        body: LayoutBuilder(
          builder: (context, constraints) =>
              BlocBuilder<HomeBloc, HomeState>(
            builder: (context, state) {
              if (state.isLoadingImages && state.searchImages.isEmpty) {
                return _buildInitialLoader(context, ext);
              }
              if (state.searchImages.isEmpty && !state.isLoadingImages) {
                return _buildEmpty(context, ext);
              }

              final photos = state.searchImages;
              final colCount =
                  responsiveColumnCount(constraints.maxWidth, minColWidth: 160);

              return Stack(
                children: [
                  RefreshIndicator(
                    color: ext.accentGold,
                    onRefresh: () async {
                      final id = state.searchImagesEventId;
                      if (id != null && id.isNotEmpty) {
                        context.read<HomeBloc>().add(HomeImagesSearched(
                              eventId: id,
                              eventName: state.searchImagesEventName,
                            ));
                      }
                    },
                    child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    cacheExtent: 800,
                    slivers: [
                      if (state.isSavingFree || _paymentLoading)
                        SliverToBoxAdapter(
                          child: LinearProgressIndicator(
                            color: ext.accentGold,
                            backgroundColor:
                                ext.accentGold.withValues(alpha: 0.15),
                            minHeight: 3,
                          ),
                        ),

                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                            10.w, 12.h, 10.w, _selectionMode ? 140.h : 120.h),
                        sliver: SliverMasonryGrid.count(
                          crossAxisCount: colCount,
                          mainAxisSpacing: 8.h,
                          crossAxisSpacing: 8.w,
                          childCount: photos.length,
                          itemBuilder: (context, index) =>
                              _buildCard(photos[index], ext),
                        ),
                      ),

                      if (state.isLoadingImages)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 20.h),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 16.w,
                                  height: 16.w,
                                  child: CircularProgressIndicator(
                                      color: ext.accentGold, strokeWidth: 2),
                                ),
                                SizedBox(width: 10.w),
                                Text(
                                  AppLocalizations.of(context)!
                                      .searchResultsFindingMore,
                                  style: TextStyle(
                                      color: ext.searchHintColor,
                                      fontSize: 13.sp),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  ),

                  // ── Bottom action bar ───────────────────────────────────────
                  if (!state.isLoadingImages || state.searchImages.isNotEmpty)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: _buildBottomBar(
                          context, ext, photos, state.isSavingFree),
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

  /// On web desktop, centre the page in a 480 dp column so it matches the
  /// phone-sized layout used across the app — fonts and spacing stay correct.

  // ── AppBar ─────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(AppThemeExtension ext, BuildContext ctx) {
    if (_selectionMode) {
      return AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: kIsWeb ? null : IconButton(
          tooltip: 'Close',
          icon: Icon(Icons.close_rounded, color: ext.greetingColor),
          onPressed: _exitSelectionMode,
        ),
        title: Text(
          AppLocalizations.of(ctx)!
              .searchResultsSelected(_selectedIds.length),
          style: TextStyle(
            color: ext.greetingColor,
            fontWeight: FontWeight.w700,
            fontSize: 16.sp,
          ),
        ),
        actions: [
          BlocBuilder<HomeBloc, HomeState>(
            builder: (context, state) {
              final allSelected =
                  _selectedIds.length == state.searchImages.length;
              return TextButton(
                onPressed: allSelected
                    ? _exitSelectionMode
                    : () => _selectAll(state.searchImages),
                child: Text(
                  allSelected
                      ? AppLocalizations.of(context)!.searchResultsDeselectAll
                      : AppLocalizations.of(context)!.searchResultsSelectAll,
                  style: TextStyle(
                    color: ext.accentGold,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            },
          ),
        ],
      );
    }

    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: kIsWeb ? null : BackButton(onPressed: () => Navigator.of(ctx).pop(), color: ext.greetingColor),
      title: Text(
        AppLocalizations.of(ctx)!.searchResultsTitle,
        style: TextStyle(
          color: ext.greetingColor,
          fontWeight: FontWeight.w700,
          fontSize: 16.sp,
        ),
      ),
      actions: [
        BlocBuilder<HomeBloc, HomeState>(
          builder: (context, state) {
            if (state.searchImages.isEmpty) return const SizedBox.shrink();
            return TextButton.icon(
              onPressed: () => _enterSelectionMode(state.searchImages.first),
              icon: Icon(Icons.check_circle_outline_rounded,
                  color: ext.accentGold, size: 18.sp),
              label: Text(
                AppLocalizations.of(context)!.searchResultsSelect,
                style: TextStyle(
                    color: ext.accentGold,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600),
              ),
            );
          },
        ),
      ],
    );
  }

  // ── Photo card ─────────────────────────────────────────────────────────────

  Widget _buildCard(Photo photo, AppThemeExtension ext) {
    final isSelected = _selectedIds.contains(photo.id);
    final isPaid = photo.price > 0;

    return Semantics(button: true, label: 'Photo', child: GestureDetector(
      onTap: _selectionMode ? () => _toggleSelection(photo) : null,
      onLongPress: _selectionMode ? null : () => _enterSelectionMode(photo),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12.r),
          border: isSelected
              ? Border.all(color: ext.accentGold, width: 2.5)
              : Border.all(color: Colors.transparent, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? ext.accentGold.withValues(alpha: 0.3)
                  : Colors.black.withValues(alpha: 0.2),
              blurRadius: isSelected ? 10 : 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10.r),
          child: Stack(
            children: [
              if (photo.mediaType == 'video')
                SizedBox(
                  width: double.infinity,
                  height: 200.h,
                  child: _VideoThumbCard(url: photo.url, ext: ext),
                )
              else
                SkidooImage(
                  imageUrl: photo.url,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  semanticLabel: 'Photo',
                  placeholder: (_, __) => Container(
                    height: 150.h,
                    color: ext.searchFieldFill,
                    child: Center(
                      child: SizedBox(
                        width: 18.w,
                        height: 18.h,
                        child: CircularProgressIndicator(
                            color: ext.accentGold, strokeWidth: 2),
                      ),
                    ),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    height: 150.h,
                    color: ext.searchFieldFill,
                    child: Icon(Icons.broken_image_outlined,
                        color: ext.searchHintColor, size: 28.sp),
                  ),
                ),

              // ── Price badge (bottom-left) ─────────────────────────────────
              Positioned(
                left: 8.w,
                bottom: 8.h,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30.r),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 9.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.30),
                        borderRadius: BorderRadius.circular(30.r),
                        border: Border.all(
                          color: isPaid
                              ? ext.accentGold.withValues(alpha: 0.60)
                              : Colors.white.withValues(alpha: 0.22),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isPaid
                                ? Icons.sell_rounded
                                : Icons.check_circle_outline_rounded,
                            color: isPaid
                                ? ext.accentGold
                                : Colors.white.withValues(alpha: 0.90),
                            size: 9.sp,
                          ),
                          SizedBox(width: 3.w),
                          Text(
                            isPaid
                                ? 'GHS ${photo.price.toStringAsFixed(2)}'
                                : 'Free',
                            style: TextStyle(
                              color: isPaid
                                  ? ext.accentGold
                                  : Colors.white.withValues(alpha: 0.92),
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                              height: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // ── Selection overlay + checkmark ─────────────────────────────
              if (_selectionMode)
                Positioned.fill(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    color: isSelected
                        ? Colors.black.withValues(alpha: 0.25)
                        : Colors.transparent,
                    child: Align(
                      alignment: Alignment.topRight,
                      child: Padding(
                        padding: EdgeInsets.all(8.w),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          child: isSelected
                              ? Container(
                                  key: const ValueKey('checked'),
                                  width: 24.w,
                                  height: 24.w,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: ext.accentGold,
                                  ),
                                  child: Icon(Icons.check_rounded,
                                      color: Colors.black, size: 14.sp),
                                )
                              : Container(
                                  key: const ValueKey('unchecked'),
                                  width: 24.w,
                                  height: 24.w,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color:
                                        Colors.black.withValues(alpha: 0.35),
                                    border: Border.all(
                                        color: Colors.white60, width: 1.5),
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ));
  }

  // ── Bottom bar ─────────────────────────────────────────────────────────────

  Widget _buildBottomBar(
    BuildContext context,
    AppThemeExtension ext,
    List<Photo> photos,
    bool isSaving,
  ) {
    if (photos.isEmpty) return const SizedBox.shrink();

    final allTotal = _totalPriceOf(photos);
    final selectedPhotos =
        photos.where((p) => _selectedIds.contains(p.id)).toList();
    final selectedTotal = _totalPriceOf(selectedPhotos);
    final hasPaidAnywhere = allTotal > 0;
    final busy = isSaving || _paymentLoading;

    return Container(
      decoration: BoxDecoration(
        color: ext.glassFill,
        border: Border(
          top: BorderSide(color: ext.glassBorder, width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 12.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Notice — only when some photos cost money ─────────────────
              if (hasPaidAnywhere) ...[
                _PayNotice(ext: ext),
                SizedBox(height: 8.h),
              ],

              // ── Buttons ───────────────────────────────────────────────────
              if (_selectionMode)
                _buildSelectionButtons(
                    context, ext, photos, selectedPhotos, selectedTotal, busy)
              else
                _buildDefaultButtons(context, ext, photos, allTotal, busy),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultButtons(
    BuildContext context,
    AppThemeExtension ext,
    List<Photo> photos,
    double allTotal,
    bool busy,
  ) {
    if (allTotal > 0) {
      // Primary: pay for everything. Secondary: enter selection to cherry-pick.
      return Row(
        children: [
          Expanded(
            child: _ActionButton(
              label: 'Pay to Get Images  ·  GHS ${allTotal.toStringAsFixed(2)}',
              icon: Icons.lock_open_rounded,
              color: ext.accentGold,
              textColor: Colors.black,
              disabled: busy,
              loading: _paymentLoading,
              onTap: () => _initPayment(photos),
            ),
          ),
          SizedBox(width: 10.w),
          _ActionButton(
            label: AppLocalizations.of(context)!.searchResultsPick,
            icon: Icons.checklist_rounded,
            color: ext.searchFieldFill,
            textColor: ext.greetingColor,
            borderColor: ext.searchHintColor.withValues(alpha: 0.3),
            disabled: busy,
            loading: false,
            onTap: () => _enterSelectionMode(photos.first),
          ),
        ],
      );
    }

    // All photos free.
    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            label: AppLocalizations.of(context)!
                .searchResultsSaveAllPhotos(photos.length),
            icon: Icons.download_for_offline_rounded,
            color: ext.accentGold,
            textColor: Colors.black,
            disabled: busy,
            loading: busy,
            onTap: () => _saveAll(photos),
          ),
        ),
        SizedBox(width: 10.w),
        _ActionButton(
          label: AppLocalizations.of(context)!.searchResultsPick,
          icon: Icons.checklist_rounded,
          color: ext.searchFieldFill,
          textColor: ext.greetingColor,
          borderColor: ext.searchHintColor.withValues(alpha: 0.3),
          disabled: busy,
          loading: false,
          onTap: () => _enterSelectionMode(photos.first),
        ),
      ],
    );
  }

  Widget _buildSelectionButtons(
    BuildContext context,
    AppThemeExtension ext,
    List<Photo> allPhotos,
    List<Photo> selectedPhotos,
    double selectedTotal,
    bool busy,
  ) {
    final nSelected = selectedPhotos.length;
    // Any paid photo anywhere in the results → "Save All" must not appear.
    final hasPaidPhotos = allPhotos.any((p) => p.price > 0);

    if (selectedTotal > 0) {
      // Paid photos in selection — payment only, no secondary button.
      return _ActionButton(
        label: 'Pay Selected  ·  GHS ${selectedTotal.toStringAsFixed(2)}',
        icon: Icons.lock_open_rounded,
        color: ext.accentGold,
        textColor: Colors.black,
        disabled: busy || nSelected == 0,
        loading: _paymentLoading,
        onTap: () => _initPayment(selectedPhotos),
      );
    }

    if (hasPaidPhotos) {
      // Selection is free but paid photos exist elsewhere — save selection only,
      // no "Save All" (would imply paid items are included for free).
      return _ActionButton(
        label: AppLocalizations.of(context)!
            .searchResultsSaveSelected(nSelected),
        icon: Icons.save_alt_rounded,
        color: ext.accentGold,
        textColor: Colors.black,
        disabled: nSelected == 0 || busy,
        loading: busy,
        onTap: () => _saveSelected(allPhotos),
      );
    }

    // Every photo is free — show both Save Selected and Save All.
    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            label: AppLocalizations.of(context)!
                .searchResultsSaveSelected(nSelected),
            icon: Icons.save_alt_rounded,
            color: ext.accentGold,
            textColor: Colors.black,
            disabled: nSelected == 0 || busy,
            loading: busy,
            onTap: () => _saveSelected(allPhotos),
          ),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: _ActionButton(
            label: AppLocalizations.of(context)!
                .searchResultsSaveAll(allPhotos.length),
            icon: Icons.download_for_offline_rounded,
            color: ext.searchFieldFill,
            textColor: ext.greetingColor,
            borderColor: ext.searchHintColor.withValues(alpha: 0.3),
            disabled: busy,
            loading: false,
            onTap: () {
              _saveAll(allPhotos);
              _exitSelectionMode();
            },
          ),
        ),
      ],
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Widget _buildInitialLoader(BuildContext context, AppThemeExtension ext) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.image_search_rounded,
              size: 56.sp, color: ext.accentGold.withValues(alpha: 0.7)),
          SizedBox(height: 24.h),
          SizedBox(
            width: 220.w,
            child: LinearProgressIndicator(
              color: ext.accentGold,
              backgroundColor: ext.accentGold.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4.r),
              minHeight: 4.h,
            ),
          ),
          SizedBox(height: 20.h),
          Text(
            AppLocalizations.of(context)!.searchResultsScanningPhotos,
            style: TextStyle(
                color: ext.greetingColor,
                fontSize: 15.sp,
                fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 8.h),
          Text(AppLocalizations.of(context)!.searchResultsMayTakeAMoment,
              style: TextStyle(color: ext.searchHintColor, fontSize: 12.sp)),
        ],
      ),
    );
  }

  Widget _buildEmpty(BuildContext context, AppThemeExtension ext) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.image_search_outlined,
              size: 64.sp, color: ext.searchHintColor),
          SizedBox(height: 12.h),
          Text(AppLocalizations.of(context)!.searchResultsNoPhotos,
              style: TextStyle(color: ext.searchHintColor, fontSize: 15.sp)),
        ],
      ),
    );
  }

  void _showSnack(BuildContext context, String msg, {required bool isError}) {
    final margin = EdgeInsets.only(bottom: 80.h, left: 16.w, right: 16.w);
    if (isError) {
      AppSnackBar.error(context, msg, margin: margin);
    } else {
      AppSnackBar.success(context, msg, margin: margin);
    }
  }
}

// ── Video thumbnail card ──────────────────────────────────────────────────────

class _VideoThumbCard extends StatefulWidget {
  const _VideoThumbCard({required this.url, required this.ext});
  final String url;
  final AppThemeExtension ext;

  @override
  State<_VideoThumbCard> createState() => _VideoThumbCardState();
}

class _VideoThumbCardState extends State<_VideoThumbCard> {
  late final VideoPlayerController _ctrl;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..setVolume(0)
      ..initialize().then((_) async {
        if (!mounted) return;
        await _ctrl.seekTo(Duration.zero);
        await _ctrl.pause();
        if (mounted) setState(() => _ready = true);
      }).catchError((_) {
        if (mounted) setState(() => _ready = false);
      });
  }

  @override
  void dispose() {
    _ctrl
      ..pause()
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (_ready)
          FittedBox(
            fit: BoxFit.cover,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: _ctrl.value.size.width,
              height: _ctrl.value.size.height,
              child: VideoPlayer(_ctrl),
            ),
          )
        else
          ColoredBox(color: widget.ext.searchFieldFill),

        // Play badge
        Center(
          child: Container(
            width: 36.w,
            height: 36.w,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              shape: BoxShape.circle,
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.35), width: 1.2),
            ),
            child:
                Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20.sp),
          ),
        ),
      ],
    );
  }
}

// ── Pay notice ────────────────────────────────────────────────────────────────

class _PayNotice extends StatelessWidget {
  const _PayNotice({required this.ext});
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: ext.accentGold.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(
            color: ext.accentGold.withValues(alpha: 0.30), width: 0.8),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: ext.accentGold, size: 15.sp),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              'Some photos require payment. Deselect paid photos to save the free ones.',
              style: TextStyle(
                color: ext.greetingColor.withValues(alpha: 0.85),
                fontSize: 12.sp,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Reusable action button ────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.textColor,
    required this.disabled,
    required this.loading,
    required this.onTap,
    this.borderColor,
  });

  final String label;
  final IconData icon;
  final Color color;
  final Color textColor;
  final Color? borderColor;
  final bool disabled;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(button: true, label: label, child: GestureDetector(
      onTap: disabled ? null : onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: disabled ? 0.5 : 1.0,
        child: Container(
          height: 46.h,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12.r),
            border: borderColor != null
                ? Border.all(color: borderColor!, width: 1)
                : null,
          ),
          alignment: Alignment.center,
          child: loading
              ? SizedBox(
                  width: 18.w,
                  height: 18.w,
                  child: CircularProgressIndicator(
                      color: textColor, strokeWidth: 2),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: textColor, size: 18.sp),
                    SizedBox(width: 6.w),
                    Flexible(
                      child: Text(
                        label,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    ));
  }
}
