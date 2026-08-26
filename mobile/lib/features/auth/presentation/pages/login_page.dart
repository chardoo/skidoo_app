import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:jperg_app/l10n/app_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/core/validators/validators.dart';
import 'package:jperg_app/features/auth/presentation/bloc/login/login_bloc.dart';
import 'package:jperg_app/features/auth/presentation/pages/email_verification_page.dart';
import 'package:jperg_app/features/auth/presentation/pages/forget_password_page.dart';
import 'package:jperg_app/features/auth/presentation/pages/interests_page.dart';
import 'package:jperg_app/core/common/widgets/app_text_field.dart';
import 'package:jperg_app/core/common/widgets/jperg_logo.dart';
import 'package:jperg_app/features/discovery/presentation/pages/discovery_page.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/utils/snackbar_utils.dart';
import 'package:jperg_app/features/chat/presentation/bloc/rooms/chat_rooms_bloc.dart';
import 'package:jperg_app/features/home/presentation/pages/home_page.dart';
import 'package:jperg_app/core/utils/web_wrap.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';

// ── Design tokens ──────────────────────────────────────────────────────────────
// The teal gradient logo/CTA is the auth flow's fixed brand accent — it stays
// the same in both themes. Background/text below are theme-aware (see `ext`).
const _kTeal        = Color(0xFF1D9E75);
const _kTealDark    = Color(0xFF16795B);

class LoginPage extends StatelessWidget {
  static const routeName = '/login';
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<LoginBloc>(),
      child: const _LoginView(),
    );
  }
}

