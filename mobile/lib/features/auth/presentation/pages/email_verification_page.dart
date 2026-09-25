import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/common/widgets/app_back_button.dart';
import 'package:jperg_app/core/common/widgets/app_code_field.dart';
import 'package:jperg_app/core/common/widgets/app_inline_banner.dart';
import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/core/error/exceptions.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/theme/app_typography.dart';
import 'package:jperg_app/features/auth/domain/usecases/resend_verification_usecase.dart';
import 'package:jperg_app/features/auth/domain/usecases/verify_code_usecase.dart';
import 'package:jperg_app/features/auth/presentation/pages/face_capture_step_page.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';

const _kCodeLength = 6;
const _kResendCooldown = Duration(seconds: 30);

/// "Check your email" — the OTP step between account creation and the app.
/// On success the backend returns a full session (same as login), so the
/// user is signed in immediately without a separate manual login.
class EmailVerificationPage extends StatefulWidget {
  const EmailVerificationPage({super.key, required this.email});

  final String email;

  static Future<void> push(BuildContext context, {required String email}) =>
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => EmailVerificationPage(email: email),
        ),
      );

  @override
  State<EmailVerificationPage> createState() => _EmailVerificationPageState();
}

class _EmailVerificationPageState extends State<EmailVerificationPage> {
  // One field, not one per digit.
  //
  // Six TextFields meant every keystroke called requestFocus() on the next
  // one, and moving focus between fields tears down the platform text-input
  // connection and builds a new one — which the user sees as the keyboard
  // dropping and springing back on each digit. A single field keeps one
  // connection for the whole code, so the keyboard never re-negotiates. It
  // also makes paste and iOS SMS autofill work without special handling.
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _isLoading = false;
  bool _isResending = false;
  String? _error;

  /// A resend that failed. Kept apart from [_error] because a resend failing
  /// and a code being rejected are different problems with different fixes,
  /// and they must never be mistaken for one another.
  String? _resendError;

  /// A resend that worked, which is a different kind of thing entirely — see
  /// where it is drawn, under the button that caused it.
  bool _codeResent = false;
  Duration _resendIn = Duration.zero;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    _startResendCooldown();
    // The caret highlight below is driven by `_focusNode.hasFocus`, which is
    // false on the first build even with autofocus set — so without this the
    // first box stayed unringed until the first keystroke.
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _controller.dispose();
    _focusNode.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  void _onFocusChanged() {
    if (mounted) setState(() {});
  }

