import 'package:dio/dio.dart' as dio;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:jperg_app/api/dio_client_service.dart';
import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/core/theme/app_typography.dart';
import 'package:jperg_app/services/auth_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/common/widgets/app_button.dart';
import 'package:jperg_app/core/common/widgets/app_widgets.dart';
import 'package:jperg_app/core/common/widgets/user_avatar.dart';
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/utils/snackbar_utils.dart';
import 'package:jperg_app/features/location/data/models/place.dart';
import 'package:jperg_app/features/location/data/repositories/location_repository.dart';
import 'package:jperg_app/features/location/presentation/widgets/location_picker_sheet.dart';
import 'package:jperg_app/features/settings/data/profile_options.dart';
import 'package:jperg_app/features/user_profile/presentation/bloc/user_profile_bloc.dart';
import 'package:jperg_app/core/theme/app_icons.dart';

/// The profile form, on its own screen.
///
/// Same fields, same save, same endpoint as the card this replaces — the
/// design changed where they live, not what they are. Email is shown and not
/// editable: changing it is a verification flow, not a text field.
class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late final TextEditingController _name;
  late final TextEditingController _username;
  late final TextEditingController _phone;

  late String _country;
  late String _language;
  late String _locale;
  late String _timezone;
  late Set<String> _interests;

  /// The town, and the whole record behind it.
  ///
  /// Two values rather than one because a name is not a location: the
  /// coordinates are what the ad and request boards rank distance by, so the
  /// `Place` the search returned is what gets saved, and [_region] is only
  /// what the field prints. See `features/location/data/models/place.dart`.
  ///
  /// Seeded from the profile state, which now carries `location` — the
  /// profile payload used to return only `ip_region`, a column that has never
  /// been written, so the region read back empty however often it was set.
  /// `GET /api/location/context` then supplies the coordinates, which the
  /// profile payload still does not carry.
  String _region = '';
  Place? _regionPlace;

  /// What the account already had, so an untouched field saves nothing.
  Place? _savedRegionPlace;

  /// Set once the country dropdown is used, so the stored location arriving a
  /// moment later cannot overwrite a choice already made. [_readStoredRegion]
  /// is a network read started in `initState`; without this, picking a country
  /// quickly enough had it silently replaced.
  bool _countryTouched = false;

  final LocationRepository _locations = LocationRepository();

  /// The avatar as it stands. Seeded from the session, replaced by whatever
  /// the upload returns — the profile state this screen reads has never
  /// carried one.
  String? _photoUrl;
  bool _uploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    // Seeded once from the state the settings page already loaded. Rebuilding
    // the controllers on every emit would move the cursor while somebody is
    // typing into them.
    final state = context.read<UserProfileBloc>().state;
    _name = TextEditingController(text: state.name);
    _username = TextEditingController(text: state.uniqueName);
    _phone = TextEditingController(text: state.contact);
    _country = state.countryCode;
    _language = state.preferredLanguage;
    _locale = state.locale;
    _timezone = state.timezone;
    // Seeded from the profile the settings page already loaded, so the field
    // is filled on the first frame. [_readStoredRegion] then refines it with
    // the stored `Place` — the coordinates, which the profile payload does not
    // carry. Seeding here matters because that call is deliberately silent on
    // failure: without this, one failed request left the field looking as
    // though no region had ever been set.
    _region = state.location;
    _interests = state.interestTags.toSet();
    _readStoredPhoto();
    _readStoredRegion();
  }

  /// The town already on the account, for the Region field to open on.
  ///
  /// Silent on failure: an empty field prompting for a town is a far better
  /// outcome on this screen than an error banner over a form somebody opened
  /// to change their phone number.
  Future<void> _readStoredRegion() async {
    final context = await _locations.context();
    if (!mounted || context == null) return;
    final place = context.place;
    setState(() {
      _savedRegionPlace = place;
      _regionPlace = place;
      _region = context.location ?? _region;
      // The account's own country wins over the profile row's when the two
      // disagree: `PUT /api/location` writes both together, so the location's
      // is the more recently stated of the two. Never over a choice the person
      // has already made on this form, though — see [_countryTouched].
      if (!_countryTouched && (context.countryCode ?? '').isNotEmpty) {
        _country = context.countryCode!;
      }
    });
  }

  /// Store the town, if it changed.
  ///
  /// Skipped entirely when it did not: this is a second request on a form
  /// whose other fields go somewhere else, and re-sending an unchanged place
  /// would overwrite `country_code` for somebody who only edited their name.
  Future<void> _saveRegion() async {
    final place = _regionPlace;
    if (place == null || place == _savedRegionPlace) return;
    try {
      await _locations.setLocation(place);
      _savedRegionPlace = place;
    } catch (_) {
      if (mounted) {
        AppSnackBar.error(context, 'Could not save your region. Try again.');
      }
    }
  }

  /// Moving country empties the town.
  ///
  /// "Accra, Nigeria" is not a place. Leaving the old town behind would also
  /// leave its coordinates behind, and those are what distance is measured
  /// from — so the board would rank somebody against a point in a country they
  /// just said they had left.
  void _onCountryChanged(String code) {
    setState(() {
      _countryTouched = true;
      if (code == _country) return;
      _country = code;
      _region = '';
      _regionPlace = null;
    });
  }

  /// Pick a town inside the country already chosen on this form.
  ///
  /// The sheet opens on its town step rather than its country step — that is
  /// the whole fix. Choosing a country here and then being handed a second
  /// country list is what made this field look like it was asking the same
  /// question twice.
  Future<void> _pickRegion() async {
    final place = await LocationPickerSheet.show(
      context,
      title: 'Your region',
      repo: _locations,
      initialCountryCode: _country.isEmpty ? null : _country,
    );
    if (place == null || !mounted) return;
    setState(() {
      _regionPlace = place;
      // "Anywhere in Ghana" is a real answer in that sheet, and it means no
      // town — so the field goes back to empty rather than printing a country
      // name into a field labelled Region.
      _region = place.isCountryWide ? '' : place.label;
      // Kept in step with the dropdown above. The sheet can reach its country
      // step by going back, so the two must not be able to disagree — and
      // `PUT /api/location` writes the country anyway.
      if (place.countryCode.isNotEmpty) _country = place.countryCode;
    });
  }

  Future<void> _readStoredPhoto() async {
    final url = await sl<AuthService>().getProfileUrl();
    if (mounted && url.isNotEmpty) setState(() => _photoUrl = url);
  }

  /// Pick a photo and put it on the account.
  ///
  /// The badge in the design had nothing behind it here — the endpoint has
  /// existed all along and no screen in the app called it.
  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      // Uploaded at a sane size: this is a 88px circle, and a 12MP original
      // costs the person data and the server storage for nothing.
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (picked == null) return;

    setState(() => _uploadingPhoto = true);
    try {
      final clientId = await sl<AuthService>().getUserId();
      final form = dio.FormData.fromMap({
        'file': await dio.MultipartFile.fromFile(picked.path,
            filename: picked.name),
      });
      final res = await sl<Api>()
          .dio
          .post('/client/profile/$clientId/photo', data: form);
      final url = res.data?['profile_url'];
      if (url is String && url.isNotEmpty) {
        await sl<AuthService>().setProfileUrl(url);
        if (mounted) setState(() => _photoUrl = url);
      }
      if (mounted) AppSnackBar.success(context, 'Profile photo updated.');
    } catch (_) {
      if (mounted) {
        AppSnackBar.error(context, 'Could not upload that photo. Try again.');
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _phone.dispose();
    super.dispose();
  }

  /// Why this handle cannot be saved, or null when it can.
  ///
  /// The API accepts `[A-Za-z0-9_]{3,30}`. Checked here so a bad handle is a
  /// sentence under the field rather than a 422 the form cannot explain —
  /// and only when it was actually edited, because an untouched field is not
  /// something the person using the screen can be asked to fix.
  static final _handleAllowed = RegExp(r'^[A-Za-z0-9_]+$');

  String? _handleProblem(String handle, {required bool changed}) {
    if (!changed) return null;
    if (handle.length < 3) return 'A username needs at least 3 characters.';
    if (handle.length > 30) return 'A username can be at most 30 characters.';
    if (!_handleAllowed.hasMatch(handle)) {
      return 'Letters, numbers and underscores only.';
    }
    return null;
  }

  void _save() {
    final state = context.read<UserProfileBloc>().state;
    final handle = _username.text.trim();
    final problem =
        _handleProblem(handle, changed: handle != state.uniqueName);
    if (problem != null) {
      AppSnackBar.error(context, problem);
      return;
    }

    // The town goes to its own endpoint, which is also the only one that can
    // store the coordinates behind it — the profile PATCH has no field for
    // either. Not awaited: the profile save below is what the screen's
    // success and error states are wired to, and a region that fails to store
    // is reported on its own rather than by failing the whole form.
    _saveRegion();

    context.read<UserProfileBloc>().add(ProfileUpdateSubmitted(
          name: _name.text.trim(),
          uniqueName: handle,
          contact: _phone.text.trim(),
          countryCode: _country,
          locale: _locale,
          preferredLanguage: _language,
          timezone: _timezone,
          interestTags: _interests.toList(),
        ));
  }

  /// The full list, in a sheet. Chosen here rather than on the form so the
  /// form stays a form.
  Future<void> _editInterests() async {
    final chosen = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _InterestsSheet(selected: _interests),
    );
    if (chosen != null && mounted) setState(() => _interests = chosen);
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
          'Edit Profile',
          style: TextStyle(
            color: ext.greetingColor,
            fontFamily: AppTypography.displayFontFamily,
            fontSize: 16.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: BlocConsumer<UserProfileBloc, UserProfileState>(
        listenWhen: (p, c) =>
            p.isUpdateSuccess != c.isUpdateSuccess ||
            p.updateErrorMessage != c.updateErrorMessage,
        listener: (context, state) {
          if (state.isUpdateSuccess) {
            AppSnackBar.success(context, 'Profile updated.');
            Navigator.of(context).maybePop();
          }
          if (state.updateErrorMessage != null) {
            AppSnackBar.error(context, state.updateErrorMessage!);
          }
        },
        builder: (context, state) {
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(AppSpacing.lg.w, AppSpacing.lg.h,
                AppSpacing.lg.w, AppSpacing.xxxl.h),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 540),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: _AvatarField(
                        initial: state.name,
                        imageUrl: _photoUrl,
                        isBusy: _uploadingPhoto,
                        onPick: _pickPhoto,
                        ext: ext,
                      ),
                    ),
                    SizedBox(height: AppSpacing.xxl.h),
                    _Field(label: 'Full Name', controller: _name, ext: ext),
                    _Field(
                      label: 'Username',
                      controller: _username,
                      prefix: '@',
                      ext: ext,
                    ),
                    // Shown because the design shows it, and read-only because
                    // changing an email means re-verifying it — a flow, not a
                    // text field.
                    _ReadOnlyField(
                        label: 'Email', value: state.email, ext: ext),
                    _Field(
                      label: 'Phone',
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      ext: ext,
                    ),
                    _Dropdown(
                      label: 'Country',
                      value: _country,
                      options: kCountryOptions,
                      onChanged: _onCountryChanged,
                      ext: ext,
                    ),
                    // A town inside the country chosen above, not a second
                    // country list. The field this used to be was bound to
                    // `locale` and labelled "Region", so picking Ghana and
                    // then opening "Region" offered "English (US)" and
                    // "French (France)" — which reads as being asked for a
                    // country again, and stored something else entirely.
                    _RegionField(
                      value: _region,
                      countryCode: _country,
                      onTap: _pickRegion,
                      ext: ext,
                    ),
                    _Dropdown(
                      label: 'Language',
                      value: _language,
                      options: kLanguageOptions,
                      onChanged: (v) => setState(() => _language = v),
                      ext: ext,
                    ),
                    // The locale, under its own name. It is a language-and-
                    // country pair used for formatting, which is why offering
                    // it as "Region" was the whole confusion.
                    _Dropdown(
                      label: 'Locale',
                      value: _locale,
                      options: kLocaleOptions,
                      onChanged: (v) => setState(() => _locale = v),
                      ext: ext,
                    ),
                    _Dropdown(
                      label: 'Timezone',
                      value: _timezone,
                      options: kTimezoneOptions,
                      onChanged: (v) => setState(() => _timezone = v),
                      ext: ext,
                    ),
                    SizedBox(height: AppSpacing.md.h),
                    _Label('Interests', ext),
                    SizedBox(height: AppSpacing.sm.h),
                    // What you have chosen, and a way to change it — not all
                    // eighteen tags at once. The design shows the selection
                    // and an Edit link, and eighteen chips on the form is a
                    // wall between the phone number and the save button.
                    Wrap(
                      spacing: AppSpacing.sm.w,
                      runSpacing: AppSpacing.sm.h,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        for (final tag in _interests)
                          _InterestChip(
                            label: tag,
                            selected: true,
                            onTap: () => setState(() => _interests.remove(tag)),
                            ext: ext,
                          ),
                        GestureDetector(
                          onTap: _editInterests,
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm.w,
                                vertical: AppSpacing.xs.h),
                            child: Text(
                              _interests.isEmpty
                                  ? 'Choose interests'
                                  : 'Edit Interests',
                              style: TextStyle(
                                color: ext.accentGold,
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w500,
                                decoration: TextDecoration.underline,
                                decorationColor: ext.accentGold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: AppSpacing.xxl.h),
                    AppButton(
                      fullWidth: true,
                      label: 'Save changes',
                      borderRadius: AppRadius.pill,
                      isLoading: state.isUpdateLoading,
                      onPressed: state.isUpdateLoading ? null : _save,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    return page;
  }
}

/// The avatar, and the badge that changes it.
///
/// The badge is the design's, and it now does what it looks like it does: pick
/// a photo, upload it, wear it. It was drawn over an endpoint no screen in the
/// app had ever called.
class _AvatarField extends StatelessWidget {
  const _AvatarField({
    required this.initial,
    required this.imageUrl,
    required this.isBusy,
    required this.onPick,
    required this.ext,
  });

  final String initial;
  final String? imageUrl;
  final bool isBusy;
  final VoidCallback onPick;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        UserAvatar(initial: initial, imageUrl: imageUrl, radius: 44.r),
        if (isBusy)
          SizedBox(
            width: 88.r,
            height: 88.r,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: ext.accentGold,
            ),
          ),
        Positioned(
          bottom: -6.h,
          child: Semantics(
            button: true,
            label: 'Change profile photo',
            child: GestureDetector(
              onTap: isBusy ? null : onPick,
              child: Container(
                padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm.w, vertical: AppSpacing.xs.h),
                decoration: BoxDecoration(
                  color: const Color(0xFF1D9E75),
                  borderRadius: BorderRadius.circular(AppRadius.pill.r),
                  border: Border.all(color: ext.homeBackground, width: 2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppSvgIcon(AppIcons.camera,
                        size: 12.sp, color: Colors.white),
                    SizedBox(width: 4.w),
                    Text(
                      'Edit',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text, this.ext);
  final String text;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: TextStyle(
            color: ext.searchHintColor,
            fontSize: 12.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    required this.ext,
    this.prefix,
    this.keyboardType,
  });

  final String label;
  final TextEditingController controller;
  final AppThemeExtension ext;
  final String? prefix;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.lg.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Label(label, ext),
          SizedBox(height: AppSpacing.xs.h),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: TextStyle(color: ext.greetingColor, fontSize: 15.sp),
            decoration: InputDecoration(
              prefixText: prefix,
              prefixStyle:
                  TextStyle(color: ext.searchHintColor, fontSize: 15.sp),
              filled: true,
              fillColor: ext.cardSurface,
              contentPadding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.md.w, vertical: AppSpacing.md.h),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md.r),
                borderSide: BorderSide(
                    color: ext.searchHintColor.withValues(alpha: 0.25)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md.r),
                borderSide: BorderSide(
                    color: ext.searchHintColor.withValues(alpha: 0.25)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({
    required this.label,
    required this.value,
    required this.ext,
  });

  final String label;
  final String value;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.lg.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Label(label, ext),
          SizedBox(height: AppSpacing.xs.h),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.md.w, vertical: AppSpacing.md.h + 2.h),
            decoration: BoxDecoration(
              color: ext.cardSurface,
              borderRadius: BorderRadius.circular(AppRadius.md.r),
              border: Border.all(
                  color: ext.searchHintColor.withValues(alpha: 0.15)),
            ),
            child: Text(
              value,
              style: TextStyle(
                color: ext.searchHintColor,
                fontSize: 15.sp,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Dropdown extends StatelessWidget {
  const _Dropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    required this.ext,
  });

  final String label;
  final String value;
  final Map<String, String> options;
  final ValueChanged<String> onChanged;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    // A stored value the list does not offer — an older account, or a list
    // that has since changed — would throw rather than render, so it falls
    // back to no selection instead.
    final current = options.containsKey(value) ? value : null;

    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.lg.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Label(label, ext),
          SizedBox(height: AppSpacing.xs.h),
          DropdownButtonFormField<String>(
            initialValue: current,
            isExpanded: true,
            dropdownColor: ext.cardSurface,
            style: TextStyle(color: ext.greetingColor, fontSize: 15.sp),
            decoration: InputDecoration(
              filled: true,
              fillColor: ext.cardSurface,
              contentPadding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.md.w, vertical: AppSpacing.md.h),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md.r),
                borderSide: BorderSide(
                    color: ext.searchHintColor.withValues(alpha: 0.25)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md.r),
                borderSide: BorderSide(
                    color: ext.searchHintColor.withValues(alpha: 0.25)),
              ),
            ),
            items: [
              for (final entry in options.entries)
                DropdownMenuItem(value: entry.key, child: Text(entry.value)),
            ],
            onChanged: (v) => v == null ? null : onChanged(v),
          ),
        ],
      ),
    );
  }
}

