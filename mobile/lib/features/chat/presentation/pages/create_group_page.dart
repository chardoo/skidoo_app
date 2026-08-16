import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:jperg_app/core/common/widgets/app_section_label.dart';
import 'package:jperg_app/core/common/widgets/search_field.dart';
import 'package:jperg_app/core/common/widgets/user_avatar.dart';
import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/validators/media_validator.dart';
import 'package:jperg_app/core/utils/snackbar_utils.dart';
import 'package:jperg_app/core/utils/web_panel_route.dart';
import 'package:jperg_app/core/utils/web_wrap.dart';
import 'package:jperg_app/core/widgets/jperg_image.dart';
import 'package:jperg_app/features/chat/data/datasources/chat_media_limits.dart';
import 'package:jperg_app/features/chat/data/datasources/user_search_data_source.dart';
import 'package:jperg_app/features/chat/domain/usecases/chat_usecases.dart';
import 'package:jperg_app/features/chat/presentation/chat_error_text.dart';
import 'package:jperg_app/models/chat/chat_room.dart';
import 'package:jperg_app/models/chat/shareable_user.dart';

/// Step one of creating a group: choose who is in it.
///
/// Split from naming the group because the designs treat them as two screens,
/// and because it matches what the two steps actually are — picking people is a
/// search-and-select task, naming is a form. Pops the created [ChatRoom].
class CreateGroupPage extends StatefulWidget {
  const CreateGroupPage({super.key});

