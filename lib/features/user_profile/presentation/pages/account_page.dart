import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:skidoo_app/core/di/service_locator.dart';
import 'package:skidoo_app/core/utils/snackbar_utils.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/l10n/app_localizations.dart';
import 'package:skidoo_app/core/theme/theme_cubit.dart';
import 'package:skidoo_app/features/discovery/presentation/bloc/discovery_bloc.dart';
import 'package:skidoo_app/features/discovery/presentation/pages/saved_items_page.dart';
import 'package:skidoo_app/features/user_profile/presentation/bloc/user_profile_bloc.dart';

String _resolveErrorMessage(String key, AppLocalizations l10n) => switch (key) {
      'accountAnonymousModeUpdateFailed' => l10n.accountAnonymousModeUpdateFailed,
      'accountHideProfileUpdateFailed' => l10n.accountHideProfileUpdateFailed,
      _ => key,
    };

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
      listenWhen: (previous, current) =>
          current.isLoggedOut != previous.isLoggedOut ||
          current.isUpdateSuccess != previous.isUpdateSuccess ||
          current.updateErrorMessage != previous.updateErrorMessage ||
          current.errorMessage != previous.errorMessage,
      listener: (context, state) {
        final l10n = AppLocalizations.of(context)!;
        if (state.isLoggedOut) {
          Navigator.of(context)
              .pushNamedAndRemoveUntil('/login', (route) => false);
        }
        if (state.isUpdateSuccess) {
          AppSnackBar.success(context, l10n.accountProfileUpdated);
        }
        if (state.updateErrorMessage != null) {
          AppSnackBar.error(context, state.updateErrorMessage!);
        }
        if (state.errorMessage != null) {
          AppSnackBar.error(context, _resolveErrorMessage(state.errorMessage!, l10n));
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
              AppLocalizations.of(context)!.accountTitle,
              style: TextStyle(
                color: ext.greetingColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          body: state.isLoading
              ? const Center(child: CircularProgressIndicator())
              : LayoutBuilder(
                  builder: (context, constraints) => Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 540),
                      child: SingleChildScrollView(
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
                            _EditProfileCard(state: state, ext: ext),
                            const SizedBox(height: 12),
                            _ThemeToggleCard(ext: ext),
                            const SizedBox(height: 12),
                            _NotificationSettingsCard(
                                isMuted: state.isMuted, ext: ext),
                            const SizedBox(height: 12),
                            _PublicationSettingsCard(
                                alwaysPublic: state.alwaysPublicImages,
                                ext: ext),
                            const SizedBox(height: 12),
                            _PrivacySettingsCard(
                              anonymousMode: state.anonymousMode,
                              hideProfile: state.hideProfile,
                              isAnonymousModeUpdating: state.isAnonymousModeUpdating,
                              isHideProfileUpdating: state.isHideProfileUpdating,
                              ext: ext,
                            ),
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
                                child: Text(
                                  AppLocalizations.of(context)!.accountLogout,
                                  style: const TextStyle(
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
              ),
            ),
        );
      },
    );
  }
}

// ── Edit Profile card ──────────────────────────────────────────────────────────

class _EditProfileCard extends StatefulWidget {
  const _EditProfileCard({required this.state, required this.ext});

  final UserProfileState state;
  final AppThemeExtension ext;

  @override
  State<_EditProfileCard> createState() => _EditProfileCardState();
}

class _EditProfileCardState extends State<_EditProfileCard> {
  bool _expanded = false;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _usernameCtrl;
  late final TextEditingController _contactCtrl;
  late final TextEditingController _countryCodeCtrl;
  late final TextEditingController _localeCtrl;
  late final TextEditingController _languageCtrl;
  late final TextEditingController _timezoneCtrl;
  late Set<String> _selectedTags;

  static const _allTags = [
    'Portrait', 'Landscape', 'Street', 'Wildlife', 'Architecture',
    'Sports', 'Travel', 'Macro', 'Fashion', 'Wedding',
    'Event', 'Food', 'Aerial', 'Night', 'Documentary',
    'Abstract', 'Fine Art', 'Photojournalism',
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl        = TextEditingController(text: widget.state.name);
    _usernameCtrl    = TextEditingController(text: widget.state.uniqueName);
    _contactCtrl     = TextEditingController(text: widget.state.contact);
    _countryCodeCtrl = TextEditingController(text: widget.state.countryCode);
    _localeCtrl      = TextEditingController(text: widget.state.locale);
    _languageCtrl    = TextEditingController(text: widget.state.preferredLanguage);
    _timezoneCtrl    = TextEditingController(text: widget.state.timezone);
    _selectedTags    = Set<String>.from(widget.state.interestTags);
  }

