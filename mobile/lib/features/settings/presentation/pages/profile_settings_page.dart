import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/common/widgets/app_back_button.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/theme/app_typography.dart';
import 'package:jperg_app/features/photographers/presentation/pages/portfolio_edit_page.dart';
import 'package:jperg_app/features/settings/presentation/pages/edit_profile_page.dart';
import 'package:jperg_app/features/settings/presentation/widgets/settings_section.dart';
import 'package:jperg_app/features/user_profile/presentation/bloc/user_profile_bloc.dart';
import 'package:jperg_app/services/auth_service.dart';

/// The two things on an account that are "how you present yourself":
/// the profile everybody has, and the portfolio only a creator does.
///
/// Portfolio used to sit under a *Photographer* heading of its own further
/// down Settings, which put the two halves of one idea on opposite ends of a
/// scrolling list. They belong together, and this is where they now are.
///
/// Nothing is edited here — both rows push the screen that does. That is the
/// point of the split: Settings should not have to know that editing a
/// portfolio is a different screen from editing a name.
class ProfileSettingsPage extends StatelessWidget {
  const ProfileSettingsPage({super.key});

  /// Whether this page has anything to offer beyond the profile row.
  ///
  /// A viewer has no portfolio, so for them this page is a single row called
  /// Profile that opens a page called Profile — a tap that exists only to be
  /// got past. Settings asks this and sends them straight to the editor
  /// instead, which is what that row has always done for them.
  ///
  /// Read from the live role rather than storage for the same reason the
  /// Settings section was: somebody who becomes a creator while the app is
  /// open has a portfolio from that moment.
  static bool get isWorthShowing => AuthService.role.value == 'photographer';

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return Scaffold(
      backgroundColor: ext.homeBackground,
      appBar: AppBar(
        backgroundColor: ext.homeBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: const AppBackButton(),
        title: Text(
          'Profile',
          style: TextStyle(
            color: ext.greetingColor,
            fontFamily: AppTypography.displayFontFamily,
            fontSize: AppTypography.md,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            AppSpacing.lg.w, AppSpacing.md.h, AppSpacing.lg.w, AppSpacing.xxxl.h),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SettingsSection(
                  children: [
                    SettingsRow(
                      label: 'Profile',
                      onTap: () => _open(context, const EditProfilePage()),
                    ),
                    // Watched, not read once: the role can move while this
                    // page is open — the creator wizard is two taps away
                    // through Account & Security — and a portfolio that
                    // appears only after a restart reads as the upgrade not
                    // having worked.
                    ValueListenableBuilder<String>(
                      valueListenable: AuthService.role,
                      builder: (context, role, _) => role != 'photographer'
                          ? const SizedBox.shrink()
                          : SettingsRow(
                              label: 'Portfolio',
                              subtitle:
                                  'Studio name, bio, specialties and samples',
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const PortfolioEditPage(),
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
      ),
    );
  }

  /// Carries the bloc down, the way Settings does: the editor reads the
  /// account this page's caller already has loaded rather than refetching the
  /// thing it is about to change.
  void _open(BuildContext context, Widget page) {
    final host = context.read<UserProfileBloc>();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider<UserProfileBloc>.value(
          value: host,
          child: page,
        ),
      ),
    );
  }
}
