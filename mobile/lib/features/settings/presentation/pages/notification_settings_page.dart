import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/common/widgets/app_widgets.dart';
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/utils/snackbar_utils.dart';
import 'package:jperg_app/core/utils/web_wrap.dart';
import 'package:jperg_app/features/notifications/data/notification_service.dart';
import 'package:jperg_app/features/settings/presentation/widgets/settings_section.dart';
import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/services/notification_prefs_service.dart';
import 'package:jperg_app/services/push_notification_service.dart';

/// What may interrupt you, and what may not.
///
/// The master switch at the top is the device's own: it is an "not right now"
/// that should work with no signal and should not follow you onto another
/// phone. Everything under it is the account's, so muting likes on one device
/// mutes them everywhere — which is what somebody means by it.
///
/// Each row governs one notification kind. Likes, comments and follows used to
/// be a single `social` column on the server, so switching one off silenced
/// the other two; they have a column each now.
class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  final _api = NotificationPreferencesApi();

  NotificationPreferences _prefs = const NotificationPreferences();
  bool _pushOn = true;
  bool _loading = true;
  String? _error;

  /// Which row is waiting on the server. One at a time is enough — a person
  /// flipping two switches in the same half-second is not the case to design
  /// for, and this keeps the row from flicking back before it settles.
  String? _saving;

  @override
  void initState() {
    super.initState();
    final cached = NotificationPreferencesApi.cached;
    if (cached != null) {
      _prefs = cached;
      _loading = false;
    }
    _load();
  }

  Future<void> _load() async {
    // The master switch is this device's and needs nothing from the server, so
    // it is read first and kept whatever happens next. A screen that refuses
    // to draw because a request failed also refuses to let anybody turn push
    // off, which is the one thing they can do with no signal.
    final muted = sl<NotificationPrefsService>().isMuted;
    if (!mounted) return;
    setState(() => _pushOn = !muted);

    // ...but the preference is only half of it. The OS has the final say, and
    // a switch reading "on" for an app the system will not let post anything
    // is the one state where nothing arrives and nothing explains why. Asked
    // after the first paint so the switch does not flicker on a cold open.
    final allowed = await PushNotificationService.instance.hasPermission();
    if (mounted && !allowed && _pushOn) setState(() => _pushOn = false);

    // Heal devices that turned push off before the switch did anything about
    // it. Until now it wrote `notifications_muted` and nothing else, so those
    // devices are still opted in at OneSignal and still receiving — the switch
    // reads off and the notifications keep coming. Re-asserting the stored
    // preference here is what closes that for someone who already flipped it;
    // the write is idempotent, so doing it on every open costs nothing.
    await PushNotificationService.instance.setSubscribed(!muted);

    try {
      final prefs = await _api.fetch();
      if (!mounted) return;
      setState(() {
        _prefs = prefs;
        _loading = false;
        _error = null;
      });
    } catch (e, stack) {
      if (!mounted) return;
      // Everything, not just Exceptions. An Error — a bad cast, a missing key
      // on something that was not a map — is exactly the failure a screen is
      // least likely to have anticipated, and `e is Exception` sent every one
      // of those to a sentence that named nothing.
      debugPrint('[NotificationSettings] load failed: $e\n$stack');
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  Future<void> _setCategory(String key, bool value) async {
    setState(() => _saving = key);
    try {
      final updated = await _api.update(key, value);
      if (!mounted) return;
      setState(() => _prefs = updated);
    } catch (e, stack) {
      if (!mounted) return;
      debugPrint('[NotificationSettings] save $key failed: $e\n$stack');
      AppSnackBar.error(context, '$e');
    } finally {
      if (mounted) setState(() => _saving = null);
    }
  }

  Future<void> _setPush(bool on) async {
    if (on) {
      // Ask the OS before storing anything. Turning this on used to write a
      // preference and stop there, so someone who had never been shown the
      // permission dialog — or had declined it once — flipped the switch, saw
      // it stay on, and never received a notification again.
      final allowed = await PushNotificationService.instance.ensurePermission();
      if (!mounted) return;
      if (!allowed) {
        // The switch stays off because the system says so. requestPermission
        // opens system settings when the OS will no longer show its dialog, so
        // there is somewhere to go — the message says where.
        setState(() => _pushOn = false);
        AppSnackBar.error(
          context,
          'Notifications are turned off for Jperg in your device settings. '
          'Allow them there to switch this on.',
        );
        return;
      }
    }

    // The part that actually stops them arriving. The preference below is read
    // only by the chat code, so writing it alone left every server-sent push
    // coming through a switch that said it would not.
    await PushNotificationService.instance.setSubscribed(on);

    // Local, and applied immediately: there is no request to fail and nothing
    // to reconcile with another device.
    await sl<NotificationPrefsService>().setMuted(!on);
    if (mounted) setState(() => _pushOn = on);
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
        title: Text(
          'Notifications',
          style: TextStyle(
            color: ext.greetingColor,
            fontSize: 16.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: _buildBody(ext),
    );

    return webWrap(page, backgroundColor: ext.homeBackground);
  }

  Widget _buildBody(AppThemeExtension ext) {
    if (_loading) return const AppLoadingIndicator();

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
          AppSpacing.lg.w, AppSpacing.md.h, AppSpacing.lg.w, AppSpacing.xxxl.h),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Dimmed rather than hidden while push is off: the settings are
              // still what they are, and hiding them would make turning push
              // back on feel like it reset them. The master switch stays live
              // above the dimming — it is the way back.
              SettingsSection(
                title: 'Push notifications',
                trailing: Switch.adaptive(
                  value: _pushOn,
                  onChanged: _setPush,
                ),
                children: const [],
              ),
              // Failed to load: say so where the missing switches would have
              // been, with a way to try again — rather than replacing the
              // whole screen, master switch included.
              if (_error != null)
                _CouldNotLoad(
                  message: _error!,
                  onRetry: () {
                    setState(() {
                      _loading = true;
                      _error = null;
                    });
                    _load();
                  },
                  ext: ext,
                )
              else
                Opacity(
                  opacity: _pushOn ? 1 : 0.45,
                  child: IgnorePointer(
                    ignoring: !_pushOn,
                    child: SettingsSection(
                      children: [
                        _row('likes', 'Likes', 'Likes on photos of you'),
                        _row('comments', 'Comments',
                            'Comments on photos of you'),
                        // No second line, as the design draws it: the label
                        // says the whole thing.
                        _row('follows', 'New Followers', null),
                        _row('photos', 'Photo Matches',
                            'Public photo appearances'),
                        _row('chat', 'Message', 'New message notifications'),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  SettingsRow _row(String key, String label, String? subtitle) => SettingsRow(
        label: label,
        subtitle: subtitle,
        value: _prefs.byName(key),
        isBusy: _saving == key,
        onChanged: (value) => _setCategory(key, value),
      );
}

/// The per-kind switches could not be fetched. Says which failure it was and
/// offers another go, in the space those switches would have filled.
class _CouldNotLoad extends StatelessWidget {
  const _CouldNotLoad({
    required this.message,
    required this.onRetry,
    required this.ext,
  });

  final String message;
  final VoidCallback onRetry;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.lg.w),
      decoration: BoxDecoration(
        color: ext.cardSurface,
        borderRadius: BorderRadius.circular(AppRadius.lg.r),
        border: Border.all(
            color: ext.searchHintColor.withValues(alpha: 0.12), width: 0.5),
      ),
      child: Column(
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: ext.searchHintColor,
              fontSize: 13.sp,
              height: 1.4,
            ),
          ),
          SizedBox(height: AppSpacing.md.h),
          TextButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}
