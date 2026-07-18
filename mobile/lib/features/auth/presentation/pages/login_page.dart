import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:skidoo_app/l10n/app_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/di/service_locator.dart';
import 'package:skidoo_app/core/validators/validators.dart';
import 'package:skidoo_app/features/auth/presentation/bloc/login/login_bloc.dart';
import 'package:skidoo_app/features/auth/presentation/pages/email_verification_page.dart';
import 'package:skidoo_app/features/auth/presentation/pages/forget_password_page.dart';
import 'package:skidoo_app/features/auth/presentation/pages/interests_page.dart';
import 'package:skidoo_app/core/common/widgets/app_text_field.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/core/utils/snackbar_utils.dart';
import 'package:skidoo_app/features/chat/presentation/bloc/rooms/chat_rooms_bloc.dart';
import 'package:skidoo_app/features/home/presentation/pages/home_page.dart';
import 'package:skidoo_app/core/utils/web_wrap.dart';

// ── Design tokens ──────────────────────────────────────────────────────────────
// The teal gradient logo/CTA is the auth flow's fixed brand accent — it stays
// the same in both themes. Background/text below are theme-aware (see `ext`).
const _kTeal        = Color(0xFF0BA98A);
const _kTealDark    = Color(0xFF078368);

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
                          SizedBox(height: 32.h),

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
                          SizedBox(height: 8.h),
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
                          SizedBox(height: 16.h),

                          // ── Password ───────────────────────────────────
                          AppPasswordField(
                            controller: _passwordController,
                            label: AppLocalizations.of(context)!.loginPassword,
                            textInputAction: TextInputAction.done,
                            validator: (v) =>
                                Validators.passwordValidator(v),
                          ),
                          SizedBox(height: 12.h),

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
                          SizedBox(height: 32.h),
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
