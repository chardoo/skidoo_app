import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:skidoo_app/l10n/app_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/common/widgets/in_app_web_view_page.dart';
import 'package:skidoo_app/core/di/service_locator.dart';
import 'package:skidoo_app/core/validators/validators.dart';
import 'package:skidoo_app/features/auth/presentation/bloc/signup/signup_bloc.dart';
import 'package:skidoo_app/features/auth/presentation/pages/email_verification_page.dart';
import 'package:skidoo_app/core/utils/snackbar_utils.dart';
import 'package:skidoo_app/features/auth/presentation/pages/login_page.dart';
import 'package:skidoo_app/features/discovery/presentation/pages/discovery_page.dart';
import 'package:skidoo_app/core/common/widgets/app_text_field.dart';
import 'package:skidoo_app/core/common/widgets/app_phone_field.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/core/utils/web_wrap.dart';

// ── Design tokens ──────────────────────────────────────────────────────────────
// The teal gradient logo/CTA is the auth flow's fixed brand accent — it stays
// the same in both themes. Background/text below are theme-aware (see `ext`).
const _kTeal        = Color(0xFF0BA98A);
const _kTealDark    = Color(0xFF078368);

// Remote privacy policy — opened in a WebView so it stays up to date without
// shipping an app update.
const _kPrivacyPolicyUrl = 'https://www.piccotechnologies.com/privacy';

class SignUpPage extends StatelessWidget {
  static const routeName = '/signup';
  const SignUpPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<SignUpBloc>(),
      child: const _SignUpView(),
    );
  }
}

class _SignUpView extends StatefulWidget {
  const _SignUpView();

  @override
  State<_SignUpView> createState() => _SignUpViewState();
}

