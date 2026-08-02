import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/common/widgets/app_widgets.dart';
import 'package:skidoo_app/core/theme/app_radius.dart';
import 'package:skidoo_app/core/theme/app_spacing.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/core/utils/web_wrap.dart';
import 'package:skidoo_app/features/ads/data/models/feed_request_model.dart';
import 'package:skidoo_app/features/ads/data/repositories/ads_repository.dart';

/// Everyone who answered one of your requests.
///
/// Only the requester can load this — the board shows everyone else a count
/// and nothing more — so it is only ever reached from your own card.
class RequestInterestsPage extends StatefulWidget {
  const RequestInterestsPage({
    super.key,
    required this.requestId,
    required this.title,
  });

  final String requestId;
  final String title;

  @override
  State<RequestInterestsPage> createState() => _RequestInterestsPageState();
}

class _RequestInterestsPageState extends State<RequestInterestsPage> {
  final _repo = AdsRepository();
  List<RequestInterest> _people = [];
  bool _loading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final people = await _repo.getRequestInterests(widget.requestId);
      if (!mounted) return;
      setState(() {
        _people = people;
        _loading = false;
      });
    } catch (e) {
      debugPrint('[RequestInterestsPage] load ERROR: $e');
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not load who answered this request.';
        _loading = false;
      });
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
            : AppBackButton(onPressed: () => Navigator.of(context).pop()),
        title: Text(
          'Interested',
          style: TextStyle(
            color: ext.greetingColor,
            fontWeight: FontWeight.w700,
            fontSize: 16.sp,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _Message(text: _errorMessage!, ext: ext, onRetry: _load)
              : _people.isEmpty
                  ? _Message(
                      text: 'No one has answered this request yet.',
                      ext: ext,
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: ext.accentGold,
                      child: ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: EdgeInsets.symmetric(vertical: AppSpacing.md.h),
                        itemCount: _people.length,
                        itemBuilder: (_, i) =>
                            _PersonTile(person: _people[i], ext: ext),
                      ),
                    ),
    );
    return webWrap(page, backgroundColor: ext.homeBackground);
  }
}

class _PersonTile extends StatelessWidget {
  const _PersonTile({required this.person, required this.ext});

  final RequestInterest person;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    final photo = person.profileUrl;
    final name = (person.name?.trim().isNotEmpty ?? false)
        ? person.name!.trim()
        : 'Photographer';

    return Container(
      margin: EdgeInsets.fromLTRB(14.w, 0, 14.w, 10.h),
      padding: EdgeInsets.all(AppSpacing.lg.w),
      decoration: BoxDecoration(
        color: ext.cardSurface,
        borderRadius: BorderRadius.circular(AppRadius.lg.r),
        border: Border.all(
          color: ext.searchHintColor.withValues(alpha: 0.1),
          width: 0.8,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20.r,
            backgroundColor: ext.avatarBackground,
            backgroundImage:
                photo != null && photo.isNotEmpty ? NetworkImage(photo) : null,
            child: photo != null && photo.isNotEmpty
                ? null
                : Text(
                    name[0].toUpperCase(),
                    style: TextStyle(
                      color: ext.avatarForeground,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
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
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (person.message != null && person.message!.isNotEmpty) ...[
                  SizedBox(height: 4.h),
                  Text(
                    person.message!,
                    style: TextStyle(
                      color: ext.searchHintColor,
                      fontSize: 12.sp,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, required this.ext, this.onRetry});

  final String text;
  final AppThemeExtension ext;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xxl.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(color: ext.searchHintColor, fontSize: 14.sp),
            ),
            if (onRetry != null) ...[
              SizedBox(height: AppSpacing.md.h),
              TextButton(
                onPressed: onRetry,
                child: Text(
                  'Retry',
                  style: TextStyle(color: ext.accentGold),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
