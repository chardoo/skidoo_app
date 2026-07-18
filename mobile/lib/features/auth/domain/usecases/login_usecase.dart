import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:skidoo_app/core/usecases/usecase.dart';
import 'package:skidoo_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:skidoo_app/features/chat/data/datasources/chat_key_datasource.dart';
import 'package:skidoo_app/features/chat/data/local/chat_database.dart';
import 'package:skidoo_app/models/Auth/LoginResponse.dart';
import 'package:skidoo_app/services/auth_service.dart';
import 'package:skidoo_app/services/e2ee_service.dart';

class LoginUseCase implements UseCase<LoginResponseObject, LoginParams> {
  final AuthRepository _repository;
  final AuthService _authService;
  final ChatDatabase _chatDb;
  final E2eeService _e2ee;
  final ChatKeyDataSource _keyDs;

  LoginUseCase(this._repository, this._authService, this._chatDb, this._e2ee,
      this._keyDs);

  @override
  Future<LoginResponseObject> call(LoginParams params) async {
    final user = await _repository.login(params.email, params.password);
    await establishSession(user);
    return user;
  }

  /// Persists [user]'s session and runs post-auth bring-up (wiping local data
  /// on an account switch, publishing/rotating E2EE keys). Shared by [call]
  /// and by [VerifyCodeUseCase] after email-OTP verification — both receive a
  /// fresh [LoginResponseObject] from the backend and need identical session
  /// establishment.
  Future<void> establishSession(LoginResponseObject user) async {
    final previousUserId = await _authService.getUserId();

    if (!kIsWeb) {
      // Different user on the same device — wipe all user-scoped local data
      // so that chat history and E2EE keys from the previous account can never
      // bleed into the new session.
      if (previousUserId.isNotEmpty && previousUserId != user.id) {
        await Future.wait([
          _chatDb.clearAll().catchError((_) {}),
          _e2ee.clearAllKeys(),
        ]);
      }
    }

    await _repository.saveUserSession(user);

    // E2EE key management is mobile-only — chat/messaging is not used on web.
    if (!kIsWeb) {
      // Server says this user has no bundle yet (new install, key wipe, or
      // account on a different device). Publish immediately so every DM is
      // encrypted from the very first message — not just after opening a DM.
      if (user.keyBundlePublished && await _e2ee.hasKeys()) {
        // Bundle already exists on both server and device — nothing to publish.
        _e2ee.markBundlePublished();
      } else {
        try {
          final PublishableKeyBundle bundle;
          if (!await _e2ee.hasKeys()) {
            bundle = await _e2ee.generateKeys();
            // generates + stores 100 OTPKs
          } else {
            bundle =
                (await _e2ee.currentBundle())!; // 0 OTPKs (top-up separately)
          }
          await _keyDs.publishBundle(bundle);
          if (bundle.oneTimePreKeys.isEmpty) {
            final otpks = await _e2ee.generateOtpks(100);
            await _keyDs.topUpPrekeys(otpks);
          }
          _e2ee.markBundlePublished();
          debugPrint(
              '[E2EE] Published bundle on login (${bundle.oneTimePreKeys.length} OTPKs in bundle)');
        } catch (e) {
          debugPrint(
              '[E2EE] Failed to publish bundle on login (will retry on DM open): $e');
        }
      }

      // Phase 2 + SPK rotation — fire-and-forget so login is never blocked.
      unawaited(_maintainKeysAfterLogin());
    }
  }

  /// Phase 2 (OTPK replenishment) and SPK rotation, run on every login/app
  /// start without blocking the login response.
  Future<void> _maintainKeysAfterLogin() async {
    // OTPK replenishment — check the server pool and top up if below threshold.
    try {
      final count = await _keyDs.prekeyCount();
      if (count < 10) {
        final needed = 100 - count;
        final otpks = await _e2ee.generateOtpks(needed);
        await _keyDs.topUpPrekeys(otpks);
        debugPrint('[E2EE] Topped up $needed OTPKs on login (server had $count)');
      }
    } catch (e) {
      debugPrint('[E2EE] OTPK check on login failed: $e');
    }

    // SPK rotation — generate a new SPK if overdue and publish the updated bundle.
    try {
      if (await _e2ee.needsSPKRotation()) {
        final rotated = await _e2ee.rotateSPK();
        await _keyDs.publishBundle(rotated);
        // Always top up OTPKs alongside a rotation so the pool stays full.
        final otpks = await _e2ee.generateOtpks(100);
        await _keyDs.topUpPrekeys(otpks);
        debugPrint('[E2EE] SPK rotated on login');
      }
    } catch (e) {
      debugPrint('[E2EE] SPK rotation on login failed: $e');
    }
  }
}

class LoginParams extends Equatable {
  final String email;
  final String password;
  const LoginParams({required this.email, required this.password});

  @override
  List<Object?> get props => [email, password];
}
