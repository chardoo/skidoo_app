import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/common/widgets/app_widgets.dart';
import 'package:skidoo_app/core/config/chat_config.dart';
import 'package:skidoo_app/core/di/service_locator.dart';
import 'package:skidoo_app/core/error/exceptions.dart';
import 'package:skidoo_app/core/theme/app_radius.dart';
import 'package:skidoo_app/core/theme/app_spacing.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/core/utils/number_format.dart';
import 'package:skidoo_app/core/utils/snackbar_utils.dart';
import 'package:skidoo_app/core/utils/web_wrap.dart';
import 'package:skidoo_app/features/ads/data/models/feed_request_model.dart';
import 'package:skidoo_app/features/ads/data/repositories/ads_repository.dart';
import 'package:skidoo_app/features/ads/presentation/pages/my_requests_page.dart'
    show EditRequestSheet;
import 'package:skidoo_app/features/ads/presentation/pages/request_photographer_page.dart';
import 'package:skidoo_app/features/chat/domain/usecases/chat_usecases.dart';
import 'package:skidoo_app/features/chat/presentation/pages/chat_room_page.dart';

/// What happened to a request while it was open, so the list behind it knows
/// whether it is out of date.
///
/// Looking at a request changes nothing about it, and the list is expensive to
/// refetch — so "I went in and came out" has to be distinguishable from "I
/// changed something".
enum RequestOutcome { unchanged, changed, deleted }

/// The photographers who answered one request.
///
/// Split by whether the requester has opened them yet — pending is a to-do
/// list, and it shrinks as they work through it. Once someone is chosen they
/// move to the top under "Your Selection" with a way to message them, and the
/// rest stay listed underneath: the choice can be changed, so the others are
/// not thrown away.
class ReviewPhotographersPage extends StatefulWidget {
  const ReviewPhotographersPage({super.key, required this.request});

  final FeedRequestModel request;

  @override
  State<ReviewPhotographersPage> createState() =>
      _ReviewPhotographersPageState();
}

class _ReviewPhotographersPageState extends State<ReviewPhotographersPage> {
  final _repo = AdsRepository();

  late FeedRequestModel _request = widget.request;
  List<RequestInterest> _people = const [];
  bool _loading = true;
  String? _errorMessage;

