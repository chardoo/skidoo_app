import 'package:dio/dio.dart' as dio_pkg;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/api/dio_client_service.dart';
import 'package:jperg_app/core/common/widgets/app_button.dart';
import 'package:jperg_app/core/common/widgets/app_confirm_dialog.dart';
import 'package:jperg_app/core/common/widgets/app_text_field.dart';
import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/core/utils/snackbar_utils.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/l10n/app_localizations.dart';
import 'package:jperg_app/core/theme/theme_cubit.dart';
import 'package:jperg_app/features/discovery/presentation/bloc/discovery_bloc.dart';
import 'package:jperg_app/features/admin/data/models/app_config.dart';
import 'package:jperg_app/features/admin/data/repositories/app_config_repository.dart';
import 'package:jperg_app/features/admin/presentation/pages/admin_settings_page.dart';
import 'package:jperg_app/features/ads/presentation/pages/my_campaigns_page.dart';
import 'package:jperg_app/features/ads/presentation/pages/my_requests_page.dart';
import 'package:jperg_app/features/ads/presentation/pages/request_board_page.dart';
import 'package:jperg_app/features/ads/presentation/widgets/create_bottom_sheet.dart';
import 'package:jperg_app/features/photographers/presentation/pages/portfolio_edit_page.dart';
import 'package:jperg_app/features/user_profile/presentation/pages/face_recognition_page.dart';
import 'package:jperg_app/services/auth_service.dart';
import 'package:jperg_app/features/discovery/presentation/pages/saved_items_page.dart';
import 'package:jperg_app/features/follow/presentation/pages/follow_list_page.dart';
import 'package:jperg_app/features/user_profile/presentation/bloc/user_profile_bloc.dart';
import 'package:jperg_app/core/utils/web_wrap.dart';
import 'package:jperg_app/core/widgets/animations/app_animations.dart';
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/common/widgets/app_section_label.dart';

String _resolveErrorMessage(String key, AppLocalizations l10n) => switch (key) {
      'accountAnonymousModeUpdateFailed' =>
        l10n.accountAnonymousModeUpdateFailed,
      'accountHideProfileUpdateFailed' => l10n.accountHideProfileUpdateFailed,
      _ => key,
    };

class AccountPage extends StatelessWidget {
  const AccountPage({super.key, this.reuseHostBloc = false});

  /// True when an ancestor already provides a loaded [UserProfileBloc].
  ///
  /// This page used to be the Profile tab itself, built once inside the nav's
  /// IndexedStack and kept warm. Pushing it as a route instead meant a fresh
  /// bloc and a fresh fetch on every open, which is why settings went from
  /// instant to a wait — the data was already sitting in the bloc the host
  /// provides.
  final bool reuseHostBloc;

