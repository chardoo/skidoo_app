import 'package:dio/dio.dart' as dio;
import 'package:jperg_app/api/dio_client_service.dart';
import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/core/error/exceptions.dart' as app_ex;

/// The three switches the settings screens own, and what they mean.
///
/// One shape and one endpoint for all three, because they are one row in one
/// table: Account & Security draws the first, Privacy draws the other two, and
/// splitting them by which screen shows them would be two clients that always
/// change together.
class AccountSettings {
  const AccountSettings({
    this.twoFactorEnabled = false,
    this.faceRecognitionEnabled = true,
    this.shareUsageData = false,
    this.hasAddedFaces = false,
  });

  /// A password alone stops being enough to sign in.
  final bool twoFactorEnabled;

  /// Whether recognition may look for this person at all. Switching it off is
  /// not a display preference — the server deletes the embeddings, because a
  /// face still in the model is still being matched whatever a flag says.
  final bool faceRecognitionEnabled;

  /// Anonymised engagement events. Off by default; the server drops the events
  /// rather than trusting the app not to send them.
  final bool shareUsageData;

  /// Not a setting. Whether there is any face data to delete, which is what
  /// the Face Data screen needs in order to say so.
  final bool hasAddedFaces;

  factory AccountSettings.fromJson(Map<String, dynamic> json) =>
      AccountSettings(
        twoFactorEnabled: json['two_factor_enabled'] == true,
        // Defaults matter here: absent means on for recognition and off for
        // the other two, matching the server's columns. Reading a missing key
        // as false would show recognition disabled for everyone the moment a
        // response shape changed.
        faceRecognitionEnabled: json['face_recognition_enabled'] != false,
        shareUsageData: json['share_usage_data'] == true,
        hasAddedFaces: json['has_added_faces'] == true,
      );

  AccountSettings copyWith({
    bool? twoFactorEnabled,
    bool? faceRecognitionEnabled,
    bool? shareUsageData,
    bool? hasAddedFaces,
  }) =>
      AccountSettings(
        twoFactorEnabled: twoFactorEnabled ?? this.twoFactorEnabled,
        faceRecognitionEnabled:
            faceRecognitionEnabled ?? this.faceRecognitionEnabled,
        shareUsageData: shareUsageData ?? this.shareUsageData,
        hasAddedFaces: hasAddedFaces ?? this.hasAddedFaces,
      );
}

class AccountSettingsApi {
  Future<AccountSettings> fetch() async {
    try {
      final res = await sl<Api>().dio.get('/client/account/settings');
      final data = res.data?['data'];
      return data is Map<String, dynamic>
          ? AccountSettings.fromJson(data)
          : const AccountSettings();
    } on dio.DioException catch (err) {
      if (err.response == null) throw const app_ex.NetworkException();
      throw app_ex.ServerException(
          'Could not load your settings: ${err.response?.statusCode}');
    }
  }

  /// Sends only the switch that changed — the endpoint patches, so the others
  /// keep whatever they were.
  ///
  /// The answer is the whole settings row, not an acknowledgement, because one
  /// switch can move another: turning face recognition off also clears
  /// `hasAddedFaces`, and the screen has to show that without asking again.
  Future<AccountSettings> update(String key, bool value) async {
    try {
      final res = await sl<Api>().dio.patch(
        '/client/account/settings',
        data: {key: value},
      );
      final data = res.data?['data'];
      return data is Map<String, dynamic>
          ? AccountSettings.fromJson(data)
          : const AccountSettings();
    } on dio.DioException catch (err) {
      if (err.response == null) throw const app_ex.NetworkException();
      // The server refuses rather than lying when it cannot make a switch
      // true — turning recognition off while the recognition service is
      // unreachable, for one. Its message is the useful one.
      final message = err.response?.data?['error']?['message'];
      throw app_ex.ServerException(
        message is String ? message : 'Could not change that setting.',
      );
    }
  }
}
