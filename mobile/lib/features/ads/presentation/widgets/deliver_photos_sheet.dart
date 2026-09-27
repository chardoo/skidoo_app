import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/common/widgets/app_button.dart';
import 'package:jperg_app/core/common/widgets/app_loading_indicator.dart';
import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/theme/app_typography.dart';
import 'package:jperg_app/core/utils/snackbar_utils.dart';
import 'package:jperg_app/features/ads/data/repositories/ads_repository.dart';
import 'package:jperg_app/features/photographers/domain/repositories/photographer_repository.dart';
import 'package:jperg_app/models/photographer/photographer_event.dart';
import 'package:jperg_app/services/auth_service.dart';

/// Choosing which album to hand to the client.
///
/// One decision, so a sheet rather than a screen: the photographer has already
/// uploaded the photographs, and this is only which of their albums the client
/// gets.
///
/// The client's address is deliberately not on this sheet. The server reads it
/// from the booking, because being an owner is matched on an email string —
/// and a typo here would cost somebody their badge for work they actually
/// delivered. Nothing on this screen can be typed.
class DeliverPhotosSheet extends StatefulWidget {
  const DeliverPhotosSheet({super.key, required this.requestId});

  final String requestId;

  /// Returns true when photos were handed over, so the screen behind can
  /// reload and show the delivery.
  static Future<bool> show(BuildContext context, {required String requestId}) async {
    final delivered = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DeliverPhotosSheet(requestId: requestId),
    );
    return delivered ?? false;
  }

  @override
  State<DeliverPhotosSheet> createState() => _DeliverPhotosSheetState();
}

class _DeliverPhotosSheetState extends State<DeliverPhotosSheet> {
  final _repo = AdsRepository();

  List<PhotographerEvent> _albums = const [];
  bool _loading = true;
  String? _selected;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final id = await sl<AuthService>().getUserId();
      final result = await sl<PhotographerRepository>().getPhotographerEvents(
        photographerId: id,
        page: 1,
        limit: 50,
      );
      if (!mounted) return;
      setState(() {
        _albums = result.events;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deliver() async {
    final album = _selected;
    if (album == null || _sending) return;
    setState(() => _sending = true);
    try {
      final result = await _repo.deliverPhotos(
        requestId: widget.requestId,
        eventId: album,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
      AppSnackBar.success(
        context,
        result.onTime
            ? 'Delivered. Your client can see the photos now.'
            : 'Delivered — after the deadline. Your client can see the photos '
                'now.',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      // The server's own sentence. "That album has no photos in it yet" is the
      // whole answer and the reader can act on it; a status code is not.
      AppSnackBar.error(
        context,
        '$e'.replaceFirst(RegExp(r'^\w*Exception: '), ''),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      decoration: BoxDecoration(
        color: ext.homeBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl.r)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: AppSpacing.md.h),
            Container(
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: ext.searchHintColor.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(AppRadius.pill.r),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(AppSpacing.lg.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Deliver photos',
                    style: TextStyle(
                      color: ext.greetingColor,
                      fontFamily: AppTypography.displayFontFamily,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: AppSpacing.xs.h),
                  Text(
                    'Pick the album for this booking. Your client is added to '
                    'it automatically — you never type their address.',
                    style: TextStyle(
                      color: ext.searchHintColor,
                      fontSize: 14.sp,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            Flexible(child: _list(ext)),
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg.w,
                AppSpacing.sm.h,
                AppSpacing.lg.w,
                AppSpacing.lg.h,
              ),
              child: AppButton(
                label: 'Deliver these photos',
                fullWidth: true,
                borderRadius: AppRadius.pill,
                isLoading: _sending,
                onPressed: _selected == null ? null : _deliver,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _list(AppThemeExtension ext) {
    if (_loading) {
      return Padding(
        padding: EdgeInsets.all(AppSpacing.xxl.w),
        child: const AppLoadingIndicator(),
      );
    }
    if (_albums.isEmpty) {
      // The likeliest reason somebody opens this and cannot finish, so it says
      // what to do rather than only that there is nothing here.
      return Padding(
        padding: EdgeInsets.all(AppSpacing.xxl.w),
        child: Text(
          'You have no albums yet. Create one and upload the photographs, '
          'then come back here to hand them over.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: ext.searchHintColor,
            fontSize: 14.sp,
            height: 1.5,
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg.w),
      itemCount: _albums.length,
      separatorBuilder: (_, __) => SizedBox(height: AppSpacing.sm.h),
      itemBuilder: (_, i) {
        final album = _albums[i];
        final selected = album.id == _selected;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _selected = album.id),
          child: Container(
            padding: EdgeInsets.all(AppSpacing.md.w),
            decoration: BoxDecoration(
              color: ext.searchFieldFill,
              borderRadius: BorderRadius.circular(AppRadius.md.r),
              border: Border.all(
                color: selected
                    ? ext.accentGold
                    : ext.searchHintColor.withValues(alpha: 0.2),
                width: selected ? 1.5 : 0.8,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        album.eventName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: ext.greetingColor,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        album.eventDate,
                        style: TextStyle(
                          color: ext.searchHintColor,
                          fontSize: 12.sp,
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  Icon(Icons.check_circle_rounded,
                      color: ext.accentGold, size: 20.sp),
              ],
            ),
          ),
        );
      },
    );
  }
}
