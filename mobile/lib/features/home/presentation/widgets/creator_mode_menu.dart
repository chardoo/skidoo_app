import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:jperg_app/core/common/widgets/user_avatar.dart';
import 'package:jperg_app/core/config/app_links_config.dart';
import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/utils/snackbar_utils.dart';
import 'package:jperg_app/services/auth_service.dart';

/// The photographer's avatar in the feed top bar, opening the mode menu.
///
/// Photographers use the same feed as everyone else — this is how they get from
/// it to the half of their account that lives on the web. Only they see it: for
/// a client there is no second mode to switch to, so the control would open a
/// menu with one disabled row in it.
///
/// Renders nothing at all until the role is known, rather than a placeholder
/// that pops into a different shape a frame later.
class CreatorModeMenu extends StatefulWidget {
  const CreatorModeMenu({
    super.key,
    required this.overSolidBackground,
    this.size = 32,
  });

  /// Whether the bar is on the page's own background rather than over media.
  /// The chevron follows the other chrome — white over a photo, themed on the
  /// solid page — while the menu itself is dark either way, as designed.
  final bool overSolidBackground;

  final double size;

  @override
  State<CreatorModeMenu> createState() => _CreatorModeMenuState();
}

class _CreatorModeMenuState extends State<CreatorModeMenu> {
  /// Held rather than re-read on every build: this sits in the feed's top bar,
  /// which rebuilds on scroll and on every tab change.
  late final Future<_CreatorIdentity> _identity = _load();

  Future<_CreatorIdentity> _load() async {
    final auth = sl<AuthService>();
    final results = await Future.wait([auth.getRole(), auth.getProfileUrl()]);
    return _CreatorIdentity(role: results[0], imageUrl: results[1]);
  }

  Future<void> _openMenu() async {
    final choice = await _showCreatorModeMenu(context, anchor: context);
    if (choice != _CreatorModeChoice.dashboard || !mounted) return;

    final opened = await launchUrl(
      Uri.parse(AppLinksConfig.creatorDashboardUrl),
      mode: LaunchMode.externalApplication,
      // Web: same tab, matching the sidebar's own creator link.
      webOnlyWindowName: '_self',
    );
    if (!opened && mounted) {
      AppSnackBar.error(context, 'Could not open the creator dashboard.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return FutureBuilder<_CreatorIdentity>(
      future: _identity,
      builder: (context, snapshot) {
        final identity = snapshot.data;
        if (identity == null || !identity.isPhotographer) {
          return const SizedBox.shrink();
        }

        return Semantics(
          button: true,
          label: 'Switch mode',
          child: GestureDetector(
            onTap: _openMenu,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: EdgeInsets.only(left: AppSpacing.sm.w),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  UserAvatar(
                    imageUrl:
                        identity.imageUrl.isEmpty ? null : identity.imageUrl,
                    initial: '',
                    radius: widget.size / 2,
                  ),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 18.sp,
                    color: widget.overSolidBackground
                        ? ext.greetingColor
                        : Colors.white,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CreatorIdentity {
  const _CreatorIdentity({required this.role, required this.imageUrl});

  final String role;
  final String imageUrl;

  bool get isPhotographer => role == 'photographer';
}

enum _CreatorModeChoice { explorer, dashboard }

/// Opens the mode menu directly under the avatar and returns what was picked.
///
/// A hand-positioned overlay rather than PopupMenuButton: the design's menu is
/// dark on both themes, right-aligned to the avatar, and carries a trailing
/// glyph per row — all of which is fighting the Material menu's own theming
/// rather than using it.
Future<_CreatorModeChoice?> _showCreatorModeMenu(
  BuildContext context, {
  required BuildContext anchor,
}) {
  final box = anchor.findRenderObject() as RenderBox?;
  final overlay =
      Navigator.of(context).overlay!.context.findRenderObject() as RenderBox?;
  if (box == null || overlay == null) return Future.value(null);

  final topRight = box.localToGlobal(
    box.size.topRight(Offset.zero),
    ancestor: overlay,
  );

  return showDialog<_CreatorModeChoice>(
    context: context,
    barrierColor: Colors.transparent,
    // Dismissed by tapping anywhere off it, like the menu it imitates.
    barrierDismissible: true,
    builder: (dialogContext) => Stack(
      children: [
        Positioned(
          top: topRight.dy + 10,
          // Right-aligned to the avatar: the menu is wider than the control, so
          // pinning the left edge would push it off the screen.
          right: overlay.size.width - topRight.dx,
          child: const _CreatorModeSheet(),
        ),
      ],
    ),
  );
}

class _CreatorModeSheet extends StatelessWidget {
  const _CreatorModeSheet();

  /// Dark on both themes, as designed — it belongs to the media surface it
  /// opens over, not to the page.
  static const _surface = Color(0xFF1C1C1E);

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 210.w,
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(AppRadius.md.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _MenuRow(
              label: 'Explorer',
              // The mode they are already in — ticked, not a destination.
              trailing: Icon(Icons.check_rounded,
                  size: 18.sp, color: ext.accentGold),
              onTap: () => Navigator.of(context).pop(_CreatorModeChoice.explorer),
            ),
            Divider(
              height: 1,
              thickness: 1,
              color: Colors.white.withValues(alpha: 0.10),
            ),
            _MenuRow(
              label: 'Creator Dashboard',
              // Leaves the app — say so before the tap, not after.
              trailing: Icon(Icons.open_in_new_rounded,
                  size: 16.sp, color: Colors.white70),
              onTap: () =>
                  Navigator.of(context).pop(_CreatorModeChoice.dashboard),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.label,
    required this.trailing,
    required this.onTap,
  });

  final String label;
  final Widget trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.md.w, vertical: 14.h),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            SizedBox(width: AppSpacing.sm.w),
            trailing,
          ],
        ),
      ),
    );
  }
}
