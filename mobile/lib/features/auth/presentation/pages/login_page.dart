import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:skidoo_app/l10n/app_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/di/service_locator.dart';
import 'package:skidoo_app/core/validators/validators.dart';
import 'package:skidoo_app/features/auth/presentation/bloc/login/login_bloc.dart';
import 'package:skidoo_app/features/auth/presentation/pages/forget_password_page.dart';
import 'package:skidoo_app/features/auth/presentation/pages/interests_page.dart';
import 'package:skidoo_app/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:skidoo_app/core/utils/snackbar_utils.dart';
import 'package:skidoo_app/features/chat/presentation/bloc/rooms/chat_rooms_bloc.dart';
import 'package:skidoo_app/features/home/presentation/pages/home_page.dart';
import 'package:skidoo_app/core/utils/web_wrap.dart';

// ── Design tokens ──────────────────────────────────────────────────────────────
const _kOrange      = Color(0xFFFF8303);
const _kOrangeDark  = Color(0xFFE66E00);
const _kBg          = Color(0xFF0A0D11);
const _kBgDeep      = Color(0xFF0F1525);
const _kSubtext     = Color(0xFF9BA3B2);

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
    final page = Scaffold(
      backgroundColor: _kBg,
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
          if (state.errorMessage != null && !state.isLoading) {
            AppSnackBar.error(context, state.errorMessage!);
          }
        },
        builder: (context, state) {
          return Stack(
            children: [
              // ── Ambient gradient background ──────────────────────────────
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [_kBg, _kBgDeep],
                  ),
                ),
              ),
              // ── Radial orange glow at top ────────────────────────────────
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
                          _kOrange.withValues(alpha: 0.18),
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
                                colors: [_kOrange, _kOrangeDark],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(14.r),
                              boxShadow: [
                                BoxShadow(
                                  color: _kOrange.withValues(alpha: 0.35),
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
                              color: Colors.white,
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
                              color: _kSubtext,
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w400,
                              letterSpacing: 0.1,
                            ),
                          ),
                          SizedBox(height: 44.h),

                          // ── Email ──────────────────────────────────────
                          AuthTextField(
                            controller: _emailController,
                            label: AppLocalizations.of(context)!.loginEmailAddress,
                            prefixIcon: Icons.mail_outline_rounded,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            validator: Validators.emailValidator,
                          ),
                          SizedBox(height: 16.h),

                          // ── Password ───────────────────────────────────
                          AuthPasswordField(
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
                            child: GestureDetector(
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const ForgetPasswordPage()),
                              ),
                              child: Text(
                                AppLocalizations.of(context)!.loginForgotPassword,
                                style: TextStyle(
                                  color: _kOrange,
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: 36.h),

                          // ── Sign in button ─────────────────────────────
                          _GradientButton(
                            label: AppLocalizations.of(context)!.loginSignIn,
                            isLoading: state.isLoading,
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
                                    color: _kSubtext,
                                    fontSize: 14.sp,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => Navigator.of(context)
                                      .pushReplacementNamed('/signup'),
                                  child: Text(
                                    AppLocalizations.of(context)!.loginSignUp,
                                    style: TextStyle(
                                      color: _kOrange,
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
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
    return webWrap(page, backgroundColor: _kBg);
  }

}

// ── Shared gradient CTA button ─────────────────────────────────────────────────
class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.label,
    required this.isLoading,
    required this.onTap,
  });

  final String label;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 56.h,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isLoading
                ? [_kOrange.withValues(alpha: 0.5), _kOrangeDark.withValues(alpha: 0.5)]
                : [_kOrange, _kOrangeDark],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(14.r),
          boxShadow: isLoading
              ? []
              : [
                  BoxShadow(
                    color: _kOrange.withValues(alpha: 0.35),
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
    );
  }
}
