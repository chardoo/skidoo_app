import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/common/widgets/app_widgets.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/utils/snackbar_utils.dart';
import 'package:jperg_app/core/utils/web_wrap.dart';
import 'package:jperg_app/features/settings/data/account_settings_api.dart';
import 'package:jperg_app/features/settings/presentation/pages/face_data_page.dart';
import 'package:jperg_app/features/settings/presentation/widgets/settings_section.dart';
import 'package:jperg_app/features/user_profile/presentation/bloc/user_profile_bloc.dart';

/// Who can see you, and what the app is allowed to work out about you.
///
/// Three groups from two services, which is not visible here and does not need
/// to be: anonymous comments and hiding your profile belong to chat, face
/// recognition and usage data to main.
class PrivacySettingsPage extends StatefulWidget {
  const PrivacySettingsPage({super.key});

  @override
  State<PrivacySettingsPage> createState() => _PrivacySettingsPageState();
}

class _PrivacySettingsPageState extends State<PrivacySettingsPage> {
  final _api = AccountSettingsApi();

  AccountSettings _settings = const AccountSettings();
  bool _loading = true;
  String? _error;
  String? _saving;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final settings = await _api.fetch();
      if (!mounted) return;
      setState(() {
        _settings = settings;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load your privacy settings.';
      });
    }
  }

  Future<void> _set(String key, bool value) async {
    setState(() => _saving = key);
    try {
      final updated = await _api.update(key, value);
      if (!mounted) return;
      setState(() => _settings = updated);
    } catch (e) {
      if (!mounted) return;
      // The server refuses rather than lying when it cannot make a switch
      // true — turning recognition off while the recognition service is down,
      // for one — so its message is the one worth showing.
      AppSnackBar.error(context,
          e is Exception ? '$e'.replaceFirst('Exception: ', '') : '$e');
    } finally {
      if (mounted) setState(() => _saving = null);
    }
  }

  Future<void> _confirmFaceRecognitionOff() async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Turn off face recognition?'),
        content: const Text(
          'Your face data is deleted, and photos of you stop being found '
          'automatically. You can turn it back on and add your face again '
          'whenever you like.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Turn off'),
          ),
        ],
      ),
    );
    if (sure == true) await _set('face_recognition_enabled', false);
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
          'Privacy',
          style: TextStyle(
            color: ext.greetingColor,
            fontSize: 16.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: _buildBody(),
    );

    return webWrap(page, backgroundColor: ext.homeBackground);
  }

  Widget _buildBody() {
    if (_loading) return const AppLoadingIndicator();
    if (_error != null) {
      return AppErrorView(
        message: _error!,
        onRetry: () {
          setState(() {
            _loading = true;
            _error = null;
          });
          _load();
        },
      );
    }

    return BlocBuilder<UserProfileBloc, UserProfileState>(
      builder: (context, profile) {
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(AppSpacing.lg.w, AppSpacing.md.h,
              AppSpacing.lg.w, AppSpacing.xxxl.h),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SettingsSection(
                    title: 'Account & safety',
                    children: [
                      SettingsRow(
                        label: 'Anonymous Comments',
                        subtitle: 'Your name is hidden when you comment',
                        value: profile.anonymousMode,
                        isBusy: profile.isAnonymousModeUpdating,
                        onChanged: (v) => context
                            .read<UserProfileBloc>()
                            .add(AnonymousModeToggled(v)),
                      ),
                      SettingsRow(
                        label: 'Hide profile',
                        subtitle: 'Your profile is hidden from the public',
                        value: profile.hideProfile,
                        isBusy: profile.isHideProfileUpdating,
                        onChanged: (v) => context
                            .read<UserProfileBloc>()
                            .add(HideProfileToggled(v)),
                      ),
                    ],
                  ),
                  SettingsSection(
                    title: 'Photo & recognition',
                    children: [
                      SettingsRow(
                        label: 'Allow Face Recognition',
                        subtitle:
                            'Let us scan and group your face automatically',
                        value: _settings.faceRecognitionEnabled,
                        isBusy: _saving == 'face_recognition_enabled',
                        // Off is destructive — it deletes the face data — so
                        // it is asked about. On is not, so it just happens.
                        onChanged: (on) => on
                            ? _set('face_recognition_enabled', true)
                            : _confirmFaceRecognitionOff(),
                      ),
                      SettingsRow(
                        label: 'Manage Face Data',
                        subtitle: _settings.hasAddedFaces
                            ? 'Add or remove your face data'
                            : 'No face data on this account',
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => FaceDataPage(
                                recognitionEnabled:
                                    _settings.faceRecognitionEnabled,
                              ),
                            ),
                          );
                          // Face data may have been deleted while in there.
                          if (mounted) _load();
                        },
                      ),
                    ],
                  ),
                  SettingsSection(
                    title: 'Diagnostic analytics',
                    children: [
                      SettingsRow(
                        label: 'Share Usage Data',
                        subtitle:
                            'Help us improve by sharing anonymized analytics',
                        value: _settings.shareUsageData,
                        isBusy: _saving == 'share_usage_data',
                        onChanged: (v) => _set('share_usage_data', v),
                      ),
                    ],
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
