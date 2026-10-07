import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/cache/session_cache.dart';
import 'package:jperg_app/core/common/widgets/app_button.dart';
import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/theme/app_typography.dart';
import 'package:jperg_app/core/utils/snackbar_utils.dart';
import 'package:jperg_app/features/photographers/domain/usecases/get_photographer_samples_usecase.dart';
import 'package:jperg_app/features/photographers/domain/usecases/photographer_profile_usecases.dart';
import 'package:jperg_app/features/photographers/presentation/pages/verify_terms_page.dart';
import 'package:jperg_app/features/photographers/presentation/widgets/creator_steps.dart';
import 'package:jperg_app/features/photographers/presentation/widgets/portfolio_form.dart';
import 'package:jperg_app/features/settings/data/account_settings_api.dart';
import 'package:jperg_app/models/photographer/photographer_sample.dart';
import 'package:jperg_app/services/auth_service.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/common/widgets/app_back_button.dart';
import 'package:jperg_app/features/photographers/presentation/pages/creator_setup_entry.dart';
import 'package:jperg_app/features/auth/presentation/widgets/onboarding_step_scaffold.dart';

/// A photographer's portfolio — the first-time setup and every later edit.
///
/// Reached three ways, and [CreatorSetupEntry] is which:
///
///  * from Account, to change a portfolio that already exists;
///  * from Account & Security's "Become a Creator", as step one of two;
///  * from "Share my work" in the signup wizard, as step 3 of 4.
///
/// Saving chains into [VerifyTermsPage] for both setup entries (and on a
/// first-ever save from the edit entry, detected by an empty portfolio); on
/// later visits it is just edit-and-save. The first-time heuristic below
/// cannot tell the three apart on its own, because a photographer whose
/// portfolio is genuinely empty looks identical to somebody starting out.
class PortfolioEditPage extends StatefulWidget {
  const PortfolioEditPage({
    super.key,
    this.entry = CreatorSetupEntry.editing,
  });

  /// Why this screen is open — see [CreatorSetupEntry]. It decides the chrome
  /// (plain app bar, the two-step row, or the wizard's four dots) and where
  /// verification goes afterwards.
  final CreatorSetupEntry entry;

  @override
  State<PortfolioEditPage> createState() => _PortfolioEditPageState();
}

/// The profile and samples the last load fetched.
///
/// Portfolio is pushed fresh from Settings and from Account every time, and it
/// opens on two requests — profile and samples — behind a full-screen spinner.
/// Neither moves unless this screen itself saves, so the second and every later
/// visit was a wait for an answer the app already had. Saving replaces it;
/// anything else that can change a portfolio bumps
/// [AppCacheSignals.portfolio].
class _PortfolioSnapshot {
  const _PortfolioSnapshot(this.profile, this.samples);
  final Map<String, dynamic> profile;
  final List<PhotographerSample> samples;
}

final _portfolioCache = SessionCache<_PortfolioSnapshot>(
  'portfolio',
  signal: AppCacheSignals.portfolio,
);

class _PortfolioEditPageState extends State<PortfolioEditPage> {
  bool _loading = true;
  bool _saving = false;
  String _userId = '';
  String? _profilePhotoUrl;
  String? _studioImageUrl;
  String _studioName = '';
  String _location = '';
  String _bio = '';
  Set<String> _specialties = {};
  bool _verifiedByAdmin = false;
  bool _isFirstTimeSetup = false;
  List<PhotographerSample> _originalSamples = [];
  PortfolioFormData? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final userId = await sl<AuthService>().getUserId();
      final Map<String, dynamic> profile;
      final List<PhotographerSample> samples;
      final cached = _portfolioCache.isFresh ? _portfolioCache.value : null;
      if (cached != null) {
        profile = cached.profile;
        samples = cached.samples;
      } else {
        final results = await Future.wait([
          sl<GetPhotographerProfileUseCase>().call(userId),
          sl<GetPhotographerSamplesUseCase>().call(userId),
        ]);
        profile = results[0] as Map<String, dynamic>;
        samples = results[1] as List<PhotographerSample>;
        _portfolioCache.save(_PortfolioSnapshot(profile, samples));
      }
      if (!mounted) return;
      setState(() {
        _userId = userId;
        _profilePhotoUrl = profile['profile_url'] as String?;
        _studioImageUrl = profile['studio_image_url'] as String?;
        _studioName =
            (profile['studio_name'] ?? profile['name'] ?? '').toString();
        _bio = (profile['bio'] ?? '').toString();
        _location = (profile['location'] ?? '').toString();
        _specialties =
            ((profile['specialties'] as List?)?.map((e) => e.toString()) ??
                    const [])
                .toSet();
        _verifiedByAdmin = profile['verified_by_admin'] == true;
        _originalSamples = samples;
        // Heuristic for "never set up a portfolio before": no bio, no
        // studio name, no specialties, no samples yet. Used to decide
        // whether saving should chain into verification (first time) or
        // just save-and-return (editing an existing portfolio).
        _isFirstTimeSetup = _studioName.isEmpty &&
            _bio.isEmpty &&
            _specialties.isEmpty &&
            samples.isEmpty;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      AppSnackBar.error(context, 'Could not load your portfolio: $e');
    }
  }

