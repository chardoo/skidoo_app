import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/utils/snackbar_utils.dart';
import 'package:jperg_app/features/gallery/data/repositories/found_review_repository.dart';

/// "Tap to deselect photos that aren't you."
///
/// Everything starts selected, because face recognition is usually right and
/// the common answer is "yes, all of these". Deselecting is the exception, so
/// it is the thing that takes a tap.
///
/// Closing decides nothing — the photos stay pending and the banner keeps
/// offering them. Only Confirm answers.
class ReviewFoundPhotosPage extends StatefulWidget {
  const ReviewFoundPhotosPage({super.key, required this.pending});

  final PendingFound pending;

  @override
  State<ReviewFoundPhotosPage> createState() => _ReviewFoundPhotosPageState();
}

class _ReviewFoundPhotosPageState extends State<ReviewFoundPhotosPage> {
  /// Ids the user has taken the tick off — "not me".
  final _deselected = <String>{};
  bool _submitting = false;

  List<PendingFoundPhoto> get _all =>
      [for (final event in widget.pending.events) ...event.photos];

  int get _selectedCount => _all.length - _deselected.length;

  void _toggle(String id) {
    setState(() {
      if (!_deselected.remove(id)) _deselected.add(id);
    });
  }

  Future<void> _confirm() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      final confirmed = [
        for (final photo in _all)
          if (!_deselected.contains(photo.id)) photo.id,
      ];
      await FoundReviewRepository().review(
        confirmed: confirmed,
        rejected: _deselected.toList(),
      );
      if (!mounted) return;
      // True tells the caller the answer landed, so it can drop the banner and
      // reload rather than guessing.
      Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint('[ReviewFoundPhotos] confirm ERROR: $e');
      if (!mounted) return;
      setState(() => _submitting = false);
      AppSnackBar.error(context, 'Could not save your answer. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final grouped = widget.pending.eventCount > 1;

    return Scaffold(
      backgroundColor: ext.homeBackground,
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          tooltip: 'Close',
          icon: Icon(Icons.close_rounded, color: ext.greetingColor, size: 24.r),
          // Nothing is sent — everything stays waiting.
          onPressed: () => Navigator.of(context).pop(false),
        ),
        title: Text(
          'Review Photos',
          style: TextStyle(
            color: ext.greetingColor,
            fontWeight: FontWeight.w700,
            fontSize: 16.sp,
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.lg.w,
              vertical: AppSpacing.sm.h,
            ),
            child: Text(
              "Tap to deselect photos that aren't you",
              textAlign: TextAlign.center,
              style: TextStyle(color: ext.searchHintColor, fontSize: 13.sp),
            ),
          ),
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                AppSpacing.md.w, AppSpacing.sm.h, AppSpacing.md.w, 120.h,
              ),
              children: [
                for (final event in widget.pending.events) ...[
                  // One event needs no heading — the whole screen is that
                  // event. Several do, or the photos are one undifferentiated
                  // wall.
                  if (grouped) ...[
                    Padding(
                      padding: EdgeInsets.only(
                        top: AppSpacing.md.h, bottom: AppSpacing.sm.h,
                      ),
                      child: Text(
                        event.eventName,
                        style: TextStyle(
                          color: ext.searchHintColor,
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 4,
                      mainAxisSpacing: 4,
                    ),
                    itemCount: event.photos.length,
                    itemBuilder: (_, i) {
                      final photo = event.photos[i];
                      return _ReviewTile(
                        photo: photo,
                        selected: !_deselected.contains(photo.id),
                        ext: ext,
                        onTap: () => _toggle(photo.id),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: EdgeInsets.fromLTRB(
          AppSpacing.xl.w, 0, AppSpacing.xl.w, AppSpacing.xl.h,
        ),
        child: _ConfirmButton(
          // Deselecting everything is still an answer — every photo is a "not
          // me" — so the button says so rather than going dead.
          label: _selectedCount == 0
              ? 'Confirm none are you'
              : 'Confirm $_selectedCount photo${_selectedCount == 1 ? '' : 's'}',
          busy: _submitting,
          ext: ext,
          onPressed: _confirm,
        ),
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({
    required this.photo,
    required this.selected,
    required this.ext,
    required this.onTap,
  });

  final PendingFoundPhoto photo;
  final bool selected;
  final AppThemeExtension ext;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: selected ? 'Selected — tap if this is not you' : 'Marked not you',
      child: GestureDetector(
        // Opaque: an Image does not absorb a hit on its own.
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.sm.r),
          child: ColoredBox(
            color: ext.avatarBackground,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  photo.url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.broken_image_outlined,
                    color: ext.searchHintColor,
                    size: 20.r,
                  ),
                ),
                // Deselected photos dim and say so, so the answer is readable
                // at a glance instead of hunting for missing ticks.
                if (!selected)
                  ColoredBox(
                    color: Colors.black.withValues(alpha: 0.55),
                    child: Center(
                      child: Text(
                        'Not me',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  right: 6.w,
                  top: 6.h,
                  child: _Tick(selected: selected, ext: ext),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Tick extends StatelessWidget {
  const _Tick({required this.selected, required this.ext});

  final bool selected;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20.r,
      height: 20.r,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? ext.accentGold : Colors.transparent,
        border: Border.all(
          color: selected
              ? ext.accentGold
              : Colors.white.withValues(alpha: 0.85),
          width: 1.6,
        ),
      ),
      child: selected
          ? Icon(Icons.check_rounded, size: 13.r, color: Colors.white)
          : null,
    );
  }
}

class _ConfirmButton extends StatelessWidget {
  const _ConfirmButton({
    required this.label,
    required this.busy,
    required this.ext,
    required this.onPressed,
  });

  final String label;
  final bool busy;
  final AppThemeExtension ext;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52.h,
      child: ElevatedButton(
        onPressed: busy ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: ext.accentGold,
          disabledBackgroundColor: ext.accentGold.withValues(alpha: 0.6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999.r),
          ),
        ),
        child: busy
            ? SizedBox(
                width: 18.r,
                height: 18.r,
                child: const CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white,
                ),
              )
            : Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}
