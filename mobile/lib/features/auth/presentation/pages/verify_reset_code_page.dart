import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/common/widgets/app_back_button.dart';
import 'package:jperg_app/core/common/widgets/app_code_field.dart';
import 'package:jperg_app/core/common/widgets/app_inline_banner.dart';
import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/core/error/exceptions.dart';
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/theme/app_typography.dart';
import 'package:jperg_app/features/auth/domain/usecases/request_password_reset_usecase.dart';
import 'package:jperg_app/features/auth/domain/usecases/verify_reset_code_usecase.dart';
import 'package:jperg_app/features/auth/presentation/pages/set_new_password_page.dart';

const _kCodeLength = 6;
const _kResendCooldown = Duration(seconds: 30);

/// Step 2 of password reset — "Check your email" (see
/// mobile/docs/FRONTEND_RESET_PASSWORD.md). Verifies the 6-digit code
/// before showing the new-password screen — this step is skippable
/// server-side, but kept as a real screen here to catch a mistyped code
/// early rather than only failing at the final change-password call.
class VerifyResetCodePage extends StatefulWidget {
  const VerifyResetCodePage({super.key, required this.email});

  final String email;

  @override
  State<VerifyResetCodePage> createState() => _VerifyResetCodePageState();
}

class _VerifyResetCodePageState extends State<VerifyResetCodePage> {
  // One field, not one per digit.
  //
  // This screen used to hold six TextFields and hand focus along the row as
  // you typed. Moving focus between fields tears down the platform text-input
  // connection and builds a new one, which the user sees as the keyboard
  // dropping and springing back on every single digit — and each field drew
  // its own filled box with its own focus ring, so the row flickered between
  // six different states while a six-digit code was entered. Backspacing was
  // worse: the handler moved focus back on an empty field, so a correction
  // could bounce between two boxes.
  //
  // A single field keeps one keyboard session for the whole code and makes the
  // boxes pure decoration driven by one controller. It is also what the signup
  // verification screen already does — the two screens do the same job and had
  // no business behaving differently. Paste and iOS SMS autofill come free.
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _isLoading = false;
  bool _isResending = false;
  String? _error;

  /// A resend that failed — kept apart from [_error] because a resend failing
  /// and a code being rejected are different problems with different fixes.
  String? _resendError;

  /// A resend that worked. Drawn under the Resend control rather than in the
  /// banner slot; see the twin of this on EmailVerificationPage.
  bool _codeResent = false;
  Duration _resendIn = Duration.zero;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    _startResendCooldown();
    // Redraw the boxes when focus arrives or leaves, so the caret highlight
    // matches whether the keyboard is actually up.
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
      _resendError = null;
      _codeResent = false;
    });
    try {
      await sl<VerifyResetCodeUseCase>().call(
        VerifyResetCodeParams(email: widget.email, code: _code),
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => SetNewPasswordPage(email: widget.email, code: _code),
        ),
      );
    } on NetworkException catch (e) {
      setState(() => _error = e.message);
    } on ServerException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(
          () => _error = 'That code doesn\'t look right. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// The cooldown starts only once the server has taken the request, so a
  /// failed resend can be retried at once instead of locking the button for
  /// thirty seconds over a request that never landed.
  Future<void> _resend() async {
    if (_resendIn > Duration.zero || _isResending) return;
    setState(() {
      _isResending = true;
      _error = null;
      _resendError = null;
      _codeResent = false;
    });
    try {
      await sl<RequestPasswordResetUseCase>().call(widget.email);
      if (!mounted) return;
      setState(() => _codeResent = true);
      // Whatever is typed is now the previous code.
      _controller.clear();
      _startResendCooldown();
    } catch (_) {
      if (mounted) {
        setState(() =>
            _resendError = 'Could not resend the code. Please try again.');
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

                  // Back to the email step — the address is fixed on this
                  // screen, so a typo there is only fixable by going back.
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Transform.translate(
                      offset: Offset(-AppSpacing.md.w, 0),
                      child: const AppBackButton(tooltip: 'Back'),
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
                    child: Icon(Icons.shield_rounded,
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

                  // Failures only, and one at a time — a rejected code or a
                  // resend that did not go through. A successful resend is a
                  // quiet line under the Resend control instead of a panel
                  // here, so confirming it does not push the button away. See
                  // the twin of this on EmailVerificationPage.
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
                          borderRadius: BorderRadius.circular(AppRadius.lg.r),
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

                  Center(
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
                                    ? 'Did not receive it? Resend in 0:${_resendIn.inSeconds.toString().padLeft(2, '0')}'
                                    : 'Did not receive it? Resend',
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

                  // The confirmation, where the action is. The slot is held
                  // whether or not there is anything in it, so confirming a
                  // resend moves nothing — see the twin of this on
                  // EmailVerificationPage for why that needs saying.
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
