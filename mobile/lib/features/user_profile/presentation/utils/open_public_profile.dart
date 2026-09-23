import 'package:flutter/material.dart';
import 'package:jperg_app/core/utils/auth_guard.dart';
import 'package:jperg_app/features/user_profile/data/repositories/public_profile_repository.dart';
import 'package:jperg_app/features/user_profile/presentation/pages/public_profile_page.dart';

/// Opens a person's profile, asking a signed-out viewer to sign in first.
///
/// The sibling of [openPhotographerProfile], and gated for the same reason:
/// the screen it opens carries Follow and Message, neither of which a guest can
/// act on, and the rest of the app already trades a guest's taps for a login
/// sheet. One helper so every surface that grows a tappable person — search
/// today, the followers list next — sends them to the same place.
///
/// The name and face the caller already has travel with the route as a seed,
/// so the profile opens on the person rather than on a spinner.
Future<void> openPublicProfile(
  BuildContext context, {
  required String userId,
  required String userName,
  String? userProfileUrl,
  String username = '',
}) {
  if (userId.isEmpty) return Future.value();

  final profile = PublicProfile.seed(
    id: userId,
    name: userName,
    photoUrl: userProfileUrl,
    username: username,
  );

  return requireAuth(
    context,
    action: () {
      // The login sheet is an async gap, and the surface that was tapped may
      // be gone by the time it closes.
      if (!context.mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PublicProfilePage(profile: profile)),
      );
    },
  );
}
