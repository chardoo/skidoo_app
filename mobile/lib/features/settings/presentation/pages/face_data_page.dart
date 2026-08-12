import 'package:dio/dio.dart' as dio;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/api/dio_client_service.dart';
import 'package:jperg_app/core/common/widgets/app_button.dart';
import 'package:jperg_app/core/common/widgets/app_widgets.dart';
import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/utils/snackbar_utils.dart';
import 'package:jperg_app/core/utils/web_wrap.dart';
import 'package:jperg_app/features/settings/data/account_settings_api.dart';
import 'package:jperg_app/features/user_profile/presentation/pages/face_recognition_page.dart';
import 'package:jperg_app/services/auth_service.dart';

/// Your face data: what it is for, how to add it, and how to be rid of it.
///
/// The design drew a list of enrolled faces with dates and a bin beside each.
/// There is no such list to draw: a selfie is sent to the recognition service
/// and dropped — never stored here — and the service holds embeddings under
/// one person, with no handle for an individual face. Listing them would mean
/// keeping everybody's selfies, which is the opposite of what this screen is
/// for.
///
/// So it says what is true instead: whether this account has face data, how to
/// add or replace it, and one button to delete all of it.
class FaceDataPage extends StatefulWidget {
  const FaceDataPage({super.key, this.recognitionEnabled = true});

  /// When recognition is switched off there is nothing to manage, and adding
  /// a face would be adding one behind the person's own setting.
  final bool recognitionEnabled;

  @override
  State<FaceDataPage> createState() => _FaceDataPageState();
}

class _FaceDataPageState extends State<FaceDataPage> {
  final _api = AccountSettingsApi();

  AccountSettings _settings = const AccountSettings();
  bool _loading = true;
  bool _deleting = false;

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
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _addFace() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const FaceRecognitionPage()),
    );
    if (mounted) _load();
  }

  Future<void> _deleteAll() async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete your face data?'),
        content: const Text(
          'This permanently removes your face from recognition, so photos of '
          'you stop being found automatically. Photos already found stay in '
          'your list. You can add your face again at any time.',
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

    setState(() => _deleting = true);
    try {
      await sl<Api>().dio.delete('/client/face-data');
      await sl<AuthService>().setHasAddedFaces(false);
      if (!mounted) return;
      AppSnackBar.success(context, 'Your face data has been deleted.');
      _load();
    } on dio.DioException catch (_) {
      if (!mounted) return;
      AppSnackBar.error(
          context, 'Could not delete face data. Please try again.');
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
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
          'Face Data',
          style: TextStyle(
            color: ext.greetingColor,
            fontSize: 16.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: _loading
          ? const AppLoadingIndicator()
          : SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(AppSpacing.lg.w, AppSpacing.lg.h,
                  AppSpacing.lg.w, AppSpacing.xxxl.h),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 540),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Explainer(ext: ext),
                      SizedBox(height: AppSpacing.xl.h),
                      _Status(
                        hasFace: _settings.hasAddedFaces,
                        enabled: widget.recognitionEnabled,
                        ext: ext,
                      ),
                      SizedBox(height: AppSpacing.xxl.h),
                      if (widget.recognitionEnabled)
                        AppButton(
                          fullWidth: true,
                          borderRadius: AppRadius.pill,
                          label: _settings.hasAddedFaces
                              ? 'Add or replace face data'
                              : 'Add your face data',
                          onPressed: _addFace,
                        ),
                      if (_settings.hasAddedFaces) ...[
                        SizedBox(height: AppSpacing.lg.h),
                        // A text link, as the design draws it — not a second
                        // filled button competing with the one above it. The
                        // weight belongs to adding, not to deleting.
                        Center(
                          child: TextButton(
                            onPressed: _deleting ? null : _deleteAll,
                            child: Text(
                              _deleting ? 'Deleting…' : 'Delete all face data',
                              style: TextStyle(
                                color: const Color(0xFFB00020),
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.underline,
                                decorationColor: const Color(0xFFB00020),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
    );

    return webWrap(page, backgroundColor: ext.homeBackground);
  }
}

class _Explainer extends StatelessWidget {
  const _Explainer({required this.ext});
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.lg.w),
      decoration: BoxDecoration(
        color: ext.accentGold.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.lg.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Face Data Management',
            style: TextStyle(
              color: ext.greetingColor,
              fontSize: 15.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: AppSpacing.sm.h),
          Text(
            'Your face data is used to find photos of you automatically. The '
            'selfies you add are used to recognise you and are not stored — '
            'only the measurements taken from them are kept, and you can '
            'delete those at any time.',
            style: TextStyle(
              color: ext.searchHintColor,
              fontSize: 13.sp,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _Status extends StatelessWidget {
  const _Status({
    required this.hasFace,
    required this.enabled,
    required this.ext,
  });

  final bool hasFace;
  final bool enabled;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    final (icon, text) = switch ((enabled, hasFace)) {
      (false, _) => (
          Icons.no_photography_outlined,
          'Face recognition is switched off for this account. Turn it back on '
              'in Privacy to add your face.',
        ),
      (true, true) => (
          Icons.verified_user_outlined,
          'Your face is enrolled. Photos of you are found automatically.',
        ),
      (true, false) => (
          Icons.person_search_outlined,
          'No face data yet. Add it and we will start finding photos of you.',
        ),
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20.sp, color: ext.searchHintColor),
        SizedBox(width: AppSpacing.md.w),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: ext.greetingColor,
              fontSize: 14.sp,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