  Future<void> _save() async {
    final data = _data;
    if (data == null || _saving) return;
    setState(() => _saving = true);
    try {
      if (data.newSampleFiles.isNotEmpty) {
        await sl<UploadSamplesUseCase>().call(
          photographerId: _userId,
          files: data.newSampleFiles,
        );
      }
      final keptIds = data.keptExistingSamples.map((s) => s.id).toSet();
      final removed = _originalSamples.where((s) => !keptIds.contains(s.id));
      for (final sample in removed) {
        await sl<DeleteSampleUseCase>()
            .call(sampleId: sample.id, photographerId: _userId);
      }
      await sl<UpdatePhotographerProfileUseCase>().call(
        photographerId: _userId,
        studioName: data.studioName,
        bio: data.bio,
        location: data.location,
        specialties: data.specialties.toList(),
      );
      if (data.newProfilePhoto != null) {
        await sl<UploadPhotographerProfilePhotoUseCase>().call(
          photographerId: _userId,
          photo: data.newProfilePhoto!,
        );
      }
      if (data.newStudioImage != null) {
        await sl<UploadStudioImageUseCase>().call(
          photographerId: _userId,
          image: data.newStudioImage!,
        );
      }
      // Every one of the calls above moved something the cached snapshot
      // describes, and the uploads answer with URLs this screen never sees —
      // so it is dropped rather than patched, and the next open refetches.
      // Becoming a creator also flips the role, which Account & Security reads.
      AppCacheSignals.portfolio.bump();
      AccountSettingsApi.invalidate();
      if (!mounted) return;
      if (widget.entry.isSetup || _isFirstTimeSetup) {
        // pushReplacement, so Back from verification does not land on a form
        // that has already been saved. `finished` is what VerifyTermsPage
        // reports once the whole wizard is through.
        final finished =
            await Navigator.of(context).pushReplacement<bool, void>(
          MaterialPageRoute(
            builder: (_) => VerifyTermsPage(entry: widget.entry),
          ),
        );
        // Not from onboarding: the wizard's last screen clears the stack
        // itself, so there is nothing here to pop back to and no caller
        // waiting on an answer.
        if (mounted && !widget.entry.isOnboarding) {
          Navigator.of(context).pop(finished ?? false);
        }
      } else {
        AppSnackBar.success(context, 'Portfolio updated.');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.error(context, 'Could not save your portfolio: $e');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// The form and its button — the same on every entry, so only the chrome
  /// around it changes.
  ///
  /// The button flows under the sample grid rather than being pinned to the
  /// bottom of the screen, which is how the design draws it on all three:
  /// the grid grows as photos are added, and a pinned button would float away
  /// from the thing it acts on.
  Widget _form(AppThemeExtension ext) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PortfolioForm(
            initialProfilePhotoUrl: _profilePhotoUrl,
            initialStudioImageUrl: _studioImageUrl,
            initialStudioName: _studioName,
            initialLocation: _location,
            initialBio: _bio,
            initialSpecialties: _specialties,
            initialSamples: _originalSamples,
            onChanged: (data) => setState(() => _data = data),
          ),
          SizedBox(height: AppSpacing.xxl.h),
          AppButton(
            fullWidth: true,
            isLoading: _saving,
            onPressed: (_data?.meetsMinimumSamples ?? false) ? _save : null,
            label: widget.entry.isSetup || _isFirstTimeSetup
                ? 'Continue'
                : 'Save',
          ),
          SizedBox(height: AppSpacing.md.h),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    // Step 3 of the signup wizard, wearing the wizard's chrome rather than an
    // app bar — the four dots are the only thing telling somebody mid-signup
    // how much is left, and a screen that drops them reads as a dead end.
    if (widget.entry.isOnboarding) {
      return OnboardingStepScaffold(
        currentStep: 3,
        totalSteps: 4,
        title: 'Set up your portfolio',
        subtitle: 'This is what shows on your public profile',
        child: _loading
            ? Center(child: CircularProgressIndicator(color: ext.accentGold))
            : _form(ext),
      );
    }

    final page = Scaffold(
      backgroundColor: ext.homeBackground,
      appBar: AppBar(
        backgroundColor: ext.homeBackground,
        elevation: 0,
        leading: const AppBackButton(),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.entry.isSetup ? 'Become a Creator' : 'Portfolio',
              style: TextStyle(
                  color: ext.greetingColor,
                  fontFamily: AppTypography.displayFontFamily,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700),
            ),
            if (_verifiedByAdmin) ...[
              SizedBox(width: 6.w),
              Icon(Icons.verified_rounded, color: ext.accentGold, size: 18.sp),
            ],
          ],
        ),
        centerTitle: widget.entry.isSetup,
      ),
      body: SafeArea(
        child: _loading
            ? Center(child: CircularProgressIndicator(color: ext.accentGold))
            : SingleChildScrollView(
                padding: EdgeInsets.all(AppSpacing.xl.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.entry.isSetup) ...[
                      const Center(child: CreatorSteps(current: 0)),
                      SizedBox(height: AppSpacing.lg.h),
                      Text(
                        'Profile info',
                        style: TextStyle(
                          color: ext.greetingColor,
                          fontFamily: AppTypography.displayFontFamily,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: AppSpacing.xs.h),
                      Text(
                        'This is what shows on your public profile',
                        style: TextStyle(
                          color: ext.searchHintColor,
                          fontSize: 14.sp,
                        ),
                      ),
                      SizedBox(height: AppSpacing.lg.h),
                    ],
                    _form(ext),
                  ],
                ),
              ),
      ),
    );
    return page;
  }
}
