import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/core/utils/web_wrap.dart';
import 'package:jperg_app/features/auth/presentation/pages/signup_page.dart';
import 'package:jperg_app/features/onboarding/presentation/models/onboarding_slide.dart';
import 'package:jperg_app/features/onboarding/presentation/widgets/onboarding_actions_section.dart';
import 'package:jperg_app/features/onboarding/presentation/widgets/onboarding_slide_view.dart';
import 'package:jperg_app/services/auth_service.dart';

const _kBg = Color(0xFF111110);
const _kTeal = Color(0xFF1D9E75);

/// First-run marketing carousel. Shown once ever — [AuthService.setHasSeenOnboarding]
/// is set when the user leaves this page (Skip or finishing the last slide),
/// after which the app always lands on sign-up/discovery/home directly.
class OnboardingPage extends StatefulWidget {
  static const routeName = '/onboarding';

  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await sl<AuthService>().setHasSeenOnboarding();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(SignUpPage.routeName);
  }

  void _continue() {
    if (_index == kOnboardingSlides.length - 1) {
      _finish();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _index == kOnboardingSlides.length - 1;
    final page = Scaffold(
      backgroundColor: _kBg,
      body: Column(
        children: [
          // ── Slides: full-bleed hero photo + copy, edge-to-edge at top ──
          Expanded(
            child: PageView.builder(
              controller: _controller,
              itemCount: kOnboardingSlides.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) => OnboardingSlideView(
                slide: kOnboardingSlides[i],
                slideCount: kOnboardingSlides.length,
                activeIndex: _index,
                accentColor: _kTeal,
                backgroundColor: _kBg,
              ),
            ),
          ),

          // ── Get Started/Continue + Skip ─────────────────────────────────
          SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(24.w, 24.h, 24.w, 12.h),
              child: OnboardingActionsSection(
                isLast: isLast,
                accentColor: _kTeal,
                onContinue: _continue,
                onSkip: _finish,
              ),
            ),
          ),
        ],
      ),
    );
    return webWrap(page, backgroundColor: _kBg);
  }
}
