import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:jperg_app/core/usecases/usecase.dart';
import 'package:jperg_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:jperg_app/features/chat/data/datasources/chat_key_datasource.dart';
import 'package:jperg_app/features/chat/data/local/chat_database.dart';
import 'package:jperg_app/models/Auth/LoginResponse.dart';
import 'package:jperg_app/services/auth_service.dart';
import 'package:jperg_app/services/e2ee_service.dart';
import 'package:jperg_app/services/push_notification_service.dart';

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
    // The *last account to hold a session on this device*, not the current
    // session's id. `getUserId()` is cleared by logout, so it reads empty on
    // every post-logout sign-in — which made the switch check below silently
    // pass and left one user's chat history in place for the next person to
    // sign in on that phone.
    final previousUserId = await _authService.getLastAccountId();

    if (!kIsWeb) {
      // Different user on the same device — wipe all user-scoped local data
      // so that chat history and E2EE keys from the previous account can never
      // bleed into the new session.
      //
      // Same account returning (including after a logout) falls through and
      // keeps its cached rooms and messages, which is the whole point of
      // caching them.
      if (previousUserId.isNotEmpty && previousUserId != user.id) {
        await Future.wait([
          _chatDb.clearAll().catchError((_) {}),
          _e2ee.clearAllKeys(),
        ]);
      }
    }

    // Recorded before the session is saved so a crash mid-bring-up still
    // leaves the device attributed to this account — the next sign-in then
    // compares against it and wipes if that was somebody else. Getting this
    // backwards would be the one failure mode that leaks data.
    await _authService.setLastAccountId(user.id);

    await _repository.saveUserSession(user);

    // Attach this device to the account so the backend's pushes reach it. The
    // id must be `user.id`, which is what the server targets as
    // external_user_id for clients and photographers alike. Fire-and-forget:
    // a push registration failure must never block signing in.
    if (!kIsWeb) {
      unawaited(() async {
        await PushNotificationService.instance.login(user.id);
        // Prompted here rather than at first launch: asking someone who has
        // just signed in converts far better than asking a stranger on the
        // splash screen, and iOS only ever lets you ask once.
        //
        // The pause lets the home screen finish rendering first — a system
        // dialog thrown up over a half-built screen reads as a glitch, and
        // gets dismissed reflexively.
        await Future.delayed(PushNotificationService.permissionPromptDelay);
        // Undecided only — signing in again after declining should not reopen
        // the system settings page, which is what requestPermission does once
        // the OS will no longer show its own dialog.
        await PushNotificationService.instance.promptIfUndecided();
      }());
    }

    // E2EE key management is mobile-only — chat/messaging is not used on web.
    //
    // Started here and deliberately not awaited. Signing in is not waiting on
    // chat crypto: on a device with no keys this generates an identity key, a
    // signed prekey and 100 one-time prekeys — each written to the keystore on
    // its own — and uploads them, all before the home screen could appear. The
    // work still begins the moment the session exists, which is what "publish
    // immediately" was asking for, and a DM opened before it lands republishes
    // on open, which is the path that already covers a failure here.
    if (!kIsWeb) {
      unawaited(_bringUpKeys(user));
    }
  }

  /// Publishes this account's key bundle if the server hasn't got one, then
  /// runs the periodic key upkeep. Off the sign-in path — see [establishSession].
  Future<void> _bringUpKeys(LoginResponseObject user) async {
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

    // Phase 2 + SPK rotation, after the publish above rather than alongside it:
    // both of them generate and upload prekeys, and racing them would have the
    // two topping up against each other.
    await _maintainKeysAfterLogin();
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