  @override
  Widget build(BuildContext context) {
    if (reuseHostBloc) return const _AccountView();
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
          AppSnackBar.error(
              context, _resolveErrorMessage(state.errorMessage!, l10n));
        }
      },
      builder: (context, state) {
        final page = Scaffold(
          // AccountPage is pushed as its own standalone route (avatar tap /
          // web sidebar), not nested in HomePage's IndexedStack like the
          // bottom-nav tabs — so unlike those, it has no themed ancestor
          // Scaffold behind it to fall back to. Transparent here left mobile
          // showing the raw black canvas; webWrap() only paints a background
          // on web (kIsWeb), so mobile needs its own explicit color.
          backgroundColor: ext.homeBackground,
          appBar: AppBar(
            elevation: 0,
            centerTitle: true,
            backgroundColor: Colors.transparent,
            automaticallyImplyLeading: !kIsWeb,
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
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 540),
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(AppSpacing.xxl.w),
                      child: Column(
                        children: [
                          SizedBox(height: AppSpacing.xxl.h),
                          CircleAvatar(
                            radius: 48.r,
                            backgroundColor: ext.avatarBackground,
                            child: Text(
                              state.name.isNotEmpty
                                  ? state.name[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                color: ext.avatarForeground,
                                fontSize: 36.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          SizedBox(height: AppSpacing.xl.h),
                          Text(
                            state.name,
                            style: TextStyle(
                              color: ext.greetingColor,
                              fontSize: 22.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 6.h),
                          Text(
                            state.email,
                            style: TextStyle(
                              color: ext.searchHintColor,
                              fontSize: 14.sp,
                            ),
                          ),
                          SizedBox(height: AppSpacing.xxxl.h),
                          Reveal(
                            delay: AppMotion.stagger * 0,
                            child: _ConnectionsCard(ext: ext),
                          ),
                          SizedBox(height: AppSpacing.md.h),
                          Reveal(
                            delay: AppMotion.stagger * 1,
                            child: _EditProfileCard(state: state, ext: ext),
                          ),
                          SizedBox(height: AppSpacing.md.h),
                          Reveal(
                            delay: AppMotion.stagger * 2,
                            child: _PhotographerPortfolioCard(ext: ext),
                          ),
                          SizedBox(height: AppSpacing.md.h),
                          Reveal(
                            delay: AppMotion.stagger * 3,
                            child: _ThemeToggleCard(ext: ext),
                          ),
                          SizedBox(height: AppSpacing.md.h),
                          Reveal(
                            delay: AppMotion.stagger * 4,
                            child: _NotificationSettingsCard(
                                isMuted: state.isMuted, ext: ext),
                          ),
                          SizedBox(height: AppSpacing.md.h),
                          Reveal(
                            delay: AppMotion.stagger * 5,
                            child: _PublicationSettingsCard(
                                alwaysPublic: state.alwaysPublicImages,
                                ext: ext),
                          ),
                          SizedBox(height: AppSpacing.md.h),
                          Reveal(
                            delay: AppMotion.stagger * 6,
                            child: _FaceRecognitionCard(ext: ext),
                          ),
                          SizedBox(height: AppSpacing.md.h),
                          Reveal(
                            delay: AppMotion.stagger * 7,
                            child: _AdsCard(ext: ext),
                          ),
                          SizedBox(height: AppSpacing.md.h),
                          Reveal(
                            delay: AppMotion.stagger * 8,
                            child: _PrivacySettingsCard(
                              anonymousMode: state.anonymousMode,
                              hideProfile: state.hideProfile,
                              isAnonymousModeUpdating:
                                  state.isAnonymousModeUpdating,
                              isHideProfileUpdating:
                                  state.isHideProfileUpdating,
                              ext: ext,
                            ),
                          ),
                          // const Spacer(),
                          SizedBox(height: AppSpacing.xxl.h),
                          AppButton(
                            fullWidth: true,
                            variant: AppButtonVariant.destructive,
                            label: AppLocalizations.of(context)!.accountLogout,
                            onPressed: () {
                              context
                                  .read<UserProfileBloc>()
                                  .add(const UserLogoutRequested());
                            },
                          ),
                          SizedBox(height: AppSpacing.xxxl.h),
                        ],
                      ),
                    ),
                  ),
                ),
        );
        return webWrap(page, backgroundColor: ext.homeBackground);
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
    'Portrait',
    'Landscape',
    'Street',
    'Wildlife',
    'Architecture',
    'Sports',
    'Travel',
    'Macro',
    'Fashion',
    'Wedding',
    'Event',
    'Food',
    'Aerial',
    'Night',
    'Documentary',
    'Abstract',
    'Fine Art',
    'Photojournalism',
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.state.name);
    _usernameCtrl = TextEditingController(text: widget.state.uniqueName);
    _contactCtrl = TextEditingController(text: widget.state.contact);
    _countryCodeCtrl = TextEditingController(text: widget.state.countryCode);
    _localeCtrl = TextEditingController(text: widget.state.locale);
    _languageCtrl = TextEditingController(text: widget.state.preferredLanguage);
    _timezoneCtrl = TextEditingController(text: widget.state.timezone);
    _selectedTags = Set<String>.from(widget.state.interestTags);
  }

  @override
  void didUpdateWidget(_EditProfileCard old) {
    super.didUpdateWidget(old);
    // Sync controllers when the profile is freshly loaded (not during an update)
    if (!widget.state.isUpdateLoading &&
        old.state.isLoading &&
        !widget.state.isLoading) {
      _nameCtrl.text = widget.state.name;
      _usernameCtrl.text = widget.state.uniqueName;
      _contactCtrl.text = widget.state.contact;
      _countryCodeCtrl.text = widget.state.countryCode;
      _localeCtrl.text = widget.state.locale;
      _languageCtrl.text = widget.state.preferredLanguage;
      _timezoneCtrl.text = widget.state.timezone;
      _selectedTags = Set<String>.from(widget.state.interestTags);
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
    return Material(
      // Material, not a decorated Container: ListTile paints its highlight and
      // ink splash onto the nearest Material ancestor, so a DecoratedBox
      // between the two swallows them (and trips an assertion in debug).
      // Giving the card itself a Material means the ink lands on top of the
      // card, clipped to its corners.
      color: ext.cardSurface,
      borderRadius: BorderRadius.circular(AppRadius.md.r),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ────────────────────────────────────────────────────
          Semantics(
              button: true,
              label: 'Expanded',
              child: InkWell(
                borderRadius: BorderRadius.vertical(top: Radius.circular(12.r)),
                onTap: () => setState(() => _expanded = !_expanded),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 14.h),
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined,
                          color: ext.accentGold, size: 18.sp),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: Text(
                          AppLocalizations.of(context)!.accountEditProfile,
                          style: TextStyle(
                            color: ext.greetingColor,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Icon(
                        _expanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: ext.searchHintColor,
                        size: 22.sp,
                      ),
                    ],
                  ),
                ),
              )),
          // ── Expandable form ───────────────────────────────────────────────
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 250),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 20.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1),
                  SizedBox(height: AppSpacing.lg.h),

                  // ── Basic info section ─────────────────────────────────
                  AppSectionLabel(
                      AppLocalizations.of(context)!.accountBasicInfo),
                  SizedBox(height: 10.h),
                  _ProfileField(
                      controller: _nameCtrl,
                      label: AppLocalizations.of(context)!.accountDisplayName,
                      icon: Icons.person_outline_rounded),
                  SizedBox(height: 10.h),
                  _ProfileField(
                      controller: _usernameCtrl,
                      label: AppLocalizations.of(context)!.accountUsername,
                      icon: Icons.alternate_email_rounded),
                  SizedBox(height: 10.h),
                  _ProfileField(
                      controller: _contactCtrl,
                      label: AppLocalizations.of(context)!.accountPhoneNumber,
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone),
                  SizedBox(height: AppSpacing.xl.h),

                  // ── Locale section ─────────────────────────────────────
                  AppSectionLabel(
                      AppLocalizations.of(context)!.accountLocaleRegion),
                  SizedBox(height: 10.h),
                  _ProfileDropdown(
                      controller: _countryCodeCtrl,
                      label: AppLocalizations.of(context)!.accountCountryCode,
                      icon: Icons.flag_outlined,
                      options: _kCountryOptions,
                      ext: ext),
                  SizedBox(height: 10.h),
                  _ProfileDropdown(
                      controller: _localeCtrl,
                      label: AppLocalizations.of(context)!.accountLocale,
                      icon: Icons.language_outlined,
                      options: _kLocaleOptions,
                      ext: ext),
                  SizedBox(height: 10.h),
                  _ProfileDropdown(
                      controller: _languageCtrl,
                      label: AppLocalizations.of(context)!
                          .accountPreferredLanguage,
                      icon: Icons.translate_rounded,
                      options: _kLanguageOptions,
                      ext: ext),
                  SizedBox(height: 10.h),
                  _ProfileDropdown(
                      controller: _timezoneCtrl,
                      label: AppLocalizations.of(context)!.accountTimezone,
                      icon: Icons.access_time_rounded,
                      options: _kTimezoneOptions,
                      ext: ext),
                  SizedBox(height: AppSpacing.xl.h),

                  // ── Interests section ──────────────────────────────────
                  AppSectionLabel(
                      AppLocalizations.of(context)!.accountPhotographyInterests),
                  SizedBox(height: 10.h),
                  StatefulBuilder(
                    builder: (context, setChipState) => Wrap(
                      spacing: 8.w,
                      runSpacing: 8.h,
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
                          selectedColor: ext.searchFieldFill,
                          checkmarkColor: ext.greetingColor,
                          labelStyle: TextStyle(
                            color: selected
                                ? ext.greetingColor
                                : ext.searchHintColor,
                            fontSize: 12.sp,
                            fontWeight:
                                selected ? FontWeight.w600 : FontWeight.w400,
                          ),
                          side: BorderSide(
                            color: selected
                                ? ext.greetingColor.withValues(alpha: 0.4)
                                : ext.searchHintColor.withValues(alpha: 0.3),
                          ),
                          backgroundColor: ext.cardSurface,
                          padding: EdgeInsets.symmetric(
                              horizontal: AppSpacing.xs.w, vertical: 2.h),
                        );
                      }).toList(),
                    ),
                  ),
                  SizedBox(height: AppSpacing.xxl.h),

                  // ── Save button ────────────────────────────────────────
                  BlocBuilder<UserProfileBloc, UserProfileState>(
                    builder: (context, state) {
                      return AppButton(
                        fullWidth: true,
                        isLoading: state.isUpdateLoading,
                        onPressed:
                            state.isUpdateLoading ? null : () => _save(context),
                        label: AppLocalizations.of(context)!.accountSaveChanges,
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


class _ProfileField extends StatelessWidget {
  const _ProfileField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType = TextInputType.text,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType keyboardType;

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      controller: controller,
      keyboardType: keyboardType,
      label: label,
      prefixIcon: icon,
    );
  }
}

// ── Curated option lists for the locale/region dropdowns ───────────────────────
// Values use the standard formats the API expects (ISO-3166 country, IETF
// language, `xx_XX` locale, IANA timezone). Any previously-saved value that
// isn't in a list is preserved as a selectable fallback by [_ProfileDropdown].

const Map<String, String> _kCountryOptions = {
  'GH': 'Ghana',
  'NG': 'Nigeria',
  'KE': 'Kenya',
  'ZA': 'South Africa',
  'EG': 'Egypt',
  'MA': 'Morocco',
  'US': 'United States',
  'CA': 'Canada',
  'GB': 'United Kingdom',
  'IE': 'Ireland',
  'DE': 'Germany',
  'FR': 'France',
  'ES': 'Spain',
  'PT': 'Portugal',
  'IT': 'Italy',
  'NL': 'Netherlands',
  'BE': 'Belgium',
  'CH': 'Switzerland',
  'SE': 'Sweden',
  'NO': 'Norway',
  'DK': 'Denmark',
  'AE': 'United Arab Emirates',
  'SA': 'Saudi Arabia',
  'IN': 'India',
  'CN': 'China',
  'JP': 'Japan',
  'SG': 'Singapore',
  'AU': 'Australia',
  'NZ': 'New Zealand',
  'BR': 'Brazil',
  'MX': 'Mexico',
};

const Map<String, String> _kLanguageOptions = {
  'en': 'English',
  'de': 'German',
  'fr': 'French',
  'es': 'Spanish',
  'pt': 'Portuguese',
  'ar': 'Arabic',
};

const Map<String, String> _kLocaleOptions = {
  'en_US': 'English (US)',
  'en_GB': 'English (UK)',
  'de_DE': 'German (Germany)',
  'fr_FR': 'French (France)',
  'es_ES': 'Spanish (Spain)',
  'pt_PT': 'Portuguese (Portugal)',
  'it_IT': 'Italian (Italy)',
  'nl_NL': 'Dutch (Netherlands)',
};

const Map<String, String> _kTimezoneOptions = {
  'UTC': 'UTC',
  'Africa/Accra': 'Accra',
  'Africa/Lagos': 'Lagos',
  'Africa/Nairobi': 'Nairobi',
  'Africa/Johannesburg': 'Johannesburg',
  'Africa/Cairo': 'Cairo',
  'Europe/London': 'London',
  'Europe/Berlin': 'Berlin',
  'Europe/Paris': 'Paris',
  'Europe/Madrid': 'Madrid',
  'Europe/Rome': 'Rome',
  'Europe/Amsterdam': 'Amsterdam',
  'America/New_York': 'New York',
  'America/Chicago': 'Chicago',
  'America/Denver': 'Denver',
  'America/Los_Angeles': 'Los Angeles',
  'America/Sao_Paulo': 'São Paulo',
  'America/Mexico_City': 'Mexico City',
  'Asia/Dubai': 'Dubai',
  'Asia/Kolkata': 'Kolkata',
  'Asia/Shanghai': 'Shanghai',
  'Asia/Tokyo': 'Tokyo',
  'Asia/Singapore': 'Singapore',
  'Australia/Sydney': 'Sydney',
  'Pacific/Auckland': 'Auckland',
};

/// Dropdown styled to match [_ProfileField], writing the selected value back to
/// [controller] so the existing save path is unchanged.
class _ProfileDropdown extends StatefulWidget {
  const _ProfileDropdown({
    required this.controller,
    required this.label,
    required this.icon,
    required this.options,
    required this.ext,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final Map<String, String> options;
  final AppThemeExtension ext;

  @override
  State<_ProfileDropdown> createState() => _ProfileDropdownState();
}

class _ProfileDropdownState extends State<_ProfileDropdown> {
  @override
  Widget build(BuildContext context) {
    final ext = widget.ext;
    final current = widget.controller.text.trim();
    final entries = <MapEntry<String, String>>[
      ...widget.options.entries,
      // Keep any saved value that isn't in the curated list selectable.
      if (current.isNotEmpty && !widget.options.containsKey(current))
        MapEntry(current, current),
    ];
    return InputDecorator(
      decoration: InputDecoration(
        labelText: widget.label,
        labelStyle: TextStyle(color: ext.searchHintColor, fontSize: 13.sp),
        prefixIcon: Icon(widget.icon, color: ext.searchHintColor, size: 18.sp),
        filled: true,
        fillColor: ext.homeBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.r),
          borderSide:
              BorderSide(color: ext.searchHintColor.withValues(alpha: 0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.r),
          borderSide:
              BorderSide(color: ext.searchHintColor.withValues(alpha: 0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.r),
          borderSide: BorderSide(color: ext.accentGold, width: 1.5),
        ),
        contentPadding:
            EdgeInsets.symmetric(horizontal: AppSpacing.md.w, vertical: 6.h),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: current.isEmpty ? null : current,
          isExpanded: true,
          isDense: true,
          hint: Text('Select',
              style: TextStyle(color: ext.searchHintColor, fontSize: 14.sp)),
          dropdownColor: ext.cardSurface,
          style: TextStyle(color: ext.greetingColor, fontSize: 14.sp),
          icon: Icon(Icons.keyboard_arrow_down_rounded,
              color: ext.searchHintColor, size: 20.sp),
          items: entries
              .map((e) => DropdownMenuItem<String>(
                    value: e.key,
                    child: Text(e.value, overflow: TextOverflow.ellipsis),
                  ))
              .toList(),
          onChanged: (v) {
            if (v == null) return;
            setState(() => widget.controller.text = v);
          },
        ),
      ),
    );
  }
}

// ── Photographer portfolio card ────────────────────────────────────────────────
// Only rendered for photographer accounts — lets them re-open the same
// studio-name/bio/specialties/sample-photos fields collected during
// onboarding's "Set up your portfolio" step. Normal users see nothing here;
// their profile editing stays entirely in _EditProfileCard above.
class _PhotographerPortfolioCard extends StatelessWidget {
  const _PhotographerPortfolioCard({required this.ext});
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: sl<AuthService>().getRole(),
      builder: (context, snap) {
        if (snap.data != 'photographer') return const SizedBox.shrink();
        return Material(
          // See the sibling cards: the ink has to land on a Material, and a
          // decorated Container between tile and Material eats it.
          color: ext.cardSurface,
          borderRadius: BorderRadius.circular(AppRadius.md.r),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 6.h),
                child: Text(
                  'PORTFOLIO',
                  style: TextStyle(
                    color: ext.searchHintColor,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              _AdsListTile(
                icon: Icons.photo_library_outlined,
                iconColor: const Color(0xFF1D9E75),
                title: 'Portfolio',
                subtitle: 'Studio name, bio, specialties, and sample photos',
                ext: ext,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PortfolioEditPage()),
                ),
              ),
            ],
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
        return Material(
          // See the sibling cards: the ink has to land on a Material, and a
          // decorated Container between tile and Material eats it.
          color: ext.cardSurface,
          borderRadius: BorderRadius.circular(AppRadius.md.r),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 6.h),
                child: Text(
                  AppLocalizations.of(context)!.accountAppearance,
                  style: TextStyle(
                    color: ext.searchHintColor,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              SwitchListTile(
                contentPadding:
                    EdgeInsets.symmetric(horizontal: AppSpacing.lg.w),
                activeThumbColor: ext.greetingColor,
                activeTrackColor: ext.searchHintColor.withValues(alpha: 0.4),
                title: Text(
                  AppLocalizations.of(context)!.accountDarkMode,
                  style: TextStyle(color: ext.greetingColor, fontSize: 14.sp),
                ),
                subtitle: Text(
                  isDark
                      ? AppLocalizations.of(context)!.accountDarkThemeOn
                      : AppLocalizations.of(context)!.accountLightThemeOn,
                  style: TextStyle(color: ext.searchHintColor, fontSize: 12.sp),
                ),
                secondary: Icon(
                  isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                  color: isDark ? ext.greetingColor : ext.searchHintColor,
                ),
                value: isDark,
                onChanged: (_) => sl<ThemeCubit>().toggleTheme(),
              ),
              SizedBox(height: AppSpacing.xs.h),
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
    return Material(
      // Material, not a decorated Container: ListTile paints its highlight and
      // ink splash onto the nearest Material ancestor, so a DecoratedBox
      // between the two swallows them (and trips an assertion in debug).
      // Giving the card itself a Material means the ink lands on top of the
      // card, clipped to its corners.
      color: ext.cardSurface,
      borderRadius: BorderRadius.circular(AppRadius.md.r),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 6.h),
            child: Text(
              AppLocalizations.of(context)!.accountPublication,
              style: TextStyle(
                color: ext.searchHintColor,
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.lg.w),
            activeThumbColor: ext.greetingColor,
            activeTrackColor: ext.searchHintColor.withValues(alpha: 0.4),
            title: Text(
              AppLocalizations.of(context)!.accountAlwaysPublicImages,
              style: TextStyle(color: ext.greetingColor, fontSize: 14.sp),
            ),
            subtitle: Text(
              alwaysPublic
                  ? AppLocalizations.of(context)!.accountUploadsPublicByDefault
                  : AppLocalizations.of(context)!
                      .accountUploadsPrivateByDefault,
              style: TextStyle(color: ext.searchHintColor, fontSize: 12.sp),
            ),
            secondary: Icon(
              Icons.public_rounded,
              color: alwaysPublic ? ext.greetingColor : ext.searchHintColor,
            ),
            value: alwaysPublic,
            onChanged: (value) {
              context.read<UserProfileBloc>().add(PublicImagesToggled(value));
            },
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          ListTile(
            contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.lg.w),
            leading: Icon(Icons.bookmark_rounded, color: ext.searchHintColor),
            title: Text(
              AppLocalizations.of(context)!.accountSavedItems,
              style: TextStyle(
                  color: ext.greetingColor,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              AppLocalizations.of(context)!.accountViewBookmarkedEvents,
              style: TextStyle(color: ext.searchHintColor, fontSize: 12.sp),
            ),
            trailing: Icon(Icons.chevron_right_rounded,
                color: ext.searchHintColor, size: 20.sp),
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
          SizedBox(height: AppSpacing.xs.h),
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
    return Material(
      // Material, not a decorated Container: ListTile paints its highlight and
      // ink splash onto the nearest Material ancestor, so a DecoratedBox
      // between the two swallows them (and trips an assertion in debug).
      // Giving the card itself a Material means the ink lands on top of the
      // card, clipped to its corners.
      color: ext.cardSurface,
      borderRadius: BorderRadius.circular(AppRadius.md.r),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 6.h),
            child: Text(
              AppLocalizations.of(context)!.accountPrivacy,
              style: TextStyle(
                color: ext.searchHintColor,
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.lg.w),
            activeThumbColor: ext.greetingColor,
            activeTrackColor: ext.searchHintColor.withValues(alpha: 0.4),
            title: Text(
              AppLocalizations.of(context)!.accountAnonymousComments,
              style: TextStyle(color: ext.greetingColor, fontSize: 14.sp),
            ),
            subtitle: Text(
              anonymousMode
                  ? AppLocalizations.of(context)!.accountAnonymousModeOn
                  : AppLocalizations.of(context)!.accountAnonymousModeOff,
              style: TextStyle(color: ext.searchHintColor, fontSize: 12.sp),
            ),
            secondary: isAnonymousModeUpdating
                ? SizedBox(
                    width: 20.w,
                    height: 20.w,
                    child: CircularProgressIndicator(
                        color: ext.searchHintColor, strokeWidth: 2),
                  )
                : Icon(
                    Icons.person_off_outlined,
                    color:
                        anonymousMode ? ext.greetingColor : ext.searchHintColor,
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
            contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.lg.w),
            activeThumbColor: ext.greetingColor,
            activeTrackColor: ext.searchHintColor.withValues(alpha: 0.4),
            title: Text(
              AppLocalizations.of(context)!.accountHideProfile,
              style: TextStyle(color: ext.greetingColor, fontSize: 14.sp),
            ),
            subtitle: Text(
              hideProfile
                  ? AppLocalizations.of(context)!.accountHideProfileOn
                  : AppLocalizations.of(context)!.accountHideProfileOff,
              style: TextStyle(color: ext.searchHintColor, fontSize: 12.sp),
            ),
            secondary: isHideProfileUpdating
                ? SizedBox(
                    width: 20.w,
                    height: 20.w,
                    child: CircularProgressIndicator(
                        color: ext.searchHintColor, strokeWidth: 2),
                  )
                : Icon(
                    Icons.visibility_off_outlined,
                    color:
                        hideProfile ? ext.greetingColor : ext.searchHintColor,
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
          SizedBox(height: AppSpacing.xs.h),
        ],
      ),
    );
  }
}

// ── Notification settings card ────────────────────────────────────────────────

class _NotificationSettingsCard extends StatelessWidget {
  const _NotificationSettingsCard({required this.isMuted, required this.ext});

  final bool isMuted;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    return Material(
      // Material, not a decorated Container: ListTile paints its highlight and
      // ink splash onto the nearest Material ancestor, so a DecoratedBox
      // between the two swallows them (and trips an assertion in debug).
      // Giving the card itself a Material means the ink lands on top of the
      // card, clipped to its corners.
      color: ext.cardSurface,
      borderRadius: BorderRadius.circular(AppRadius.md.r),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 6.h),
            child: Text(
              AppLocalizations.of(context)!.accountNotifications,
              style: TextStyle(
                color: ext.searchHintColor,
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.lg.w),
            activeThumbColor: ext.greetingColor,
            activeTrackColor: ext.searchHintColor.withValues(alpha: 0.4),
            title: Text(
              AppLocalizations.of(context)!.accountMuteNotifications,
              style: TextStyle(color: ext.greetingColor, fontSize: 14.sp),
            ),
            subtitle: Text(
              isMuted
                  ? AppLocalizations.of(context)!.accountMutedOn
                  : AppLocalizations.of(context)!.accountMutedOff,
              style: TextStyle(color: ext.searchHintColor, fontSize: 12.sp),
            ),
            secondary: Icon(
              isMuted
                  ? Icons.notifications_off_outlined
                  : Icons.notifications_outlined,
              color: isMuted ? ext.searchHintColor : ext.greetingColor,
            ),
            value: isMuted,
            onChanged: (value) {
              context
                  .read<UserProfileBloc>()
                  .add(NotificationsMuteToggled(value));
            },
          ),
          SizedBox(height: AppSpacing.xs.h),
        ],
      ),
    );
  }
}

