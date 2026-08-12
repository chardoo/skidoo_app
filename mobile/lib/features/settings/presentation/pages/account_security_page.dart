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
import 'package:jperg_app/features/photographers/presentation/pages/portfolio_edit_page.dart';
import 'package:jperg_app/core/utils/web_wrap.dart';
import 'package:jperg_app/features/settings/data/account_settings_api.dart';
import 'package:jperg_app/features/settings/presentation/widgets/settings_section.dart';
import 'package:jperg_app/services/auth_service.dart';

/// How you get in, and how you stop being able to.
///
/// Change Password and Delete Account existed on the server and nowhere in the
/// app — the endpoints have been there the whole time with no screen to reach
/// them. Two-factor is new on both sides.
class AccountSecurityPage extends StatefulWidget {
  const AccountSecurityPage({super.key});

  @override
  State<AccountSecurityPage> createState() => _AccountSecurityPageState();
}

class _AccountSecurityPageState extends State<AccountSecurityPage> {
  final _api = AccountSettingsApi();

  AccountSettings _settings = const AccountSettings();
  bool _loading = true;
  bool _savingTwoFactor = false;

  /// Read once from the stored session rather than from the profile state,
  /// which does not carry the role.
  bool _isPhotographer = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final settings = await _api.fetch();
      final role = await sl<AuthService>().getRole();
      if (!mounted) return;
      setState(() {
        _settings = settings;
        _isPhotographer = role == 'photographer';
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _setTwoFactor(bool on) async {
    setState(() => _savingTwoFactor = true);
    try {
      final updated = await _api.update('two_factor_enabled', on);
      if (!mounted) return;
      setState(() => _settings = updated);
      AppSnackBar.success(
        context,
        on
            ? 'Two-factor is on. You will be sent a code when you sign in.'
            : 'Two-factor is off.',
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.error(context, 'Could not change that. Please try again.');
    } finally {
      if (mounted) setState(() => _savingTwoFactor = false);
    }
  }

  Future<void> _changePassword() async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => const _ChangePasswordDialog(),
    );
    if (changed == true && mounted) {
      AppSnackBar.success(context, 'Password updated.');
    }
  }

  /// Opens the wizard rather than flipping the role on the spot.
  ///
  /// It used to call becomePhotographer() here and say "sign in again to see
  /// your tools" — so the account changed before anything had been asked of
  /// it, and someone who tapped Get started out of curiosity was a
  /// photographer with no portfolio, no ID on file and nothing agreed to. The
  /// role moves at the end now, when the verification is submitted.
  Future<void> _becomeCreator() async {
    final done = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
          builder: (_) => const PortfolioEditPage(isCreatorSetup: true)),
    );
    // Their tools appear where their role decides, so the page behind this
    // has to be told the role moved.
    if (done == true && mounted) _load();
  }

  Future<void> _deleteAccount() async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete your account?'),
        content: const Text(
          'Your name, email and photos of you are removed and you are signed '
          'out. Photos you have bought stay with the photographers who sold '
          'them, for their records. This cannot be undone.',
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
      await sl<Api>().dio.delete('/client/account');
      await sl<AuthService>().removeToken();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    } on dio.DioException catch (_) {
      if (!mounted) return;
      AppSnackBar.error(context, 'Could not delete your account just now.');
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
          'Account & Security',
          style: TextStyle(
            color: ext.greetingColor,
            fontSize: 16.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: _loading
          ? const AppLoadingIndicator()
          : Builder(
              builder: (context) => SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(AppSpacing.lg.w, AppSpacing.md.h,
                    AppSpacing.lg.w, AppSpacing.xxxl.h),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 540),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SettingsSection(
                          title: 'Security features',
                          children: [
                            SettingsRow(
                              label: 'Change Password',
                              onTap: _changePassword,
                            ),
                            SettingsRow(
                              label: 'Two-Factor Authentication',
                              subtitle: 'Secure your account with a code',
                              value: _settings.twoFactorEnabled,
                              isBusy: _savingTwoFactor,
                              onChanged: _setTwoFactor,
                            ),
                          ],
                        ),
                        // Only for someone who is not one already — a
                        // photographer being invited to become a creator would
                        // read as the app not knowing who they are.
                        if (!_isPhotographer)
                          _BecomeCreator(
                            ext: ext,
                            onStart: _becomeCreator,
                          ),
                        SettingsSection(
                          children: [
                            SettingsRow(
                              label: 'Delete Account',
                              destructive: true,
                              onTap: _deleteAccount,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );

    return webWrap(page, backgroundColor: ext.homeBackground);
  }
}

class _BecomeCreator extends StatelessWidget {
  const _BecomeCreator({required this.ext, required this.onStart});

  final AppThemeExtension ext;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: AppSpacing.xl.h),
      padding: EdgeInsets.all(AppSpacing.lg.w),
      decoration: BoxDecoration(
        color: ext.accentGold.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.lg.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.star_border_rounded,
                  size: 20.sp, color: ext.accentGold),
              SizedBox(width: AppSpacing.sm.w),
              Text(
                'Become a Creator',
                style: TextStyle(
                  color: ext.greetingColor,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.md.h),
          for (final line in const [
            'Post photos and media',
            'Receive photographer requests directly from viewers',
            'Monetise your content with flexible pricing',
          ])
            Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.xs.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('•  ',
                      style: TextStyle(
                          color: ext.searchHintColor, fontSize: 13.sp)),
                  Expanded(
                    child: Text(
                      line,
                      style: TextStyle(
                          color: ext.searchHintColor,
                          fontSize: 13.sp,
                          height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          SizedBox(height: AppSpacing.md.h),
          Center(
            child: AppButton(
              label: 'Get started',
              variant: AppButtonVariant.secondary,
              borderRadius: AppRadius.pill,
              onPressed: onStart,
            ),
          ),
        ],
      ),
    );
  }
}

/// Current password, new password, done — the shape the endpoint asks for.
class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await sl<Api>().dio.patch('/client/account/password', data: {
        'current_password': _current.text,
        'new_password': _next.text,
      });
      if (mounted) Navigator.of(context).pop(true);
    } on dio.DioException catch (err) {
      // The server says which of the two it objected to — the current password
      // being wrong reads very differently from the new one being too weak.
      final message = err.response?.data?['error']?['message'];
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error =
            message is String ? message : 'Could not change your password.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Change password'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _current,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Current password'),
          ),
          SizedBox(height: AppSpacing.md.h),
          TextField(
            controller: _next,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'New password'),
          ),
          if (_error != null) ...[
            SizedBox(height: AppSpacing.md.h),
            Text(
              _error!,
              style: TextStyle(color: const Color(0xFFB00020), fontSize: 12.sp),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _busy ? null : _submit,
          child: Text(_busy ? 'Saving…' : 'Save'),
        ),
      ],
    );
  }
}
