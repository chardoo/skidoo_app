import 'dart:typed_data';

import 'package:dio/dio.dart' as dio;

import 'package:jperg_app/api/dio_client_service.dart';
import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/features/settings/data/account_settings_api.dart';
import 'package:jperg_app/services/auth_service.dart';

/// Save selfies as this account's reference face.
///
/// The same `/client/train-model` the sign-up wizard posts to, taking photos
/// that have already been captured — so the easy-search checkbox costs no
/// second capture.
///
/// Returns null when it worked, or a sentence to show the person when it did
/// not. It never throws: every caller is on a path where the enrolment is the
/// *extra*, not the errand, and a failure must not take the thing they
/// actually asked for with it.
///
/// `use_as_profile` is deliberately never sent. That is a separate decision
/// about a public avatar; bundling it would put somebody's selfie on their
/// profile because they wanted to be matched in future albums.
Future<String?> saveFaceForFutureEvents(
  List<({String name, Uint8List bytes})> faces,
) async {
  if (faces.isEmpty) return null;
  try {
    final email = await sl<AuthService>().getEmail();
    final form = dio.FormData.fromMap({
      'email': email,
      'files': [
        for (final face in faces)
          dio.MultipartFile.fromBytes(face.bytes, filename: face.name),
      ],
    });
    await sl<Api>().dio.post(
          '/client/train-model',
          data: form,
          options: dio.Options(
            contentType: 'multipart/form-data',
            receiveTimeout: const Duration(minutes: 3),
            sendTimeout: const Duration(minutes: 3),
          ),
        );
    await markFaceAdded();
    return null;
  } on dio.DioException catch (e) {
    // The one refusal worth naming. train-model rejects enrolment outright
    // when face recognition is switched off in Settings › Privacy, and
    // "something went wrong" would send somebody hunting for a fault that is
    // their own setting.
    if (e.response?.statusCode == 400) {
      return 'Face recognition is off for your account. Turn it on in '
          'Settings › Privacy to save your face.';
    }
    return 'We could not save your face for next time.';
  } catch (_) {
    return 'We could not save your face for next time.';
  }
}

/// Record that this account now has a face, everywhere that caches the answer.
///
/// Two places hold it and they are read by different screens. Setting only the
/// first is why Settings › Privacy › Manage Face Data could still say there was
/// no face data after one had just been added: that screen draws from
/// [AccountSettingsApi]'s cached row, which is a server answer from before the
/// enrolment and does not change because a local flag did.
///
/// Call this from anywhere that enrols, rather than `setHasAddedFaces` alone.
Future<void> markFaceAdded() async {
  await sl<AuthService>().setHasAddedFaces(true);
  // Not written through: the enrolment endpoint answers with its own payload,
  // not the settings row, so there is no fresh row to save — only a stale one
  // to stop trusting.
  AccountSettingsApi.invalidate();
}