/// The Region row: a town, chosen from a search inside the country above.
///
/// A tappable field rather than a dropdown, because there is no list to put in
/// one. Towns come from a geocoder — the app has never shipped a town list and
/// could not keep one — so the control has to be a search, and the search is
/// the sheet every other part of the app already picks places with.
class _RegionField extends StatelessWidget {
  const _RegionField({
    required this.value,
    required this.countryCode,
    required this.onTap,
    required this.ext,
  });

  /// The town's name, or empty when none is set.
  final String value;

  /// Only used for the hint — the sheet is what scopes the search.
  final String countryCode;

  final VoidCallback onTap;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    final country = kCountryOptions[countryCode];
    final empty = value.trim().isEmpty;
    // Naming the country in the hint is what tells somebody the list they are
    // about to see is towns in *their* country, before they tap it.
    final hint = country == null
        ? 'Choose a town or city'
        : 'Choose a town or city in $country';

    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.lg.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Label('Region', ext),
          SizedBox(height: AppSpacing.xs.h),
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.md.r),
            child: Container(
              padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.md.w, vertical: AppSpacing.md.h),
              decoration: BoxDecoration(
                color: ext.cardSurface,
                borderRadius: BorderRadius.circular(AppRadius.md.r),
                border: Border.all(
                    color: ext.searchHintColor.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  Icon(Icons.location_on_outlined,
                      size: 18.sp, color: ext.searchHintColor),
                  SizedBox(width: AppSpacing.sm.w),
                  Expanded(
                    child: Text(
                      empty ? hint : value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15.sp,
                        color: empty ? ext.searchHintColor : ext.greetingColor,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded,
                      size: 20.sp, color: ext.searchHintColor),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InterestChip extends StatelessWidget {
  const _InterestChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.ext,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.md.w, vertical: AppSpacing.xs.h + 2.h),
          decoration: BoxDecoration(
            color: selected
                ? ext.accentGold.withValues(alpha: 0.18)
                : ext.cardSurface,
            borderRadius: BorderRadius.circular(AppRadius.pill.r),
            border: Border.all(
              color: selected
                  ? ext.accentGold.withValues(alpha: 0.6)
                  : ext.searchHintColor.withValues(alpha: 0.25),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? ext.greetingColor : ext.searchHintColor,
              fontSize: 12.sp,
              fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

/// Every interest, as a sheet over the form.
///
/// Its own selection until Done: backing out of a sheet should leave the form
/// as it was, which it cannot do if every tap has already changed it.
class _InterestsSheet extends StatefulWidget {
  const _InterestsSheet({required this.selected});

  final Set<String> selected;

  @override
  State<_InterestsSheet> createState() => _InterestsSheetState();
}

class _InterestsSheetState extends State<_InterestsSheet> {
  late final Set<String> _chosen = {...widget.selected};

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return Container(
      padding: EdgeInsets.fromLTRB(
          AppSpacing.lg.w, AppSpacing.md.h, AppSpacing.lg.w, AppSpacing.xxl.h),
      decoration: BoxDecoration(
        color: ext.homeBackground,
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.lg.r)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: AppDragHandle()),
            SizedBox(height: AppSpacing.lg.h),
            Text(
              'Your interests',
              style: TextStyle(
                color: ext.greetingColor,
                fontFamily: AppTypography.displayFontFamily,
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: AppSpacing.xs.h),
            Text(
              'What you like to see. We use these to choose what to show you.',
              style: TextStyle(color: ext.searchHintColor, fontSize: 12.sp),
            ),
            SizedBox(height: AppSpacing.lg.h),
            Flexible(
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: AppSpacing.sm.w,
                  runSpacing: AppSpacing.sm.h,
                  children: [
                    for (final tag in kInterestTags)
                      _InterestChip(
                        label: tag,
                        selected: _chosen.contains(tag),
                        onTap: () => setState(() {
                          _chosen.contains(tag)
                              ? _chosen.remove(tag)
                              : _chosen.add(tag);
                        }),
                        ext: ext,
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(height: AppSpacing.xl.h),
            AppButton(
              fullWidth: true,
              borderRadius: AppRadius.pill,
              label: 'Done',
              onPressed: () => Navigator.of(context).pop(_chosen),
            ),
          ],
        ),
      ),
    );
  }
}
