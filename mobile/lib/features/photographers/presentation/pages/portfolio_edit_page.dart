import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/common/widgets/app_button.dart';
import 'package:skidoo_app/core/di/service_locator.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/core/utils/snackbar_utils.dart';
import 'package:skidoo_app/core/utils/web_wrap.dart';
import 'package:skidoo_app/features/photographers/domain/usecases/get_photographer_samples_usecase.dart';
import 'package:skidoo_app/features/photographers/domain/usecases/photographer_profile_usecases.dart';
import 'package:skidoo_app/features/photographers/presentation/pages/verify_terms_page.dart';
import 'package:skidoo_app/features/photographers/presentation/widgets/portfolio_form.dart';
import 'package:skidoo_app/models/photographer/photographer_sample.dart';
import 'package:skidoo_app/services/auth_service.dart';
import 'package:skidoo_app/core/theme/app_spacing.dart';
import 'package:skidoo_app/core/common/widgets/app_back_button.dart';

/// Account-section "Portfolio" screen — a photographer's portfolio setup,
/// done on demand from Account rather than automatically during onboarding.
/// The first time (detected by an empty portfolio), saving chains into
/// [VerifyTermsPage] to complete setup; on later visits (portfolio already
/// has content) it's just an edit-and-save screen. Plain AppBar chrome,
/// matching `face_recognition_page.dart`'s convention — no step-progress
/// bar, this isn't part of the onboarding wizard.
class PortfolioEditPage extends StatefulWidget {
  const PortfolioEditPage({super.key});

  @override
  State<PortfolioEditPage> createState() => _PortfolioEditPageState();
}

class _PortfolioEditPageState extends State<PortfolioEditPage> {
  bool _loading = true;
  bool _saving = false;
  String _userId = '';
  String? _profilePhotoUrl;
  String? _studioImageUrl;
  String _studioName = '';
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
      final results = await Future.wait([
        sl<GetPhotographerProfileUseCase>().call(userId),
        sl<GetPhotographerSamplesUseCase>().call(userId),
      ]);
      final profile = results[0] as Map<String, dynamic>;
      final samples = results[1] as List<PhotographerSample>;
      if (!mounted) return;
      setState(() {
        _userId = userId;
        _profilePhotoUrl = profile['profile_url'] as String?;
        _studioImageUrl = profile['studio_image_url'] as String?;
        _studioName = (profile['studio_name'] ?? profile['name'] ?? '').toString();
        _bio = (profile['bio'] ?? '').toString();
        _specialties = ((profile['specialties'] as List?)?.map((e) => e.toString()) ?? const [])
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
      if (!mounted) return;
      if (_isFirstTimeSetup) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const VerifyTermsPage()),
        );
      } else {
        AppSnackBar.success(context, 'Portfolio updated.');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) AppSnackBar.error(context, 'Could not save your portfolio: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final page = Scaffold(
      backgroundColor: ext.homeBackground,
      appBar: AppBar(
        backgroundColor: ext.homeBackground,
        elevation: 0,
        leading: kIsWeb
            ? null
            : AppBackButton(onPressed: () => Navigator.of(context).pop()),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Portfolio',
              style: TextStyle(
                  color: ext.greetingColor, fontSize: 17.sp, fontWeight: FontWeight.w700),
            ),
            if (_verifiedByAdmin) ...[
              SizedBox(width: 6.w),
              Icon(Icons.verified_rounded, color: ext.accentGold, size: 18.sp),
            ],
          ],
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: _loading
            ? Center(child: CircularProgressIndicator(color: ext.accentGold))
            : SingleChildScrollView(
                padding: EdgeInsets.all(AppSpacing.xl.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PortfolioForm(
                      initialProfilePhotoUrl: _profilePhotoUrl,
                      initialStudioImageUrl: _studioImageUrl,
                      initialStudioName: _studioName,
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
                      label: _isFirstTimeSetup ? 'Continue' : 'Save',
                    ),
                    SizedBox(height: AppSpacing.md.h),
                  ],
                ),
              ),
      ),
    );
    return webWrap(page, backgroundColor: ext.homeBackground);
  }
}