  /// Anything that makes the card behind this screen wrong: a new status, a
  /// chosen photographer, an edit. Viewing does not count.
  bool _changed = false;

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
      final people = await _repo.getRequestInterests(_request.id);
      if (!mounted) return;
      setState(() {
        _people = people;
        _loading = false;
      });
    } catch (e) {
      debugPrint('[ReviewPhotographers] load ERROR: $e');
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not load who answered this request.';
        _loading = false;
      });
    }
  }

  RequestInterest? get _selected {
    for (final person in _people) {
      if (person.selected) return person;
    }
    return null;
  }

  List<RequestInterest> get _pending =>
      [for (final p in _people) if (!p.viewed && !p.selected) p];

  List<RequestInterest> get _viewed =>
      [for (final p in _people) if (p.viewed && !p.selected) p];

  Future<void> _open(RequestInterest person) async {
    // Marked as looked at before the profile opens, so coming straight back
    // still moves them out of pending — the tap is the looking.
    unawaited(_markViewed(person));

    final chose = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RequestPhotographerPage(
          photographer: person,
          requestTitle: _request.title,
          alreadySelected: person.selected,
          onSelect: () => _select(person),
        ),
      ),
    );
    if (!mounted) return;
    // Either way the list has moved: viewed at least, selected at most.
    await _load();
    if (!mounted) return;
    if (chose == true) {
      AppSnackBar.success(context, '${person.name ?? 'Photographer'} selected.');
    }
  }

  Future<void> _markViewed(RequestInterest person) async {
    if (person.viewed) return;
    try {
      await _repo.markInterestViewed(_request.id, person.id);
    } catch (e) {
      debugPrint('[ReviewPhotographers] markViewed ERROR: $e');
    }
  }

  Future<bool> _select(RequestInterest person) async {
    try {
      await _repo.selectPhotographer(_request.id, person.id);
      _changed = true;
      return true;
    } catch (e) {
      debugPrint('[ReviewPhotographers] select ERROR: $e');
      if (mounted) {
        AppSnackBar.error(context, 'Could not select that photographer.');
      }
      return false;
    }
  }

  Future<void> _clearSelection() async {
    try {
      await _repo.clearSelection(_request.id);
      if (!mounted) return;
      setState(() {
        _request = _request.copyWith(status: 'open');
        _changed = true;
      });
      await _load();
      if (mounted) {
        AppSnackBar.success(context, 'Request is open to photographers again.');
      }
    } catch (e) {
      debugPrint('[ReviewPhotographers] clearSelection ERROR: $e');
      if (mounted) AppSnackBar.error(context, 'Could not undo that.');
    }
  }

  Future<void> _message(RequestInterest person) async {
    try {
      final room = await sl<GetOrCreateDirectRoomUseCase>().call(
        recipientId: person.id,
        recipientRole: ChatConfig.rolePhotographer,
        localDisplayName: person.name ?? 'Photographer',
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ChatRoomPage(room: room)),
      );
    } catch (e) {
      debugPrint('[ReviewPhotographers] message ERROR: $e');
      if (!mounted) return;
      final blocked = e is ServerException && e.message.contains('400');
      AppSnackBar.error(
        context,
        blocked
            ? 'This user is not accepting messages.'
            : 'Could not open the conversation.',
      );
    }
  }

  Future<void> _delete() async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete request?'),
        content: const Text(
          'This removes the request and everyone who answered it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (sure != true) return;
    try {
      await _repo.deleteRequest(_request.id);
      if (mounted) Navigator.of(context).pop(RequestOutcome.deleted);
    } catch (e) {
      debugPrint('[ReviewPhotographers] delete ERROR: $e');
      if (mounted) AppSnackBar.error(context, 'Could not delete this request.');
    }
  }

  Future<void> _edit() async {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => EditRequestSheet(
        request: _request,
        ext: ext,
        repo: _repo,
        onSave: (updated) {
          if (mounted) {
            setState(() {
              _request = updated;
              _changed = true;
            });
          }
        },
      ),
    );
  }

  Future<void> _close() async {
    try {
      await _repo.closeRequest(_request.id, status: 'closed');
      if (!mounted) return;
      setState(() {
        _request = _request.copyWith(status: 'closed');
        _changed = true;
      });
      AppSnackBar.success(context, 'Request closed.');
    } catch (e) {
      debugPrint('[ReviewPhotographers] close ERROR: $e');
      if (mounted) AppSnackBar.error(context, 'Could not close this request.');
    }
  }

  Future<void> _republish() async {
    try {
      final updated = await _repo.republishRequest(_request.id);
      if (!mounted) return;
      setState(() {
        _request = updated ?? _request.copyWith(status: 'open');
        _changed = true;
      });
      AppSnackBar.success(context, 'Request is back on the board.');
    } catch (e) {
      debugPrint('[ReviewPhotographers] republish ERROR: $e');
      if (mounted) AppSnackBar.error(context, 'Could not republish this.');
    }
  }

  void _leave() => Navigator.of(context).pop(
        _changed ? RequestOutcome.changed : RequestOutcome.unchanged,
      );

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final selected = _selected;
    // Expired counts as closed here: nobody can answer it, so editing it is
    // pointless and republishing is the only thing that helps.
    final closed = !_request.isLive;

    final page = Scaffold(
      backgroundColor: ext.homeBackground,
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        leading: kIsWeb
            ? null
            : AppBackButton(onPressed: _leave),
        title: Text(
          'Review Photographers',
          style: TextStyle(
            color: ext.greetingColor,
            fontWeight: FontWeight.w700,
            fontSize: 16.sp,
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: ext.greetingColor),
            onSelected: (value) {
              if (value == 'edit') _edit();
              if (value == 'close') _close();
              if (value == 'delete') _delete();
              if (value == 'republish') _republish();
              if (value == 'unselect') _clearSelection();
            },
            // Everything that used to sit behind the card's "Manage" button
            // lives here now, since the card itself opens this screen.
            itemBuilder: (_) => [
              if (!closed)
                const PopupMenuItem(
                  value: 'edit', child: Text('Edit request'),
                ),
              if (!closed)
                const PopupMenuItem(
                  value: 'close', child: Text('Close request'),
                ),
              // Only where the server would accept it — see canRepublish.
              if (_request.canRepublish && selected == null)
                const PopupMenuItem(
                  value: 'republish', child: Text('Republish request'),
                ),
              if (selected != null)
                const PopupMenuItem(
                  value: 'unselect', child: Text('Undo selection'),
                ),
              const PopupMenuItem(
                value: 'delete', child: Text('Delete request'),
              ),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              color: ext.accentGold,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.md.w, 0, AppSpacing.md.w, AppSpacing.xxl.h,
                ),
                children: [
                  _RequestCard(request: _request, ext: ext),
                  if (_errorMessage != null) ...[
                    SizedBox(height: AppSpacing.xl.h),
                    Center(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: ext.searchHintColor),
                      ),
                    ),
                  ],
                  if (selected != null) ...[
                    _SectionHeader(text: 'Your Selection', ext: ext),
                    _PersonTile(
                      person: selected,
                      ext: ext,
                      highlighted: true,
                      onTap: () => _open(selected),
                      // The whole point of choosing someone is being able to
                      // talk to them.
                      onMessage: () => _message(selected),
                    ),
                    if (_pending.isNotEmpty || _viewed.isNotEmpty)
                      _SectionHeader(text: 'All Requests', ext: ext),
                    for (final person in [..._pending, ..._viewed])
                      _PersonTile(
                        person: person,
                        ext: ext,
                        onTap: () => _open(person),
                      ),
                  ] else ...[
                    if (_pending.isNotEmpty)
                      _SectionHeader(text: 'Pending Requests', ext: ext),
                    for (final person in _pending)
                      _PersonTile(
                        person: person, ext: ext, onTap: () => _open(person),
                      ),
                    if (_viewed.isNotEmpty)
                      _SectionHeader(text: 'Viewed Requests', ext: ext),
                    for (final person in _viewed)
                      _PersonTile(
                        person: person, ext: ext, onTap: () => _open(person),
                      ),
                  ],
                  if (_people.isEmpty && _errorMessage == null) ...[
                    SizedBox(height: 80.h),
                    Center(
                      child: Text(
                        'No one has answered this request yet.',
                        style: TextStyle(
                          color: ext.searchHintColor, fontSize: 14.sp,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );

    // The system back gesture does not go through the app bar's button, and
    // popping with nothing would tell the list "unchanged" after a selection.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: webWrap(page, backgroundColor: ext.homeBackground),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request, required this.ext});

  final FeedRequestModel request;
  final AppThemeExtension ext;

  String get _meta {
    final parts = <String>[
      if (request.createdAt != null)
        '${request.createdAt!.day.toString().padLeft(2, '0')}.'
            '${request.createdAt!.month.toString().padLeft(2, '0')}.'
            '${request.createdAt!.year}',
      if (request.location.isNotEmpty) request.location,
    ];
    return parts.join(' | ');
  }

  @override
  Widget build(BuildContext context) {
    final active = request.isLive;
    return Container(
      margin: EdgeInsets.symmetric(vertical: AppSpacing.md.h),
      padding: EdgeInsets.all(AppSpacing.lg.w),
      decoration: BoxDecoration(
        color: ext.accentGold.withValues(alpha: 0.08),
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
                  _meta,
                  style: TextStyle(
                    color: ext.searchHintColor, fontSize: 12.sp,
                  ),
                ),
              ],
            ),
          ),
          Text(
            active
                ? 'Active'
                : (request.isExpired && request.status == 'open'
                    ? 'Expired'
                    : 'Closed'),
            style: TextStyle(
              color: active ? ext.accentGold : ext.searchHintColor,
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.text, required this.ext});

  final String text;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.xs.w, AppSpacing.md.h, 0, AppSpacing.sm.h,
        ),
        child: Text(
          text,
          style: TextStyle(
            color: ext.searchHintColor,
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
}

class _PersonTile extends StatelessWidget {
  const _PersonTile({
    required this.person,
    required this.ext,
    required this.onTap,
    this.highlighted = false,
    this.onMessage,
  });

  final RequestInterest person;
  final AppThemeExtension ext;
  final VoidCallback onTap;
  final bool highlighted;
  final VoidCallback? onMessage;

  String get _name => (person.name?.trim().isNotEmpty ?? false)
      ? person.name!.trim()
      : 'Photographer';

  String get _meta {
    final parts = <String>[
      if (person.location?.isNotEmpty ?? false) person.location!,
      '${compactCount(person.followerCount)} followers',
    ];
    return parts.join(' | ');
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$_name, $_meta',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          margin: EdgeInsets.only(bottom: AppSpacing.sm.h),
          padding: EdgeInsets.all(AppSpacing.md.w),
          decoration: BoxDecoration(
            color: ext.cardSurface,
            borderRadius: BorderRadius.circular(AppRadius.md.r),
            border: highlighted
                ? Border(left: BorderSide(color: ext.accentGold, width: 3))
                : null,
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
                    : Text(
                        _name[0].toUpperCase(),
                        style: TextStyle(color: ext.avatarForeground),
                      ),
              ),
              SizedBox(width: AppSpacing.md.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _name,
                      style: TextStyle(
                        color: ext.greetingColor,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            _meta,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: ext.searchHintColor, fontSize: 12.sp,
                            ),
                          ),
                        ),
                        if (person.rating != null) ...[
                          SizedBox(width: 6.w),
                          Icon(Icons.star_rounded,
                              size: 12.r, color: ext.accentGold),
                          Text(
                            person.rating!.toStringAsFixed(1),
                            style: TextStyle(
                              color: ext.searchHintColor, fontSize: 12.sp,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (onMessage != null)
                IconButton(
                  tooltip: 'Message',
                  icon: Icon(Icons.chat_bubble_outline_rounded,
                      size: 20.r, color: ext.accentGold),
                  onPressed: onMessage,
                )
              else
                Icon(Icons.chevron_right_rounded,
                    color: ext.searchHintColor, size: 20.r),
            ],
          ),
        ),
      ),
    );
  }
}
