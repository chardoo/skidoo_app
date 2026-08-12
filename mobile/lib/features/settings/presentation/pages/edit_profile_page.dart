import 'package:dio/dio.dart' as dio;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:jperg_app/api/dio_client_service.dart';
import 'package:jperg_app/core/di/service_locator.dart';
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
import 'package:jperg_app/core/utils/web_wrap.dart';
import 'package:jperg_app/features/settings/data/profile_options.dart';
import 'package:jperg_app/features/user_profile/presentation/bloc/user_profile_bloc.dart';

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
    _interests = state.interestTags.toSet();
    _readStoredPhoto();
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

  void _save() {
    context.read<UserProfileBloc>().add(ProfileUpdateSubmitted(
          name: _name.text.trim(),
          uniqueName: _username.text.trim(),
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
                        initial: state.name.isNotEmpty ? state.name : '?',
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
                      onChanged: (v) => setState(() => _country = v),
                      ext: ext,
                    ),
                    _Dropdown(
                      label: 'Language',
                      value: _language,
                      options: kLanguageOptions,
                      onChanged: (v) => setState(() => _language = v),
                      ext: ext,
                    ),
                    _Dropdown(
                      label: 'Region',
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
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w600,
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

    return webWrap(page, backgroundColor: ext.homeBackground);
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
                    Icon(Icons.photo_camera_rounded,
                        size: 12.sp, color: Colors.white),
                    SizedBox(width: 4.w),
                    Text(
                      'Edit',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w600,
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
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
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
