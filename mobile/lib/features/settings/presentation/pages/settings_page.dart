import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/common/widgets/app_back_button.dart';
import 'package:jperg_app/core/common/widgets/user_avatar.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/utils/snackbar_utils.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/utils/web_wrap.dart';
import 'package:jperg_app/features/settings/presentation/pages/account_security_page.dart';
import 'package:jperg_app/features/settings/presentation/pages/edit_profile_page.dart';
import 'package:jperg_app/features/settings/presentation/pages/help_support_page.dart';
import 'package:jperg_app/features/settings/presentation/pages/notification_settings_page.dart';
import 'package:jperg_app/features/settings/presentation/pages/privacy_settings_page.dart';
import 'package:jperg_app/features/settings/presentation/widgets/settings_section.dart';
import 'package:jperg_app/features/photographers/presentation/pages/portfolio_edit_page.dart';
import 'package:jperg_app/services/auth_service.dart';
import 'package:jperg_app/features/user_profile/presentation/bloc/user_profile_bloc.dart';
import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/core/theme/theme_cubit.dart';

/// Settings, as a list of things rather than a page of everything.
///
/// This was one screen carrying ten expandable cards — every setting in the
/// app open at once, in a column you scrolled past to reach Log Out. It is a
/// table of contents now: each row opens the one screen it names.
///
/// The rows are grouped as the design groups them. Where a row's screen talks
/// to a service, it is not always this one: anonymous comments and hide
/// profile belong to the chat service, notification preferences and the
/// account switches to main, and dark mode to the device.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

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
        leading: const AppBackButton(),
        title: Text(
          'Settings',
          style: TextStyle(
            color: ext.greetingColor,
            fontSize: 16.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: BlocConsumer<UserProfileBloc, UserProfileState>(
        // Signing out clears the session and says so through the state; this
        // is what acts on it. Without it the token was gone, the screen stayed
        // exactly where it was, and Log Out looked like it had done nothing.
        //
        // On the transition, not on the value: `isLoggedOut` stays true once
        // set, and a rebuild for any other reason would otherwise navigate
        // again.
        listenWhen: (previous, current) =>
            previous.isLoggedOut != current.isLoggedOut ||
            previous.errorMessage != current.errorMessage,
        listener: (context, state) {
          if (state.isLoggedOut) {
            // The whole stack: settings, the profile tab underneath it, and
            // everything else that was showing this person's things.
            Navigator.of(context, rootNavigator: true)
                .pushNamedAndRemoveUntil('/login', (route) => false);
            return;
          }
          if (state.errorMessage != null) {
            AppSnackBar.error(context, state.errorMessage!);
          }
        },
        builder: (context, state) {
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(AppSpacing.lg.w, AppSpacing.md.h,
                AppSpacing.lg.w, AppSpacing.xxxl.h),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 540),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _WhoYouAre(state: state, ext: ext),
                    SizedBox(height: AppSpacing.xl.h),
                    SettingsSection(
                      title: 'Account settings',
                      children: [
                        SettingsRow(
                          icon: Icons.person_outline_rounded,
                          label: 'Profile',
                          onTap: () => _open(context, const EditProfilePage()),
                        ),
                        SettingsRow(
                          icon: Icons.shield_outlined,
                          label: 'Account & Security',
                          onTap: () =>
                              _open(context, const AccountSecurityPage()),
                        ),
                        SettingsRow(
                          icon: Icons.visibility_off_outlined,
                          label: 'Privacy',
                          onTap: () =>
                              _open(context, const PrivacySettingsPage()),
                        ),
                      ],
                    ),
                    // Photographer accounts only. A viewer has no portfolio,
                    // and a heading over an empty section is worse than no
                    // heading. The role is read once, from the stored session.
                    FutureBuilder<String>(
                      future: sl<AuthService>().getRole(),
                      builder: (context, snap) {
                        if (snap.data != 'photographer') {
                          return const SizedBox.shrink();
                        }
                        return SettingsSection(
                          title: 'Photographer',
                          children: [
                            SettingsRow(
                              icon: Icons.photo_library_outlined,
                              label: 'Portfolio',
                              subtitle:
                                  'Studio name, bio, specialties and samples',
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const PortfolioEditPage(),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    SettingsSection(
                      title: 'Preferences',
                      children: [
                        SettingsRow(
                          icon: Icons.notifications_none_rounded,
                          label: 'Notifications',
                          onTap: () =>
                              _open(context, const NotificationSettingsPage()),
                        ),
                        // The one row that acts where it stands: a theme is
                        // instant and local, and a screen to hold one switch
                        // would be a screen to hold one switch.
                        BlocBuilder<ThemeCubit, ThemeMode>(
                          bloc: sl<ThemeCubit>(),
                          builder: (context, mode) => SettingsRow(
                            icon: Icons.dark_mode_outlined,
                            label: 'Dark Mode',
                            value: mode == ThemeMode.dark,
                            onChanged: (_) => sl<ThemeCubit>().toggleTheme(),
                          ),
                        ),
                        SettingsRow(
                          icon: Icons.help_outline_rounded,
                          label: 'Help & Support',
                          onTap: () => _open(context, const HelpSupportPage()),
                        ),
                      ],
                    ),
                    SettingsSection(
                      children: [
                        SettingsRow(
                          icon: Icons.logout_rounded,
                          label: 'Log Out',
                          destructive: true,
                          onTap: () => context
                              .read<UserProfileBloc>()
                              .add(const UserLogoutRequested()),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    return webWrap(page, backgroundColor: ext.homeBackground);
  }

  /// Every sub-screen is handed the bloc this page already has loaded, so
  /// opening one does not refetch the account it is about to edit.
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

/// The name and face at the top — who these settings belong to.
class _WhoYouAre extends StatelessWidget {
  const _WhoYouAre({required this.state, required this.ext});

  final UserProfileState state;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        UserAvatar(
          initial: state.name.isNotEmpty ? state.name : '?',
          radius: 22.r,
        ),
        SizedBox(width: AppSpacing.md.w),
        Expanded(
          child: Text(
            state.name.isNotEmpty ? state.name : state.email,
            style: TextStyle(
              color: ext.greetingColor,
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