  @override
  State<CreateGroupPage> createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends State<CreateGroupPage> {
  final _searchController = TextEditingController();
  final _userSearch = sl<UserSearchDataSource>();

  List<ShareableUser> _results = [];
  final List<ShareableUser> _selected = [];
  bool _isSearching = false;
  Timer? _debounce;

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _isSearching = false;
      });
      return;
    }
    setState(() => _isSearching = true);
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(query));
  }

  Future<void> _search(String query) async {
    final page = await _userSearch.search(query.trim());
    if (!mounted || query != _searchController.text) return;
    setState(() {
      _results = page.users;
      _isSearching = false;
    });
  }

  void _toggle(ShareableUser user) {
    setState(() {
      final index = _selected.indexWhere((u) => u.id == user.id);
      if (index >= 0) {
        _selected.removeAt(index);
      } else {
        _selected.add(user);
      }
    });
  }

  Future<void> _next() async {
    // Panel-shaped on web so step two stays inside the messages column instead
    // of covering the app; a plain full-screen push on every other platform.
    final room = await showWebPanelPage<ChatRoom>(
      context,
      _GroupNamePage(members: List.of(_selected)),
    );
    if (room != null && mounted) Navigator.of(context).pop(room);
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    final page = Scaffold(
      backgroundColor: ext.homeBackground,
      appBar: AppBar(
        backgroundColor: ext.homeBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        leadingWidth: 84.w,
        leading: TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: TextStyle(color: ext.searchHintColor, fontSize: 15.sp),
          ),
        ),
        title: Text(
          'Add Members',
          style: TextStyle(
            color: ext.greetingColor,
            fontWeight: FontWeight.bold,
            fontSize: 17.sp,
          ),
        ),
        actions: [
          TextButton(
            // A group of one is a DM; the New Chat screen already does those.
            onPressed: _selected.isEmpty ? null : _next,
            child: Text(
              'Next',
              style: TextStyle(
                color: _selected.isEmpty
                    ? ext.searchHintColor.withValues(alpha: 0.5)
                    : ext.accentGold,
                fontSize: 15.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(AppSpacing.md.w, AppSpacing.sm.h,
                    AppSpacing.md.w, AppSpacing.sm.h),
                child: SearchField(
                  controller: _searchController,
                  hint: 'Search for people',
                  onChanged: _onSearchChanged,
                  onClear: () {
                    _searchController.clear();
                    _onSearchChanged('');
                  },
                ),
              ),

              if (_selected.isNotEmpty)
                _SelectedStrip(users: _selected, onRemove: _toggle),

              Expanded(child: _buildResults(ext)),
            ],
          ),
        ),
      ),
    );
    return webWrap(page, backgroundColor: ext.homeBackground);
  }

  Widget _buildResults(AppThemeExtension ext) {
    if (_isSearching) {
      return Center(
        child: SizedBox(
          width: 22.w,
          height: 22.w,
          child:
              CircularProgressIndicator(color: ext.accentGold, strokeWidth: 2),
        ),
      );
    }

    if (_results.isEmpty) {
      return Center(
        child: Text(
          _searchController.text.trim().isEmpty
              ? 'Search for people to add'
              : 'No users found.',
          style: TextStyle(color: ext.searchHintColor, fontSize: 14.sp),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.only(bottom: AppSpacing.xxl.h),
      itemCount: _results.length + 1,
      itemBuilder: (_, index) {
        if (index == 0) {
          return AppSectionLabel(
            'Users',
            padding: EdgeInsets.fromLTRB(AppSpacing.lg.w, AppSpacing.sm.h,
                AppSpacing.lg.w, AppSpacing.xs.h),
          );
        }
        final user = _results[index - 1];
        return _SelectableUserRow(
          user: user,
          selected: _selected.any((u) => u.id == user.id),
          onTap: () => _toggle(user),
        );
      },
    );
  }
}

/// Horizontal strip of who's been picked so far, each removable.
class _SelectedStrip extends StatelessWidget {
  const _SelectedStrip({required this.users, required this.onRemove});

  final List<ShareableUser> users;
  final ValueChanged<ShareableUser> onRemove;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: AppSpacing.md.w),
      padding: EdgeInsets.symmetric(vertical: AppSpacing.md.h),
      decoration: BoxDecoration(
        color: ext.accentGold.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.lg.r),
      ),
      child: SizedBox(
        height: 76.h,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.md.w),
          itemCount: users.length,
          separatorBuilder: (_, __) => SizedBox(width: AppSpacing.md.w),
          itemBuilder: (_, i) {
            final user = users[i];
            return SizedBox(
              width: 56.w,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      UserAvatar(
                        imageUrl: user.imageUrl,
                        initial: user.name,
                        radius: 22,
                      ),
                      Positioned(
                        top: -2,
                        right: -2,
                        child: Semantics(
                          button: true,
                          label: 'Remove ${user.name}',
                          child: GestureDetector(
                            onTap: () => onRemove(user),
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: ext.cardSurface,
                              ),
                              padding: EdgeInsets.all(1.w),
                              child: Icon(Icons.cancel,
                                  size: 16.sp, color: ext.searchHintColor),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    _firstName(user.name),
                    style:
                        TextStyle(color: ext.greetingColor, fontSize: 11.sp),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  static String _firstName(String full) {
    final trimmed = full.trim();
    if (trimmed.isEmpty) return '';
    final space = trimmed.indexOf(' ');
    return space == -1 ? trimmed : trimmed.substring(0, space);
  }
}

class _SelectableUserRow extends StatelessWidget {
  const _SelectableUserRow({
    required this.user,
    required this.selected,
    required this.onTap,
  });

  final ShareableUser user;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return Semantics(
      selected: selected,
      button: true,
      label: user.name,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.lg.w, vertical: 10.h),
          child: Row(
            children: [
              UserAvatar(
                imageUrl: user.imageUrl,
                initial: user.name,
                radius: 18,
              ),
              SizedBox(width: AppSpacing.md.w),
              Expanded(
                child: Text(
                  user.name,
                  style: TextStyle(color: ext.greetingColor, fontSize: 15.sp),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (selected)
                Icon(Icons.check_circle, color: ext.accentGold, size: 22.sp)
              else
                Icon(Icons.circle_outlined,
                    color: ext.searchHintColor.withValues(alpha: 0.5),
                    size: 22.sp),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Step two: name the group ──────────────────────────────────────────────────

class _GroupNamePage extends StatefulWidget {
  const _GroupNamePage({required this.members});
  final List<ShareableUser> members;

  @override
  State<_GroupNamePage> createState() => _GroupNamePageState();
}

class _GroupNamePageState extends State<_GroupNamePage> {
  final _nameController = TextEditingController();
  final _createGroup = sl<CreateGroupRoomUseCase>();
  final _uploadImage = sl<UploadChatImageUseCase>();

  String? _localPhotoPath;
  String? _uploadedPhotoUrl;
  bool _isUploadingPhoto = false;
  bool _isCreating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // The Create button enables as soon as there is a name.
    _nameController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    final limits = await sl<ChatMediaLimitsService>().get();
    final error = await MediaValidator.validate(picked,
        isVideo: false, maxBytes: limits.maxImageBytes);
    if (!mounted) return;
    if (error != null) {
      AppSnackBar.error(context, error);
      return;
    }

    setState(() {
      _localPhotoPath = picked.path;
      _isUploadingPhoto = true;
    });

    // Uploaded now rather than at create time so a slow upload happens while
    // the user is still typing the name, and so a failure is reported here
    // where it can be retried — not as part of creating the group.
    try {
      final url = await _uploadImage(File(picked.path), mimeType: picked.mimeType);
      if (!mounted) return;
      setState(() {
        _uploadedPhotoUrl = url;
        _isUploadingPhoto = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _localPhotoPath = null;
        _isUploadingPhoto = false;
      });
      AppSnackBar.error(context, uploadErrorText(e, isVideo: false));
    }
  }

  Future<void> _create() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Group name is required.');
      return;
    }

    setState(() {
      _isCreating = true;
      _error = null;
    });

    try {
      final room = await _createGroup(
        name: name,
        imageUrl: _uploadedPhotoUrl,
        inviteeIds: [for (final u in widget.members) u.id],
        // Fallbacks for anyone the server can't resolve itself.
        inviteeNames: {
          for (final u in widget.members)
            if (u.name.trim().isNotEmpty) u.id: u.name.trim(),
        },
        inviteeImages: {
          for (final u in widget.members)
            if ((u.imageUrl ?? '').isNotEmpty) u.id: u.imageUrl!,
        },
      );
      if (!mounted) return;
      Navigator.of(context).pop(room);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isCreating = false;
        _error = 'Could not create group. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final canCreate = _nameController.text.trim().isNotEmpty &&
        !_isCreating &&
        !_isUploadingPhoto;

    final page = Scaffold(
      backgroundColor: ext.homeBackground,
      appBar: AppBar(
        backgroundColor: ext.homeBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded,
              color: ext.greetingColor, size: 22.sp),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Group Name',
          style: TextStyle(
            color: ext.greetingColor,
            fontWeight: FontWeight.bold,
            fontSize: 17.sp,
          ),
        ),
        actions: [
          TextButton(
            onPressed: canCreate ? _create : null,
            child: _isCreating
                ? SizedBox(
                    width: 18.w,
                    height: 18.w,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: ext.accentGold),
                  )
                : Text(
                    'Create',
                    style: TextStyle(
                      color: canCreate
                          ? ext.accentGold
                          : ext.searchHintColor.withValues(alpha: 0.5),
                      fontWeight: FontWeight.bold,
                      fontSize: 15.sp,
                    ),
                  ),
          ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.lg.w, vertical: AppSpacing.lg.h),
            children: [
              Center(
                child: _PhotoPicker(
                  localPath: _localPhotoPath,
                  isUploading: _isUploadingPhoto,
                  onTap: _pickPhoto,
                ),
              ),
              SizedBox(height: AppSpacing.xxl.h),

              const AppSectionLabel('Group name'),
              SizedBox(height: AppSpacing.sm.h),
              TextField(
                controller: _nameController,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                style: TextStyle(color: ext.greetingColor, fontSize: 15.sp),
                decoration: InputDecoration(
                  hintText: 'Enter a group name',
                  hintStyle:
                      TextStyle(color: ext.searchHintColor, fontSize: 15.sp),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.md.w, vertical: 14.h),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md.r),
                    borderSide: BorderSide(
                        color: ext.searchHintColor.withValues(alpha: 0.3)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md.r),
                    borderSide: BorderSide(
                        color: ext.searchHintColor.withValues(alpha: 0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md.r),
                    borderSide: BorderSide(color: ext.accentGold),
                  ),
                ),
              ),

              if (_error != null) ...[
                SizedBox(height: AppSpacing.sm.h),
                Text(_error!,
                    style: TextStyle(color: ext.errorRed, fontSize: 12.sp)),
              ],

              SizedBox(height: AppSpacing.xl.h),
              AppSectionLabel(
                  'Pending group members (${widget.members.length})'),
              SizedBox(height: AppSpacing.sm.h),
              _MembersSummary(members: widget.members),
            ],
          ),
        ),
      ),
    );
    return webWrap(page, backgroundColor: ext.homeBackground);
  }
}

