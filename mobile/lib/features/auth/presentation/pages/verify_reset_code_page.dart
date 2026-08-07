import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/core/error/exceptions.dart';
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/utils/snackbar_utils.dart';
import 'package:jperg_app/core/utils/web_wrap.dart';
import 'package:jperg_app/core/widgets/paste_aware_digit_formatter.dart';
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
  final _controllers =
      List.generate(_kCodeLength, (_) => TextEditingController());
  final _focusNodes = List.generate(_kCodeLength, (_) => FocusNode());
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
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
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

  String get _code => _controllers.map((c) => c.text).join();

  void _onDigitChanged(int index, String value) {
    if (value.isNotEmpty && index < _kCodeLength - 1) {
      _focusNodes[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
    if (_code.length == _kCodeLength) _verify();
  }

  void _handlePaste(String digits, int pastedAtIndex) {
    setState(() {
      for (var i = 0; i < _kCodeLength; i++) {
        if (i == pastedAtIndex) continue;
        _controllers[i].text = i < digits.length ? digits[i] : '';
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final lastIndex = (digits.length - 1).clamp(0, _kCodeLength - 1);
      _focusNodes[lastIndex].requestFocus();
      if (_code.length == _kCodeLength) _verify();
    });
  }

  Future<void> _verify() async {
    if (_code.length != _kCodeLength || _isLoading) return;
    setState(() {
      _isLoading = true;
      _error = null;
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
      setState(() => _error = 'That code doesn\'t look right. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resend() async {
    if (_resendIn > Duration.zero) return;
    _startResendCooldown();
    try {
      await sl<RequestPasswordResetUseCase>().call(widget.email);
      if (mounted) {
        AppSnackBar.info(context, 'A new code is on its way.');
      }
    } catch (_) {
      if (mounted) {
        AppSnackBar.error(context, 'Could not resend the code. Please try again.');
      }
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
                  SizedBox(height: 48.h),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(_kCodeLength, (i) {
                      return SizedBox(
                        width: 44.w,
                        height: 52.h,
                        child: TextField(
                          controller: _controllers[i],
                          focusNode: _focusNodes[i],
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          maxLength: 1,
                          style: TextStyle(
                            color: ext.greetingColor,
                            fontSize: 20.sp,
                            fontWeight: FontWeight.w700,
                          ),
                          inputFormatters: [
                            PasteAwareDigitFormatter(
                                index: i, onPaste: _handlePaste),
                          ],
                          decoration: InputDecoration(
                            counterText: '',
                            filled: true,
                            fillColor: ext.searchFieldFill,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppRadius.md.r),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppRadius.md.r),
                              borderSide: BorderSide(color: ext.accentGold, width: 1.5),
                            ),
                          ),
                          onChanged: (v) => _onDigitChanged(i, v),
                        ),
                      );
                    }),
                  ),

                  if (_error != null) ...[
                    SizedBox(height: 14.h),
                    Text(_error!,
                        style: TextStyle(color: ext.errorRed, fontSize: 12.5.sp)),
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
                              ? 'Did not receive it? Resend in 0:${_resendIn.inSeconds.toString().padLeft(2, '0')}'
                              : 'Did not receive it? Resend',
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
