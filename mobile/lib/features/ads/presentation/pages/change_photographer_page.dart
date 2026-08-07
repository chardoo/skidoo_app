import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/common/widgets/app_widgets.dart';
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/utils/snackbar_utils.dart';
import 'package:jperg_app/core/utils/web_wrap.dart';
import 'package:jperg_app/features/ads/data/models/feed_request_model.dart';
import 'package:jperg_app/features/ads/data/repositories/ads_repository.dart';
import 'package:jperg_app/features/photographers/presentation/widgets/photographer_meta.dart';

/// Swapping the chosen photographer for another one.
///
/// Everyone who answered is still here, including the current pick — changing
/// your mind and changing it back are the same action. The confirmation names
/// both people, because the one being dropped is told and the requester should
/// know that before it happens rather than after.
class ChangePhotographerPage extends StatefulWidget {
  const ChangePhotographerPage({
    super.key,
    required this.request,
    required this.people,
    this.currentId,
  });

  final FeedRequestModel request;
  final List<RequestInterest> people;
  final String? currentId;

  @override
  State<ChangePhotographerPage> createState() => _ChangePhotographerPageState();
}

class _ChangePhotographerPageState extends State<ChangePhotographerPage> {
  final _repo = AdsRepository();
  String? _picked;
  bool _saving = false;

  RequestInterest? get _current {
    for (final person in widget.people) {
      if (person.id == widget.currentId) return person;
    }
    return null;
  }

  Future<void> _confirm() async {
    final chosen = _picked;
    if (chosen == null || _saving) return;

    final incoming = widget.people.firstWhere((p) => p.id == chosen);
    final outgoing = _current;

    final agreed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _ConfirmSheet(
        ext: Theme.of(context).extension<AppThemeExtension>()!,
        // Names both sides. "Kwame Studios will be notified of the
        // cancellation" is a real consequence for a real person.
        message: outgoing == null
            ? '${incoming.name ?? 'They'} will receive your booking request '
                'for ${widget.request.title}.'
            : '${outgoing.name ?? 'They'} will be notified of the '
                'cancellation. ${incoming.name ?? 'The new photographer'} '
                'will receive your booking request for '
                '${widget.request.title}.',
      ),
    );
    if (agreed != true) return;

    setState(() => _saving = true);
    try {
      await _repo.selectPhotographer(widget.request.id, chosen);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint('[ChangePhotographer] select ERROR: $e');
      if (!mounted) return;
      setState(() => _saving = false);
      AppSnackBar.error(context, 'Could not change the photographer.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    final page = Scaffold(
      backgroundColor: ext.homeBackground,
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        leading: kIsWeb
            ? null
            : AppBackButton(onPressed: () => Navigator.of(context).pop(false)),
        title: Text(
          'Select New Photographer',
          style: TextStyle(
            color: ext.greetingColor,
            fontWeight: FontWeight.w700,
            fontSize: 16.sp,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                AppSpacing.md.w, AppSpacing.md.h, AppSpacing.md.w, 0,
              ),
              children: [
                _RequestHeader(request: widget.request, ext: ext),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.xs.w, AppSpacing.md.h, 0, AppSpacing.sm.h,
                  ),
                  child: Text(
                    'All Requests',
                    style: TextStyle(
                      color: ext.searchHintColor,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                for (final person in widget.people)
                  _SelectableTile(
                    person: person,
                    ext: ext,
                    // The current pick reads as chosen until another is
                    // touched, so the screen opens showing the truth.
                    selected: (_picked ?? widget.currentId) == person.id,
                    onTap: () => setState(() => _picked = person.id),
                  ),
              ],
            ),
          ),
          SafeArea(
            minimum: EdgeInsets.fromLTRB(
              AppSpacing.xl.w, AppSpacing.md.h, AppSpacing.xl.w, AppSpacing.lg.h,
            ),
            child: SizedBox(
              width: double.infinity,
              height: 50.h,
              child: ElevatedButton(
                // Nothing to do until they pick someone other than the person
                // already chosen.
                onPressed: (_saving ||
                        _picked == null ||
                        _picked == widget.currentId)
                    ? null
                    : _confirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ext.accentGold,
                  disabledBackgroundColor:
                      ext.searchHintColor.withValues(alpha: 0.25),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999.r),
                  ),
                ),
                child: _saving
                    ? SizedBox(
                        width: 18.r,
                        height: 18.r,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white,
                        ),
                      )
                    : Text(
                        'Continue',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
    return webWrap(page, backgroundColor: ext.homeBackground);
  }
}

class _RequestHeader extends StatelessWidget {
  const _RequestHeader({required this.request, required this.ext});