class _PhotoPicker extends StatelessWidget {
  const _PhotoPicker({
    required this.localPath,
    required this.isUploading,
    required this.onTap,
  });

  final String? localPath;
  final bool isUploading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    const size = 110.0;

    return Semantics(
      button: true,
      label: localPath == null ? 'Add group photo' : 'Change group photo',
      child: GestureDetector(
        onTap: isUploading ? null : onTap,
        child: SizedBox(
          width: size.w,
          height: size.w,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (localPath != null)
                ClipOval(
                  child: kIsWeb
                      ? JpergImage(
                          imageUrl: localPath!,
                          width: size,
                          height: size,
                          fit: BoxFit.cover,
                        )
                      : Image.file(File(localPath!), fit: BoxFit.cover),
                )
              else
                _DashedCircle(size: size, ext: ext),
              if (isUploading)
                ClipOval(
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: 0.35),
                    child: Center(
                      child: SizedBox(
                        width: 22.w,
                        height: 22.w,
                        child: const CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedCircle extends StatelessWidget {
  const _DashedCircle({required this.size, required this.ext});
  final double size;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedCirclePainter(color: ext.accentGold),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: ext.accentGold.withValues(alpha: 0.10),
        ),
        alignment: Alignment.center,
        child: Text(
          'Add Photo',
          style: TextStyle(
            color: ext.accentGold,
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// Dashed ring around the empty photo slot. Painted rather than assembled from
/// widgets because Flutter has no dashed border style.
class _DashedCirclePainter extends CustomPainter {
  const _DashedCirclePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    final radius = size.width / 2;
    final center = Offset(radius, radius);
    const dash = 0.09; // radians drawn
    const gap = 0.055; // radians skipped

    for (double a = 0; a < 6.28318; a += dash + gap) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - 1),
        a,
        dash,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashedCirclePainter old) => old.color != color;
}

/// "Sarah, Michael and 3 others" over a stack of their faces.
class _MembersSummary extends StatelessWidget {
  const _MembersSummary({required this.members});
  final List<ShareableUser> members;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    const maxFaces = 3;
    final faces = members.take(maxFaces).toList();

    return Container(
      padding: EdgeInsets.all(AppSpacing.md.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md.r),
        border:
            Border.all(color: ext.searchHintColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          SizedBox(
            // Overlapped faces: each after the first is inset by 20, so the
            // row is one avatar wide plus the visible sliver of each extra.
            width: (28 + (faces.length - 1) * 20).toDouble().w,
            height: 34.w,
            child: Stack(
              children: [
                for (int i = 0; i < faces.length; i++)
                  Positioned(
                    left: (i * 20).toDouble().w,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: ext.homeBackground, width: 2),
                      ),
                      child: UserAvatar(
                        imageUrl: faces[i].imageUrl,
                        initial: faces[i].name,
                        radius: 15,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(width: AppSpacing.md.w),
          Expanded(
            child: Text(
              _summary(),
              style: TextStyle(color: ext.greetingColor, fontSize: 14.sp),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _summary() {
    final names = [
      for (final m in members)
        if (m.name.trim().isNotEmpty) _firstName(m.name),
    ];
    if (names.isEmpty) return '${members.length} people';
    if (names.length == 1) return names.first;
    if (names.length == 2) return '${names[0]} and ${names[1]}';
    final rest = names.length - 2;
    return '${names[0]}, ${names[1]} and $rest '
        '${rest == 1 ? 'other' : 'others'}';
  }

  static String _firstName(String full) {
    final trimmed = full.trim();
    final space = trimmed.indexOf(' ');
    return space == -1 ? trimmed : trimmed.substring(0, space);
  }
}