class _SignUpViewState extends State<_SignUpView>
    with SingleTickerProviderStateMixin {
  final _formKey                  = GlobalKey<FormState>();
  final _emailController          = TextEditingController();
  final _usernameController       = TextEditingController();
  final _contactController        = TextEditingController();
  final _passwordController       = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  late final AnimationController _fadeCtrl;
  late final Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
    // Rebuild as the user types so the Create-account button enables/disables.
    for (final c in [
      _emailController,
      _usernameController,
      _contactController,
      _passwordController,
      _confirmPasswordController,
    ]) {
      c.addListener(_onFieldChanged);
    }
  }

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  bool get _requiredTextFilled =>
      _emailController.text.trim().isNotEmpty &&
      _usernameController.text.trim().isNotEmpty &&
      _contactController.text.trim().isNotEmpty &&
      _passwordController.text.isNotEmpty &&
      _confirmPasswordController.text.isNotEmpty;

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _contactController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      context.read<SignUpBloc>().add(SignUpSubmitted(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
            contact: _contactController.text.trim(),
            userName: _usernameController.text.trim(),
          ));
    }
  }

  void _continueAsGuest() {
    Navigator.of(context)
        .pushNamedAndRemoveUntil(DiscoveryPage.routeName, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final page = Scaffold(
      backgroundColor: ext.homeBackground,
      body: BlocConsumer<SignUpBloc, SignUpState>(
        listener: (context, state) {
          if (state.isSuccess) {
            EmailVerificationPage.push(context, email: state.email);
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
              // ── Radial teal glow ───────────────────────────────────────
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
                          _kTeal.withValues(alpha: 0.15),
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
                          SizedBox(height: 48.h),

                          // ── Logo mark ──────────────────────────────────
                          Container(
                            width: 52.w,
                            height: 52.w,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [_kTeal, _kTealDark],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(14.r),
                              boxShadow: [
                                BoxShadow(
                                  color: _kTeal.withValues(alpha: 0.35),
                                  blurRadius: 20,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.photo_camera_rounded,
                              color: Colors.white,
                              size: 26.sp,
                            ),
                          ),
                          SizedBox(height: 28.h),

                          // ── Heading ────────────────────────────────────
                          Text(
                            AppLocalizations.of(context)!.signupCreateAccount,
                            style: TextStyle(
                              color: ext.greetingColor,
                              fontSize: 30.sp,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.5,
                              height: 1.1,
                            ),
                          ),
                          SizedBox(height: 8.h),
                          Text(
                            AppLocalizations.of(context)!.signupSubtitle,
                            style: TextStyle(
                              color: ext.searchHintColor,
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w400,
                              letterSpacing: 0.1,
                            ),
                          ),
                          SizedBox(height: 36.h),

                          // ── Email ──────────────────────────────────────
                          AppTextField(
                            controller: _emailController,
                            label: AppLocalizations.of(context)!.signupEmailAddress,
                            hint: 'e.g. jane@example.com',
                            prefixIcon: Icons.mail_outline_rounded,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            validator: Validators.emailValidator,
                          ),
                          SizedBox(height: 14.h),

                          // ── Username ───────────────────────────────────
                          AppTextField(
                            controller: _usernameController,
                            label: AppLocalizations.of(context)!.signupUsername,
                            hint: 'e.g. jane_doe',
                            prefixIcon: Icons.person_outline_rounded,
                            textInputAction: TextInputAction.next,
                            validator: Validators.nameValidator,
                          ),
                          SizedBox(height: 14.h),

                          // ── Contact (with country dial-code dropdown) ──
                          AppPhoneField(
                            controller: _contactController,
                            label: AppLocalizations.of(context)!.signupPhoneNumber,
                            hint: 'e.g. 241234567',
                            validator: Validators.nationalPhoneValidator,
                          ),
                          SizedBox(height: 14.h),

                          // ── Password ───────────────────────────────────
                          AppPasswordField(
                            controller: _passwordController,
                            label: AppLocalizations.of(context)!.signupPassword,
                            textInputAction: TextInputAction.next,
                            validator: Validators.signupPasswordValidator,
                          ),
                          SizedBox(height: 14.h),

                          // ── Confirm password ───────────────────────────
                          AppPasswordField(
                            controller: _confirmPasswordController,
                            label: AppLocalizations.of(context)!.signupConfirmPassword,
                            textInputAction: TextInputAction.done,
                            validator: (v) {
                              if (v != _passwordController.text) {
                                return AppLocalizations.of(context)!.signupPasswordsDoNotMatch;
                              }
                              return Validators.signupPasswordValidator(v);
                            },
                          ),
                          SizedBox(height: 32.h),

                          // ── Sign up button ─────────────────────────────
                          _GradientButton(
                            label: AppLocalizations.of(context)!.signupCreateAccountButton,
                            isLoading: state.isLoading,
                            enabled: _requiredTextFilled,
                            onTap: _submit,
                          ),
                          SizedBox(height: 16.h),

                          // ── Privacy policy consent ─────────────────────
                          Center(
                            child: Wrap(
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  'By creating an account, you agree to our ',
                                  style: TextStyle(
                                      color: ext.searchHintColor, fontSize: 12.5.sp),
                                ),
                                Semantics(
                                  button: true,
                                  label: 'Privacy Policy',
                                  child: GestureDetector(
                                    onTap: () => InAppWebViewPage.open(
                                      context,
                                      url: _kPrivacyPolicyUrl,
                                      title: 'Privacy Policy',
                                    ),
                                    child: Text(
                                      'Privacy Policy',
                                      style: TextStyle(
                                        color: _kTeal,
                                        fontSize: 12.5.sp,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 20.h),

                          // ── Sign in link ───────────────────────────────
                          Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  AppLocalizations.of(context)!.signupAlreadyHaveAccount,
                                  style: TextStyle(
                                    color: ext.searchHintColor,
                                    fontSize: 14.sp,
                                  ),
                                ),
                                Semantics(button: true, label: 'Log in', child: GestureDetector(
                                  onTap: () => Navigator.of(context)
                                      .pushReplacementNamed(LoginPage.routeName),
                                  child: Text(
                                    AppLocalizations.of(context)!.signupSignIn,
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
                          SizedBox(height: 12.h),

                          // ── Continue as guest ───────────────────────────
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
                          SizedBox(height: 40.h),
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

// ── Gradient CTA button ────────────────────────────────────────────────────────
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
