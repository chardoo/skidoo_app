import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/di/service_locator.dart';
import 'package:skidoo_app/core/error/exceptions.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/core/utils/snackbar_utils.dart';
import 'package:skidoo_app/core/utils/web_wrap.dart';
import 'package:skidoo_app/features/auth/domain/usecases/verify_code_usecase.dart';
import 'package:skidoo_app/features/auth/presentation/pages/face_capture_step_page.dart';

const _kCodeLength = 6;
const _kResendCooldown = Duration(seconds: 30);

/// Lets a single OTP box accept a full pasted code. `TextField.maxLength`
/// would otherwise silently truncate a paste to 1 character before it's
/// even visible to `onChanged`, so this formatter runs first: on a
/// multi-digit paste it hands the whole string to [onPaste] (which fills
/// the other boxes) and keeps only this box's own digit (by [index]) for
/// itself, so the box that received the paste still ends up correct.
class _PasteAwareDigitFormatter extends TextInputFormatter {
  _PasteAwareDigitFormatter({required this.index, required this.onPaste});

  final int index;
  final void Function(String digits, int pastedAtIndex) onPaste;

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digitsOnly = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.length > 1) {
      onPaste(digitsOnly, index);
      final own = index < digitsOnly.length ? digitsOnly[index] : '';
      return TextEditingValue(
        text: own,
        selection: TextSelection.collapsed(offset: own.length),
      );
    }
    return TextEditingValue(
      text: digitsOnly,
      selection: TextSelection.collapsed(offset: digitsOnly.length),
    );
  }
}

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

  // Distributes a pasted code across all boxes except [pastedAtIndex] —
  // that box's own formatter already keeps its correct digit. Programmatic
  // controller updates don't fire onChanged, so focus/verify are handled
  // here explicitly rather than relying on _onDigitChanged.
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
                  SizedBox(height: 24.h),
                  Text(
                    'Check your email',
                    style: TextStyle(
                      color: ext.greetingColor,
                      fontSize: 26.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'We sent a $_kCodeLength-digit code to ${widget.email}',
                    style: TextStyle(color: ext.searchHintColor, fontSize: 14.sp),
                  ),
                  SizedBox(height: 32.h),

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
                            _PasteAwareDigitFormatter(
                                index: i, onPaste: _handlePaste),
                          ],
                          decoration: InputDecoration(
                            counterText: '',
                            filled: true,
                            fillColor: ext.searchFieldFill,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.r),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.r),
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
                        style: const TextStyle(color: Color(0xFFFF4757), fontSize: 12.5)),
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
                  SizedBox(height: 20.h),

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
                  SizedBox(height: 40.h),
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
