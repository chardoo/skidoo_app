import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:skidoo_app/core/di/service_locator.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/core/theme/theme_cubit.dart';
import 'package:skidoo_app/features/discovery/presentation/pages/saved_items_page.dart';
import 'package:skidoo_app/features/user_profile/presentation/bloc/user_profile_bloc.dart';

class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          sl<UserProfileBloc>()..add(const UserProfileLoadRequested()),
      child: const _AccountView(),
    );
  }
}

class _AccountView extends StatelessWidget {
  const _AccountView();

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return BlocConsumer<UserProfileBloc, UserProfileState>(
      listener: (context, state) {
        if (state.isLoggedOut) {
          Navigator.of(context)
              .pushNamedAndRemoveUntil('/login', (route) => false);
        }
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.errorMessage!)),
          );
        }
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: ext.homeBackground,
          appBar: AppBar(
            elevation: 0,
            centerTitle: true,
            backgroundColor: ext.homeBackground,
            title: Text(
              'Account',
              style: TextStyle(
                color: ext.greetingColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          body: state.isLoading
              ? const Center(child: CircularProgressIndicator())
              : LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight - 48,
                      ),
                      child: IntrinsicHeight(
                        child: Column(
                          children: [
                            const SizedBox(height: 24),
                            CircleAvatar(
                              radius: 48,
                              backgroundColor: ext.avatarBackground,
                              child: Text(
                                state.name.isNotEmpty
                                    ? state.name[0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                  color: ext.avatarForeground,
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              state.name,
                              style: TextStyle(
                                color: ext.greetingColor,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              state.email,
                              style: TextStyle(
                                color: ext.searchHintColor,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 32),
                            _ThemeToggleCard(ext: ext),
                            const SizedBox(height: 12),
                            _NotificationSettingsCard(
                                isMuted: state.isMuted, ext: ext),
                            const SizedBox(height: 12),
                            _PublicationSettingsCard(
                                alwaysPublic: state.alwaysPublicImages,
                                ext: ext),
                            const Spacer(),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: () {
                                  context
                                      .read<UserProfileBloc>()
                                      .add(const UserLogoutRequested());
                                },
                                child: const Text(
                                  'Logout',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }
}

// ── Theme toggle card ─────────────────────────────────────────────────────────

class _ThemeToggleCard extends StatelessWidget {
  const _ThemeToggleCard({required this.ext});

  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeCubit, ThemeMode>(
      bloc: sl<ThemeCubit>(),
      builder: (context, themeMode) {
        final isDark = themeMode == ThemeMode.dark;
        return Container(
          decoration: BoxDecoration(
            color: ext.cardSurface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                child: Text(
                  'Appearance',
                  style: TextStyle(
                    color: ext.searchHintColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              SwitchListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16),
                activeThumbColor: ext.accentGold,
                activeTrackColor: ext.accentGold.withValues(alpha: 0.4),
                title: Text(
                  'Dark Mode',
                  style: TextStyle(
                      color: ext.greetingColor, fontSize: 14),
                ),
                subtitle: Text(
                  isDark ? 'Dark theme is on' : 'Light theme is on',
                  style: TextStyle(
                      color: ext.searchHintColor, fontSize: 12),
                ),
                secondary: Icon(
                  isDark
                      ? Icons.dark_mode_outlined
                      : Icons.light_mode_outlined,
                  color: isDark ? ext.accentGold : ext.searchHintColor,
                ),
                value: isDark,
                onChanged: (_) => sl<ThemeCubit>().toggleTheme(),
              ),
              const SizedBox(height: 4),
            ],
          ),
        );
      },
    );
  }
}

// ── Publication settings card ─────────────────────────────────────────────────

class _PublicationSettingsCard extends StatelessWidget {
  const _PublicationSettingsCard(
      {required this.alwaysPublic, required this.ext});

  final bool alwaysPublic;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ext.cardSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Text(
              'Publication',
              style: TextStyle(
                color: ext.searchHintColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
          ),
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            activeThumbColor: ext.accentGold,
            activeTrackColor: ext.accentGold.withValues(alpha: 0.4),
            title: Text(
              'Always add public images',
              style: TextStyle(color: ext.greetingColor, fontSize: 14),
            ),
            subtitle: Text(
              alwaysPublic
                  ? 'New uploads are public by default'
                  : 'New uploads are private by default',
              style: TextStyle(color: ext.searchHintColor, fontSize: 12),
            ),
            secondary: Icon(
              Icons.public_rounded,
              color: alwaysPublic ? ext.accentGold : ext.searchHintColor,
            ),
            value: alwaysPublic,
            onChanged: (value) {
              context
                  .read<UserProfileBloc>()
                  .add(PublicImagesToggled(value));
            },
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            leading: Icon(Icons.bookmark_rounded, color: ext.accentGold),
            title: Text(
              'Saved items',
              style: TextStyle(
                  color: ext.greetingColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              'View your bookmarked events',
              style: TextStyle(color: ext.searchHintColor, fontSize: 12),
            ),
            trailing: Icon(Icons.chevron_right_rounded,
                color: ext.searchHintColor, size: 20),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SavedItemsPage()),
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

// ── Notification settings card ────────────────────────────────────────────────

class _NotificationSettingsCard extends StatelessWidget {
  const _NotificationSettingsCard(
      {required this.isMuted, required this.ext});

  final bool isMuted;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ext.cardSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Text(
              'Notifications',
              style: TextStyle(
                color: ext.searchHintColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
          ),
          SwitchListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16),
            activeThumbColor: ext.accentGold,
            activeTrackColor: ext.accentGold.withValues(alpha: 0.4),
            title: Text(
              'Mute message sounds & vibration',
              style: TextStyle(color: ext.greetingColor, fontSize: 14),
            ),
            subtitle: Text(
              isMuted
                  ? 'Messages arrive silently'
                  : 'You\'ll feel a vibration for new messages',
              style: TextStyle(color: ext.searchHintColor, fontSize: 12),
            ),
            secondary: Icon(
              isMuted
                  ? Icons.notifications_off_outlined
                  : Icons.notifications_outlined,
              color: isMuted ? ext.searchHintColor : ext.accentGold,
            ),
            value: isMuted,
            onChanged: (value) {
              context
                  .read<UserProfileBloc>()
                  .add(NotificationsMuteToggled(value));
            },
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}