  void _startResendCooldown() {
    setState(() => _resendIn = _kResendCooldown);
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      final next = _resendIn - const Duration(seconds: 1);
      if (next <= Duration.zero) {
        t.cancel();
        setState(() => _resendIn = Duration.zero);
      } else {
        setState(() => _resendIn = next);
      }
    });
  }

  String get _code => _controller.text;

  void _onCodeChanged(String value) {
    if (_error == null && _resendError == null && !_codeResent) return;
    setState(() {
      _error = null;
      _resendError = null;
      _codeResent = false;
    });
  }

  Future<void> _verify() async {
    if (_code.length != _kCodeLength || _isLoading) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await sl<VerifyCodeUseCase>()
          .call(VerifyCodeParams(email: widget.email, code: _code));
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const FaceCaptureStepPage()),
      );
    } on NetworkException catch (e) {
      setState(() => _error = e.message);
    } on ServerException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Verification failed. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Ask the backend for another code.
  ///
  /// This used to start the cooldown, say a code was on its way, and never
  /// call anything — so "Resend code" was a 30-second timer with a message
  /// attached, and the code genuinely never came. The request is the point;
  /// the cooldown only starts once the server has accepted it, so a failed
  /// attempt can be retried immediately rather than locking the button for
  /// thirty seconds over a request that never happened.
  Future<void> _resend() async {
    if (_resendIn > Duration.zero || _isResending) return;
    setState(() {
      _isResending = true;
      _error = null;
      _resendError = null;
      _codeResent = false;
    });
    try {
      await sl<ResendVerificationUseCase>().call(widget.email);
      if (!mounted) return;
      setState(() => _codeResent = true);
      // The typed digits are now the *old* code; leaving them in place invites
      // the user to submit them and be told they are wrong.
      _controller.clear();
      _startResendCooldown();
    } on NetworkException catch (e) {
      if (mounted) setState(() => _resendError = e.message);
    } on ServerException catch (e) {
      if (mounted) setState(() => _resendError = e.message);
    } catch (_) {
      if (mounted) {
        setState(() =>
            _resendError = 'Could not send a new code. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final page = Scaffold(
      backgroundColor: ext.homeBackground,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 28.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: AppSpacing.md.h),

                  // ── Way back ───────────────────────────────────────────
                  // This screen had no exit. Someone who mistyped their email
                  // on the previous step — the single most likely reason a code
                  // never arrives — could only close the app, because the
                  // address is fixed here and there was nothing to tap.
                  //
                  // Left-aligned with the content rather than put in an AppBar,
                  // so the page keeps its full-bleed layout; the negative inset
                  // cancels the tap padding an IconButton carries, which would
                  // otherwise indent the arrow past the heading below it.
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Transform.translate(
                      offset: Offset(-AppSpacing.md.w, 0),
                      child: const AppBackButton(tooltip: 'Back to sign up'),
                    ),
                  ),
                  SizedBox(height: AppSpacing.lg.h),

                  Container(
                    width: 56.w,
                    height: 56.w,
                    decoration: BoxDecoration(
                      color: ext.accentGold.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.mark_email_read_rounded,
                        color: ext.accentGold, size: 26.sp),
                  ),
                  SizedBox(height: AppSpacing.xxl.h),
                  Text(
                    'Check your email',
                    style: TextStyle(
                      color: ext.greetingColor,
                      fontFamily: AppTypography.displayFontFamily,
                      fontSize: 24.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: AppSpacing.sm.h),
                  Text(
                    'We sent a $_kCodeLength-digit code to ${widget.email}',
                    style:
                        TextStyle(color: ext.searchHintColor, fontSize: 14.sp),
                  ),
                  SizedBox(height: AppSpacing.xxxl.h),

                  AppCodeField(
                    controller: _controller,
                    focusNode: _focusNode,
                    length: _kCodeLength,
                    hasError: _error != null,
                    onChanged: _onCodeChanged,
                    onCompleted: (_) {
                      // Close the keyboard deliberately, once, rather than
                      // letting it flicker on the way there.
                      _focusNode.unfocus();
                      _verify();
                    },
                  ),

                  // Only failures take space up here, and only one at a time:
                  // a rejected code, or a resend that did not go through.
                  // Both are things to fix before the button below is worth
                  // pressing, which is why they sit between the code and it.
                  //
                  // A *successful* resend does not belong here. It used to
                  // take this slot as a three-line green panel — repeating the
                  // email address the screen states two lines above, plus a
                  // note about the spam folder — which made the largest thing
                  // on the screen an acknowledgement, and shoved the Verify
                  // button a hundred pixels down the instant you tapped
                  // Resend. It is now one quiet line under the Resend control
                  // itself, where the action was: see below.
                  if (_error != null || _resendError != null) ...[
                    SizedBox(height: AppSpacing.lg.h),
                    AppInlineBanner(message: _error ?? _resendError!),
                  ],
                  SizedBox(height: 28.h),

                  SizedBox(
                    width: double.infinity,
                    height: 52.h,
                    child: ElevatedButton(
                      onPressed: (_isLoading || _code.length != _kCodeLength)
                          ? null
                          : _verify,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ext.accentGold,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            ext.accentGold.withValues(alpha: 0.5),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14.r),
                        ),
                      ),
                      child: _isLoading
                          ? SizedBox(
                              width: 20.w,
                              height: 20.w,
                              child: const CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2.5),
                            )
                          : Text('Verify',
                              style: TextStyle(
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.w700)),
                    ),
                  ),
                  SizedBox(height: AppSpacing.xl.h),

                  // Fixed height, because the label changes shape as well as
                  // wording: "Didn't receive it? Resend code" wraps to two
                  // lines at this width while "Resend code in 0:30" fits one,
                  // so the control was 56 high before a resend and 48 after.
                  // In a vertically centred column that shrinkage moves
                  // everything — including the Verify button, a moment after
                  // the thumb has tapped just below it.
                  SizedBox(
                    height: 56.h,
                    child: Center(
                      child: Semantics(
                        button: true,
                        label: 'Resend code',
                        child: TextButton(
                          onPressed: (_resendIn > Duration.zero || _isResending)
                              ? null
                              : _resend,
                          child: _isResending
                              ? SizedBox(
                                  width: 16.w,
                                  height: 16.w,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: ext.accentGold,
                                  ),
                                )
                              : Text(
                                  _resendIn > Duration.zero
                                      ? 'Resend code in 0:${_resendIn.inSeconds.toString().padLeft(2, '0')}'
                                      : "Didn't receive it? Resend code",
                                  style: TextStyle(
                                    color: _resendIn > Duration.zero
                                        ? ext.searchHintColor
                                        : ext.accentGold,
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),

                  // The confirmation, where the action is.
                  //
                  // The countdown in the control right above already says the
                  // send went through, so this is reinforcement rather than
                  // news — and the spam hint is the part actually worth
                  // reading, since wanting a code that has not arrived is the
                  // only reason anyone taps Resend.
                  //
                  // The slot is held whether or not there is anything in it,
                  // so confirming a resend moves nothing. Without that the
                  // page still jumps: the whole column is vertically centred,
                  // so growing it by a line lifts everything above by half a
                  // line — less rude than the banner that used to shove the
                  // button down the page, but still the button moving under a
                  // thumb that has just tapped near it.
                  SizedBox(
                    height: 34.h,
                    child: _codeResent
                        ? Center(
                            child: Semantics(
                              liveRegion: true,
                              child: Text(
                                'New code sent. Check your spam folder too.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: ext.accentGold,
                                  // A step below the control above it: this is
                                  // subordinate to the thing it reports on.
                                  fontSize: AppTypography.xs,
                                  fontWeight: AppTypography.medium,
                                ),
                              ),
                            ),
                          )
                        : null,
                  ),
                  SizedBox(height: AppSpacing.xxl.h),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return page;
  }
}