  @override
  void didUpdateWidget(_EditProfileCard old) {
    super.didUpdateWidget(old);
    // Sync controllers when the profile is freshly loaded (not during an update)
    if (!widget.state.isUpdateLoading && old.state.isLoading && !widget.state.isLoading) {
      _nameCtrl.text        = widget.state.name;
      _usernameCtrl.text    = widget.state.uniqueName;
      _contactCtrl.text     = widget.state.contact;
      _countryCodeCtrl.text = widget.state.countryCode;
      _localeCtrl.text      = widget.state.locale;
      _languageCtrl.text    = widget.state.preferredLanguage;
      _timezoneCtrl.text    = widget.state.timezone;
      _selectedTags         = Set<String>.from(widget.state.interestTags);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    _contactCtrl.dispose();
    _countryCodeCtrl.dispose();
    _localeCtrl.dispose();
    _languageCtrl.dispose();
    _timezoneCtrl.dispose();
    super.dispose();
  }

  void _save(BuildContext context) {
    context.read<UserProfileBloc>().add(ProfileUpdateSubmitted(
          name: _nameCtrl.text.trim(),
          uniqueName: _usernameCtrl.text.trim(),
          contact: _contactCtrl.text.trim(),
          countryCode: _countryCodeCtrl.text.trim(),
          locale: _localeCtrl.text.trim(),
          preferredLanguage: _languageCtrl.text.trim(),
          timezone: _timezoneCtrl.text.trim(),
          interestTags: _selectedTags.toList(),
        ));
  }

  @override
  Widget build(BuildContext context) {
    final ext = widget.ext;
    return Container(
      decoration: BoxDecoration(
        color: ext.cardSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ────────────────────────────────────────────────────
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(
                children: [
                  Icon(Icons.edit_outlined, color: ext.accentGold, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context)!.accountEditProfile,
                      style: TextStyle(
                        color: ext.greetingColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: ext.searchHintColor,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
          // ── Expandable form ───────────────────────────────────────────────
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 250),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 16),

                  // ── Basic info section ─────────────────────────────────
                  _SectionLabel(AppLocalizations.of(context)!.accountBasicInfo, ext),
                  const SizedBox(height: 10),
                  _ProfileField(
                      controller: _nameCtrl,
                      label: AppLocalizations.of(context)!.accountDisplayName,
                      icon: Icons.person_outline_rounded,
                      ext: ext),
                  const SizedBox(height: 10),
                  _ProfileField(
                      controller: _usernameCtrl,
                      label: AppLocalizations.of(context)!.accountUsername,
                      icon: Icons.alternate_email_rounded,
                      ext: ext),
                  const SizedBox(height: 10),
                  _ProfileField(
                      controller: _contactCtrl,
                      label: AppLocalizations.of(context)!.accountPhoneNumber,
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      ext: ext),
                  const SizedBox(height: 20),

                  // ── Locale section ─────────────────────────────────────
                  _SectionLabel(AppLocalizations.of(context)!.accountLocaleRegion, ext),
                  const SizedBox(height: 10),
                  _ProfileField(
                      controller: _countryCodeCtrl,
                      label: AppLocalizations.of(context)!.accountCountryCode,
                      icon: Icons.flag_outlined,
                      maxLength: 2,
                      ext: ext),
                  const SizedBox(height: 10),
                  _ProfileField(
                      controller: _localeCtrl,
                      label: AppLocalizations.of(context)!.accountLocale,
                      icon: Icons.language_outlined,
                      ext: ext),
                  const SizedBox(height: 10),
                  _ProfileField(
                      controller: _languageCtrl,
                      label: AppLocalizations.of(context)!.accountPreferredLanguage,
                      icon: Icons.translate_rounded,
                      ext: ext),
                  const SizedBox(height: 10),
                  _ProfileField(
                      controller: _timezoneCtrl,
                      label: AppLocalizations.of(context)!.accountTimezone,
                      icon: Icons.access_time_rounded,
                      ext: ext),
                  const SizedBox(height: 20),

                  // ── Interests section ──────────────────────────────────
                  _SectionLabel(AppLocalizations.of(context)!.accountPhotographyInterests, ext),
                  const SizedBox(height: 10),
                  StatefulBuilder(
                    builder: (context, setChipState) => Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _allTags.map((tag) {
                        final selected = _selectedTags.contains(tag);
                        return FilterChip(
                          label: Text(tag),
                          selected: selected,
                          onSelected: (_) {
                            setChipState(() {
                              setState(() {
                                selected
                                    ? _selectedTags.remove(tag)
                                    : _selectedTags.add(tag);
                              });
                            });
                          },
                          selectedColor: ext.accentGold.withValues(alpha: 0.2),
                          checkmarkColor: ext.accentGold,
                          labelStyle: TextStyle(
                            color: selected
                                ? ext.accentGold
                                : ext.searchHintColor,
                            fontSize: 12,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                          side: BorderSide(
                            color: selected
                                ? ext.accentGold
                                : ext.searchHintColor.withValues(alpha: 0.3),
                          ),
                          backgroundColor: ext.cardSurface,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 2),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Save button ────────────────────────────────────────
                  BlocBuilder<UserProfileBloc, UserProfileState>(
                    builder: (context, state) {
                      final loading = state.isUpdateLoading;
                      return SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ext.accentGold,
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: loading ? null : () => _save(context),
                          child: loading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  AppLocalizations.of(context)!.accountSaveChanges,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label, this.ext);

  final String label;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        color: ext.searchHintColor,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _ProfileField extends StatelessWidget {
  const _ProfileField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.ext,
    this.keyboardType = TextInputType.text,
    this.maxLength,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final AppThemeExtension ext;
  final TextInputType keyboardType;
  final int? maxLength;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLength: maxLength,
      style: TextStyle(color: ext.greetingColor, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: ext.searchHintColor, fontSize: 13),
        prefixIcon: Icon(icon, color: ext.searchHintColor, size: 18),
        counterText: '',
        filled: true,
        fillColor: ext.homeBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
              color: ext.searchHintColor.withValues(alpha: 0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
              color: ext.searchHintColor.withValues(alpha: 0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: ext.accentGold, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
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
                  AppLocalizations.of(context)!.accountAppearance,
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
                  AppLocalizations.of(context)!.accountDarkMode,
                  style: TextStyle(
                      color: ext.greetingColor, fontSize: 14),
                ),
                subtitle: Text(
                  isDark
                      ? AppLocalizations.of(context)!.accountDarkThemeOn
                      : AppLocalizations.of(context)!.accountLightThemeOn,
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
              AppLocalizations.of(context)!.accountPublication,
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
              AppLocalizations.of(context)!.accountAlwaysPublicImages,
              style: TextStyle(color: ext.greetingColor, fontSize: 14),
            ),
            subtitle: Text(
              alwaysPublic
                  ? AppLocalizations.of(context)!.accountUploadsPublicByDefault
                  : AppLocalizations.of(context)!.accountUploadsPrivateByDefault,
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
              AppLocalizations.of(context)!.accountSavedItems,
              style: TextStyle(
                  color: ext.greetingColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              AppLocalizations.of(context)!.accountViewBookmarkedEvents,
              style: TextStyle(color: ext.searchHintColor, fontSize: 12),
            ),
            trailing: Icon(Icons.chevron_right_rounded,
                color: ext.searchHintColor, size: 20),
            onTap: () {
              final discoveryBloc = context.read<DiscoveryBloc>();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => BlocProvider.value(
                    value: discoveryBloc,
                    child: const SavedItemsPage(),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

// ── Privacy settings card ─────────────────────────────────────────────────────

class _PrivacySettingsCard extends StatelessWidget {
  const _PrivacySettingsCard({
    required this.anonymousMode,
    required this.hideProfile,
    required this.isAnonymousModeUpdating,
    required this.isHideProfileUpdating,
    required this.ext,
  });

  final bool anonymousMode;
  final bool hideProfile;
  final bool isAnonymousModeUpdating;
  final bool isHideProfileUpdating;
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
              AppLocalizations.of(context)!.accountPrivacy,
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
              AppLocalizations.of(context)!.accountAnonymousComments,
              style: TextStyle(color: ext.greetingColor, fontSize: 14),
            ),
            subtitle: Text(
              anonymousMode
                  ? AppLocalizations.of(context)!.accountAnonymousModeOn
                  : AppLocalizations.of(context)!.accountAnonymousModeOff,
              style: TextStyle(color: ext.searchHintColor, fontSize: 12),
            ),
            secondary: isAnonymousModeUpdating
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: ext.accentGold, strokeWidth: 2),
                  )
                : Icon(
                    Icons.person_off_outlined,
                    color: anonymousMode ? ext.accentGold : ext.searchHintColor,
                  ),
            value: anonymousMode,
            onChanged: isAnonymousModeUpdating
                ? null
                : (value) {
                    context
                        .read<UserProfileBloc>()
                        .add(AnonymousModeToggled(value));
                  },
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            activeThumbColor: ext.accentGold,
            activeTrackColor: ext.accentGold.withValues(alpha: 0.4),
            title: Text(
              AppLocalizations.of(context)!.accountHideProfile,
              style: TextStyle(color: ext.greetingColor, fontSize: 14),
            ),
            subtitle: Text(
              hideProfile
                  ? AppLocalizations.of(context)!.accountHideProfileOn
                  : AppLocalizations.of(context)!.accountHideProfileOff,
              style: TextStyle(color: ext.searchHintColor, fontSize: 12),
            ),
            secondary: isHideProfileUpdating
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: ext.accentGold, strokeWidth: 2),
                  )
                : Icon(
                    Icons.visibility_off_outlined,
                    color: hideProfile ? ext.accentGold : ext.searchHintColor,
                  ),
            value: hideProfile,
            onChanged: isHideProfileUpdating
                ? null
                : (value) {
                    context
                        .read<UserProfileBloc>()
                        .add(HideProfileToggled(value));
                  },
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
              AppLocalizations.of(context)!.accountNotifications,
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
              AppLocalizations.of(context)!.accountMuteNotifications,
              style: TextStyle(color: ext.greetingColor, fontSize: 14),
            ),
            subtitle: Text(
              isMuted
                  ? AppLocalizations.of(context)!.accountMutedOn
                  : AppLocalizations.of(context)!.accountMutedOff,
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
