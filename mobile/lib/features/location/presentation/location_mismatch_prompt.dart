import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/utils/snackbar_utils.dart';
import 'package:jperg_app/features/location/data/repositories/location_repository.dart';
import 'package:jperg_app/features/location/presentation/widgets/location_picker_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// "You seem to be somewhere else — is your location still right?"
///
/// Where a photographer works decides which jobs they are shown at all: the
/// country is a hard filter, so someone who moved and never updated their
/// profile quietly stops seeing local work, with nothing on screen explaining
/// why. This is the only thing that would tell them.
///
/// Asked, never applied. The country a request arrives from is where somebody
/// is *right now* — a wedding photographer on a job abroad has not moved — and
/// rewriting their working location out from under them would break exactly
/// the thing this exists to protect.
///
/// Rate-limited hard, and that is most of the design. A prompt that appears on
/// every launch while somebody is travelling is a prompt they learn to dismiss
/// without reading, which costs the one time it mattered.
class LocationMismatchPrompt {
  LocationMismatchPrompt._();

  /// Long enough that a fortnight abroad produces one prompt rather than
  /// fourteen, short enough that an actual move is noticed within a week.
  static const _minimumGap = Duration(days: 7);

  /// Remembered per detected country, so the prompt is silent for the trip
  /// somebody dismissed and speaks up again if they turn up somewhere new.
  static const _prefix = 'location_prompt_dismissed_';

  /// Held across the check-and-stamp, and released the moment the stamp lands.
  ///
  /// There is a gap between asking the server and writing the stamp; two calls
  /// landing inside it both read "not asked yet" and both push a sheet, stacked
  /// one on the other, so dismissing reveals another. The shell calls this once
  /// per mount, but "once" is a property of the caller.
  ///
  /// Deliberately not held for the sheet's lifetime. The stamp already stops a
  /// second prompt, and a flag that outlives the await would stay set for as
  /// long as somebody left the sheet open.
  static bool _checking = false;

  /// Show it if there is a genuine disagreement and it has not been raised
  /// recently. Never throws and never blocks: this runs during launch, and a
  /// launch that fails over an optional prompt is worse than no prompt.
  ///
  /// [repo] and [prefs] are injectable for tests.
  static Future<void> maybeShow(
    BuildContext context, {
    LocationRepository? repo,
    SharedPreferences? prefs,
  }) async {
    if (_checking) return;
    _checking = true;

    final LocationContext ctx;
    final String detected;
    final LocationRepository repository;
    try {
      final store = prefs ?? sl<SharedPreferences>();
      repository = repo ?? LocationRepository();

      final fetched = await repository.context();
      if (fetched == null || !fetched.locationMismatch) return;

      final country = fetched.detectedCountryCode;
      if (country == null || country.isEmpty) return;
      if (!_isDue(store, country)) return;
      if (!context.mounted) return;

      // Stamped before the sheet rather than after it. Dismissing by swiping
      // away returns no answer at all, and a prompt that only records the
      // answers it likes is a prompt that reappears every launch for anyone
      // who swipes.
      await _stamp(store, country);
      ctx = fetched;
      detected = country;
    } catch (_) {
      // Deliberately silent. Nothing here is worth interrupting a launch for.
      return;
    } finally {
      _checking = false;
    }

    // Outside the guard: awaiting the sheet means awaiting the person, and
    // nothing should be held for that long.
    if (!context.mounted) return;
    await _show(context, ctx, detected, repository);
  }

  static bool _isDue(SharedPreferences store, String country) {
    final last = store.getInt('$_prefix$country');
    if (last == null) return true;
    final since = DateTime.now().millisecondsSinceEpoch - last;
    return since >= _minimumGap.inMilliseconds;
  }

  static Future<void> _stamp(SharedPreferences store, String country) async {
    await store.setInt(
      '$_prefix$country',
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  static Future<void> _show(
    BuildContext context,
    LocationContext ctx,
    String detected,
    LocationRepository repo,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _MismatchSheet(
        current: ctx.location ?? ctx.countryCode ?? 'somewhere else',
        detected: detected,
        repo: repo,
      ),
    );
  }
}

class _MismatchSheet extends StatefulWidget {
  const _MismatchSheet({
    required this.current,
    required this.detected,
    required this.repo,
  });

  final String current;
  final String detected;
  final LocationRepository repo;

  @override
  State<_MismatchSheet> createState() => _MismatchSheetState();
}

class _MismatchSheetState extends State<_MismatchSheet> {
  bool _saving = false;

  Future<void> _update() async {
    final place = await LocationPickerSheet.show(
      context,
      title: 'Where do you work?',
      repo: widget.repo,
    );
    if (place == null || !mounted) return;

    setState(() => _saving = true);
    try {
      await widget.repo.setLocation(place);
      if (!mounted) return;
      Navigator.of(context).pop();
      AppSnackBar.success(context, 'Location updated to ${place.label}.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppSnackBar.error(context, 'Could not update your location.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return Container(
      decoration: BoxDecoration(
        color: ext.homeBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      padding: EdgeInsets.fromLTRB(
          AppSpacing.xl.w, 0, AppSpacing.xl.w, AppSpacing.xl.h),
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          top: false,
          // Scrollable, like the sibling sheets. The body is several lines of
          // prose and grows with the system font scale; on a short screen at a
          // large text size it is taller than the space a sheet gets, and a
          // Column that cannot fit simply clips the buttons off the bottom.
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    margin: EdgeInsets.symmetric(vertical: AppSpacing.md.h),
                    width: 36.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: ext.searchHintColor.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                ),
                SizedBox(height: AppSpacing.sm.h),
                Row(
                  children: [
                    Container(
                      width: 42.w,
                      height: 42.w,
                      decoration: BoxDecoration(
                        color: ext.accentGold.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      alignment: Alignment.center,
                      child: Icon(Icons.travel_explore_rounded,
                          color: ext.accentGold, size: 22.r),
                    ),
                    SizedBox(width: AppSpacing.md.w),
                    Expanded(
                      child: Text(
                        'Still working in ${widget.current}?',
                        style: TextStyle(
                          color: ext.greetingColor,
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: AppSpacing.md.h),
                Text(
                  // Says what it costs, because "update your location" on its own
                  // reads as housekeeping and this is the reason a board can look
                  // empty.
                  'It looks like you are opening the app from somewhere else. '
                  'Your location decides which requests and campaigns reach '
                  'you — if you have moved, jobs near you will not show up '
                  'until you change it.',
                  style: TextStyle(
                    color: ext.searchHintColor,
                    fontSize: 14.sp,
                    height: 1.5,
                  ),
                ),
                SizedBox(height: AppSpacing.xl.h),
                SizedBox(
                  width: double.infinity,
                  height: 46.h,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _update,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ext.accentGold,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.xl.r),
                      ),
                    ),
                    child: _saving
                        ? SizedBox(
                            width: 18.w,
                            height: 18.w,
                            child: const CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : Text(
                            'Update my location',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
                SizedBox(height: AppSpacing.sm.h),
                Center(
                  child: TextButton(
                    onPressed:
                        _saving ? null : () => Navigator.of(context).pop(),
                    child: Text(
                      // Named for the common case. Most people seeing this are
                      // travelling, not moving.
                      'I am just travelling',
                      style: TextStyle(
                        color: ext.searchHintColor,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
