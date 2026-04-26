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
    final previousUserId = await _authService.getUserId();
    final user = await _repository.login(params.email, params.password);

    // Different user on the same device — wipe all user-scoped local data
    // so that chat history and E2EE keys from the previous account can never
    // bleed into the new session.
    if (previousUserId.isNotEmpty && previousUserId != user.id) {
      await Future.wait([
        _chatDb.clearAll(),
        _e2ee.clearAllKeys(),
      ]);
    }

    await _repository.saveUserSession(user);

    // Server says this user has no bundle yet (new install, key wipe, or
    // account on a different device). Publish immediately so every DM is
    // encrypted from the very first message — not just after opening a DM.
    if (!user.keyBundlePublished || !await _e2ee.hasKeys()) {
      try {
        final PublishableKeyBundle bundle;
        if (!await _e2ee.hasKeys()) {
          bundle = await _e2ee.generateKeys(); // generates + stores 100 OTPKs
        } else {
          bundle = (await _e2ee.currentBundle())!; // 0 OTPKs (top-up separately)
        }
        await _keyDs.publishBundle(bundle);
        if (bundle.oneTimePreKeys.isEmpty) {
          final otpks = await _e2ee.generateOtpks(100);
          await _keyDs.topUpPrekeys(otpks);
        }
        debugPrint('[E2EE] Published bundle on login (${bundle.oneTimePreKeys.length} OTPKs in bundle)');
      } catch (e) {
        debugPrint('[E2EE] Failed to publish bundle on login (will retry on DM open): $e');
      }
    }

    return user;
  }
}

class LoginParams extends Equatable {
  final String email;
  final String password;
  const LoginParams({required this.email, required this.password});

  @override
  List<Object?> get props => [email, password];
}