// ── Ads & Promotions card ─────────────────────────────────────────────────────

class _AdsCard extends StatelessWidget {
  const _AdsCard({required this.ext});
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppConfig>(
      valueListenable: AppConfigRepository.notifier,
      builder: (context, cfg, _) {
        return FutureBuilder<bool>(
          future: sl<AuthService>().isSuperAdmin(),
          builder: (context, adminSnap) {
            final isAdmin = adminSnap.data == true;
            final showRequests = cfg.requestsEnabled;
            final showAds = cfg.adsEnabled;

            // "Creators" used to seed this list — it has moved elsewhere. Every
            // block below guards its own leading divider, so the list starting
            // empty is fine.
            final tiles = <Widget>[];

            if (showRequests || showAds) {
              if (tiles.isNotEmpty) {
                tiles.add(const Divider(height: 1, indent: 16, endIndent: 16));
              }
              tiles.add(_AdsListTile(
                icon: Icons.add_circle_outline_rounded,
                iconColor: const Color(0xFF10B981),
                title: 'Create',
                subtitle: 'Post a request or start an ad campaign',
                ext: ext,
                onTap: () => CreateBottomSheet.show(context),
              ));
            }

            if (showRequests) {
              if (tiles.isNotEmpty) {
                tiles.add(const Divider(height: 1, indent: 16, endIndent: 16));
              }
              tiles.add(_AdsListTile(
                icon: Icons.inbox_outlined,
                iconColor: ext.infoBlue,
                title: 'Request Board',
                subtitle: 'Browse open requests from others',
                ext: ext,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RequestBoardPage()),
                ),
              ));
              tiles.add(const Divider(height: 1, indent: 16, endIndent: 16));
              tiles.add(_AdsListTile(
                icon: Icons.edit_note_rounded,
                iconColor: const Color(0xFF10B981),
                title: 'My Requests',
                subtitle: 'Manage the requests you posted',
                ext: ext,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const MyRequestsPage()),
                ),
              ));
            }

