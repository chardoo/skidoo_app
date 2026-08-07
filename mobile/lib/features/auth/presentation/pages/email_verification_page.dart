import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/core/error/exceptions.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/utils/snackbar_utils.dart';
import 'package:jperg_app/core/utils/web_wrap.dart';
import 'package:jperg_app/features/auth/domain/usecases/verify_code_usecase.dart';
import 'package:jperg_app/features/auth/presentation/pages/face_capture_step_page.dart';
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:flutter/services.dart';

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
  String? _error;
  Duration _resendIn = Duration.zero;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    _startResendCooldown();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _resendTimer?.cancel();
    super.dispose();
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
    // Redraw the boxes for the new digit / caret position.
    setState(() => _error = null);
    if (value.length == _kCodeLength) {
      // Complete — close the keyboard deliberately, once, rather than letting
      // it flicker on the way there.
      _focusNode.unfocus();
      _verify();
    }
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

  void _resend() {
    if (_resendIn > Duration.zero) return;
    _startResendCooldown();
    AppSnackBar.info(context, 'If a new code doesn\'t arrive shortly, check your spam folder.');
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
                  SizedBox(height: 48.h),
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
                      fontSize: 26.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: AppSpacing.sm.h),
                  Text(
                    'We sent a $_kCodeLength-digit code to ${widget.email}',
                    style: TextStyle(color: ext.searchHintColor, fontSize: 14.sp),
                  ),
                  SizedBox(height: AppSpacing.xxxl.h),

                  // ── Code boxes ─────────────────────────────────────────
                  // A single transparent TextField laid over the six boxes:
                  // the boxes are pure decoration driven by the controller, so
                  // there is exactly one focus node and one keyboard session.
                  Stack(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(_kCodeLength, (i) {
                          final digits = _code;
                          final filled = i < digits.length;
                          // The caret sits on the first empty box — or on the
                          // last one when the code is complete.
                          final isCurrent = _focusNode.hasFocus &&
                              (i == digits.length ||
                                  (digits.length == _kCodeLength &&
                                      i == _kCodeLength - 1));
                          return Container(
                            width: 44.w,
                            height: 52.h,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: ext.searchFieldFill,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.md.r),
                              border: Border.all(
                                color: isCurrent
                                    ? ext.accentGold
                                    : Colors.transparent,
                                width: 1.5,
                              ),
                            ),
                            child: Text(
                              filled ? digits[i] : '',
                              style: TextStyle(
                                color: ext.greetingColor,
                                fontSize: 20.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          );
                        }),
                      ),
                      // Invisible, but real: it owns the input connection and
                      // takes the taps, so tapping any box opens the keyboard.
                      Positioned.fill(
                        child: TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          autofocus: true,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          // Lets iOS offer the emailed code from the keyboard
                          // bar instead of making the user retype it.
                          autofillHints: const [AutofillHints.oneTimeCode],
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(_kCodeLength),
                          ],
                          // Hidden rather than removed — the boxes above are
                          // the visible rendering of this field's value.
                          showCursor: false,
                          cursorColor: Colors.transparent,
                          style: const TextStyle(
                            color: Colors.transparent,
                            height: 0.01,
                          ),
                          decoration: const InputDecoration(
                            counterText: '',
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                            fillColor: Colors.transparent,
                            filled: true,
                          ),
                          onChanged: _onCodeChanged,
                          onSubmitted: (_) => _verify(),
                        ),
                      ),
                    ],
                  ),

                  if (_error != null) ...[
                    SizedBox(height: 14.h),
                    Text(_error!,
                        style: TextStyle(color: ext.errorRed, fontSize: 12.5)),
                  ],
                  SizedBox(height: 28.h),

                  SizedBox(
                    width: double.infinity,
                    height: 52.h,
                    child: ElevatedButton(
                      onPressed: (_isLoading || _code.length != _kCodeLength) ? null : _verify,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ext.accentGold,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: ext.accentGold.withValues(alpha: 0.5),
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
                              style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  SizedBox(height: AppSpacing.xl.h),

                  Center(
                    child: Semantics(
                      button: true,
                      label: 'Resend code',
                      child: TextButton(
                        onPressed: _resendIn > Duration.zero ? null : _resend,
                        child: Text(
                          _resendIn > Duration.zero
                              ? 'Resend code in 0:${_resendIn.inSeconds.toString().padLeft(2, '0')}'
                              : "Didn't receive it? Resend code",
                          style: TextStyle(
                            color: _resendIn > Duration.zero
                                ? ext.searchHintColor
                                : ext.accentGold,
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: AppSpacing.huge.h),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return webWrap(page, backgroundColor: ext.homeBackground);
  }
}
