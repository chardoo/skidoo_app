import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:jperg_app/api/dio_client_service.dart';
import 'package:jperg_app/core/error/exceptions.dart' as app_ex;

const _tag = '[PublicProfileRepository]';

/// Somebody else's profile, as a stranger sees it.
///
/// The counterpart to [ProfileOverviewRepository], which reads the signed-in
/// account's own screen. That one carries the email, the face-data switches and
/// the campaign counts; this one carries a name, a face and two figures,
/// because that is all `GET /client/users/{id}/profile` will hand out.
class PublicProfile {
  const PublicProfile({
    required this.id,
    required this.name,
    this.username = '',
    this.photoUrl = '',
    this.bio = '',
    this.location = '',
    this.verified = false,
    this.followers = 0,
    this.following = 0,
    this.isFollowedByMe = false,
    this.isMe = false,
  });

  final String id;
  final String name;

  /// The `@handle`, empty when the account has none — see [SearchUserRow].
  final String username;
  final String photoUrl;
  final String bio;
  final String location;
  final bool verified;
  final int followers;
  final int following;

  /// False for a signed-out viewer, and for yourself.
  final bool isFollowedByMe;
  final bool isMe;

  /// What the screen draws while the fetch is in flight: the name and face the
  /// row that was tapped already had. Same idea as [CreatorProfile.seed] — a
  /// profile should open on the person, not on a spinner.
  factory PublicProfile.seed({
    required String id,
    required String name,
    String? photoUrl,
    String username = '',
  }) =>
      PublicProfile(
        id: id,
        name: name,
        username: username,
        photoUrl: photoUrl ?? '',
      );

  factory PublicProfile.fromJson(String id, Map<String, dynamic> json) {
    final stats = json['stats'] is Map<String, dynamic>
        ? json['stats'] as Map<String, dynamic>
        : const <String, dynamic>{};
    int count(dynamic v) => v is num ? v.toInt() : 0;
    String str(dynamic v) => v?.toString() ?? '';

    return PublicProfile(
      id: str(json['id']).isEmpty ? id : str(json['id']),
      name: str(json['name']),
      username: str(json['username']),
      photoUrl: str(json['profile_url']),
      bio: str(json['bio']),
      location: str(json['location']),
      verified: json['verified_by_admin'] == true,
      followers: count(stats['followers']),
      following: count(stats['following']),
      isFollowedByMe: json['isFollowedByMe'] == true,
      isMe: json['isMe'] == true,
    );
  }

  /// The fetched profile laid over the seed, so a field the server did not
  /// send does not blank out the one the row handed over.
  PublicProfile mergedWith(PublicProfile other) => PublicProfile(
        id: other.id.isNotEmpty ? other.id : id,
        name: other.name.isNotEmpty ? other.name : name,
        username: other.username.isNotEmpty ? other.username : username,
        photoUrl: other.photoUrl.isNotEmpty ? other.photoUrl : photoUrl,
        bio: other.bio.isNotEmpty ? other.bio : bio,
        location: other.location.isNotEmpty ? other.location : location,
        verified: other.verified,
        followers: other.followers,
        following: other.following,
        isFollowedByMe: other.isFollowedByMe,
        isMe: other.isMe,
      );
}

class PublicProfileRepository {
  PublicProfileRepository() : _dio = Api().dio;

  /// A repository talking to [dio] instead of the app's shared client, so the
  /// screen can be exercised against a stubbed transport.
  @visibleForTesting
  PublicProfileRepository.forTest(Dio dio) : _dio = dio;

  final Dio _dio;

  /// `GET /client/users/{id}/profile`.
  ///
  /// Throws [app_ex.NotFoundException] both when there is no such account and
  /// when it is a photographer — the server refuses those on purpose, because
  /// a creator is a different screen. Nothing downstream should tell the two
  /// apart: either way there is no plain profile here to show.
  Future<PublicProfile> getProfile(String userId) async {
    debugPrint('$_tag getProfile → $userId');
    try {
      final resp = await _dio.get('/client/users/$userId/profile');
      debugPrint('$_tag getProfile ← status=${resp.statusCode}');
      final body = resp.data;
      return PublicProfile.fromJson(
        userId,
        body is Map<String, dynamic> ? body : const {},
      );
    } on DioException catch (err) {
      final response = err.response;
      if (response == null) throw const app_ex.NetworkException();
      if (response.statusCode == 404) {
        throw const app_ex.NotFoundException('This profile is unavailable.');
      }
      throw app_ex.ServerException(
          'Could not load this profile: ${response.statusCode}');
    }
  }
}