            if (showAds) {
              if (tiles.isNotEmpty) {
                tiles.add(const Divider(height: 1, indent: 16, endIndent: 16));
              }
              tiles.add(_AdsListTile(
                icon: Icons.rocket_launch_rounded,
                iconColor: Colors.deepOrange,
                title: 'My Campaigns',
                subtitle: 'Track and top up your ad campaigns',
                ext: ext,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const MyCampaignsPage()),
                ),
              ));
            }

            if (isAdmin) {
              if (tiles.isNotEmpty) {
                tiles.add(const Divider(height: 1, indent: 16, endIndent: 16));
              }
              tiles.add(_AdsListTile(
                icon: Icons.admin_panel_settings_rounded,
                iconColor: const Color(0xFFEF4444),
                title: 'Admin Settings',
                subtitle: 'Configure feed, ads, and app-wide settings',
                ext: ext,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AdminSettingsPage()),
                ),
              ));
            }

            // Nothing to promote: requests and ads both switched off for a
            // non-admin. Reachable now that "Creators" no longer holds the list
            // open — a card with a heading and no rows under it would read as
            // something that failed to load.
            if (tiles.isEmpty) return const SizedBox.shrink();

            return Material(
              // Material, not a decorated Container: ListTile paints its
              // highlight and ink splash onto the nearest Material ancestor,
              // so a DecoratedBox between the two swallows them (and trips an
              // assertion in debug). Same treatment as every sibling card.
              color: ext.cardSurface,
              borderRadius: BorderRadius.circular(AppRadius.md.r),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 6.h),
                    child: Text(
                      'ADS & PROMOTIONS',
                      style: TextStyle(
                        color: ext.searchHintColor,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  ...tiles,
                  SizedBox(height: AppSpacing.xs.h),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ── Face Recognition card ─────────────────────────────────────────────────────

class _FaceRecognitionCard extends StatefulWidget {
  const _FaceRecognitionCard({required this.ext});
  final AppThemeExtension ext;

  @override
  State<_FaceRecognitionCard> createState() => _FaceRecognitionCardState();
}

class _FaceRecognitionCardState extends State<_FaceRecognitionCard> {
  bool _deleting = false;

  /// Asks for confirmation, then calls `DELETE /client/face-data` to wipe the
  /// user's enrolled face embeddings. The endpoint is idempotent and derives
  /// the user from the auth token, so no body is sent.
  Future<void> _deleteFaceData() async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Delete your face data?',
      message: 'This permanently removes your face from recognition so you '
          'will no longer be matched in future event photos. This cannot '
          'be undone — you would need to re-add your photos to be found '
          'again.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;

    setState(() => _deleting = true);
    try {
      final res = await sl<Api>().dio.delete('/client/face-data');
      // 200 → { "status": "deleted" | "not_found" }. Both mean no embeddings
      // remain, so re-prompt enrollment by clearing the local flag.
      if (res.statusCode == 200) {
        await sl<AuthService>().setHasAddedFaces(false);
        if (!mounted) return;
        final status = (res.data is Map) ? res.data['status'] as String? : null;
        AppSnackBar.success(
          context,
          status == 'not_found'
              ? 'No face data was found — nothing to delete.'
              : 'Your face data has been deleted.',
        );
      } else {
        if (!mounted) return;
        AppSnackBar.error(
            context, 'Could not delete face data. Please try again.');
      }
    } on dio_pkg.DioException catch (e) {
      // 400 → the similarity service rejected the delete; local state is
      // untouched server-side, so ask the user to retry rather than assume.
      if (!mounted) return;
      final msg = e.response?.statusCode == 400
          ? 'Face deletion service is busy. Please try again in a moment.'
          : 'Could not delete face data. Please check your connection.';
      AppSnackBar.error(context, msg);
    } catch (_) {
      if (mounted) {
        AppSnackBar.error(
            context, 'Could not delete face data. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = widget.ext;
    return Material(
      // Material, not a decorated Container: ListTile paints its highlight and
      // ink splash onto the nearest Material ancestor, so a DecoratedBox
      // between the two swallows them (and trips an assertion in debug).
      // Giving the card itself a Material means the ink lands on top of the
      // card, clipped to its corners.
      color: ext.cardSurface,
      borderRadius: BorderRadius.circular(AppRadius.md.r),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 6.h),
            child: Text(
              'IDENTITY',
              style: TextStyle(
                color: ext.searchHintColor,
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
          ),
          _AdsListTile(
            icon: Icons.face_outlined,
            iconColor: const Color(0xFF8B5CF6),
            title: 'Face Recognition',
            subtitle: 'Train model to find you in event photos',
            ext: ext,
            onTap: () {
              if (kIsWeb) {
                AppSnackBar.info(
                  context,
                  'Face recognition is only available on the mobile app.',
                );
                return;
              }
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const FaceRecognitionPage()),
              );
            },
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          ListTile(
            contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.lg.w),
            leading: Icon(Icons.no_accounts_outlined,
                color: _deleting ? ext.searchHintColor : Colors.redAccent),
            title: Text(
              'Delete my face data',
              style: TextStyle(
                  color: ext.greetingColor,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              'Remove your face from recognition',
              style: TextStyle(color: ext.searchHintColor, fontSize: 12.sp),
            ),
            trailing: _deleting
                ? SizedBox(
                    width: 18.w,
                    height: 18.w,
                    child: const CircularProgressIndicator(
                        color: Colors.redAccent, strokeWidth: 2),
                  )
                : Icon(Icons.chevron_right_rounded,
                    color: ext.searchHintColor, size: 20.sp),
            onTap: _deleting ? null : _deleteFaceData,
          ),
          SizedBox(height: AppSpacing.xs.h),
        ],
      ),
    );
  }
}

// ── Connections (followers / following) card ──────────────────────────────────

class _ConnectionsCard extends StatelessWidget {
  const _ConnectionsCard({required this.ext});
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    return Material(
      // Material, not a decorated Container: ListTile paints its highlight and
      // ink splash onto the nearest Material ancestor, so a DecoratedBox
      // between the two swallows them (and trips an assertion in debug).
      // Giving the card itself a Material means the ink lands on top of the
      // card, clipped to its corners.
      color: ext.cardSurface,
      borderRadius: BorderRadius.circular(AppRadius.md.r),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 6.h),
            child: Text(
              'CONNECTIONS',
              style: TextStyle(
                color: ext.searchHintColor,
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
          ),
          _AdsListTile(
            icon: Icons.group_rounded,
            iconColor: Colors.pinkAccent,
            title: 'Followers',
            subtitle: 'People who follow you',
            ext: ext,
            onTap: () => FollowListPage.open(
              context,
              initialTab: FollowListTab.followers,
            ),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          _AdsListTile(
            icon: Icons.person_add_alt_1_rounded,
            iconColor: ext.infoBlue,
            title: 'Following',
            subtitle: 'Accounts you follow',
            ext: ext,
            onTap: () => FollowListPage.open(
              context,
              initialTab: FollowListTab.following,
            ),
          ),
          SizedBox(height: AppSpacing.xs.h),
        ],
      ),
    );
  }
}

// ── Ads & Promotions card ─────────────────────────────────────────────────────

class _AdsListTile extends StatelessWidget {
  const _AdsListTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.ext,
    required this.onTap,
  });
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final AppThemeExtension ext;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.lg.w),
      leading: Icon(icon, color: iconColor),
      title: Text(
        title,
        style: TextStyle(
            color: ext.greetingColor,
            fontSize: 14.sp,
            fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: ext.searchHintColor, fontSize: 12.sp),
      ),
      trailing: Icon(Icons.chevron_right_rounded,
          color: ext.searchHintColor, size: 20.sp),
      onTap: onTap,
    );
  }
}