  final FeedRequestModel request;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    final date = request.eventDate ?? request.createdAt;
    final meta = [
      if (date != null)
        '${date.day.toString().padLeft(2, '0')}.'
            '${date.month.toString().padLeft(2, '0')}.${date.year}',
      if (request.location.isNotEmpty) request.location,
    ].join(' | ');

    return Container(
      padding: EdgeInsets.all(AppSpacing.lg.w),
      decoration: BoxDecoration(
        color: ext.accentGold.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.lg.r),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.title,
                  style: TextStyle(
                    color: ext.greetingColor,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  meta,
                  style: TextStyle(color: ext.searchHintColor, fontSize: 12.sp),
                ),
              ],
            ),
          ),
          Text(
            request.isLive ? 'Active' : 'Closed',
            style: TextStyle(
              color: request.isLive ? ext.accentGold : ext.searchHintColor,
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectableTile extends StatelessWidget {
  const _SelectableTile({
    required this.person,
    required this.ext,
    required this.selected,
    required this.onTap,
  });

  final RequestInterest person;
  final AppThemeExtension ext;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = (person.name?.trim().isNotEmpty ?? false)
        ? person.name!.trim()
        : 'Photographer';
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: AppSpacing.sm.h),
        padding: EdgeInsets.all(AppSpacing.md.w),
        decoration: BoxDecoration(
          color: ext.cardSurface,
          borderRadius: BorderRadius.circular(AppRadius.md.r),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18.r,
              backgroundColor: ext.avatarBackground,
              backgroundImage: (person.profileUrl?.isNotEmpty ?? false)
                  ? NetworkImage(person.profileUrl!)
                  : null,
              child: (person.profileUrl?.isNotEmpty ?? false)
                  ? null
                  : Text(name[0].toUpperCase(),
                      style: TextStyle(color: ext.avatarForeground)),
            ),
            SizedBox(width: AppSpacing.md.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      color: ext.greetingColor,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  PhotographerMeta(
                    ext: ext,
                    location: person.location,
                    followerCount: person.followerCount,
                    rating: person.rating,
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 7.h),
              decoration: BoxDecoration(
                color: selected ? ext.accentGold : Colors.transparent,
                borderRadius: BorderRadius.circular(999.r),
                border: Border.all(color: ext.accentGold, width: 1),
              ),
              child: Text(
                selected ? 'Selected' : 'Select',
                style: TextStyle(
                  color: selected ? Colors.white : ext.accentGold,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfirmSheet extends StatelessWidget {
  const _ConfirmSheet({required this.ext, required this.message});

  final AppThemeExtension ext;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ext.homeBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xl.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36.w,
                  height: 4.h,
                  margin: EdgeInsets.only(bottom: AppSpacing.lg.h),
                  decoration: BoxDecoration(
                    color: ext.searchHintColor.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              Text(
                'Confirm photographer?',
                style: TextStyle(
                  color: ext.greetingColor,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: AppSpacing.sm.h),
              Text(
                message,
                style: TextStyle(
                  color: ext.searchHintColor, fontSize: 13.sp, height: 1.45,
                ),
              ),
              SizedBox(height: AppSpacing.xl.h),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 46.h,
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: ext.searchHintColor.withValues(alpha: 0.4),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999.r),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: ext.greetingColor, fontSize: 14.sp,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: AppSpacing.md.w),
                  Expanded(
                    child: SizedBox(
                      height: 46.h,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ext.accentGold,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999.r),
                          ),
                        ),
                        child: Text(
                          'Confirm selection',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