class _LoginView extends StatefulWidget {
  const _LoginView();
  @override
  State<_LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<_LoginView>
    with SingleTickerProviderStateMixin {
  final _formKey              = GlobalKey<FormState>();
  final _emailController      = TextEditingController();
  final _passwordController   = TextEditingController();
  late final AnimationController _fadeCtrl;
  late final Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
    // Rebuild as the user types so the Sign-in button enables/disables.
    _emailController.addListener(_onFieldChanged);
    _passwordController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  bool get _fieldsFilled =>
      _emailController.text.trim().isNotEmpty &&
      _passwordController.text.isNotEmpty;

  /// Leave the gate and carry on without an account.
  ///
  /// Two ways onto this screen, and they want opposite things. Opened as a
  /// route by somebody starting the app signed out, there is nothing behind it
  /// — so the guest feed replaces the stack. Pushed on top of a feed a guest
  /// was already browsing (the Found gate, via `openSignIn`), popping is what
  /// "continue" means: it puts them back exactly where they were, still
  /// looking at whatever sent them here.
  ///
  /// `canPop` rather than a flag on the constructor, because `openSignIn`
  /// pushes this by *name* and a named route cannot carry a callback. Asking
  /// the navigator is the same question with an answer that is already true.
  void _continueAsGuest() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      navigator.pushNamedAndRemoveUntil(
        DiscoveryPage.routeName, (route) => false,
      );
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      context.read<LoginBloc>().add(LoginSubmitted(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final page = Scaffold(
      backgroundColor: ext.homeBackground,
      body: BlocConsumer<LoginBloc, LoginState>(
        listener: (context, state) {
          if (state.isSuccess) {
            // Reload rooms with the freshly-acquired auth token so the root-
            // level ChatRoomsBloc (which may have started unauthenticated)
            // connects to the WS and populates the unread-count badge.
            context.read<ChatRoomsBloc>().add(const ChatRoomsLoadRequested());
            Navigator.of(context).pushNamedAndRemoveUntil(
              state.needsInterests
                  ? InterestsPage.routeName
                  : HomePage.routeName,
              (route) => false,
            );
          }
          if (state.needsEmailVerification) {
            // Dispatch immediately so a later, unrelated state change can't
            // re-trigger this navigation while LoginPage is still on the stack.
            context.read<LoginBloc>().add(const LoginEmailVerificationHandled());
            EmailVerificationPage.push(context, email: _emailController.text.trim());
          }
          if (state.errorMessage != null && !state.isLoading) {
            AppSnackBar.error(context, state.errorMessage!);
          }
        },
        builder: (context, state) {
          return Stack(
            children: [
              // ── Ambient gradient background ──────────────────────────────
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [ext.homeBackground, ext.cardSurface],
                  ),
                ),
              ),
              // ── Radial teal glow at top ────────────────────────────────
              Positioned(
                top: -120,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    width: 320,
                    height: 320,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          _kTeal.withValues(alpha: 0.18),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // ── Content ──────────────────────────────────────────────────
              SafeArea(
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: SingleChildScrollView(
                        padding: EdgeInsets.symmetric(horizontal: 28.w),
                        child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 60.h),

                          // ── Logo ───────────────────────────────────────
                          //
                          // The real wordmark, centred. This was a generic
                          // camera glyph in a gradient tile — a stand-in that
                          // said "photo app" rather than which one, on the
                          // first screen anybody sees.
                          //
                          // Centred while the copy below stays left-aligned:
                          // the column is crossAxisAlignment.start, so the
                          // logo asks for the full width and centres itself
                          // inside that.
                          Align(
                            alignment: Alignment.center,
                            child: JpergLogo(height: 34.h, color: _kTeal),
                          ),
                          SizedBox(height: AppSpacing.xxxl.h),

                          // ── Heading ────────────────────────────────────
                          Text(
                            AppLocalizations.of(context)!.loginWelcomeBack,
                            style: TextStyle(
                              color: ext.greetingColor,
                              fontSize: 30.sp,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.5,
                              height: 1.1,
                            ),
                          ),
                          SizedBox(height: AppSpacing.sm.h),
                          Text(
                            AppLocalizations.of(context)!.loginSignInToAccount,
                            style: TextStyle(
                              color: ext.searchHintColor,
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w400,
                              letterSpacing: 0.1,
                            ),
                          ),
                          SizedBox(height: 44.h),

                          // ── Email ──────────────────────────────────────
                          AppTextField(
                            controller: _emailController,
                            label: AppLocalizations.of(context)!.loginEmailAddress,
                            prefixIcon: Icons.mail_outline_rounded,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            validator: Validators.emailValidator,
                          ),
                          SizedBox(height: AppSpacing.lg.h),

                          // ── Password ───────────────────────────────────
                          AppPasswordField(
                            controller: _passwordController,
                            label: AppLocalizations.of(context)!.loginPassword,
                            textInputAction: TextInputAction.done,
                            validator: (v) =>
                                Validators.passwordValidator(v),
                          ),
                          SizedBox(height: AppSpacing.md.h),

                          // ── Forgot password ────────────────────────────
                          Align(
                            alignment: Alignment.centerRight,
                            child: Semantics(button: true, label: 'Forget password page', child: GestureDetector(
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const ForgetPasswordPage()),
                              ),
                              child: Text(
                                AppLocalizations.of(context)!.loginForgotPassword,
                                style: TextStyle(
                                  color: _kTeal,
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            )),
                          ),
                          SizedBox(height: 36.h),

                          // ── Sign in button ─────────────────────────────
                          _GradientButton(
                            label: AppLocalizations.of(context)!.loginSignIn,
                            isLoading: state.isLoading,
                            enabled: _fieldsFilled,
                            onTap: _submit,
                          ),
                          SizedBox(height: 28.h),

                          // ── Sign up link ───────────────────────────────
                          Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  AppLocalizations.of(context)!.loginNoAccount,
                                  style: TextStyle(
                                    color: ext.searchHintColor,
                                    fontSize: 14.sp,
                                  ),
                                ),
                                Semantics(button: true, label: 'Signup', child: GestureDetector(
                                  onTap: () => Navigator.of(context)
                                      .pushReplacementNamed('/signup'),
                                  child: Text(
                                    AppLocalizations.of(context)!.loginSignUp,
                                    style: TextStyle(
                                      color: _kTeal,
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                )),
                              ],
                            ),
                          ),
                          SizedBox(height: AppSpacing.md.h),

                          // ── Continue as guest ───────────────────────────
                          // The signed-out feed is a real destination, not a
                          // consolation: someone can browse, search and find
                          // their photos before ever making an account. Sign-up
                          // has offered this from the start; login sent people
                          // looking for a way past it back out through Back.
                          Center(
                            child: Semantics(
                              button: true,
                              label: 'Continue as guest',
                              child: TextButton(
                                onPressed: _continueAsGuest,
                                child: Text(
                                  'Continue as guest',
                                  style: TextStyle(
                                    color: ext.searchHintColor,
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: AppSpacing.xxxl.h),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
            ],
          );
        },
      ),
    );
    return webWrap(page, backgroundColor: ext.homeBackground);
  }

}

// ── Shared gradient CTA button ─────────────────────────────────────────────────
class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.label,
    required this.isLoading,
    required this.onTap,
    this.enabled = true,
  });

  final String label;
  final bool isLoading;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dimmed = isLoading || !enabled;
    return Semantics(button: true, enabled: enabled && !isLoading, label: label, child: GestureDetector(
      onTap: dimmed ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 56.h,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: dimmed
                ? [_kTeal.withValues(alpha: 0.5), _kTealDark.withValues(alpha: 0.5)]
                : [_kTeal, _kTealDark],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(14.r),
          boxShadow: dimmed
              ? []
              : [
                  BoxShadow(
                    color: _kTeal.withValues(alpha: 0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: Center(
          child: isLoading
              ? SizedBox(
                  width: 24.w,
                  height: 24.w,
                  child: const CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : Text(
                  label,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
        ),
      ),
    ));
  }
}
